#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

use FindBin '$Bin';

use DBI;
use POSIX qw(strftime);
use Date::Parse;
use Net::SMTP::SSL;


eval { require "$Bin/config.pl"; } || die "Unable to load config file, because: $@\n";
use vars qw($db_in_cfg $db_stat_cfg $last_days $delta_pos_percent $delta_neg_percent $notifier $notifier_pass);

#################################################

# Database to get income from
my ($dbh_in, $dbh_stat);
eval {
	$dbh_in = DBI->connect("dbi:mysql:database=$db_in_cfg->{dbname};host=$db_in_cfg->{dbhost};port=$db_in_cfg->{dbport}", $db_in_cfg->{dbuser}, $db_in_cfg->{dbpass}, {RaiseError => 1});
};
if($@) {
	die "Error: $@\n";
}
# Database to save statistics
eval {
	$dbh_stat = DBI->connect("dbi:mysql:database=$db_stat_cfg->{dbname};host=$db_stat_cfg->{dbhost};port=$db_stat_cfg->{dbport}", $db_stat_cfg->{dbuser}, $db_stat_cfg->{dbpass}, {RaiseError => 1});
};
if($@) {
	die "Error: $@\n";
}

# Get and income by hour from inbox table and save statistics

my $sth = $dbh_stat->prepare("SELECT MAX(date_in) FROM income_stats");
$sth->execute();
my $date_from = $sth->fetchrow() || strftime("%F 00:00:00", localtime(time() - $last_days * 24 * 3600));
my $date_to = strftime("%F %H:59:59", localtime(time() - 3600));
print "Get summarized income by hour from $date_from to $date_to\n";

my $time_from = str2time($date_from);
my $time_to = str2time($date_to);
my $income_time = $time_from;

my @income_by_hour;
while($income_time < $time_to) {
	my $hour_income = get_hour_income($dbh_in, $income_time);
	$income_time += 3600;
	next if !$hour_income;
	push @income_by_hour, $hour_income;
	print "$hour_income->{date} - $hour_income->{income}\n";
}

save_hour_income_stat($dbh_stat, \@income_by_hour);

# Check last income, compare with average for current hour and notify if the deviation is too large

my @income_stats = get_hour_income_stats($dbh_stat, $last_days);

if(@income_stats) {
	my $last_income = $income_stats[0];

	print "last_income: $last_income->{date_in} - $last_income->{income_hour}\n";

	my @incomes = map {$_->{income_hour}} @income_stats;

	my @smooth_incomes = smooth(@incomes);
	my $average = average(@smooth_incomes);
	if($average) {
		print "income by hour:\n";
		for(my $i =0; $i <= $#smooth_incomes; $i++) {
			my $delta = sprintf("%.2f", $smooth_incomes[$i] - $average);
			my $delta_percent = sprintf("%.2f", $delta / $average * 100);
			print "  $smooth_incomes[$i]  - delta: $delta  ( $delta_percent % ) \n";
		}

		my $last_delta = sprintf("%.2f", $last_income->{income_hour} - $average);
		my $last_delta_percent = sprintf("%.2f", $last_delta / $average * 100);
		print "\nAverage income by hour: $average\n";
		print "last_income: $last_income->{income_hour}\n";
		print "Last delta: $last_delta ( $last_delta_percent % )\n";

		if($last_delta_percent < -$delta_neg_percent || $last_delta_percent > $delta_pos_percent) {
			notify($dbh_stat, $last_income, $last_delta_percent);
		}
	}
}

print "\n".('='x50)."\n\n";

#################################################

sub notify{
	my ($dbh, $last_income, $last_delta_percent) = @_;
	my $message;
	if($last_delta_percent > $delta_pos_percent) {
		$message = "The last hour ($last_income->{date_in}) income exceeds average by more than $delta_pos_percent%";
	}
	elsif($last_delta_percent < -$delta_neg_percent) {
		$message = "The last hour ($last_income->{date_in}) income is lower than average by more than $delta_neg_percent%";
	}
	if($message) {
		my @recipients = get_recipients($dbh);
		foreach(@recipients) {
			send_gmail($notifier, $notifier_pass, $_->{email}, $message);
		}
		print $message;
	}
}

sub get_recipients {
	my ($dbh) = @_;
	my $recipients = $dbh->selectall_arrayref("SELECT * FROM recipients WHERE active=1", { Slice => {} });
	return () unless($recipients && @$recipients);
	return @$recipients;
}

sub send_gmail {
	my ($from, $pass, $to, $text) = @_;
	my $subj = "Income report";
	print "Send notification Gmail:\n\tfrom: $from\n\tTo: $to\n\tSubj: $subj\n\tText: $text\n";
	my $smtp = Net::SMTP::SSL->new('smtp.gmail.com',
								 Port => 465,
								 Debug => 0);
	$smtp->auth($from, $pass);
	$smtp->mail($from);
	$smtp->to($to);
	$smtp->data();
	$smtp->datasend("From: $from\n");
	$smtp->datasend("To: $to\n");
	$smtp->datasend("Subject: $subj\n");
	$smtp->datasend("\n");
	$smtp->datasend($text."\n");
	$smtp->dataend();
	$smtp->quit;
}

sub smooth {
	my @data = @_;
	return @data unless @data;
	my $average = average(@data);
	return @data unless $average;
	my $max_delta_id = 0;
	my $max_delta = abs($data[0] - $average);
	for(my $i = 0; $i <=$#data; $i++) {
		my $delta = $data[$i] - $average;
		if(abs($delta) > $max_delta) {
			$max_delta_id = $i;
			$max_delta = abs($data[$i] - $average);
		}
	}
	my $max_delta_percent = sprintf("%.2f", abs($max_delta / $average * 100));
	if($max_delta_percent > $delta_neg_percent) {
		splice(@data, $max_delta_id, 1);
		@data = smooth(@data);
	}
	return @data;
}

sub sum {
	my $sum = 0;
	foreach(@_){
		$sum += $_;
	}
	return $sum;
}

sub average {
	return if !@_;
	my $avg = sprintf("%.2f", sum(@_) / scalar(@_));
	return $avg;
}

sub get_hour_income_stats {
	my ($dbh, $days) = @_;
	my @data;
	my $date_from = strftime("%F 00:00:00", localtime(time() - $last_days * 24 * 3600));
	my $sql = "SELECT * FROM income_stats WHERE date_in > ? AND HOUR(date_in) = HOUR(NOW()) ORDER BY date_in DESC";
	my $sth = $dbh->prepare($sql);
	$sth->execute($date_from);
	while(my $row = $sth->fetchrow_hashref()) {
		push @data, $row;
	}
	return @data;
}

sub save_hour_income_stat{
	my ($dbh, $income_stat) = @_;
	return if (!$income_stat || !@$income_stat);
	foreach(@$income_stat){
		my $sql = "REPLACE INTO income_stats(date_in, income_hour) VALUES(?, ?)";
		$dbh->do($sql, {}, $_->{date}, $_->{income});
	}
}

sub get_hour_income {
	my ($dbh, $time) = @_;
	my $time_from = strftime("%F %H:00:00", localtime($time));
	my $time_to = strftime("%F %H:59:59", localtime($time));
	my $sql = "SELECT SUM(system_income2) FROM inbox WHERE date_received BETWEEN ? AND ?";
	my $sth = $dbh->prepare($sql);
	$sth->execute($time_from, $time_to);
	my $income = $sth->fetchrow();
	return if !defined $income;
	return {date => $time_to, income => $income};
}

