#!/usr/bin/perl

use strict;
use Data::Dumper;

##########################################
my $defpath = "./def";
my $binpath = "./bin";
my $libpath = "./lib";
my $cfgfile = "$defpath/modules.default";

my $isql = "/usr/local/firebird/bin/isql";

my $SMARTOIL_ROOT_DIR;
my $error;

my $pagesizemax = 20;
my $pagesize;
my $first = 0;
my ($x0, $y0, $x1, $y1) = (8, 6, 4, 4);
my %ports = ();
my $sections = {}; 
my $dbparams = {};
my @trk_list = ();
my %ports = ();
my $remroot;
my $fr_num;
##########################################
my $azs_cfg = {
		'1azsname' => 'АЗС N1',
		'2address' => 'пр.Ленина 13',
		'3phone' => '223-33-22',
		'4jur_addr' => 'пр.Ленина 14',
		'5ip' => 'localhost',
		'6fr' => '123000',
};
my $usr_cfg = {
		'1name' => 'Иванов',
		'2name' => 'Петр',
		'3name' => 'Сидорович',
		'birth' => '01.01.1977',
		'educ' => 'среднее',
		'prof' => 'администратор',
		'sex' => '1',
		'state' => '0',
		'xpassw' => '1',
};
##########################################
my $so_module = {'pilot' => { 'file' => 'pilot', 'descr' => 'Управляющий модуль'},
		'cr' => { 'descr' => 'Кардридер' },
		'pump' => { 'file' => 'pump', 'descr' => 'Модуль ТРК' },
		'struna' => { 'file' => 'struna', 'descr' => 'Уровнемер' },
		'dialog' => { 'file' => 'soildialog', 'descr' => 'Интерфейс' },
		'libfilex' => { 'descr' => 'Модуль обмена файлами' },
		'common' => { 'descr' => 'Общие параметры' },
		'database' => { 'descr' => 'База данных' },
		'shop' => { 'file' => 'soilshop', 'descr' => 'Магазин' }
		};
my %names = (	'pilot' => 'Управляющий модуль',
		'pump' => 'Модуль ТРК',
		'butrk' => 'Блок управления ТРК',
		'cr' => 'Кардридер',
		'shop' => 'Магазин',
		'libfilex' => 'Модуль обмена файлами',
		'database' => 'База данных',
		'trk' => 'Топливораздаточная колонка',
		'port' => 'Порт',
		'fr' => 'Фискальный регистратор',
		'dialog' => 'Интерфейс',
		'libfilex' => 'Модуль обмена файлами',
		'cardreader' => 'Кардридер',
		'supported_cardreaders' => 'Поддерживаемые типы',
		'valid_centers' => 'Разрешенные центры выдачи карт',
		'struna' => 'Уровнемер',
		'db_password' => 'Пароль к базе',
		'db_path' => 'Путь к файлу базы',
		'db_user' => 'Пользователь',
		'host' => 'Хост/IP-адрес упр. комп-ра',
		'conn_attempts' => 'Количество попыток',
		'est_timeout' => 'Таймаут попытки',
		'pingdelta' => 'Интервал опроса',
		'general_type' => 'Тип библиотеки',
		'module_name' => 'Название модуля',
		'int_cfgbu_trknum' => 'К-во рабочих каналов БУТРК',
		'int_cfgbu_opspresent' => 'Наличие охранно-пож. сигн-и',
		'int_cfgbu_port1present' => 'Порт PC',
		'int_cfgbu_port1speed' => 'Скорость порта PC',
		'int_cfgbu_port2present' => 'Порт фискального устр-ва',
		'int_cfgbu_port2speed' => 'Скорость фискального устр-ва',
		'int_cfgbu_maxdoze' => 'Макс. доза на канале',
		'int_cfgbu_maxtrknum' => 'Макс. возм. кол-во колонок',
		'typeofpump' => 'Режим работы заправки',
		'int_cfgtrk_chready' => 'Канал включен',
		'int_cfgtrk_guns' => 'К-во пистолетов на канале',
		'int_cfgtrk_impperlitt' => 'К-во импульсов на литр',
		'int_cfgtrk_waitonkl1' => 'Задержка на вкл. клапана 1',
		'int_cfgtrk_waitonkl2' => 'Задержка на вкл. клапана 2',
		'int_cfgtrk_offkl1' => 'Время откл. 2 клапана',
		'int_cfgtrk_waitimp' => 'Время ожидания импульса',
		'int_cfgtrk_plogic' => 'Логика пистолета для пуска',
		'int_cfgtrk_glogic' => 'INT_CFGTRK_GLOGIC',
		'devname' => 'Порт (устройство)',
		'baudrate' => 'Скорость порта',
		'PARENB' => 'Откл. бит четности',
		'PARODD' => 'Откл. бит нечётности',
		'INPCK' => 'INPCK',
		'CS8' => '8 битов данных',
		'CSTOPB' => 'Установить стоповый бит',
		'CREAD' => 'CREAD',
		'HUPCL' => 'HUPCL',
		'CLOCAL' => 'Не менять польз-ля порта',
		'VTIME' => 'Задержка в миллисекундах',
		'VMIN' => 'Мин. к-во символов',
		'root' => 'Корневой каталог',
		'accepted' => 'Принятые задания',
		'getting' => 'Принимаемые задания',
		'dirinfo' => 'Название контр. файла',
		'forward' => 'Отправленные задания',
		'performing' => 'Отправляемые задания',
		'prepared' => 'Подготавливаемые задания',
		'notcomlete' => 'Незавершенные задания',
		'device' => 'Дисковод',
		'remroot' => 'Каталог для монтирования',
		'client_list' => 'Список клиентов',
		'name' => 'Название',
		'reformat' => 'Переформатирование карты',
		'check_write' => 'Проверка записи',
		'check_attempts' => 'К-во попыток перезаписи',
		'serial' => 'Серийный номер',
		'instance' => 'Экземпляр',
		'file' => 'Файл',
		'name' => 'Название АЗС',
		'address' => 'Адрес',
		'phone' => 'Телефон',
		'jur_addr' => 'Юридический адрес',
		'ip' => 'IP-адрес',
  		'1azsname' => 'Название АЗС',
  		'2address' => 'Адрес',
  		'3phone' => 'Телефон',
  		'4jur_addr' => 'Юридический адрес',
  		'5ip' => 'IP-адрес',
  		'1name' => 'Фамилия',
  		'2name' => 'Имя',
  		'3name' => 'Отчество',
  		'birth' => 'День рождения',
  		'educ' => 'Образование',
  		'prof' => 'Профессия',
  		'sex' => 'Пол (0-Ж, 1-М)',
  		'state' => 'Сем. полож. (0-Хол, 1-Жен)',
  		'xpassw' => 'Пароль',
  		'6fr' => 'Номер фиск. рег-ра',
		);
##########################################
#my $pid = `ps -aux |grep /pilot | grep -v grep`;
#if($pid){ mydie("Pilot is running. Stop it and try again. \n$pid\n\n"); }
my $quick = selectinstalltype();		#Выбор типа установки
################################
$SMARTOIL_ROOT_DIR = setpath();			# Путь для установки

my @modules = ('pilot', 'pump', 'cr', 'dialog', 'shop', 'struna');
my $selected = checkselected(\@modules);			# список выбранных модулей

my $config = getconfig($cfgfile);		# полный default-ный конфиг из modules.conf
#$fr_num = $config->{'dialog'}{'1'}{'fr'}{'serial'};
my $db_selected = delete $selected->{'database'};

if($selected->{'shop'}){ $selected->{'dialog'} = 1; }
if($selected->{'cr'}){ $selected->{'dialog'} = 1; }
if($selected->{'dialog'}){ $selected->{'libfilex'} = 1; }

foreach(keys %$selected){ if(!-d "$SMARTOIL_ROOT_DIR/$_"){mkdir "$SMARTOIL_ROOT_DIR/$_", 0777 or mydie("Can't create $SMARTOIL_ROOT_DIR/$_: $!"); } }

my $shop_selected = delete $selected->{'shop'};
my $common = delete $config->{'common'};		# параметры связи и путь к базе
my $pilot = delete $config->{'pilot'};			# адрес и порт пилота
my $pilot_selected = delete $selected->{'pilot'};

my $necessary_modules = delete $pilot->{'necessary_modules'};
my $libfilex = delete $common->{'libfilex'};	# libfilex - нужна только диалогу ????
$libfilex->{'01'}{'root'} = "$SMARTOIL_ROOT_DIR/filexroot/";
$libfilex->{'01'}{'remroot'} = "$SMARTOIL_ROOT_DIR/mnt/";
$config->{'dialog'}{'libfilex'} = $libfilex;	# 

if(!$selected->{'cr'}){ delete $config->{'dialog'}{1}{'cardreader'}; }
foreach(keys %$config){
  if(!$selected->{$_}){ delete $config->{$_}; }
}

#---------------------------
my $quick_m = $quick;				# Для общих параметров сбрасываем флаг быстрой установки
undef $quick;
################################
my $commonconf = {%$common, %$pilot};

my $connparams = {
			'conn_attempts' => delete $commonconf->{'conn_attempts'},
			'est_timeout' => delete $commonconf->{'est_timeout'},
			'pingdelta' => delete $commonconf->{'pingdelta'},
		};

if(!$pilot_selected && !$selected->{'dialog'}){		# параметры для файлов module.conf
  foreach(keys %$commonconf){			# если ни пилот, ни база  не выбраны, параметры базы не нужны
    if(/^db_/){ delete $commonconf->{$_}; }
  }
}
if(!%$selected && !$pilot_selected){
  foreach(keys %$commonconf){			# если выбрана только база, параметры сети не нужны
    if(!/^db_/){ delete $commonconf->{$_}; }
  }
}
if($config->{'dialog'}{'libfilex'} && !$pilot_selected){ $commonconf->{'remroot'} = $config->{'dialog'}{'libfilex'}{'01'}{'remroot'}; }
while(1){
  $commonconf = editparams("Общие параметры", $commonconf);
  foreach(keys %$connparams){ $commonconf->{$_} = $connparams->{$_}; }
  $error = checkDBconnect($commonconf->{db_path}, $commonconf->{db_user}, $commonconf->{db_password});
    if($error){ next; }
    else{
      $fr_num = getval($commonconf, "select SERIAL_NUM from cash_register where CASH_REG_ID=1", 'SERIAL_NUM');
      ($azs_cfg, $usr_cfg) = set_azs_data($commonconf->{db_path}, $commonconf->{db_user}, $commonconf->{db_password});
      $config->{'dialog'}{'1'}{'fr'}{'serial'} = $azs_cfg->{'6fr'};
    }
  last;
}
if($config->{'dialog'}{'libfilex'} && !$pilot_selected){
  $remroot = delete $commonconf->{'remroot'};
}

$commonconf->{'pilot_host'} = $commonconf->{'host'};	# В module.conf должно быть pilot_host и pilot_port
$commonconf->{'pilot_port'} = $commonconf->{'port'};	# в отличие от файла pilot.conf
delete $commonconf->{'host'};
delete $commonconf->{'port'};
clearscreen();
$quick = $quick_m;
#---------------------------
#---------------------------
if($pilot_selected){
  my $trk = delete $config->{'pump'}{'butrk'}{1}{'trk'}{0};
  if($selected->{'pump'}){			 # Номера колонок
    my $trk_list =  gettrklist($commonconf->{db_path}, $commonconf->{db_user}, $commonconf->{db_password});
    foreach(@$trk_list){
      $config->{'pump'}{'butrk'}{1}{'trk'}{$_ - 1} = $trk;
    }
  }
  foreach my $module_name(sort keys %$selected){
    my $curcfg = $config->{$module_name};
    $curcfg = configmodule($module_name, $curcfg);
  }
#------------------------
  $config->{'common'} = $commonconf;
  if($config->{'dialog'}{'libfilex'}){
    $config->{'common'}{'libfilex'} = delete $config->{'dialog'}{'libfilex'};
    $remroot = $config->{'common'}{'libfilex'}{'01'}{'remroot'};
  }
#------------------------
# Изврат с магазином
  if($shop_selected){
    $config->{'shop'} = $config->{'dialog'};
  }
  if($config->{'dialog'}{'1'}{'fr'}{'serial'}){$config->{'dialog'}{'1'}{'fr'}{'serial'} =~s/ /_/g }
}
#------------------------
if($remroot && !-d $remroot){ mkdir $remroot, 0777 or mydie("Can't create $remroot: $!"); }
#------------------------
foreach(keys %$config){ makeconfigsection($_, $config->{$_}); }
#------------------------
clearscreen();
print "\nWriting configuration files \n";
#-- Write module.conf for selected modules --
if($pilot_selected){				# запись pilot.conf
  my $cfg = { 'pilot' => { 'host' => $commonconf->{'pilot_host'}, 'port' => $commonconf->{'pilot_port'} } };
  writeconf($cfg, "$SMARTOIL_ROOT_DIR/pilot/pilot.conf");
  writeconf($sections, "$SMARTOIL_ROOT_DIR/pilot/modules.conf");
  delete $selected->{'pilot'};
}
if($shop_selected){ $selected->{'shop'} = 1; }

delete $commonconf->{'libfilex'};

foreach(sort keys %$selected){			# запись всех module.conf
  $commonconf->{'module_name'} = $_;
  $commonconf->{'module_number'} = 1;
  delete $commonconf->{'db_path'};
  delete $commonconf->{'db_user'};
  delete $commonconf->{'db_password'};
  my $cfg = {'common' => $commonconf};
  writeconf($cfg, "$SMARTOIL_ROOT_DIR/$_/module.conf");
}
if($pilot_selected){ $selected->{'pilot'} = 1; }
print "\nCopy executables \n";
foreach(sort keys %$selected){
   if($so_module->{$_}{'file'}) {
     fcopy("$binpath/$so_module->{$_}{'file'}", "$SMARTOIL_ROOT_DIR/$_/$so_module->{$_}{'file'}");
     chmod 0755, "$SMARTOIL_ROOT_DIR/$_/$so_module->{$_}{'file'}";
   }
}
if(%$selected){
  if(!-d "$SMARTOIL_ROOT_DIR/lib"){mkdir "$SMARTOIL_ROOT_DIR/lib", 0777 or mydie("Can't create $SMARTOIL_ROOT_DIR/lib: $!"); }
  print "\nCopy libraries \n";
  foreach(<$libpath/*>){
    (my $file = $_) =~s/^(.*)\///;
    fcopy("$libpath/$file", "$SMARTOIL_ROOT_DIR/lib/$file"); chmod 0755, "$SMARTOIL_ROOT_DIR/lib/$file";
  }
}

setenv("$ENV{'HOME'}/.bashrc");

finish();

#xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
##########################################
sub finish{
  print "\n=======  Установка завершена  =======\n\n";
  exit 0;
}
#
sub mydie{
  my $error = shift;
  {clearscreen(); print "\n$error\n\n"; exit; } ; 
}
##########################################
# Диалоговые процедуры
###########################
sub readkey{
  my $key;
  my %keys = (
  		"[D" => 'left',
  		"[C" => 'right',
  		"[A" => 'up',
  		"[B" => 'down',
  		"[I" => 'pgup',
  		"[5" => 'pgup',
  		"[G" => 'pgdn',
  		"[6" => 'pgdn',
  		"[H" => 'home',
  		"[F" => 'end',
  		"[P" => 'F4',
  		"OS" => 'F4',
  		"[14" => 'F4',
  		"[V" => 'F10',
  		"[21" => 'F10',
  		"" => 'backspace',
  		"" => 'backspace',
  		"\12" => 'enter',
  );
  open TTY, "+</dev/tty" or die "No tty: $! ";
  system "stty cbreak -echo </dev/tty >/dev/tty 2>&1";
  while(1){
    $key = getc(TTY);
    if($key =~/^[ A-Za-z0-9АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдежзийклмнопрстуфхцчшщъыьэюя_\/.,\-]$/){ last; }
    if($keys{$key}){ $key = $keys{$key}; last; }
    if( $key eq "\033" ){
      $key .= getc(TTY);
      $key .= getc(TTY);
      if($keys{$key}){ $key = $keys{$key}; last; }
      if($key eq "[2"){ $key .= getc(TTY); if($keys{$key}){ $key = $keys{$key}; last; } }
    }
  }
  system "stty -cbreak </dev/tty >/dev/tty 2>&1";
  close TTY;
  return $key;
}
###########################
# Мелочи для работы с экраном
sub gotoxy{ my $x = shift; my $y = shift; print "[$y;$x"."H"; }
sub clearscreen{ print "[2J"; } 
sub clearlines{ my $y = shift; gotoxy(0,$y); print "[0J"; }
sub clearline{ print "[2K"; }
sub cleartoend{ print "[0K"; }
sub clearsubstr{ my $n = shift; print "[$n X"; }
sub setinvers{ print "[7m"; }
sub setnormal{print "[0m";}
sub showerror{ my $error = shift; gotoxy(4,23); clearline; print "[31m>>>  $error [0m"; }
sub clearerror{ print "[s"; gotoxy(0,23); clearline; print "[u"; }
sub quit{ clearscreen(); gotoxy(0,0); exit; }
sub printline{
  my $x = shift;
  my $y = shift;
  my $text = shift;
  gotoxy($x,$y);
  clearline;
  print $text;
}
##########################################
# Выбор типа установки быстрая/подробная
sub selectinstalltype{
  clearscreen();
  my ($x, $y) = (7, 10);
  my $t = 1;
  my $type = { '1' => 'Быстрая', '0' => 'Подробная' };
  printline(4, 4, "[1mТип установки [0m");
  printline(4, 24, "[1m<Enter>[0m - дальше,  [1m<F10>[0m - выход");
  for(0..1){
    gotoxy($x, $y - $_); print "( ) $type->{$_}";
  }
  gotoxy($x + 1, $y - $t); print "*"; gotoxy($x + 1, $y - $t);
  while(1){
    my $key = readkey;
    if($key eq 'F10'){ quit; }
    if($key eq 'enter'){ return $t; }
    if($key eq 'up'){ $t = 1; }
    if($key eq 'down'){ $t = 0; }
    print " ";
    gotoxy($x + 1, $y - $t); print "*"; gotoxy($x + 1, $y - $t);
  }
  return 1;
}

##########################################
# Задаем каталог для установки
# Если есть переменная окружения - берем ее,
# иначе поумолчанию - текущий каталог + имя каталога по умолчанию
# Если указать только имя - прибавить его к текущему пути
sub setrootdir{
  my $rootdir;
  my $workdir = `pwd`; chomp $workdir;
  if($ENV{'SMARTOIL_ROOT_DIR'}){ $rootdir = $ENV{'SMARTOIL_ROOT_DIR'}; }
  elsif($ENV{'HOME'}){ $rootdir = "/usr/home/$ENV{'USER'}/SMARTOIL-2"; }
  else{ $rootdir = `pwd`; chomp $rootdir; }
  printline(4, 4, "[1mВыбор каталога для установки [0m");
  printline(4, 8, "");
  printline(6, 10, "Путь: ");
  my $dir = editstr(12, 10, $rootdir);
  if(!$dir){ return $rootdir; }
  else{
    if($dir !~/^\//){ $dir = $workdir.'/'.$dir;}
    return $dir;
  }
}
##########################################
# Проверяем возможность установки в SMARTOIL_ROOT_DIR
sub setpath{
  clearscreen();
  my $dir;
  while(1){
    if($error) { showerror($error); undef $error; }
    $dir = setrootdir;
    if($dir !~/\w/){ $error = "Недопустимый путь $dir"; next; }
    if(system("mkdir -p $dir > /dev/null 2>&1")){ $error = "Невозможно создать каталог $dir"; next; }
    if(-d $dir && !-w $dir){ $error = "Отсутствует право на запись в каталог $dir"; next; }
    my @files = <$dir/*>;
    if(@files){
      clearscreen();
      printline(4, 4, "[1mВыбор каталога для установки [0m");
      printline(4, 8, "Каталог \"$dir\" не пуст.");
      printline(4, 10, "Устанавливать все равно? (Y/N/Q) [N]:");
      gotoxy(42,10);
      my $key = readkey;
      if($key =~/^y$/i){ return $dir; }
      elsif($key =~/^n$/i || $key eq 'enter'){ next; }
      elsif($key =~/^q$/i){ quit; }
      else{ next; };
    }
    last;
  }
  return $dir;
}
##########################################
# Выбор модулей
sub selectmodules{
  my $moduleslist = shift;
  my @modules = @$moduleslist;
  my %selected = ();
  clearscreen();
  printline(4, 2, "[1mУстановка в $SMARTOIL_ROOT_DIR [0m");
  printline(4, 4, "[1mВыбор устанавливаемых модулей  [0m");
  for my $i(0..$#modules){
    gotoxy($x0 - 1 , $y0 + $i); clearline; print "[ ] $names{$modules[$i]}";
  }
  printline(4, 24, "[1m<Space>[0m - выбор,  [1m<A>[0m - все,  [1m<Enter>[0m - дальше,  [1m<F10>[0m - выход");
  my $i = 0;
  while(1){
    gotoxy($x0, $y0 + $i);
    my $key = readkey;
    if($key eq ' '){
      if($selected{$modules[$i]}){ delete $selected{$modules[$i]}; print ' '; }
      else{ $selected{$modules[$i]} = 1; print 'X'; }
    }
    if($key =~/^a$/i){
      for(0..$#modules){
        gotoxy($x0, $y0 + $_); $selected{$modules[$_]} = 1; print 'X';
      }
      gotoxy($x0, $y0 + $i);
    }
    if($key eq 'up'){ if($i > 0){ $i--; gotoxy($x0, $y0 + $i); } }
    if($key eq 'down'){if($i < $#modules){ $i++; gotoxy($x0, $y0 + $i); } }
    if($key eq 'pgup'){ $i = 0; gotoxy($x0, $y0); }
    if($key eq 'pgdn'){ $i = $#modules; gotoxy($x0, $y0 + $i); }
    if($key eq 'home'){ $i = 0; gotoxy($x0, $y0); }
    if($key eq 'end'){$i = $#modules; gotoxy($x0, $y0 + $i); }
    if($key eq 'F10'){ quit; }
    if($key eq 'enter'){
      last;
    }
  }
  return \%selected;
}
##########################################
# Ждем, пока не будут выбраны модули для установки
# или не получим отказ
sub checkselected{
  my $moduleslist = shift;
  my $selected = {};
  while(1){
    my $key;
    $selected = selectmodules($moduleslist);
    if(!%$selected){
      clearscreen();
      printline(4, 4, "[1mВыбор устанавливаемых модулей [0m");
      printline(4, 8, "Не выбраны модули для установки.");
      printline(4, 10, "Возврат (R)/ Выход (Q)? [R]: ");
      while(1){
        $key = readkey;
        if($key =~/^(r|R)$/ || $key eq 'enter'){ last; }
        if($key =~/^(q|Q)$/){ quit; }
      }
    }
    else{ last; }
  }
  clearscreen();
  return $selected;
}
##########################################
sub editstr{
  my $x0 = shift;
  my $y0 = shift;
  my $str = shift;
  my $str0 = $str;
  my $pw = shift;
  my $strlen = length($str);
  my $firstkey = undef;
  my $key;
  gotoxy($x0, $y0); cleartoend; setinvers; 
  print (($pw)?hidepassw($str):$str);
  my $cur = length($str);
  while(1){
    $key = readkey;
    setnormal;
    gotoxy($x0, $y0); print (($pw)?hidepassw($str):$str); gotoxy($x0 + $cur, $y0);
    clearerror;
    if($key eq 'home'){ $cur = 0; gotoxy($x0 + $cur, $y0); }
    elsif($key eq 'end'){ $cur = $strlen; gotoxy($x0 + $cur, $y0); }
    elsif($key eq 'left'){ if($cur > 0){ $cur--; gotoxy($x0 + $cur, $y0); } }
    elsif($key eq 'right'){ if($cur < $strlen){$cur++; gotoxy($x0 + $cur, $y0); } }
    elsif($key eq 'backspace'){
      if($cur > 0){
        $cur--; substr($str, $cur, 1, '');
        gotoxy($x0, $y0); cleartoend; print (($pw)?hidepassw($str):$str); gotoxy($x0 + $cur, $y0); $strlen--;
      }
    }
    elsif($key =~/^[ a-zA-Z0-9\/,.\-_АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдежзийклмнопрстуфхцчшщъыьэюя]$/){
      if(!$firstkey){ $str = ''; $strlen = 1; $cur = 0; gotoxy($x0, $y0); cleartoend; }
      $str = substr($str, 0, $cur).$key.substr($str, $cur); $strlen++; $cur++;
      gotoxy($x0, $y0); print (($pw)?hidepassw($str):$str); gotoxy($x0 + $cur, $y0);
    }
    elsif($key eq 'enter' || $key eq 'F10'){
      last;
    }
    else{ undef $key; $firstkey = 1; next; }
    $firstkey = 1;
  }
  $str =~s/^\s+//;
  $str =~s/\s+$//;
  if($str eq '' || !defined $str){ $str = $str0; }
  return $str;
}
##########################################
sub setenv{
  my $file = shift;
  undef $quick;
  clearscreen();
  while(1){
    my $env = editparams('Запись переменных окружения', { 'file' => $file});
    $file = $env->{'file'};
    if(!-w $file){ $error = "Can't open $file: $!"; next; }
    last;
  }
  open PROFILE, "+<$file" or die "Can't open $file: $!";
  flock(PROFILE, 2);
  my @lines = <PROFILE>;
  seek PROFILE, 0, 0;
  my ($smartoil_dir, $ld_library_path);
  foreach(@lines){
    if(!/^\#/ && /SMARTOIL_ROOT_DIR=(.*)/){
      s/SMARTOIL_ROOT_DIR=(.*)/SMARTOIL_ROOT_DIR=$SMARTOIL_ROOT_DIR/;
      $smartoil_dir = $1;
    }
    print PROFILE;
  }
  if(!$smartoil_dir){
    print PROFILE "export SMARTOIL_ROOT_DIR=$SMARTOIL_ROOT_DIR\n";
    print PROFILE "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$SMARTOIL_ROOT_DIR/lib\n";
  }
  flock(PROFILE, 3);
  close PROFILE;
  clearscreen();
}
##########################################
# Конфигурирование списка параметров
sub editparams{
  my $module_name = shift;
  my $params = shift;
  my $module_name_0 = $module_name;
  my @subnames = split '/', $module_name;
  foreach my $subname(@subnames){ $subname = ($names{$subname})?$names{$subname}:$subname ; }
  $module_name = join '/', @subnames;
  $module_name =~s/\/(\d+)/[0m[[1m$1[0m]/g ;
  $module_name =~s/\//[0m\/[1m/g;
  if($quick){return $params};		# При быстрой установке оставляем все значения по умолчанию
  my $paramnamewidth = 30;
  clearscreen();
  printline(1, 1, "Конфигурация: [1m".$module_name."[0m");
  printline($x1, 24, "[1m<F4>[0m - редактировать, [1m<Enter>[0m - дальше, [1m<F10>[0m - выход");
  my @lines = sort keys %$params;
  my $linesnum = $#lines; 
  my $pagesize = $pagesizemax;
  if($linesnum < $pagesize){ $pagesize = $linesnum; }
  my $i = 0;
  my $first = 0;
  while(1){
    for ($first..($first + $pagesize)){
      my ($name, $val) = ($lines[$_], $params->{$lines[$_]});
      if($_ == $i){ setinvers; }
      gotoxy($x1, $y1 -$first + $_); printf("%-$paramnamewidth"."s%s", ($names{$name})?$names{$name}:$name); setnormal;
      gotoxy($x1 + $paramnamewidth, $y1 -$first + $_); cleartoend; print (($name =~/passw/)?hidepassw($val):$val);
    }
    if($error) { showerror("$error"); undef $error; }
    gotoxy($x1 + $paramnamewidth - 1, $y1 + $i - $first);
    my $key = readkey;
    clearerror();
    if($key eq 'up'){ if($i > 0){ $i--; if($first > 0 && $i == $first - 1){ $first--; } } }
    elsif($key eq 'down'){ if($i < $linesnum){ $i++; if($first < ($linesnum - $pagesize) && $i == $first + $pagesize + 1){ $first++; } } }
    elsif($key eq 'pgup'){ $i -= $pagesize; if($i < 0){ $i = 0; } $first -= $pagesize; if($first < 0){ $first = 0; } }
    elsif($key eq 'pgdn'){ $i += $pagesize; if($i > $linesnum){ $i = $linesnum; } $first += $pagesize; if($first > ($linesnum - $pagesize)){ $first = $linesnum - $pagesize}; }
    elsif($key eq 'home'){ $i = 0; $first = 0; }
    elsif($key eq 'end'){ $i = $linesnum; $first = $linesnum- $pagesize; } 
    elsif($key eq 'F4'){
      my ($name, $val) = ($lines[$i], $params->{$lines[$i]});
      my $pw = undef;;
      if($name =~/passw/){ $pw = 1; }
      gotoxy($x1, $y1 - $first + $i);
      clearline;
      print (($names{$name})?$names{$name}:$name);
      $val = editstr($x1 + $paramnamewidth, $y1 - $first + $i, $val, $pw);
      $params->{$lines[$i]} = $val;
      if($name =~/^port|devname$/ && $module_name_0 =~/(cardreader|butrk|struna)/){ $error = checkports($1, $val); if($error){ next; } }
    }
    elsif($key eq 'F10'){ quit; }
    elsif($key eq 'enter'){
      if($module_name_0 =~/(cardreader|butrk|struna)/){
        my $device = $1;
        for('port', 'devname'){
          if(defined $params->{$_}){ $error = checkports($device, $params->{$_}); }
        }
      }
      if($error){ next; }
      last;
    }
    else{ next; }
  }
  return $params;
}
##########################################
sub checkports{
  my $device = shift;
  my $port = shift;
  $port = substr($port, -1);
  if($ports{$port} && $ports{$port} ne $device){ return "Порт /dev/cuaa$port занят устройством \"$names{$ports{$port}}\""; }
  else{ $ports{$port} = "$device"; }
  return undef;
}
#xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# полная конфигурация из modules.conf
sub getconfig{
  my $file = shift;
  my $config = {};
  my @path;
  my $ref;
  open CONF, $file or die "Can't open $file: $!";
  my @lines = <CONF>;
  close CONF;
  foreach my $line (@lines){
    next if $line =~ /^\s*$/;
    if ($line =~ /^\[\/(.*)\/\]$/){
      @path = split '/',$1;
      $ref = add_path($config, @path);
      next;
    }
    if ($line =~ /^(.*)=(.*)$/){
      $ref->{$1} = $2;
    }
  }
  return $config
}

sub add_path{
  my $h = shift;
  my @path = @_;
  my $ref=$h;
  foreach my $el (@path){
    $ref->{$el} = {} unless exists($ref->{$el});
    $ref = $ref->{$el};
  }
  return $ref;
}

#xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# запись конфига в файл
sub writeconf{
  my $config = shift;
  my $filename = shift;
  print "Write $filename....";
  open CONF, ">$filename" or die "Can't write $filename: $!";
  print CONF "[/]\n";
  foreach my $section(sort keys %$config){
#-------  Изврат с COMMON-ами -----------
    (my $section_m = $section) =~s/^pump/common\/pump/;
#----------------------------------------
    print CONF "\n[/$section_m/]\n";
    foreach(sort keys %{$config->{$section}}){
      print CONF "$_=$config->{$section}{$_}\n";
    }
  }
  close CONF;
  print "OK\n";
}
##########################################
sub configmodule{
  my $module_name = shift;
  my $cfg = shift;
  my $params = {};
  foreach my $k(sort keys %$cfg){
    if(ref($cfg->{$k}) ne 'HASH'){ $params->{$k} = $cfg->{$k}; }
    else{ configmodule($module_name."/$k", $cfg->{$k}); }
  }
  if(%$params){ $params = editparams($module_name, $params); }
  foreach(sort keys %$params){
    $cfg->{$_} = $params->{$_};
  }
  return $cfg;
}
##########################################
sub makeconfigsection{
  my $module_name = shift;
  my $cfg = shift;
  my $params = {};
  foreach my $k(sort keys %$cfg){
    if(ref($cfg->{$k}) ne 'HASH'){ $params->{$k} = $cfg->{$k}; }
    else{ makeconfigsection($module_name."/$k", $cfg->{$k}); }
  }
  if(%$params){ $sections->{$module_name} = $params; }
  foreach(sort keys %$params){
    $cfg->{$_} = $params->{$_};
  }
}
##########################################
sub fcopy{
  my $src = shift;
  my $dest = shift;
  my $bufsize = 1024;
  print "$dest....";
  open SRC, "$src" or die "Can't read $src: $!\n";
  binmode SRC;
  open DEST, ">$dest" or die "Can't write to $dest: $!\n";
  while (sysread(SRC, my $buff, $bufsize)){
    print DEST $buff;
  }
  close DEST;
  close SRC;
  print "OK\n";
}
##########################################
sub checkDBconnect{
  my $db_path = shift;
  my $db_user = shift;
  my $db_password = shift;
  my $sql = "connect '$db_path' user '$db_user' password '$db_password';\n";
  my @isqlOUT = `echo -e "$sql" | $isql 2>&1`;
  while(@isqlOUT){
    my $line = shift @isqlOUT;
    if($line =~/SQLCODE = -(\d+)/){ $error = "Невозможно подключение к базе данных"; return $error; }
  }

  return undef;
}
##########################################
sub gettrklist{
  my $db_path = shift;
  my $db_user = shift;
  my $db_password = shift;
  my @trk_list = ();
  clearscreen();
  my $sql .= "connect '$db_path' user '$db_user' password '$db_password';\n";
  $sql .= "select GASATERIA_NUM from GASATERIA;\n";
  if(!-x $isql){ mydie "\nCan't run $isql\n"; }
  my @isqlOUT = `echo -e "$sql" | $isql 2>&1`;
  while(@isqlOUT){
    my $line = shift @isqlOUT;
    if($line =~/SQLCODE = -(\d+)/){ mydie ("\nНевозможно получить список колонок\n"); }
    if($line =~/GASATERIA_NUM/){
      shift @isqlOUT; last;
    }
  }
  foreach(@isqlOUT){
    chomp;
    if(/^\s*(\d+)\s*$/){
      if($1 > 0){ push @trk_list, $1; } }
  }
  return \@trk_list;
}
##########################################
sub getval{
  my $conf = shift;
  my $query = shift;
  my $str = shift;
  my $sql = "connect '$conf->{db_path}' user '$conf->{db_user}' password '$conf->{db_password}';\n";
  $sql .= "$query;\n";
  if(!-x $isql){ mydie "\nCan't run $isql\n"; }
  my @isqlOUT = `echo -e "$sql" | $isql 2>&1`;
  while(@isqlOUT){
    my $line = shift @isqlOUT;
    if($line =~/SQLCODE = -(\d+)/){ mydie ("\nОшибка базы данных. SQLCODE = -$1\n"); }
    if($line =~/$str/){
      shift @isqlOUT; shift @isqlOUT; last;
    }
  }
  my $val = shift(@isqlOUT);
  chomp $val;
  $val =~s/^\s+//;
  $val =~s/\s+$//;
  return $val;
}
##########################################
# Данные по АЗС
sub set_azs_data{
  my $db_path = shift;
  my $db_user = shift;
  my $db_password = shift;
  my $quick_m = $quick;				# Для общих параметров сбрасываем флаг быстрой установки
  undef $quick;
  my $sql = '';
  $azs_cfg = editparams('Информация по АЗС', $azs_cfg);
  $usr_cfg = editparams('Информация о пользователе', $usr_cfg);
  $azs_cfg->{'6fr'} =~s/ /_/g;

  my $fr_max = getval($commonconf, "select  max(CASH_REG_ID) from cash_register", "MAX");
  $fr_max++;
  my $usr_max = getval($commonconf, "select  max(EMPLOYEE_ID) from employee", "MAX");
  $usr_max++;
  my $code = sprintf("%04d", $usr_max);
#-----------------------
# Изврат с кривым выравниванием списка
$usr_cfg->{'1name'} = sprintf("%-9s%s", $usr_cfg->{'1name'});
$usr_cfg->{'2name'} = sprintf("%-9s%s", $usr_cfg->{'2name'});
$usr_cfg->{'3name'} = sprintf("%-11s%s", $usr_cfg->{'3name'});
#-----------------------

  $sql .= "CONNECT '$db_path' USER '$db_user' PASSWORD '$db_password';\n";
  $sql .= "EXECUTE PROCEDURE set_filling_station(  1, '$azs_cfg->{'1name'}', '$azs_cfg->{'2address'}', '$azs_cfg->{'3phone'}', '$azs_cfg->{'4jur_addr'}','$azs_cfg->{'5ip'}');\n";
  $sql .= "EXECUTE PROCEDURE set_employee($usr_max, '$code', '$usr_cfg->{'2name'}', '$usr_cfg->{'3name'}', '$usr_cfg->{'1name'}','$usr_cfg->{'xpassw'}', '$usr_cfg->{'birth'}', $usr_cfg->{'sex'},'$usr_cfg->{'educ'}','$usr_cfg->{'prof'}', $usr_cfg->{'state'}, 1);\n";
  $sql .= "EXECUTE PROCEDURE set_cash_register($fr_max, 1, '$azs_cfg->{'6fr'}','Отдел 1');\n";
  $sql .= "COMMIT;\n";
  clearscreen;
  print "\n\nЗагрузка информации по АЗС.........\n\n";
  my $logfile = "$SMARTOIL_ROOT_DIR/dbinstallAZS.log";
  open LOG, ">$logfile" or die "Can't open $logfile ";
  my @isqlOUT = `echo -e "$sql" | $isql 2>&1`;
  while(@isqlOUT){
    my $line = shift @isqlOUT;
    if($line){ print LOG "$line"; }
  }
  close LOG;
  $quick = $quick_m;
  return ($azs_cfg, $usr_cfg);
}
##########################################
sub hidepassw{
  my $val = shift;
  my $length = length($val);
  $val = "*"x$length;
  return $val;
}

