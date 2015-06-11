#!/usr/bin/perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin";
use lib "$Bin/libs";

use POSIX qw(WNOHANG strftime setlocale LC_ALL);
use IO::Socket qw(:DEFAULT :crlf);
use Date::Parse;
use DBI;
use URI;
use URI::Escape;
use File::Path qw(make_path);
use Data::Dumper;

use SMSAgregator::Utils::Daemonize;
use SMSAgregator::Utils::SmartLog;
use SMSAgregator::Utils::Restore;
use SMSAgregator::Utils::SimpleSocket;
use Util;

setlocale(LC_ALL, 'en_US.UTF-8');

require "$Bin/config.pl";
use vars qw($__PID $__PORT $__URLS @__PHONES_TEST $__DELIVERY_URL $__STORE_PATH $__LOGS_PATH @__NOT_OK_PHONES);

my $quit = 0;
my $cache = {};

my $store_full_path = $Bin . '/'. $__STORE_PATH;
if( !-d $store_full_path ) {
	eval { make_path($store_full_path); };
}

my $logs_path = $Bin . '/'. $__LOGS_PATH;
if( !-d $logs_path ) {
	eval { make_path($logs_path); };
}

my $oLog = new SMSAgregator::Utils::SmartLog;
$oLog->addSubDir('logconnection', '!logconn', 0);
$oLog->addSubDir('data', '!logreport', 0);
$oLog->addSubDir('delivery_report', '!logdelivery', 0);
$oLog->setDebug(0);
$oLog->init($Bin . '/logs/');

##Daemonize script (if daemon already worked, then current process is down)
my $oDaemon = new SMSAgregator::Utils::Daemonize;
$oDaemon->daemonize;
$oDaemon->writePID($__PID);

##Waiting child process (if exists)
$SIG{CHLD} = sub {
	while(waitpid(-1, WNOHANG) > 0){}
};

local $SIG{INT} = \&exiting;
local $SIG{TERM} = \&exiting;
local $SIG{HUP} = \&exiting;

sub exiting {
	$quit++;
};

my $listen_socket = IO::Socket::INET->new(
	LocalPort => $__PORT, 
	Listen => 200, 
	Proto => 'tcp', 
	Reuse => 1, 
	Timeout => 60 * 60 * 60
);
die "Error while opening socket: $@\n" unless $listen_socket;
warn "Daemon started, thx\n";

#Main cycle work with connections
while(!$quit) {
	next unless my $connection = $listen_socket->accept;

	my $child = fork;
	exit 0 unless defined $child;

	if($child == 0) {
		$listen_socket->close;
		interact($connection);
		exit 0;
	}

	$connection->close;
}

sub interact {
	my $socket = shift;
	STDOUT->fdopen($socket, ">");
	STDIN->fdopen($socket, "<");
	$| = 1;
	my $raw_request = '';
	$socket->sysread($raw_request, POSIX::BUFSIZ);
	chomp $raw_request;

	my %request_data = parse_request($raw_request);
	my $request = $request_data{content} || '';

	userRequest($socket, "Ok", 200);

	unless($request_data{method} and $request_data{method} =~ /^(GET|POST)/) {
		warn "Bad request: $request_data{head_query}\n";
		return;
	}

	my $mode = $request_data{script_name} || '';
	my $query_string = $request_data{query_string} || '';
	my %query = param_from_query($query_string);

	my $timeRun = strftime("%F", localtime);
	my $timeRunHM = strftime("%F %T", localtime);

	if($mode eq '/life_report/u_life_report.php') {
		if(!$query{text} || !$query{from} || !$query{to}) {
			return;
		}

		my %sender_url_param = (
			sender => $query{'to'},
			from   => $query{'from'},
			id     => $query{rid},
		);
		my $sender_url = $__DELIVERY_URL . '?' . param_to_query(%sender_url_param) . "&status=%d&full_status=%A&ext_id=%F";
		my %sendsms_url_param = (
			from => $query{'from'},
			to   => $query{to},
			text => $query{'text'},
		);
		my $url = $__URLS->{SENDSMS}{url}."?user=smssend&pass=hF58KwD2&". param_to_query(%sendsms_url_param) .
			"&smsc=Smsagreg&meta-data=%3Fsmpp%3Fcharging_id%3D12544&dlr-mask=31&dlr-url=" .
			uri_escape($sender_url);
		requestGet($url, $__URLS->{SENDSMS}{store});
		return;
	} elsif($mode eq '/life/index.php') {
		my $ridAdd = (1 + int(rand(9))) . (1 + int(rand(9))) . (1 + int(rand(9))) . (1 + int(rand(9))) . time();
		(my $sender = $query{sender}) =~ s/\+//g;
		my $text = $query{text} || '';
		$text =~ s/§/_/g;
		$text =~ s/¡/@/g;
		$text = uri_escape($text);
		my $date = strftime("%Y-%m-%d %H:%M:%S", localtime(str2time($query{time}) + 10800));
		$date = uri_escape($date);
		my $urlNew = '';
		my $recipient = $query{recipient} || '';
		if($query{recipient} && $query{recipient} ~~ @__PHONES_TEST) {
			$urlNew = $__URLS->{FIRST}{url} . "incore/?from=".$sender."&sms_status=mt&sms_id=li".$ridAdd."&date=".$date."&msg=".$text."&short_number=".$recipient;
		}
		else {
			$urlNew = $__URLS->{FIRST}{url} . "smsbil/?from=".$sender."&sms_status=mt&sms_id=li".$ridAdd."&date=".$date."&msg=".$text."&short_number=".$recipient;
		}
		my $res = requestGet($urlNew, $__URLS->{FIRST}{store});
	} elsif($mode eq '/life/delivery_report.php') {
		(my $sender = $query{sender}) =~ s/\+//g;
		my $status = int($query{status});
		my $pay_status = '';
		if($status == 16 or $status == 2 or $status == 0) {
			$pay_status = 'not_ok';
		} elsif($status != 8) {
			$pay_status = 'ok';
		}
		my $rid = lc $query{id};
		$rid = 'li' . $rid unless $rid =~ /^li/;
		my $ext_id = $query{ext_id} || '';
		my $urlNew = $__URLS->{STATUS}{url} . '?from=' . $sender . '&pay_status=' . $pay_status . '&sms_status=mt&sms_id=' . $rid . '&ext_id=' . $ext_id;
		
		if($status != 8) {
			sleep 3;
			my $res = requestGet($urlNew, $__URLS->{STATUS}{store}) || '';
			warn "!logdelivery $sender . ' -|- ' . $rid . ' -|- ' . $status . ' -|- ' . $pay_status . ' -|- ' . $res\n";
		}
		if ($pay_status eq 'not_ok') {
			if ($query{from} && $query{from} ~~ @__NOT_OK_PHONES) {
				my $mess_free = "Vash SMS zapros otklonen. Summa na Vashem schete menshe stoimosti zaprashivaemoi SMS uslugi. Popolnite Vash mobilnyi schet i povtorite popytku.";
				my $url1 = $__URLS->{SENDSMS}{url}."?user=smssend&pass=hF58KwD2&from=".$query{from}."&to=".$sender."&smsc-id=smsagreg_bulk&text=".uri_escape($mess_free);
				requestGet($url1, $__URLS->{SENDSMS}{store});
			}
		}
	} else {
		warn "Unknown mode: $mode\n";
		return 0;
	}

	return 1;
}

sub userRequest {
	my ($socket, $request, $status) = @_;
	return if !$request;

	my $datetime = strftime("%a, %d %b %Y %T", gmtime);
	my $length = length $request;
	my $headers = "HTTP/1.1 $status 
Date: $datetime GMT
Server: SMS-Agregator-Life-Server 1.0
Content-Language: en
Content-Type: text/html; charset=utf-8
Content-Length: $length
Connection: close" . CRLF . CRLF;
	print $socket $headers;
	print $socket $request;
	close $socket;
}

sub requestGet {
	my ($url, $store_file) = @_;

	my %request_param = parseUrl($url);
	return unless %request_param;

	my $request = 'GET ' . $request_param{path} . ' HTTP/1.1' . CRLF . CRLF;
	my $result;
	eval {
		my $oSocket = new SMSAgregator::Utils::SimpleSocket($request_param{host}, $request_param{port});
		$result = $oSocket->send($request);
	};
	if($@) {
		my $oRestore = SMSAgregator::Utils::Restore->new($__STORE_PATH);
		return if(!$oRestore);
		$oRestore->store($store_file, $request);
		return;
	}
	return $result;
}

1;
