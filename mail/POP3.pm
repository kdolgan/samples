#############################################
#
#  POP3 - functions
#
#############################################

use strict;

use Mail::POP3Client;
use MIME::Parser;
use MIME::Entity;

use Time::ParseDate;
use Term::ReadKey;


#############################################

my @att_list = ();
my ($pop,$i,$msg_count);
my $att_type_list;
my ($saved_msg_dir, $saved_att_dir, $tmp_dir);

#############################################
# Логин и пароль на POP сервер
#############################################
sub pop3login{
  print "\nPOP3 login: ";
  ReadMode 2;
  my $user = <>; chomp $user;
  print "\nPOP3 password: ";
  my $pass = <>; chomp $pass;
  print "\n";
  ReadMode 0;
  return ($user, $pass);
}
#############################################
# Коннектимся к РОР-серверу
#############################################
sub pop3connect{
  my $host = shift;
  my $user = shift;
  my $pass = shift;

  $pop = new Mail::POP3Client( HOST => $host );
  $pop->User( $user );
  $pop->Pass( $pass );
  $pop->Connect() || return 'ERROR: '.$pop->Message();
  print "Connected to POP3 server\n";
  return $pop;
}
##############################################
# Адрес отправителя
##############################################
sub get_sender_email{
  my $head = shift;
  my $sender = $head->get('From');
  if($sender =~/<(.*\@.*)>/){$sender = $1;}
  return $sender;
}
##############################################
# Дата сообщения
##############################################
sub get_msg_date{ 
  my $head = shift;
  my $date = parsedate($head->get('Date'));
  my ($sec,$min,$hour,$day,$mon,$year) = (localtime($date))[0..5];
  foreach($sec,$min,$hour,$day){
    $_ = sprintf("%02d",$_);
  }
  $mon = sprintf("%02d",$mon+1);
  $date = ($year+1900).$mon.$day.'_'.$hour.$min.$sec;
  return $date;
}
##############################################
#  Проверка на multipart-ность
##############################################
sub ent_handler{
  my $ent = shift;
  my $sender = shift;
  my $msg_date =shift;
  if($ent->is_multipart){
    multipart_handler($ent, $sender, $msg_date);
  }
  else{
    my $att_list = part_handler($ent, $sender, $msg_date);
    return @$att_list;
  }
}
##############################################
#  Вытаскивание вложений
##############################################
sub multipart_handler{
  my $ent = shift;
  my $sender = shift;
  my $msg_date =shift;
  my @parts = $ent->parts;
  my @atts = grep $_->mime_type ne 'text/plain', @parts;
  foreach(@atts){
    my $att_list = ent_handler($_, $sender, $msg_date);
  }
}
##############################################
#  Разбор части сообщения
##############################################
sub part_handler{
  my $part = shift;
  my $sender = shift;
  my $msg_date =shift;
  my $head = $part->head;
  my $body = $part->bodyhandle;
  my $name = $head->get('Content-Disposition');

  foreach(@$att_type_list){
    if($name =~ /filename=\"([^\"]+.$_)\"/i){
      $name = $1;
      push @att_list, $name;
      save_att($body, $name, $sender, $msg_date, $_);
    }
  }
  return \@att_list;
}
#############################################
# Сохраняем вложения
##############################################
sub save_att{
  my $body = shift;
  my $name = shift;
  my $sender = shift;
  my $msg_date =shift;
  my $att_type = shift;
  my $path = "$saved_att_dir/$sender";
  if(!-d $path){
    mkdir($path, 0777);
  }
  $name =~ s/(.*)\.$att_type$/$1.'-'.$msg_date.".$att_type"/ei;
  if ($name =~/\.xls$/){
    $name .= '.tmp';
  }
  if(!-e "$path/$name"){
    open F, ">$path/$name" or warn "Cant open file $name !";
    $body->print(\*F)  or warn "Can't write to $path/$name";
    close F;
  }
}
#############################################
# Сохраняем сообщение
#############################################
sub save_msg{
  my $i = shift;
  my $entity = shift;
  my $sender = shift;
  my $msg_date =shift;
  my $path = "$saved_msg_dir/$sender";
  if(!-d $path){
    mkdir($path, 0777);
  }
  my $saved_msg = "$path/$msg_date".".msg";
  if(!-e $saved_msg){
    open FF,">$saved_msg" or die "Can't open file $saved_msg: $!";
    $entity->print(\*FF);
    close FF;
    return $saved_msg;
  }
}
##############################################
#  Обработка сообщения
##############################################
sub message_handler{
  my $i = shift;
  my $message = $pop->Retrieve($i);
  my $parser = new MIME::Parser;
  $parser->output_dir($tmp_dir);
  my $entity = $parser->parse_data($message);
  my $head = $entity->head;
  my $sender = get_sender_email($head);
  my $msg_date = get_msg_date($head);
  my $att_count = 0;
  my @att_list = ent_handler($entity, $sender, $msg_date);
  if (@att_list){
    save_msg($i, $entity, $sender, $msg_date);
    print "Message $i from $sender : ".@att_list." attachments saved\n";
    $att_count = @att_list;
    @att_list = ();
#    $pop->Delete($i);
  }
  $entity->purge;
  return $att_count;
}
##############################################
#  Очистка временного каталога
##############################################
sub empty_tmp{
  my $tmp_dir = shift;
  foreach(<$tmp_dir/*>){
    unlink $_;
  }
}

1;
