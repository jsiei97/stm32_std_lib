#!/usr/bin/perl -w 
#use strict;

use File::Copy;
use File::Path;
use Cwd;
use Archive::Zip;       
use POSIX qw(strftime);

## A ISO-date string
$date_now = strftime("%Y%m%d-%H%M%S", localtime);
print $date_now ."\n";

$cwd_path = getcwd();
#print "CWD: ".$cwd_path."\n";


#
# http://stackoverflow.com/questions/1695925/how-do-i-import-a-third-party-lib-into-git
#

$tmp_path = $cwd_path."/tmp/";
mkpath $tmp_path; 
chdir $tmp_path;

#
# First some basic config. 
#
$stdlibzip = "stm32f10x_stdperiph_lib.zip";
$url = "http://www.st.com/stonline/products/support/micro/files/stm32f10x_stdperiph_lib.zip";
$cmd_str = "wget ".$url." -O ".$stdlibzip; 


#
# Now let's download the zip file.
#
if( -e $stdlibzip) {
    print "File exists: ".$stdlibzip."\n";

} else {
    open(DATA, $cmd_str." 2>&1 |") || die "Failed: $!\n";
    while ( defined( my $line = <DATA> )  ) {
        print $line;
    }
    close DATA;
}

if( -e $stdlibzip) {
    print "File downloaded: ".$stdlibzip."\n";
} else {
    die("Can't download file: ".$stdlibzip."\n");
}


#
# Then we unpack some parts of it.
#
my $zip = Archive::Zip->new($stdlibzip);
foreach my $member ($zip->members)
{
    if(!defined($first_dir_name) and $member->isDirectory) {
        if( $member->fileName =~ /StdPeriph/) {
            $first_dir_name = $member->fileName;
        }
    }

    #print $member->fileName."\n";
    next if $member->isDirectory;
    if ( 
        $member->fileName =~ /Libraries/ or
        $member->fileName =~ /Release_Notes.html/ )
    {
        if ( 
            $member->fileName =~ /startup\/iar/ or 
            $member->fileName =~ /startup\/arm/  )
        {
            print $member->fileName." (IGNORE)\n";
        } 
        else 
        {
            $file = $member->fileName;
            print $file."\n";
            if ( $member->fileName =~ /(.*)(\/src)(.*)/)
            {
                $file = $1.$3;
                print $file." (SRC)  \n";
            }
            if ( $member->fileName =~ /(.*)(\/inc)(.*)/)
            {
                $file = $1.$3;
                print $file." (INC)  \n";
            }
            $member->extractToFileNamed($file);
        }
    }
}



#
# In the first dir we had the version number from ST.
# Let's grap it for later use.
#

#print "ZIP info: ".$first_dir_name."\n";

if( $first_dir_name  =~ /V([0-9]{1,}).([0-9]{1,}).([0-9]{1,})/) {
    $lib_ver = $&;
    $lib_track = "StdPeriph_Lib_V".$1;
} else {
    die("Error, what version is this? (".$first_dir_name.")\n");
}

print "Lib version: ".$lib_ver."\n";
print "Lib track: ".$lib_track."\n";



#
#Go back and do it for real...
#
chdir $cwd_path;



# 
# Is this tag already created?
# If so just exit (we don't have anything more to do...
#
$cmd_str = "git tag";
open(DATA, $cmd_str." 2>&1 |") || die "Failed: $!\n";
while ( defined( my $line = <DATA> )  ) {
    if($line =~ /$lib_ver/) {
        die("This version (".$lib_ver.") is tagged... exit\n");
    }
}
close DATA;

#
# Create and switch to the right branch
#
system("git branch ".$lib_track);
system("git checkout ".$lib_track);

# 
# Maybe add a check so that we are in the right branch?
# git branch
# and then check so we find: /" * ".$lib_track/
#
system("git branch");


#
# Now let's cleanup so we can make way for the new stuff
#
opendir DIR, ".";
foreach $file (readdir(DIR))
{
    if(-d $file)
    {
        if (
            $file =~ /^.{1,2}$/ or
            $file =~ /.git/ or
            $file =~ /tmp/ )
        {

        }
        else 
        {
            print "Let's remove: ".$file."\n";
            system("rm -rf ".$file);
        }

    }
}
closedir DIR;


$lib_dir_name = "StdPeriph_Lib";

if(-e "tmp/".$first_dir_name)
{
    move("tmp/".$first_dir_name, $lib_dir_name);
}

if(-e $lib_dir_name) {
    print "Dir is ok: ".$lib_dir_name."\n";
} else {
    die("Error: ".$lib_dir_name."\n");
}


#
# More error control...?
#

system("git add ".$lib_dir_name);
system("git commit -a -m 'ST:s ".$lib_dir_name." ".$lib_ver."'");
system("git tag '".$lib_ver."'");

system("rm -rf tmp/");

1;
