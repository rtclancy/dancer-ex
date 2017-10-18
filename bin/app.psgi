#!/usr/bin/env perl

#!/usr/bin/env/perl
#!/usr/bin/perl
#use CGI;
use Fcntl;
use Plack::Request;
#use Dancer;

#sub display_form {
#    return "display_form: hello world";
#}

my $app_root   ;
my $image_root ;
our @return_string;
our $version="v1.1";

sub my_print
{
    return [push @return_string, $_[0]];
}
    
if (0)
{
    $app_root   = "..";
    $image_root   = "..";
} else {
    $app_root   = "/opt/app-root/src";
    $image_root   = "/opt/app-root/src";
}

#our $query = new CGI;
our $query;

my $debug_log =  "$app_root/dynamic_data/debug_log.txt";
my $data_file1 = "$app_root/dynamic_data/roll_call_in.csv";
my $data_file2 = "$app_root/dynamic_data/roll_call_out.csv";
my $data_file_blank = "$app_root/data/roll_call_blank.csv";
my $data_file_out1 = "$app_root/dynamic_data/tmp_roll_call_in.csv";
my $data_file_out2 = "$app_root/dynamic_data/tmp_roll_call_out.csv";
my $player_id;
my $day;
my $player;
my $player_delta;
my $action;
our $illegal_delta;
our $timestamp;
our $week_of;
our $stale=0;

sub debug_message
{
    sysopen (f_out, $debug_log, O_WRONLY | O_CREAT | O_APPEND,0666) or die "can't open $data_file_out1: $!";
    print f_out "$_[0]\n";
    close(f_out);
}
sub clear_debug
{
    sysopen (f_out, $debug_log, O_WRONLY | O_CREAT | O_TRUN,0666) or die "can't open $data_file_out1: $!";
    close(f_out);
}



sub subr_player_id
{
  my $sub_nonnull;
  my $sub_day=$_[0];
  my $sub_player=$_[1];
  my $sub_out_inb=$_[2];
  my $sub_player_id="empty";
  my $sub_print=$_[3];
  #  print "<p>$day:$player</p>";

  
  
  if ($sub_day==0) 
    {
      if (!$sub_out_inb)
	{
	  $sub_player_id=$query->param("mon_player_list_in_$sub_player");
	}
      else
	{
	  $sub_player_id=$query->param("mon_player_list_out_$sub_player");
	}
    }
  if ($sub_day==1) 
    {
      if (!$sub_out_inb)
	{
	  $sub_player_id=$query->param("wed_player_list_in_$sub_player");
	}
      else
	{
	  $sub_player_id=$query->param("wed_player_list_out_$sub_player");
	}
    }
  if ($sub_day==2) 
    {
      if (!$sub_out_inb)
	{
	  $sub_player_id=$query->param("fri_player_list_in_$sub_player");
	}
      else
	{
	  $sub_player_id=$query->param("fri_player_list_out_$sub_player");
	}
    }

  #strip leading &nbsp
  $sub_nonnull = 0;
  while (length($sub_player_id))
    {
      if (ord($sub_player_id)== 0xa0)  #test leading character
	{
	  $sub_player_id = substr($sub_player_id,1); #delete leading character
	}
      else
	{
	  $sub_nonnull=1;
	  last;
	}
    }
  if (!$sub_nonnull) 
    {
      $sub_player_id='&nbsp';
    }
  if (!($sub_player_id =~ m/\w/))
  {
#      print "whitespace only";
      $sub_player_id='&nbsp';
  }
      
  if ($sub_print)
  {
      #print f_out "$sub_player_id,";
      print "<p>*** $sub_day:$sub_player:$sub_player_id***</p>\n";

      if ($sub_player == 0 && $sub_day == 2 && $sub_out_inb == 0)
      {
	  print $query->param("mon_player_list_in_0");
	  print $query->param("wed_player_list_in_0");
	  print $query->param("fri_player_list_in_0");
	  print $query->param("mon_player_list_out_0");
	  print $query->param("wed_player_list_out_0");
	  print $query->param("fri_player_list_out_0");
      }
  }
  if ($sub_player_id =~ m/rich/i) {
      $sub_player_id="RichC aka The Weak Link";   
  }

  return($sub_player_id);
}

######################################################################
######################################################################
sub copy_files
  {
    my $i;
    my ($linein);
    sysopen (f_gd_out, $_[1], O_WRONLY|O_CREAT|O_TRUNC,0666) or die "can't open $_[1]: $!";
    #flock(f_gd_out);
    sysopen (f_gd, $_[0], O_RDONLY) or die "can't open $_[0]: $!";
    #while ($linein = <f_gd>) {}
    for ($i=0;$i<3;$i++)
      {
	$linein=<f_gd>;
	print f_gd_out "$linein";
	#print f_gd_out (chomp($linein));
      }
#update timestamp
    $linein=<f_gd>;
    $linein=time;#$linein+1;
    print f_gd_out "$linein\n";
    
    if ($_[2] == 1) #if resetting form update week of in data file
      {
	$linein=<f_gd>;
	print f_gd_out "$week_of\n";
        print f_gd_out "NA\n"; #last player to update
      }
    else
      {
	$linein=<f_gd>;
	print f_gd_out "$linein";
        print f_gd_out "$player_delta\n";
      }
    
    #in count and out count
    $linein=<f_gd>;
    print f_gd_out "$linein";
    $linein=<f_gd>;
    print f_gd_out "$linein";

    close(f_gd_out);   
    close(f_gd);   
}

######################################################################
######################################################################
sub illegal_delta
{
  my @in_player_list;
  my @in_player_list_tmp;
  my @out_player_list;
  my @out_player_list_tmp;
  my @day_array=("Monday", "Wednesday","Friday");
  my $linein;
  
  $illegal_delta=0;

  sysopen (f_in1, $data_file1, O_RDONLY) or die "can't open $data_file1: $!";
  sysopen (f_in2, $data_file_out1, O_RDONLY) or die "can't open $data_file_out1: $!";
  sysopen (f_in3, $data_file2, O_RDONLY) or die "can't open $data_file2: $!";
  sysopen (f_in4, $data_file_out2, O_RDONLY) or die "can't open $data_file_out2: $!";

  for ($day=0;$day<3;$day++)
    {
      $linein = <f_in1>;
      @in_player_list = split(/,/,$linein);
      $linein = <f_in2>;
      @in_player_list_tmp = split(/,/,$linein);
      $linein = <f_in3>;
      @out_player_list = split(/,/,$linein);
      $linein = <f_in4>;
      @out_player_list_tmp = split(/,/,$linein);
      for ($player=0;$player<20;$player++)
	{
	  if (($in_player_list_tmp[$player] ne '&nbsp') && ($out_player_list_tmp[$player] ne '&nbsp'))
	    {
	      &my_print("<p>Day $day, Row $player, Can't be both in and out</p>");
	      &my_print("<p>When changing status from in to out or vice versa, clear the old status, add the new status, and hit submit_roll</p>");
	      $illegal_delta=1;
	      close(f_in1);close(f_in2);close(f_in3);close(f_in4);
	      return('null');
	    }
	}
    }
  close(f_in1);close(f_in2);close(f_in3);close(f_in4);
  return('null');
}
sub player_delta
{
  my @in_player_list;
  my @in_player_list_tmp;
  my @out_player_list;
  my @out_player_list_tmp;
  my @day_array=("Monday", "Wednesday","Friday");
  my $linein;
  
  sysopen (f_in1, $data_file1, O_RDONLY) or die "can't open $data_file1: $!";
  sysopen (f_in2, $data_file_out1, O_RDONLY) or die "can't open $data_file_out1: $!";
  sysopen (f_in3, $data_file2, O_RDONLY) or die "can't open $data_file2: $!";
  sysopen (f_in4, $data_file_out2, O_RDONLY) or die "can't open $data_file_out2: $!";

  for ($day=0;$day<3;$day++)
    {
      $linein = <f_in1>;
      @in_player_list = split(/,/,$linein);
      $linein = <f_in2>;
      @in_player_list_tmp = split(/,/,$linein);
      $linein = <f_in3>;
      @out_player_list = split(/,/,$linein);
      $linein = <f_in4>;
      @out_player_list_tmp = split(/,/,$linein);
      for ($player=0;$player<20;$player++)
	{
	  if ($in_player_list[$player] ne $in_player_list_tmp[$player])
	    {
	      if ($in_player_list[$player] eq '&nbsp') #legal replacement
		{
		  $player_delta=$in_player_list_tmp[$player];
		  close(f_in1);close(f_in2);close(f_in3);close(f_in4);
		  return($player_delta);
		}
	    }
	  if ($out_player_list[$player] ne $out_player_list_tmp[$player])
	    {
	      if ($out_player_list[$player] eq '&nbsp') #legal replacement
		{
		  $player_delta=$out_player_list_tmp[$player];
		  close(f_in1);close(f_in2);close(f_in3);close(f_in4);
		  return($player_delta);
		}
	    }
	}
    }
  close(f_in1);close(f_in2);close(f_in3);close(f_in4);
  return('null');
}

sub send_mail 
{
my $smtpserver = 'smtp.comcast.net';
my $smtpport = 587;
my $smtpuser   = 'rtclancy@comcast.net';
my $smtppassword = '$CoM2396qCaS%';

my $transport = Email::Sender::Transport::SMTP->new({
  host => $smtpserver,
  port => $smtpport,
  sasl_username => $smtpuser,
  sasl_password => $smtppassword,
});

my $email = Email::Simple->create(
  header => [
    To      => 'rtclancy@yahoo.com',
    From    => 'rtclancy@comcast.net',
    Subject => 'Hi!',
  ],
  body => "This is my message\n",
);

sendmail($email, { transport => $transport });
}

######################################################################
######################################################################
sub check_for_stale 
{
  my $linein;
  my $ts;
  my @timestamp;

  sysopen (f_in1, $data_file1, O_RDONLY) or die "can't open $data_file1: $!";
  sysopen (f_in2, $data_file_out1, O_RDONLY) or die "can't open $data_file_out1: $!";
  sysopen (f_in3, $data_file2, O_RDONLY) or die "can't open $data_file2: $!";
  sysopen (f_in4, $data_file_out2, O_RDONLY) or die "can't open $data_file_out2: $!";
  $stale=0;

#read off first 3 lines of file in order to get to timestamp
  for ($day=0;$day<3;$day++)
    {
      $linein = <f_in1>;
      $linein = <f_in2>;
      $linein = <f_in3>;
      $linein = <f_in4>;
    }
  for ($ts=0;$ts<4;$ts++)
    {
      if ($ts == 0)
	{
	  $timestamp[$ts] = <f_in1>;
	}
      if ($ts == 1)
	{
	  $timestamp[$ts] = <f_in2>;
	}
      if ($ts == 2)
	{
	  $timestamp[$ts] = <f_in3>;
	}
      if ($ts == 3)
	{
	  $timestamp[$ts] = <f_in4>;
	}
      chomp($timestamp[$ts]);
    }

  if (($timestamp[0] != $timestamp[1]) || ($timestamp[2] != $timestamp[3]))
    {
      $stale=1;
    }
  
  for ($ts=0;$ts<4;$ts++)
  {
      &debug_message("Stale = $stale");
      &debug_message("ts$ts:/ $timestamp[$ts]");
  }
close(f_in1);close(f_in2);close(f_in3);close(f_in4);
return($stale);
}

sub html_head
{
#&my_print ("Content-type: text/html\n\n");
&my_print( # <<"EndOfText";
"<HTML>
<HEAD>
<TITLE>Roll Call</TITLE>
</HEAD>
");#EndOfText
}

sub html_tail {
&my_print( # <<"EndOfText";
"</BODY>
</HTML>
"); #   EndOfText
}

sub display_form {
my $in_count;
my $out_count;
my @in_count_per_day;
my @out_count_per_day;
my $df_player_id;
my $linein;
my @tmp_player_list;
my @tmp_player_list_out;
my @mon_player_list;
my @wed_player_list;
my @fri_player_list;
my @mon_player_list_out;
my @wed_player_list_out;
my @fri_player_list_out;
# display the form	
&my_print( #endoftext
"<FORM METHOD=\"POST\" ACTION=\"index.pl\"><TABLE width=60% border=\"1\"; style=\"font-size:14px;text-align:center;word-wrap;break-word;\">"
);#EndofText
###################################################################
#heading
###################################################################
&my_print("<HR>\n");
my @day_array=("Monday", "Wednesday","Friday");
sysopen (f_in1, $data_file1, O_RDONLY) or die "can't open $data_file1: $!";
sysopen (f_in2, $data_file2, O_RDONLY) or die "can't open $data_file2: $!";

for ($day=0;$day<3;$day++)
  {
    if ($day == 0)
      {
	$linein = <f_in1>;
	@mon_player_list = split(/,/,$linein);
	$linein = <f_in2>;
	@mon_player_list_out = split(/,/,$linein);
      }
    if ($day == 0)
      {
	$linein = <f_in1>;
	@wed_player_list = split(/,/,$linein);
	$linein = <f_in2>;
	@wed_player_list_out = split(/,/,$linein);
      }
    if ($day == 0)
      {
	$linein = <f_in1>;
	@fri_player_list = split(/,/,$linein);
	$linein = <f_in2>;
	@fri_player_list_out = split(/,/,$linein);
      }
  }
my $in_timestamp = <f_in1>;
chomp($in_timestamp);
my $out_timestamp = <f_in2>;
chomp($out_timestamp);
my $df_week_of = <f_in2>;
chomp($df_week_of);
my $tmp_player_delta = <f_in2>;
chomp($tmp_player_delta);

if ($player_delta eq 'null') { #then get player_delta from DB file
    $player_delta=$tmp_player_delta;
}

close(f_in1);
close(f_in2);

#print "<p>$in_timestamp</p>";
#print "<p>$out_timestamp</p><br>";

&my_print( # <<"EndofText";
"<TR>
<TD>Week of: <INPUT SIZE=20 TYPE=\"text\" NAME=\"week_of\" VALUE=\"$df_week_of\" readonly/></TD>
<TD><INPUT SIZE=4 TYPE=\"submit\" NAME=\"action\" VALUE=\"submit_roll\" /></TD>
<TD><INPUT SIZE=4 TYPE=\"submit\" NAME=\"action\" VALUE=\"reset_roll\" /></TD>
</TR>
");
#EndofText

for ($day=0;$day<3;$day++)
  {
&my_print( # <<"EndofText";
"<TH width=20% ALIGN=\"center\" $optional_style><STRONG>$day_array[$day]</STRONG></TH>
"); #EndofText
 }


&my_print(  "</HR>\n");

my $user_agent=$query->headers->user_agent;#$ENV{'HTTP_USER_AGENT'};
#print $user_agent;
my $mobile_device;
if ((($user_agent =~ m/Mozilla/i) && (($user_agent =~ m/Firefox/i) || ($user_agent =~ m/windows/i) || ($user_agent =~ m/ipad/i))) && 1)
  {
    $mobile_device=0;
    #&debug_message("Access is from a Non-Mobile Device");
  }
else
  {
    $mobile_device=1;
    #&debug_message("Access is from a Mobile Device");
  }
#&debug_message($user_agent);



if (!($mobile_device) && 1)
{
&my_print(  "<TR>\n");
&my_print( "<TD><img width=150 height=150 src=/image_files/sun_icon.gif></TD>\n");
&my_print( "<TD><img width=150 height=150 src=/image_files/shooters.jpg></TD>\n");
&my_print( "<TD><img width=150 height=150 src=/image_files/Basketball.JPG></TD>\n");
&my_print(  "</TR>\n");
}

#in versus out headings in table
&my_print ("<TR>\n");
for ($day=0;$day<3;$day++)
  {
    $in_count=0;
    $out_count=0;
    if ($day == 0)
      {
	@tmp_player_list=@mon_player_list;
	@tmp_player_list_out=@mon_player_list_out;
      }
    if ($day == 1)
      {
	@tmp_player_list=@wed_player_list;
	@tmp_player_list_out=@wed_player_list_out;
      }
    if ($day == 2)
      {
	@tmp_player_list=@fri_player_list;
	@tmp_player_list_out=@fri_player_list_out;
      }
    for ($player=0;$player<20;$player++)
      {	
	if (($tmp_player_list[$player] ne '&nbsp'))
	  {
	    $in_count=$in_count+1;
	  }
	if (($tmp_player_list_out[$player] ne '&nbsp'))
	  {
	    $out_count=$out_count+1;
	  }
      }
    $in_count_per_day[$day]=$in_count;
    $out_count_per_day[$day]=$out_count;
    
    &my_print( "<TD><TABLE width=100%><HR width=100%><TH width=50% align=CENTER>IN($in_count)</TH><TH width=50% align=CENTER>OUT($out_count)</TH></HR></TABLE></TD>\n");
  }
&my_print( "</TR>\n");


for ($player=0;$player<20;$player++)
  {
$df_player_id = $player+1;
    &my_print(  "<TR>\n");
    for ($day=0;$day<3;$day++)
      {
	if ($day==0)
	  {
	    &my_print( "<TD><TABLE><TR>\n");
&my_print( # <<"EndofText";
"<TD style=\"width:20px\" ALIGN=\"left\"> <p > $df_player_id:</p></TD>
<TD ALIGN=\"left\" $optional_style> <p ><INPUT SIZE=20% border=none bg=none $optional_style NAME=\"mon_player_list_in_$player\" value=\"$mon_player_list[$player]\" /> </p> </TD>
");#EndofText
&my_print( # <<"EndofText";
"<TD ALIGN=\"left\" $optional_style> <p > <INPUT SIZE=20% border=none bg=none $optional_style NAME=\"mon_player_list_out_$player\" value=\"$mon_player_list_out[$player]\" /> </p> </TD>
"); #EndofText
	    &my_print( "</TR></HR></TABLE></TD>");
      }
	if ($day==1)
	  {
	    &my_print( "<TD><TABLE><TR>\n");
	    &my_print( # << "EndofText";
"<TD ALIGN=\"left\" $optional_style> <p >  <INPUT SIZE=20% $optional_style NAME=\"wed_player_list_in_$player\" value=\"$wed_player_list[$player]\" /> </p> </TD>
");#EndofText
	    &my_print( # << "EndofText";
"<TD ALIGN=\"left\" $optional_style> <p >  <INPUT SIZE=20% $optional_style NAME=\"wed_player_list_out_$player\" value=\"$wed_player_list_out[$player]\" /> </p> </TD>
");#EndofText
	    &my_print( "</TR></HR></TABLE></TD>");
      }
	if ($day==2)
	  {
	    &my_print( "<TD><TABLE><TR>\n");
	&my_print( # << "EndofText";
"<TD ALIGN=\"left\" $optional_style> <p >  <INPUT SIZE=20% $optional_style NAME=\"fri_player_list_in_$player\" value=\"$fri_player_list[$player]\" /> </p> </TD>
");#EndofText
	&my_print( # << "EndofText";
"<TD ALIGN=\"left\" $optional_style> <p >  <INPUT SIZE=20% $optional_style NAME=\"fri_player_list_out_$player\" value=\"$fri_player_list_out[$player]\" /> </p> </TD>
");EndofText
	    &my_print( "</TR></HR></TABLE></TD>");
      }
      }
    &my_print( "</TR>\n");
  }
&my_print("<TR>\n");
my $tmp_timestamp=localtime($in_timestamp);
&my_print("<TD>Roll Call Version:$version<br>Last Update::<br>$player_delta<br>$tmp_timestamp</TD>");
&my_print("</TR>\n");

&my_print(  "</TABLE>\n");
&my_print( #<<"EndOfText";
"<INPUT SIZE=4 TYPE=\"hidden\" NAME=\"in_ts\" VALUE=\"$in_timestamp\" /></TD>
<INPUT SIZE=4 TYPE=\"hidden\" NAME=\"out_ts\" VALUE=\"$out_timestamp\" /></TD>
<INPUT SIZE=4 TYPE=\"hidden\" NAME=\"in_count_mon\" VALUE=\"$in_count_per_day[0]\" /></TD>
<INPUT SIZE=4 TYPE=\"hidden\" NAME=\"in_councdt_wed\" VALUE=\"$in_count_per_day[1]\" /></TD>
<INPUT SIZE=4 TYPE=\"hidden\" NAME=\"in_count_fri\" VALUE=\"$in_count_per_day[2]\" /></TD>
<INPUT SIZE=4 TYPE=\"hidden\" NAME=\"out_count_mon\" VALUE=\"$out_count_per_day[0]\" /></TD>
<INPUT SIZE=4 TYPE=\"hidden\" NAME=\"out_count_wed\" VALUE=\"$out_count_per_day[1]\" /></TD>
<INPUT SIZE=4 TYPE=\"hidden\" NAME=\"out_count_fri\" VALUE=\"$out_count_per_day[2]\" /></TD>
"); #EndOfText

&my_print( # <<"EndOfText";
"</FORM>
"); #EndOfText
#$return_string="hello world1";
return @return_string;    
}

if (1) {
    my $app = sub {
        my $env = shift;
        @return_string=();
        
        &debug_message($env->{PATH_INFO});
        if ($env->{PATH_INFO} eq '/image_files/sun_icon.gif') {
            open my $fh, "<:raw", "$image_root/image_files/sun_icon.gif" or die $!;
            return [ 200, ['Content-Type' => 'image/x-icon'], $fh ];
        } elsif ($env->{PATH_INFO} eq '/image_files/shooters.jpg') {
            open my $fh, "<:raw", "$image_root/image_files/shooters.jpg" or die $!;
            return [ 200, ['Content-Type' => 'image/x-icon'], $fh ];
        } elsif ($env->{PATH_INFO} eq '/image_files/Basketball.JPG') {
            open my $fh, "<:raw", "$image_root/image_files/Basketball.JPG" or die $!;
            return [ 200, ['Content-Type' => 'image/x-icon'], $fh ];
        } else {
            &clear_debug;
            #test to see if this is the first run of the application as in this case the data files won't exist
            if ((-e $data_file1 && -e $data_file2)==0) {
                &copy_files ($data_file_blank,$data_file1,1);
                &copy_files ($data_file_blank,$data_file2,1);
            }
            
            $query=Plack::Request->new($env);
            unless ($action = $query->param('action')) {
                $action = 'none';
            }
            
            #$action='none';
            #$action='reset_roll';
            #$action='submit_roll';
#        my $query     = $req->parameters->{query};
            
#        my @names=$query->param;
            
            
            if ($action eq 'none' || 0) {
                &html_head;
                $player_delta='null';
                &display_form;
#            &my_print("<p> Action = $action </p><br>");
            }
            
            if ($action eq 'submit_roll' && 1) {
                &html_head;
                
                if (1) 
                {
                    #open file for temporarily storing who is in
                    sysopen (f_out, $data_file_out1, O_RDWR | O_CREAT | O_TRUNC,0666) or die "can't open $data_file_out1: $!";
                    
                    for ($day=0;$day<3;$day++)
                    {
                        for ($player=0;$player<20;$player++)
                        {
                            $player_id=&subr_player_id($day,$player,0,0);
                            print f_out "$player_id,";
                        }
                        print f_out "\n";
                    }
                    $timestamp=$query->param("in_ts");
                    print f_out "$timestamp\n";
                    $week_of=$query->param("week_of");
                    print f_out "$week_of\n";
                    close(f_out);
                    
                    #open file for temporarily storing who is out
                    sysopen (f_out, $data_file_out2, O_RDWR | O_CREAT | O_TRUNC,0666) or die "can't open $data_file_out2: $!";
                    
                    for ($day=0;$day<3;$day++)
                    {
                        for ($player=0;$player<20;$player++)
                        {
                            $player_id=&subr_player_id($day,$player,1,0);
                            print f_out "$player_id,";
                        }
                        print f_out "\n";
                    }
                    $timestamp=$query->param("out_ts");
                    print f_out "$timestamp\n";
                    $week_of=$query->param("week_of");
                    print f_out "$week_of\n";
                    close(f_out);
                    
                    ## diff input and output files to find out who is being added
                    &illegal_delta;
                    
                    $player_delta=&player_delta;
                    
                    #print $player_delta;
                    
                    $stale=&check_for_stale;
                    
                    if (!$stale && ($player_delta ne 'null') && !$illegal_delta)
                    {
                        #copy temporary files back to database
                        #&update_ts;
                        &copy_files($data_file_out1,$data_file1,0);
                        &copy_files($data_file_out2,$data_file2,0);
                        
                        &my_print( "<p>Submission Complete $player_delta</p>\n");
                    }
                    elsif ($stale)
                    {
                        &my_print("<p>Stale Data! Please try again</p>\n");
                    }
                    elsif ($illegal_delta)
                    {
                        &my_print("<p>Illegal Change, Check for prior messages $player_delta</p>");
                    }
                    elsif ($player_delta = 'null')
                    {
                        &my_print("<p>No Change Has Been Detected, Please resubmit your change</p>");
                    }
                }
                &display_form;
#            &my_print("<p> Action = $action </p><br>");	    
            }
            
            if ($action eq 'reset_roll') 
            {
                &html_head;
                $player_delta='null'; #forces webpage to use value from blank file
                $player_id=&subr_player_id(2,0,1,0);
                $week_of=&subr_player_id(2,0,0,0);
                if (0)
                {
                    print $query->param("mon_player_list_in_0");
                    print $query->param("wed_player_list_in_0");
                    print $query->param("fri_player_list_in_0");
                    print $query->param("mon_player_list_out_0");
                    print $query->param("wed_player_list_out_0");
                    print $query->param("fri_player_list_out_0");
                }
                if ($player_id eq "shooterjoe" || 0)
                {
                    &copy_files ($data_file_blank,$data_file1,1);
                    &copy_files ($data_file_blank,$data_file2,1);
                    &my_print("<p>Roll Call Has Been Reset</p>\n");
                }
                else
                {
                    &my_print("<p>Incorrect Code For Reset</p>\n");
                }
                
                &display_form;
#            &my_print("<p> Action = $action </p><br>");	    
            }
            
            
            &html_tail;
            #print $my_string;
            #print "Hello";
            return [200, ['Content-Type' => 'text/html'],  [@return_string]];
        }
}
}
else
{
    &html_head;
    &display_form;
    &html_tail;
    print "@return_string";
}
