#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

use FindBin '$Bin';

use POSIX qw(strftime);
use Date::Parse;
use DBI;

use Mailer;

eval { require "$Bin/config.pl"; } || die "Unable to load config file, because: $@\n";
use vars qw($_TAIL $_LOG $_NOTIFY_LOG %_ERR_CFG %_DB_CFG $_OPERATOR_ID);

#########################################

my $errors = {};
my $err_stats = {};

open IN, "$_TAIL -f $Bin/$_LOG |";
while(my $line = <IN>){
	chomp $line;
	if($line =~ /(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}).+\s+command_status:\s+(\d+) = (0x[0-9a-z]+)/i) {
		my ($date, $dec_code, $error_code) = ($1, $2, $3);
		if($_ERR_CFG{$error_code}  || $error_code eq '0x00000000') {
			my $time = str2time($date);

			my $error_info = { code => $error_code, time => $time };
			change_error_stats($err_stats, $error_info);
			next if $error_code eq '0x00000000';

			if(!exists($errors->{$error_code}) || !@{$errors->{$error_code}}) {
				$errors->{$error_code} = [ $error_info ];
				next;
			}

			push @{$errors->{$error_code}}, $error_info;

			my $err_count = scalar(@{$errors->{$error_code}});
			my $err_first_time = $errors->{$error_code}[0]{time};
			my $dt = $time - $err_first_time;
			my $chk_count = $err_count > $_ERR_CFG{$error_code}->{maximum} ? 'more' : 'less';
			my $chk_time = $dt <= $_ERR_CFG{$error_code}->{pertime} ? 'less' : 'more';

			if($dt > $_ERR_CFG{$error_code}->{pertime} && $err_count <= $_ERR_CFG{$error_code}->{maximum}) {
				while(@{$errors->{$error_code}} && ($time - $errors->{$error_code}[0]{time}) > $_ERR_CFG{$error_code}->{pertime} ) {
					shift @{$errors->{$error_code}};
				}
				next;
			}
			if($err_count > $_ERR_CFG{$error_code}->{maximum} && $dt <= $_ERR_CFG{$error_code}->{pertime}) {
				if(notify($errors->{$error_code})) {
					$errors->{$error_code} = [ $error_info ];
				}
			}
		}
	}
}
close IN;

#########################################

sub change_error_stats {
	my ($err_stats, $error_info) = @_;

	my $error_code = $error_info->{code};
	my $error_time = $error_info->{time};

	if(!exists($err_stats->{$error_code})) {
		my $start_date = strftime("%F %H:00:00", localtime($error_time));
		my $start_time = str2time($start_date);
		$err_stats->{$error_code} = { count => 1, time_start => $start_time };
	}
	else {
		$err_stats->{$error_code}{count}++;
		my $old_start_time = $err_stats->{$error_code}{time_start};
		if(($error_time - $old_start_time) >= 3600) {
			my $new_start_date = strftime("%F %H:00:00", localtime($error_time));
			my $new_start_time = str2time($new_start_date);
			if(save_error_stats($error_code, $err_stats->{$error_code})) {
				$err_stats->{$error_code} = { count => 1, time_start => $new_start_time };
			}
		}
	}
}

sub save_error_stats {
	my ($error_code, $stats) = @_;

	if($error_code =~ /0x\d*/) {
		$error_code = hex($error_code);
	}
	my $error_count = $stats->{count};
	my $time_start = strftime("%F %H:00:00", localtime($stats->{time_start}));
	my $dbh = DBI->connect_cached("dbi:mysql:database=$_DB_CFG{dbname};host=$_DB_CFG{dbhost};port=$_DB_CFG{dbport}", $_DB_CFG{dbuser}, $_DB_CFG{dbpass});
	return unless $dbh;
	my $sql = "INSERT INTO kannel_errors (err_code, err_count, time_start, operator_id) VALUES(?, ?, ?, ?)";
	$dbh->do($sql, {}, $error_code, $error_count, $time_start, $_OPERATOR_ID);
	return 1;
}

sub notify {
	my ($errors) = @_;
	return unless @$errors;
	my $err_count = scalar(@$errors);
	my $error_code = $errors->[0]{code};
	my $t_first = strftime("%F %T", localtime($errors->[0]{time}));
	my $t_last = strftime("%F %T", localtime($errors->[$#$errors]{time}));
	my $message = "Error $error_code occured $err_count times from $t_first to $t_last";
	Mailer->send($message);
	my $log_file = "$Bin/$_NOTIFY_LOG";
	open LOG, ">>$log_file";
	print LOG $message."\n";
	close LOG;
	return 1;
}

