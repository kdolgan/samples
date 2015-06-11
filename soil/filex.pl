#!/usr/bin/perl

use strict;

use POSIX qw(WNOHANG setsid);
use IO::File;
use Sys::Syslog qw(:DEFAULT setlogsock);

#####################################

my $dirIN = "/smartoil/filex/ftpin";         # каталог приема по FTP
my $dirOUT = "/smartoil/filex/ftpout";       # каталог отправки по FTP
my $dirIMP = "/smartoil/filex/imp";          # каталог импорта
my $dirEXP = "/smartoil/filex/exp";          # каталог экспорта
my $impex = "/smartoil/filex/imit-impex.pl";      # модуль импорта-экспорта
my $logfile = "filex.log";                             # лог-файл
my $pidfile = "/smartoil/filex/filex.pid";  # PID-файл

my $ftpdir = "ftp://192.168.1.1/azsftp/"; # удаленный каталог для загрузки файлов
my $ftpuser = "anonymous";                # FTP - пользователь
my $ftppass = "1";                        # FTP - пароль

my $pppId = 'ppp1';              # ppp-интерфейс
my $ctrlmask = '$$$';            # расширение контрольных файлов 
my $interval = 5;                # интервал опроса каталога
my $ppptimeout = 60;             # таймаут на подключение
my $pppn = 3;                    # к-во попыток дозвона
my $pppIncomingCmd = "/usr/sbin/pppd call incoming ttyS1"; # команда запуска pppd для входящих звонков
my $pppOfficeCmd = "/usr/sbin/pppd call office ttyS1";     # команда запуска pppd для отправки файлов
my $pppConfigCmd = "/sbin/ifconfig";                       # команда проверки ppp-интерфейса

my $pppdpid;

#####################################

foreach($dirIN, $dirOUT, $dirIMP, $dirEXP){
	if(!-d $_){
		die "Directory \"$_\" doesn't exist\nDie...\n\n";
	}
}

my $runmode = shift;

if($runmode eq '-d'){
	my $cmd = shift;
	openlog('filex.pl', 'cons', 'user');
	setlogsock('unix');
	if($cmd eq 'start'){
		my $fh = openPID($pidfile);
		my $pid = daemonize();
		print $fh $pid;
		close $fh;
		syslog('info', '**** File Transmitter started ****');
	}
	elsif($cmd eq 'stop'){
		my $fh = IO::File->new($pidfile) or die "Can't open PID file\n\n";
		my $pid = <$fh>;
		my $c = kill 'TERM', $pid;
		close $fh;
		unlink $pidfile or die "Can't remove PID file\n\n";
		print "\n=== File Transmitter stopped ===\n\n";
		exit;
	}
	else{
		usage();
	}
}
elsif($runmode ne '-c'){
	usage();
}
else{
	print "\n**** File Transmitter started [$$] ****\n\n";
}
#============================
$SIG{__DIE__} = \&myDie;
$SIG{INT} = $SIG{TERM} = \&myTerm;
$SIG{CHLD} = 'IGNORE';
$SIG{ALRM} = sub{die "timeout"};
#============================
$pppdpid = pppdIncomingInit();
sleep 5;
if($pppdpid && kill(0, $pppdpid)){
	printMessage('info', "PPPD for incomings initialized [$pppdpid]");
}
else{
	printMessage('err', "Can't run pppd for incomings");
	die "Transmitter terminated";
}

while(1){
	prepareForImport();
	prepareForExport();
	sendFiles();
	sleep($interval);
}

#####################################

sub prepareForExport{	# Перенос экспортируемых файлов в ФТП-OUT каталог
	my $workdir = `pwd`;
	chdir $dirEXP;
	foreach my $file(getfiles($dirEXP)){
		my $cmd = escapeString("mv $file $dirOUT");
		my $code = system($cmd);
		if(!$code){
			mkCtrlFile("$dirOUT/$file");
			printMessage('info', "Prepared for FTP: $file");
		}
		else{
			printMessage('err',"Error ($code) preparing for FTP: $file");
		}
	}
	chdir $workdir;
}

sub sendFiles{	# Отправка файлов из ФТП-OUT
	my $workdir = `pwd`;
	my $pppIsRunning = undef;
	my $i = 0;
	chdir $dirOUT;
	my @filesforsend = ();
	foreach my $file(getfiles($dirOUT)){
		my $ctrlfile = "$file.$ctrlmask";
		if(-e $ctrlfile && (stat($ctrlfile))[7] == 0){
			push @filesforsend, $file;
		}
	}
	if(@filesforsend){
		dropIncoming();
		sleep 1;
		while($i < $pppn && !$pppIsRunning){
			$pppdpid = dial();
			if(!$pppdpid){
				printMessage('err', "Can't run pppd");
				return;
			}
			$pppIsRunning = pppDetect();
			if($pppIsRunning){
				foreach my $file(@filesforsend){
					sendFile($file);
				}
			}
			else{
				printMessage('err', "Can't run pppd");
			}
			hangUp();
			$i++;
		}
		sleep 5;
		$pppdpid = pppdIncomingInit();
		if($pppdpid){
			printMessage('info', "pppd for incomings initialized [$pppdpid]");
		}
		else{
			printMessage('err', "Can't run pppd for incomings");
		}
	}
	chdir $workdir;
}

sub sendFile{	# Отправка 1 файла из ФТП-OUT
	my $file = shift;
	my $ctrlfile = "$file.$ctrlmask";
	my $ftpcmd = escapeString("curl -# -u $ftpuser:$ftppass -T $file $ftpdir >/dev/null");
	my $code = system($ftpcmd);
	my $code;
	if(!$code){
		$ftpcmd = escapeString("curl -# -u $ftpuser:$ftppass -T $ctrlfile $ftpdir >/dev/null");
		$code = system($ftpcmd);
		if(!$code){
			printMessage('info', "Sent: $file");
			unlink $file;
			unlink $ctrlfile;
		}
		else{
			printMessage('err', "Sending error ($code) : $ctrlfile");
		}
	}
	else{
		printMessage('err', "Sending error ($code): $file");
	}
}

sub prepareForImport{	# Перенос принятых по ФТП файлов в каталог для импорта
	my $workdir = `pwd`;
	chdir $dirIN;
	foreach my $file(getfiles($dirIN)){
		my $ctrlfile = "$file.$ctrlmask";
		if(-e $ctrlfile && (stat($ctrlfile))[7] == 0){
			my $cmd = escapeString("mv $file $dirIMP");
			my $code = system($cmd);
			if(!$code){
				printMessage('info', "Transfered: $file");
				unlink($ctrlfile);
				$code = system("$impex -imp");
				if(!$code){
					printMessage('info', "Imported $file");
				}
				else{
					printMessage('err', "Import error ($code): $file");
				}
			}
			else{
				printMessage('err', "Transfer error ($code): $file");
			}
		}
	}
	chdir $workdir;
}

sub daemonize {	# Демонизируемся
	die "Can't fork" unless defined(my $child = fork);
	if($child){exit 0;}
	print "\nTransmitter started. PID=$$\n";
	setsid();
	open(STDIN, "</dev/null");
	open(STDOUT, ">/dev/null");
	open(STDERR, ">&STDOUT");
	chdir '/';
	$ENV{PATH} = '/bin:/usr/bin:/usr/local/bin';
	umask(0);
	return $$
}

sub openPID {	# Открываем PID-файл, если уже есть - проверяем наличие процесса, если запущен- вывливаемся
	my $file = shift;
	if(-e $file){
		my $fh = IO::File->new($file) || return;
		my $pid = <$fh>;
		if(kill 0 => $pid){die "Process width pid=$pid already running";}
		warn "Removing PID file\n";
		die "Can't unlink PID file $file" unless(-w $file && unlink $file)
	}
	return IO::File->new("$file", O_WRONLY|O_CREAT|O_EXCL, 0644) or die "Can't create $file: $!\n";
}

sub mkCtrlFile{	# Создаем контрольный файл нулевой длины с расширением '$$$'
	my $file = shift;
	my $ctrlfile = "$file.$ctrlmask";
	open FF, ">$ctrlfile" or printMessage('err',"Can't create $ctrlfile");
	close FF;
	return $ctrlfile;
}

sub usage{
	print "\n\tUsage: $0 [-c | -d start|stop]\n";
	print "\t\t-c \t\t- console output\n";
	print "\t\t-d start|stop \t- daemon\n\n";
	exit;
}

sub myDie{
	my $msg = "Die....!!!!!!!!!!";
	dropIncoming();
	printMessage('err', $msg);
	die;
}

sub myTerm{
	my $msg = "File Transmitter terminated !!!!!!!!!!";
	dropIncoming();
	printMessage('err', $msg);
	exit;
}

sub getResult{	# Результат выполнения внешней команды
	my $cmd = shift;
	my $code = undef;
	$? = undef;
	open FF, "$cmd |";
	my $errtext = <FF>;
	close FF;
	$code = $?;
	return ($code, $errtext);
}

sub escapeString{
	my $str = shift;
	$str =~s/\$/\\\$/g;
	return $str;
}

sub printMessage{	# Вывод сообщений в syslog либо в консоль
	my $priority = shift;
	my $msg = shift;
	if($runmode eq '-d'){
		syslog($priority, $msg);
	}
	else{
		print "$priority:\t$msg\n";
	}
}

sub dial{
	printMessage('info', "Dialing........");
	my $pppdpid = fork();
	if(!$pppdpid){
		exec($pppOfficeCmd);
	}
	return $pppdpid;
}

sub hangUp{
	if($pppdpid && kill(0, $pppdpid)){
		my $code = system("kill -9 $pppdpid");
		if(!$code){
			printMessage('info', "Connection closed (pppdpid=$pppdpid) ");
			undef $pppdpid;
		}
		else{
			printMessage('err', "Can't close connection (pppdPID=$pppdpid)");
		}
	}
}

sub pppdIncomingInit{
	my $pppdpid = fork();
	if(!$pppdpid){
		exec($pppIncomingCmd);
	}
	return $pppdpid;
}

sub dropIncoming{
	if($pppdpid && kill(0, $pppdpid)){
		my $code = system("kill -9 $pppdpid");
		if(!$code){
			printMessage('info', "Close incoming connection (pppdPID=$pppdpid)");
			undef $pppdpid;
		}
		else{
			printMessage('err', "Can't kill $pppdpid");
		}
	}
}

sub pppDetect{	# Смотрим ifconfig - поднялся ли pppd
	my $pppOK = undef;
	eval{
		alarm($ppptimeout);
		while(!$pppOK){
			open FF, "$pppConfigCmd |";
			while(<FF>){
				if(/^$pppId/){
					$pppOK = 1;
					last;
				}
			}
			close FF;
		}
		alarm(0);
	};
	return $pppOK;
}

sub getfiles{	# Список файлов каталога
	my $dir = shift;
	opendir DIR, $dir;
	my @files = grep { -f "$dir/$_" } readdir(DIR);
	closedir DIR;
	return @files;
}

