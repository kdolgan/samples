package Adnet::Log::Writer;

use strict;
use warnings;
use Data::Dumper;

use FindBin '$Bin';
use POSIX qw(strftime);
use Fcntl qw(:flock SEEK_END);

use Adnet::Log;

use vars qw(@ISA);
@ISA = qw( Adnet::Log );

#########################################

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	my $log_dir;
	if($self->{log_path}) {
		if($self->{log_path} =~ /^\//) {
			$log_dir = $self->{log_path};
		}
		else {
			$log_dir = $Bin.'/'.$self->{log_path};
		}
	}
	else {
		$log_dir = $Bin;
	}
	$self->{log_file} = $log_dir.'/'.$self->{log_name};
	return $self;
}

sub start {
	my ($self) = @_;
	open(my $fh, ">>", $self->{log_file}) or die "Log error: $!\n";
	$self->{log_fh} = $fh;
	$self->{time_start} = time();
	return $fh;
}

sub write_log_line {
	my ($self, $data) = @_;
	return unless($data && %$data);
	my $line = $self->prepage_log_line($data);
	my $fh = $self->{log_fh};
	flock($fh, LOCK_EX);
	seek($fh, 0, SEEK_END);
	my $time = strftime("%Y-%m-%d %H:%M:%S", localtime());
	print $fh "[ $time ] $line\n";
	flock($fh, LOCK_UN);
}

sub archive_log {
	my ($self, $arc_suffix) = @_;
	my $log_size = (stat($self->{log_file}))[7];
	return unless $log_size;
	open(LOG, "+<", $self->{log_file}) or die "Log reading error: $!\n";
	my $log_archive = $self->{log_file}.'-'.$arc_suffix;

	print "***** Save log_archive: $log_archive\n";

	flock(LOG, LOCK_EX) or die "Cannot lock - $!\n";
	seek(LOG, 0, 0);
	open ARC, ">>$log_archive" or die "Cannot write - $!\n";
	flock(ARC, LOCK_EX) or die "Cannot lock - $!\n";
	while(<LOG>) {
		print ARC;
	}
	flock(ARC, LOCK_UN);
	close ARC;
	seek(LOG, 0, 0);
	truncate(LOG, 0);
	flock(LOG, LOCK_UN);
	close LOG;
}

sub write {
	my ($self, $data) = @_;
	$self->write_log_line($data);
	return unless $self->{arc_period};
	my $now = time();
	my $delta = $now - $self->{time_start};
	my $remainder = $delta % $self->{arc_period};
	return if $remainder;
	my $arc_suffix = strftime("%Y%m%d%H%M%S", localtime());
	$arc_suffix .= '-'.$self->{host_suffix} if $self->{host_suffix};
	my $log_archive = $self->{log_file}.'-'.$arc_suffix;
	if($now - $self->{time_start} > $self->{arc_period} && !-e $log_archive) {
		$self->archive_log($arc_suffix);
	}
}

=head1 NAME

Adnet::Log::Writer - Base logging package

=head1 SYNOPSIS

  use Adnet::Log::Writer;

  my $logger = Adnet::Log::Writer->new(
	host_suffix => $_HOST_SUFFIX,
	log_path => $_LOG_PATH,
	log_name => $_LOG_NAME,
	arc_period => $_ARC_PERIOD,
	separator => $_SEPARATOR || "\t",
	fields => \@_FIELDS,
  );

=head1 METHODS

=head2 start

  my $log_fh = $logger->start(); # open log and return file hanndler

=head2 archive_log

  $logger->archive_log($arc_suffix); # archive log on the fly

=head2 write_log_line

  $logger->write_log_line($data); # wrile data string to log file

=head2 write

  $logger->write($data); # the same as $logger->write_log_line, but also archive log periodically when $_ARC_PERIOD is defined

=cut

1;
