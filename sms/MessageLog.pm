package MessageLog;

use strict;
use warnings;
use Data::Dumper;

use Redis;
use JSON::XS;
use MessageTask;

my %LOG_LEVELS = (
	INFO  => 1,
	DEBUG => 2,
	WARN  => 3,
	ERROR => 4,
);

my $MAX_MESSAGES_COUNT = 1000;
my $FLUSH_PERIOD = 60;

#######################################

sub new {
	my ($class, %param) = @_;
	my $self = {};
	bless $self, $class;
	$self->{buffer} = [];
	$self->{gearman_host} = $param{gearman_host} || '127.0.0.1';
	$self->{gearman_port} = $param{gearman_port} || 4730;
	return $self;
}

sub error {
	my ($self, $error) = @_;
	if(!defined $error) {
		return $self->{error};
	}
	elsif(!$error) {
		delete $self->{error};
	}
	else {
		$error =~ s/\s+$//;
		$self->{error} = $error;
	}
}

sub connectToRedis {
	my ($self, %redis_cfg) = @_;
	my $redis;
	eval {
		$redis = Redis->new( server => "$redis_cfg{host}:$redis_cfg{port}");
	};
	if($@){
		$self->error("$@");
		return;
	}
	return $redis;
}

sub logToRedis {
	my ($self, %param) = @_;
	
	my $redis_host = $param{host};
	my $redis_port = $param{port};
	my $messages = $param{data};
	return unless ($messages && @$messages);

	my $redis = $self->connectToRedis(host => $redis_host, port => $redis_port);
	return unless $redis;

	my $success_count = 0;
	my $failed_count = 0;
	foreach my $msg(@$messages) {
		my $key = delete $msg->{key};
		my $json = JSON::XS->new->encode($msg);
		my $res;
		eval {
			$res = $redis->rpush($key, $json);
		};
		if($@) {
			$failed_count++;
			next;
		}
		$success_count++;
	}
	if($failed_count) {
		$self->error("Error while saving $failed_count messages");
	}
	return $success_count;
}

sub log {
	my ($self, $msg, $log_level) = @_;

	local $SIG{INT} = sub { $self->on_exit };
	local $SIG{TERM} = sub { $self->on_exit };
	local $SIG{HUP} = sub { $self->on_exit };

	$log_level = uc($log_level);
	return unless(exists $LOG_LEVELS{$log_level});
	$self->{started} = time() unless $self->{started};
	my $msg_data = {
		key => $msg->{key},
		text => $msg->{text},
		time => time(),
		log_level => $log_level,
	};
	push @{$self->{buffer}}, $msg_data;
	if(scalar(@{$self->{buffer}} >= $MAX_MESSAGES_COUNT) || (time() - $self->{started}) > $FLUSH_PERIOD) {
		$self->flush;
	}
}

sub flush {
	my ($self) = @_;
	my $data = $self->{buffer};
	$self->{buffer} = [];

	my $msg_task = new MessageTask;
	$msg_task->addMessageTask(
		host => $self->{gearman_host},
		port => $self->{gearman_port},
		data => JSON::XS->new->encode($data),
	);
	$self->{started} = time();
};

sub on_exit {
	my ($self) = @_;
	$self->flush;
	exit;
}

=head1 NAME

MessageLog - parse messages and store them in Redis

=head1 SYNOPSIS

  use MessageLog;

  $logger = new MessageLog;
  $logger->logToRedis(%parameters)


=head1 CONSTRUCTOR

=head2 MessageLog->new()

Returns a MessageLog object.

=head1 METHODS

=head2 $logger->logToRedis(%parameters)

Save messages to Redis

  my $result = $logger->logToRedis(
    host => $redis_host,
    port => $redis_port,
    data => $messages_array_ref
  );

=head2 $logger->log($msg, $log_level)

Add message to buffer

=head2 $logger->flush()

Create saving messages task and clear buffer


=cut

1;
