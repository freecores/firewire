#!/home/jimwu/bin/perl -w
###############################################################################
#
# File:         v2html
# RCS:          $Header: /home/marcus/revision_ctrl_test/oc_cvs/cvs/firewire/bin/v2html.pl,v 1.1 2002-03-07 02:03:39 johnsonw10 Exp $
# Description:  Verilog to html converter
# Author:       Costas Calamvokis
# Created:      Wed Aug 20 11:24:31 1997
# Modified:     Tue Nov 20 21:21:07 2001
# Language:     Perl
#
# Copyright 1998-2001 Costas Calamvokis
# Copyright 1997      Hewlett-Packard Company
#
#  This file nay be copied, modified and distributed only in accordance
#  with the terms of the limited licence contained in the accompanying
#  file LICENCE.TXT.
#
###############################################################################

# This is commented out in the distribution because it means that
#  v2html will work even if the perl libraries are not installed
#  properly
#use strict; 

# Define the global variables 

use vars qw($output_hier $output_index $hier_file $frame_file $quiet $incremental
	    $maint $frames $frame_bottom $frame_middle $frame_top $frame_code
	    $link_to_source $cgi_script $web_base $js_hier
	    $js_file $out_dir $js_cookies
	    $print_unconnected $print_no_mods $grey_ifdefed_out $cgi_key
	    $t_and_f_in_hier $compress @compress_cmd $compress_extension
	    $hier_comment $tabstop $js_sigs $help_info @inc_dirs @lib_dirs 
	    @lib_exts %navbar %classes $lines_per_file $index_info $style_sheet_link
	    @output_files @args $css

	    $verilog_db

	    @verilog_keywords $verilog_gatetype_regexp
	    %verilog_keywords_hash %verilog_compiler_keywords_hash

            $version $vert_frames $mail_regexp $http_regexp $VID $icon_c $icon_i
	    $icon_x @newer_files @files $file @hier_tops %cmd_line_defines
	    $module $debug $ul_id @index_stack );

# check the perl version is high enough
if ( $] < 5.004 ) {
    print "Error: this script can only run with Perl version 5.004 or greater\n";
    exit 1;
}

# initialize
&init;

# read the arguments
&process_args;

# legal stuff - do not delete
if (!$quiet) {
    print "v2html version $version. See LICENCE.TXT for licence.\n";
    print " Copyright 1998-2001 Costas Calamvokis\n";
    print " Copyright 1997      Hewlett-Packard Company\n";
}

$style_sheet_link  =  "<link rel=\"Stylesheet\" title=\"v2html stylesheet\" ". 
    "media=\"Screen\" href=\"$css\">\n";

# set up the navbar
$navbar{order} = [ ];
if ( $output_hier ) {
    push ( @{$navbar{order}} , ( 'Hierarchy' ) );
}
if ( $output_index ) { 
    push ( @{$navbar{order}} , ( 'Files' , 'Modules' , 'Signals' , 'Tasks' , 'Functions' ));
}
push ( @{$navbar{order}} , ( 'Help' ) );
# now set what each navbar item links to
$navbar{Hierarchy} = $hier_file;
($navbar{Files}    = $hier_file) =~ s/(\..*|)$/-f$1/;
($navbar{Modules}  = $hier_file) =~ s/(\..*|)$/-m$1/;
($navbar{Signals}  = $hier_file) =~ s/(\..*|)$/-s$1/;
($navbar{Tasks}    = $hier_file) =~ s/(\..*|)$/-t$1/;
($navbar{Functions}= $hier_file) =~ s/(\..*|)$/-fn$1/;
$navbar{Help}      = "http://www.burbleland.com/v2html/help_7_0.html?$help_info";

# check incremental
if ($incremental) {
    if (check_incremental($out_dir)) {
	print "All html files are up to date, nothing to do.\n" unless $quiet;
	exit 0;
    }
    print "Rebuilding all files\n" unless $quiet;
}

$verilog_db = &rvp::read_verilog(\@files,[],\%cmd_line_defines,
				 $quiet,\@inc_dirs,\@lib_dirs,\@lib_exts);

if ($output_index) {
    print "Writing indexes\n" unless $quiet;
    print_indexes($verilog_db,$js_hier);
}

# write the hierarchy (must be done after the indexes)
if ($output_hier) {
    print "Writing hierarchy to $hier_file\n" unless $quiet;
    print_hier($hier_file,$js_hier,\@hier_tops);
}

# write the frames
if ($frames) {
    print "Writing frames to $frame_file\n" unless $quiet;
    if (defined(@hier_tops)) {
	print_frame_top($frame_file,$hier_file,join(", ",@hier_tops),
			$js_hier,$vert_frames);
    }
    else {
	print_frame_top($frame_file,$hier_file,$web_base,
			$js_hier,$vert_frames);
    }
}

# print out gif icons used 
print_gifs($out_dir, ($cgi_script || $js_hier), $output_index );

# print out the cascading style sheet
print_css($out_dir);

# convert each file
foreach $file (&rvp::get_files($verilog_db)) {
    convert(&rvp::get_files_full_name($verilog_db,$file));
}

# Write out a file list for incremental - we can not rely on the user provided
#  one because we may have read more files finding modules and includes
if ($incremental) {
    write_filelist($verilog_db,$out_dir);
}

foreach my $problem (&rvp::get_problems($verilog_db)) {
    if ( $problem !~ m/\n/ ) {
	$problem =~ s/(.{60,79}) /$1\n    /g;
    }
    print "$problem.\n";
}

exit 0;

###############################################################################
#   Subroutines
###############################################################################

###############################################################################
# initialize global variables
#
sub init {

    @output_files=(); # stores a list of files we've written for incremental
    $output_hier = 1;
    $output_index = 1;
    $hier_file = 'hierarchy.html';
    $frame_file="frame.html";
    $quiet     = 0;
    $incremental = 0;
    $maint     = '';
    $frames      = 0;
    $vert_frames = 0;
    $frame_bottom = "";
    $frame_middle = "";
    $frame_code   = ""; # frame for jumping to code
    $frame_top    = "";
    $link_to_source = 0;
    $cgi_script = "";
    $web_base  = "";
    $js_file = "";
    $help_info = "";
    $print_unconnected=1;
    $print_no_mods=1;
    $grey_ifdefed_out = 1;
    $t_and_f_in_hier=0;
    $compress=0;
    $hier_comment = "";
    @compress_cmd = ('compress', '-f');
    $compress_extension = '.Z';
    srand( time() ^ ( $$ + ( $$ << 15)));
    $cgi_key= substr(rand,2,-1);
    $tabstop=0;
    @inc_dirs=('.');
    @lib_dirs=('.');
    @lib_exts=('');
    $lines_per_file=1000;
    $js_hier   =1; # javascript hierarchy
    $js_sigs   =1; # javascript signals
    $js_cookies=1; # javascript cookies
    $css= 'v2html.css'; # default cascading style sheet name

    $out_dir='./';

    @verilog_keywords = (
       qw(
       always assign attribute begin case casex casez deassign default
       defparam disable edge else end endattribute endcase endfunction
       endmodule endprimitive endspecify endtable endtask event for force
       forever fork function highz0 highz1 if initial join large macromodule
       medium module negedge parameter posedge primitive pull0 pull1 release
       repeat rtranif1 scalared small specify specparam strength strong0
       strong1 table task trior use vectored wait weak0 weak1 while),
       (@rvp::verilog_gatetype_keywords),
       (@rvp::verilog_sigs),
       qw(
       config endconfig design instance liblist use library cell
       generate endgenerate automatic));  # V2001

    $verilog_gatetype_regexp = "\\b(" . 
	join("|",@rvp::verilog_gatetype_keywords) . 
	    ")\\b";
    @verilog_keywords_hash{@verilog_keywords} = "" x @verilog_keywords;

    @verilog_compiler_keywords_hash{@rvp::verilog_compiler_keywords} = 
	"" x @rvp::verilog_compiler_keywords;


    $version = '$Header: /home/marcus/revision_ctrl_test/oc_cvs/cvs/firewire/bin/v2html.pl,v 1.1 2002-03-07 02:03:39 johnsonw10 Exp $'; #'
    $version =~ s/^\S+ \S+ (\S+) .*$/$1/;

    # map from easy to remember names to the crytic class names used in html files
    %classes = (comment=>'C', pp_ignore=>'P', string=>'S', compiler=>'M',
		systemtask=>'ST', keyword=>'K', signal_input=>'SI',
		signal_output=>'SO', signal_output_reg=>'SOR',
		signal_inout_reg=>'SIOR', signal_inout=>'SIO', signal_reg=>'SR',
		signal_integer=>'SIT', signal_wire=>'SW', signal_tri=>'STI',
		signal_tri0=>'ST0', signal_tri1=>'ST1', signal_triand=>'STA',
		signal_trireg=>'STR', signal_supply0=>'SS0',
		signal_supply1=>'SS1', signal_wand=>'SWA', signal_wor=>'SWO',
		signal_time=>'STM', signal_real=>'SRL', module=>'MM', task=>'T',
		function=>'F', define=>'D', parameter=>'PA',
		navbar=>'NB',
		signal_genvar=>'GV', attribute=>'AT',  # V2001
		);
 
    # the regexp to find a mail address in a comment (for linking)
    $mail_regexp='\b([^@ \t\n]+@[^@ \t\n\.]+\.[^@ \n\t]+)\b';
    $http_regexp='\b(http:[^ \n\t]+)';

    # a verilog identifier is this reg exp 
    #  a non-escaped identifier is A-Z a-z _ 0-9 or $ 
    #  an escaped identifier is \ followed by non-whitespace
    #   why \\\\\S+ ? This gets \\\S+ in to the string then when it
    #   it used we get it searching for \ followed by non-whitespace (\S+)
    $VID = '[A-Za-z_][A-Za-z_0-9\$]*|\\\\\S+';

    # icons for hierarchy when using javascript 
    $icon_c = "<img align=bottom border=0 src=\"v2html-c.gif\">";
    $icon_x = "<img align=bottom border=0 src=\"v2html-x.gif\">";
    $icon_i = "<img align=top border=0 alt=\"Index\" src=\"v2html-i.gif\">";
}

###############################################################################
#   Command line processing
###############################################################################

###############################################################################
# Set up any variables as specified in the arg list.
# Put input filenames in @files
#
sub process_args {
    my ($f,$value,%files_seen);

    # $#ARGV is the index of last arg. 
    
    @args=( @ARGV );

    while ($_ = $ARGV[0]) {
	shift(@ARGV);
	if ( /^-debug$/ ) { 
	    $debug = 1; 
	    &rvp::set_debug();
	    next;
	    }
	elsif ( /^-o$/ ) { 
	    $out_dir = shift(@ARGV);
	    $out_dir =~ s/[\/]?$/\//;
	    next; 
	    }
	elsif ( /^-m$/ ) { 
	    &usage("$_ needs an argument") if ($#ARGV < 0);
	    $maint = shift(@ARGV);
	    next; 
	    }
	elsif ( /^-ht$/ ) { 
	    &usage("$_ needs an argument") if ($#ARGV < 0);
	    push(@hier_tops,shift(@ARGV));
	    next; 
	    }
	elsif ( /^-h$/ ) { 
	    &usage("$_ needs an argument") if ($#ARGV < 0);
	    $hier_file = shift(@ARGV);
	    next; 
	    }
	elsif ( /^-hc$/ ) { 
	    &usage("$_ needs an argument") if ($#ARGV < 0);
	    $hier_comment = shift(@ARGV);
	    quote_html(\$hier_comment);
	    next; 
	    }
	elsif ( /^-nh$/ ) { 
	    $output_hier = 0;
	    $help_info.='nh-';
	    next; 
	    }
	elsif ( /^-htf$/ ) { 
	    $t_and_f_in_hier=1;
	    $help_info.='htf-';
	    next; 
	    }
	elsif ( /^-nu$/ ) { 
	    $print_unconnected = 0;
	    $help_info.='nu-';
	    next; 
	    }
	elsif ( /^-nnm$/ ) { 
	    $print_no_mods = 0;
	    $help_info.='nnm-';
	    next; 
	    }
	elsif ( /^-ni$/ ) { 
	    $grey_ifdefed_out = 0;
	    $help_info.='ni-';
	    next; 
	    }
	elsif ( /^-nindex$/ ) { 
	    $output_index = 0;
	    $help_info.='nindex-';
	    next; 
	    }
	elsif ( /^-q$/ ) { 
	    $quiet = 1;
	    next; 
	    }
	elsif ( /^-i$/ ) { 
	    $incremental = 1;
	    $help_info.='i-';
	    next; 
	    }
 	elsif ( /^-c$/ ) { 
	    &usage("$_ needs two arguments") if ($#ARGV < 1);
	    $js_hier =0;
 	    $cgi_script = shift(@ARGV);
 	    $web_base  = shift(@ARGV);
 	    if (($cgi_script !~ m&^/&) || ($web_base   !~ m&^/&)) {
 		die "\nError: -c option must be followed by:\n".
		    "   /path/cgi_script_name\n".
		    "   /path_to_html_files\n".
		    " relative web server's root (not file system root)\n\n";
 	    }
 	    $web_base =~ s|/$||;
	    $help_info.='c-';
 	    next; 
 	    }
	elsif ( /^-js$/ || /^-qs$/ || /^-nqs$/ ) { 
	    print "Warning: obsolete option $_\n";
	    # js hierarchy is now on by default - qs now wrapped into sigpopup
	    next; 
	    }
	elsif ( /^-njshier$/ ) { 
	    $js_hier = 0;
	    $help_info.='njshier-';
	    next; 
	    }
	elsif ( /^-nsigpopup$/ ) { 
	    $js_sigs = 0;
	    $help_info.='nsigpopup-';
	    next; 
	    }
	elsif ( /^-ncookies$/ ) { 
	    $js_cookies = 0;
	    $help_info.='ncookies-';
	    next; 
	    }
	elsif ( /^-s$/ ) { 
	    $link_to_source = 1;
	    $help_info.='s-';
	    next; 
	    }
	elsif ( /^-z$/ ) { 
	    $compress = 1;
	    $help_info.='z-';
	    next; 
	    }
	elsif ( /^-zc$/ ) { 
	    &usage("$_ needs an argument") if ($#ARGV < 0);
	    $_ = shift(@ARGV);
	    @compress_cmd = split ;
	    next; 
	    }
	elsif ( /^-ze$/ ) { 
	    &usage("$_ needs an argument") if ($#ARGV < 0);
	    $compress_extension = shift(@ARGV);
	    next; 
	    }
	elsif ( /^-font$/ ) { 
	    &usage if ($#ARGV < 0);
	    $_ = shift(@ARGV);
	    print "Warning -font option option is no longer supported ".
		"edit cascading style sheet (v2html.css) instead\n";
	    next; 
	}
	elsif ( /^-f$/ ) { 
	    &usage("$_ needs an argument") if ($#ARGV < 0);
	    add_options_from_file(shift(@ARGV)); 
	    next;
	}
	elsif ( /^-F$/ || /^-VF$/ ) { 
	    $frames = 1;
	    if ( /^-VF$/ ) {
		$vert_frames = 1;
		$help_info.='VF-';
	    }
	    else {
		$help_info.='F-';
	    }
	    $frame_bottom = 'target="bottom"';
	    $frame_middle = 'target="middle"';
	    $frame_code   = 'target="middle"';
	    $frame_top    = 'target="upper"';
	    if ($#ARGV >= 0) { 
		if ($ARGV[0] =~ m/.*\.html$/) {
		    $frame_file = shift(@ARGV);
		}
	    }
	    next; 
	}
	elsif ( /^-g$/ ) {
	    print "Warning: obsolete option $_\n";
	    $f = shift(@ARGV);
	}
	elsif ( /^-lines$/ ) {
	    &usage("$_ needs an argument") if ($#ARGV < 0);
	    $lines_per_file = shift(@ARGV);
	}
	elsif ( /^\+define\+($VID)(?:(?:=)(.*))?$/o ) {
	    # define with optional value (+define+NAME or +define+NAME=VALUE
	    if ($2) {	
		$cmd_line_defines{$1}=$2;
	    }
	    else {
		$cmd_line_defines{$1}="";
	    }
	}
	elsif ( /^-k$/ ) {
	    &usage("$_ needs an argument") if ($#ARGV < 0);
	    $cgi_key = shift(@ARGV);
	}
	elsif ( /^-tab$/ ) { 
	    &usage("$_ needs an argument") if ($#ARGV < 0);
	    $tabstop = shift(@ARGV);
	    next; 
	    }
	elsif ( /^-css$/ ) {
	    &usage("$_ needs an argument") if ($#ARGV < 0);
	    $css = shift(@ARGV);
	}
	elsif ( /^-y$/ ) { 
	    &usage("$_ needs an argument") if ($#ARGV < 0);
	    push(@lib_dirs,shift(@ARGV));
	    next; 
	    }
	elsif ( /^\+incdir\+(.+)$/ ) { 
	    push(@inc_dirs,$1);
	    next; 
	    }
	elsif ( /^\+libext\+(.+)$/ ) { 
	    push(@lib_exts,split(/\+/,$1));
	    next; 
	    }
	elsif ( /^-exp$/ ) { 
	    print "Warning: obsolete option -exp (defines are always expanded)\n";
	    next; 
	    }
	else {
	    if ( /^-v$/ ) { # -v file is exactly the same as file without -v
		&usage("$_ needs an argument") if ($#ARGV < 0);
		$_=shift(@ARGV);
	      }
	    my @fglobbed = glob($_);
	    if ( 1 == @fglobbed && ! -r $_ ) { # arg didn't expand & is not readable as a file
	      # try it as a VCS/verilog with no parameters
	      if (/^-([BCIMRSVu])|(Mupdate)|(ID)|(O0)|(PP)|(RI)|(RIG)|(RPP)$/ ||
		  /^-(line)|(lmc-hm)|(lmc-swif)|(location)|(platform)$/ ||
		  /^-(p[a-zA-Z0-9]+)$/ ||
		  /^\+.*$/ ) {
		print "Warning: ignoring VCS/verilog option $_\n" unless $quiet;
		next;
	      }
	      # try it as a MTI/verilog with no parameter
	      if (/^-(incr)$/) {
		print "Warning: ignoring MTI/verilog option $value\n" 
		  unless $quiet;
		next;
	      }

	      # try it as a VCS/verilog with one parameter
	      if (/^-([jJlPL])|(ASFLAGS)|(CC)|(CFLAGS)|(LDFLAGS)|(as)$/ ||
		  /^-(cc)|(grw)|(ld)|(syslib)|(vcd)$/) {
		$value = $_ ." ". shift(@ARGV);
		print "Warning: ignoring VCS/verilog option $value\n" 
		  unless $quiet;
		next;
	      }
	      # report an error: if it doesn't look like a bad option
	      #   report it as an unreadable file
	      if ( /^[-+]/ ) { &usage("Unrecognized option: $_"); }
	      else        { &usage("Verilog file $_ is not readable"); }
	    }
	    else {
	      # Must be a file
	      foreach $f ( @fglobbed ) { 
		if ( -r $f ) { # see if it is readable
		  if (exists($files_seen{$f})) {
		    print "Warning: ignoring duplicate file on command line $f\n";
		  }
		  else {
		    push(@files,$f);
		  }
		  $files_seen{$f}=1;
		}
		else {
		  &usage("Verilog file $_ is not readable");
		}
	      }
	    }
	  }
    }

    &usage("No verilog files specified") if (@files == 0);

    die "\nError: You can not use Javascript and CGI at the same time\n\n"
	if ($js_hier && $cgi_script);

    $frame_code = 'target="_top"' if ($js_hier && !$frames);


}

###############################################################################
# show usage
#
sub usage {
    my ($msg) = @_;

    print "\nError: $msg\n";
    print <<EOF;

usage: v2html [options] file1 [file2] ...

Verilog like options:

  +define: Specify a define for use when processing, can be either:
            +define+NAME or +define+NAME=VALUE
  +incdir: Specify a directory to search for includes +incdir+DIR_NAME
  -y     : Specify a library to search for modules eg: -y DIR_NAME
  +libext: Specify a the extension for libraries eg: +libext+.v or +libext+.v+.V
  -v     : Specify a library file (same as putting the file without -v)

options:
 -f        : file to read options and file names from
 -o        : output directory for html files (default: current directory).
 -q        : be quiet.
 -m        : mail address for site maintainer.
 -F        : generate output using three frames - default output is frame.html
             you can change this by putting a file name (with .html extension
             after the -F option)
 -VF       : same as -F but does vertical frames with the hierarchy down the side
 -i        : incremental - check dates of files, if all .v.html files are newer
              than their .v files then do nothing, otherwise convert them all.
 -ht       : specify a top module to print the hierarchy for (the default
             is to do all hierarchies found in the input files) multiple
             -ht options can be specified.
 -htf      : print tasks and functions in the hierarchy
 -hc       : a comment to print at the top of the hierarchy
 -nh       : skip writing the hierarchy.
 -nindex   : skip writing the indexes.
 -nu       : skip writing the list of unconnected modules in the hierarchy
 -nnm      : skip writing the list of files with no modules in the hierarchy
 -ni       : do not 'grey out' code that is ifdefed out
 -s        : link to the source (in footer of each page) only works if:
             - your web server has access to the source code
             - you run v2html in the output directory or use absolute
               path names for the verilog
 -njshier  : turn off Javascript hierarchy generation.
 -ncookies : turn off Javascript cookies (for remembering js hierarchy state)
 -nsigpopup: turn off Javascript signal popup window.
 -css      : specify a URL for the cascading style sheet to use
 -z        : compress html files
 -zc       : compress command to use (default is compress)
 -ze       : extension of compressed files (default is .Z)
 -tab      : set tabstop to specified value
 -lines    : lines per html page (big files are split across multiple pages)
 -c        : activate CGI features (expanding of hierarchy) - to use this 
             you must have the v2html CGI script on your webserver - see man page.
 -k        : key to use for hierarchy CGI (default is to use a random one)
 -h        : name of file to write the hierarchy to (default: hierarchy.html).
 -debug    : useless info for debugging

Ignored options:
 
  most VCS options (the only conflicts with v2html options are -o -s and -i)
  all +options not mentioned above

example:
  v2html -hc "Our Chip" -o /users/www/p/html -m Joe_Blogs\@jb.com
     +incdir+/p/includes -y /p/verilog +libext+.v+.V /p/verilog/chip_top.v

See http://www.burbleland.com/v2html/v2html.html for more details

EOF

    exit 1;

} #'

###############################################################################
# The argument specifies a file that contains arguments - exactly the
#  same as on the command line
# comments are # or // you can quote things like this: -zc 'gzip -f'
#
sub add_options_from_file {
    my ($file) = @_;
    my (@args_found,$text_s);
    
    open(F,"<$file") || usage("can not open $file to read arguments");
    $/ = undef;
    $text_s = <F>;
    $/ = "\n";
    close(F);

    while ($text_s =~ m%((?:/\*.*?\*/)|(?://[^\n]*\n)|(?:#[^\n]*\n)|(?:'[^']*')|(?:"[^"]*")|(?:\S+))%gs )
    {   #'){ get emacs mode back in sync!
	$_ = $1;
	if ( m/\n$/ || m%/\*.*?\*/%s ) {	    # comment, chuck it 
	    print " cmdfile: chucking comment :|$_|\n" if $debug;
	}
	elsif ( m/^['"]/ ) {        # "']{
	    s/\A.//;
	    s/.\Z//;
	    print " cmdfile: found string |$_|\n" if $debug;
	    push(@args_found,$_);
	}
	else {
	    print " cmdfile: found word |$_|\n" if $debug;
	    push(@args_found,$_);
	}
    }

    unshift( @ARGV, @args_found );
    push( @args , @args_found );
}

###############################################################################
#   Misc functions
###############################################################################

###############################################################################
# given a source file name work out the .html file name
#  without the path
#
sub hfile {
    my ($sfile,$sline) = @_;
    my ($page);

    # debugging checks
    # die "No line passed to hfile!\n" unless defined($sline);
    # die  "bad sline: $sline\n" unless $sline=~m/^[0-9-]+$/;

    # NB sline starts at 1
    $page = ($sline <= $lines_per_file) ? '' : 
	".p" . (1+int(($sline-1)/$lines_per_file));
    $sfile  =~ s/^.*[\/\\]//;
    $sfile .= "$page.html";
    $sfile .= $compress_extension if $compress;

    return $sfile;
}

###############################################################################
# given a source file name work out the file without the path
#
sub ffile {
    my ($sfile) = @_;

    $sfile =~ s/^.*[\/\\]//;

    return $sfile;
}

###############################################################################
# Check whether we need to rebuild - delete any old files if we do
#
sub check_incremental {
    my ($out_dir) = @_;
    my ($incr_file,$filelist,$rebuild,@old_input_files,@old_output_files,@old_args,
	$file,$mtime,$mtime_s,$mtime_o,$section);
    local(*F);

    $incr_file="$out_dir.v2html_incr";

    $rebuild=0;
    if ( ! -r $incr_file ) {
	print "Could not find file list $incr_file\n" unless $quiet;
	$rebuild= 1;
    }
    
    # read the incremental file, and check that the options match
    if ($rebuild==0) {
	open(F,"<$incr_file") || die "can not open $filelist read to file list";
	$section=1;
	# Read incr file, be quite careful, as anything read into old_output_files 
	#  can get deleted
	while (<F>) { 
	    chomp; 
	    if (m/^---output files/) {
		if ($section==1) {
		    $section++;
		}
		else {
		    print "Corrupt incremental file $out_dir.v2html_incr, remove and retry\n"; 
		    exit;
		}
	    }
	    elsif (m/^---options/) {
		if ($section==2) {
		    $section++;
		}
		else {
		    print "Corrupt incremental file $out_dir.v2html_incr, remove and retry\n"; 
		    exit;
		}
	    }
	    else {
		if    ($section==1) { push(@old_input_files,$_);  }
		elsif ($section==2) { push(@old_output_files,$_); }
		elsif ($section==3) { push(@old_args,$_); }
	    }
	}
	if ($section!=3) {
	    print "Corrupt incremental file $out_dir.v2html_incr, remove and retry\n"; exit;
	}

	if ("@args" ne "@old_args") {
	    print "Arguments are different\n" unless $quiet;
	    $rebuild=1;
	}
    }
    if ($rebuild==0) {
	$mtime_s=$mtime_o=0;
	# find the newest source file
	foreach $file (@old_input_files) {
	    if ( -r $file ) {
		$mtime   = (stat( $file ))[9];
		$mtime_s = ($mtime>$mtime_s) ? $mtime : $mtime_s;
	    }
	    else {
		print "Source file $file has gone\n" unless $quiet;
		$rebuild=1;
		last;
	    }
	}
	# find the oldest output file
	foreach $file (@old_output_files) {
	    if ( -r $file ) {
		$mtime   = (stat( $file ))[9];
		$mtime_o = (($mtime<$mtime_o)||($mtime_o==0)) ? $mtime : $mtime_o;
	    }
	    else {
		print "Output file $file has gone\n" unless $quiet;
		$rebuild=1;
		last;
	    }
	}
    }

    if ($rebuild==0) {
	if ($mtime_o < $mtime_s ) {
	    print "Some source files are newer than the output files\n"
		unless $quiet;
	    $rebuild=1;
	}
	elsif ($mtime_o < (stat( $0 ))[9]) {
	    print "Some output files are older than $0\n"
		unless $quiet;
	    $rebuild=1;
	}
    }

    # Need to remove files produced on the last run to stop junk accumulating
    #  in the output dir (now that multiple pages
    if ($rebuild) {
	print "Removing old output files\n" unless $quiet;
	foreach $file (@old_output_files) {
	    if ( $file =~ m/\.html/ ) {
		unlink($file);
	    }
	    else {
		print "Warning: skipping remove of $file (does not end in .html)\n";
	    }
	}
    }

    return ($rebuild==0);
}

###############################################################################
# Write out the files read for incremental compiles
#
sub write_filelist {
    my ($fdata,$out_dir)= @_;
    my ($file,$opt);
    local (*F);

    open(F,">$out_dir.v2html_incr") || die "Could not write to $out_dir.v2html_incr";

    foreach $file (sort &rvp::get_files($verilog_db)) {
	print F &rvp::get_files_full_name($verilog_db,$file) . "\n";
    }

    print F "---output files\n";
    foreach $file (@output_files) {
	print F "$file\n";
    }

    print F "---options\n";
    foreach $opt (@args) {
	print F "$opt\n";
    }
    close(F);
}



###############################################################################
# Print out the footer
#  arguments: $out: output file handle
#              $src: name of source file (to put in footer)
#              $js:  flag telling it whether to print it, or
#                     to generate javascript to print it
sub print_footer {
    my ($out,$src,$narrow,$js) = @_;


    print_h_or_js($out,"<hr>\n",$js);
    print_h_or_js($out,"<table>\n <tr><td><i>This page:<\/i><\/td>\n",$js);

    print_h_or_js($out,"<td> </td></tr><tr>\n",$js) if $narrow;

    if ($maint ne '') {
	print_h_or_js($out,"  <td><i>Maintained by:<\/i><\/td>\n",$js);
	print_h_or_js($out,"  <td><i><a href=\"mailto:" . $maint . "\">\n",$js);
	print_h_or_js($out,"  " . $maint . "<\/a><\/i><\/tr>\n<tr>\n",$js);
	print_h_or_js($out,"<td> </td>\n",$js) if !$narrow;
    }

    print_h_or_js($out,"  <td><i>Created:<\/i><\/td><td><i>" . 
	localtime() . "<\/i><\/td><\/tr>\n",$js);
    
    if ($src ne '') {
	print_h_or_js($out,"<tr>\n",$js);
	print_h_or_js($out," <td> </td>\n",$js) if !$narrow;
	print_h_or_js($out," <td><i>From:<\/i><\/td><td><i>\n",$js);

	if ($link_to_source) {
	    print_h_or_js($out,"  <a href=\"" . $src . "\">\n",$js);
	    quote_html(\$src);
	    print_h_or_js($out,$src . "<\/a>",$js);
	}
	else {
	    quote_html(\$src);
	    print_h_or_js($out,$src,$js);
	}
	print_h_or_js($out, "<\/i><\/td><\/tr>\n",$js);
    }

    print_h_or_js($out,"</table>\n<hr>\n",$js);

    ##################################################################
    #             Do not alter any of this footer information        #
    ##################################################################
    print_h_or_js($out,'<table width="100%"><tr><td><i>Verilog converted to html by ',$js);
    print_h_or_js($out,' <a target="_top" '.
		  'href="http://www.burbleland.com/v2html/v2html.html">',$js);
    print_h_or_js($out,"  v2html $version<\/a> \n",$js);
    print_h_or_js($out," (written by",$js);
    print_h_or_js($out," <a href=\"mailto:v2html\@burbleland.com\">",$js);
    print_h_or_js($out,"Costas Calamvokis<\/a>).<\/i></td>",$js);
    print_h_or_js($out,'<td align="right"><b>'.
		  '<a href="http://www.burbleland.com/v2html/help_7_0.html?'.
		  $help_info.'">Help</a></b></td>',$js) if !$narrow;
    print_h_or_js($out,'</tr></table>',$js);
    ##################################################################
    #                    End of footer information                   #
    ##################################################################

    # put a big blank table (90% of the size of the window) at the
    # bottom of the page to make it scroll better
    print_h_or_js($out, "<table height=\"90%\"><tr><td></td></tr></table>\n" , $js);
}


###############################################################################
#   Print out a navigation bar
###############################################################################

sub print_navbar {
    my ($out,$js,$type,$data,$prevnext,$prevnext_file,$narrow) = @_;
    my ($elem,$col,$elem_num);

    $col = @{$data->{order}};

    # skip hierarchy if frames are on - it'll always be in top frame
    if ($frames) {
	foreach $elem (@{$data->{order}}) {
	    $col-- if $elem eq 'Hierarchy';
	}
    }

    if ($type eq 'Hierarchy' && ($cgi_script||$js_hier)) {
	$col+=2; # put in two extra buttons for the show all/hide all
    }


    # prev next takes an extra column
    $col++ if $prevnext;

    return unless ($col);

    my $width = $narrow ? 33 : int(100/$col);

    my $td_code="<td align=\"center\" width=\"$width\%\" ".
           "onmousedown=\"this.style.border=\\'inset\\';\" ". 
	       "onmouseup=\"this.style.border=\\'outset\\';\" ";

    # if we are framed then we can't just set location when a table
    #  element is clicked, have to set parent.middle.location to put
    #  code into the middle frame, and 
    my $frame_code_js;
    my $frame_top_js;
    ($frame_code_js = $frame_code) =~ s/^.*"(.*)".*$/parent.$1./;
    $frame_code_js="" if $frame_code_js =~ m/_top/;
    ($frame_top_js  = $frame_top)  =~ s/^.*"(.*)".*$/parent.$1./;


    print_h_or_js($out,"<center><table class=$classes{navbar} cols=$col ".
		  "><tr>",$js);


    if ($prevnext) {
	print_h_or_js($out,"$td_code onclick=\"${frame_code_js}location=\\'$prevnext_file\\';\">".
		      "<a $frame_code href=\"$prevnext_file\">$prevnext</a></td>",
		      $js);
    }
    $elem_num=0;
    foreach $elem (@{$data->{order}}) {
	if ($type eq 'Hierarchy' && $elem eq 'Hierarchy') {
	    if ($cgi_script) {
		print_h_or_js($out,"$td_code onclick=\"${frame_top_js}location=\\'$cgi_script$web_base/?k=$cgi_key&x=C&in=$hier_file&f=$frames\\';\"><a $frame_top " . 
		    "href=\"$cgi_script$web_base/?k=$cgi_key&x=C&in=$hier_file&f=$frames\">" .
			"Hide All</a></td>\n",0);
		print_h_or_js($out,"$td_code onclick=\"${frame_top_js}location=\\'$cgi_script$web_base/?k=$cgi_key&x=A&in=$hier_file&f=$frames\\';\"><a $frame_top " . 
		    "href=\"$cgi_script$web_base/?k=$cgi_key&x=A&in=$hier_file&f=$frames\">" .
			"Show All</a></td>\n",0);
		$elem_num+=2;
	    }
	    if ($js_hier && $js) {
		print_h_or_js($out,"$td_code onclick=\"javascript:parent.printIt(\\'C\\',-1)\">".
			      "<a href=\"javascript:parent.printIt(\\'C\\',-1);\">".
			      "Hide All</a></td>\n",1);
		print_h_or_js($out,"$td_code onclick=\"javascript:parent.printIt(\\'A\\',-1);\">".
			      "<a href=\"javascript:parent.printIt(\\'A\\',-1)\">".
			      "Show All</a></td>\n",1);
		$elem_num+=2;
	    }
	}
	# skip hierarchy if frames are on - it'll always be in top frame
	next if (($elem eq 'Hierarchy') && $frames);
	if ($narrow && ($elem_num!=0) && (($elem_num%3)==0)) {  
	    print_h_or_js($out,"</tr><tr>",$js); 
	}
	$elem_num++;
	if ( $elem eq $type ) {
	    print_h_or_js($out,"$td_code>".
			  "<font color=\"#808080\">$elem</font></td>",$js);
	}
	else {
	    my $i = $data->{$elem};
	    $i =~ s|\\|\\\\|;
	    print_h_or_js($out,"$td_code onclick=\"${frame_code_js}location=\\'$i\\';\">".
			  "<a $frame_code href=\"$data->{$elem}\">$elem</a></td>",
			  $js);
	}
    }

    print_h_or_js($out,"<\/tr><\/table><\/center>\n",$js);

}

###############################################################################
#   Index printing
###############################################################################

###############################################################################
# Collect the data and print all indexes
#
sub print_indexes {
    my ($fdata,$js) = @_;

    my (@files,@modules,@signals,@tasks,@functions,$m,$sig,$tf,$t_type,$indl);

    # this stores the mapping between index letter and index file name
    #  for each of the indexes, as well as the nav bar
    $index_info = {};

    # approx line count we'd like for an index, divide be expected lines
    #  per entry to give number of elements per index that we need to
    #  call print index
    $indl = 1000; 

    @files = &rvp::get_files($fdata);           # get the files
    @modules = &rvp::get_modules($fdata);       # get the modules

    # get the signals
    @signals = ();
    foreach $m (&rvp::get_modules($fdata)) {
	foreach $sig (&rvp::get_modules_signals($fdata,$m)) {
	    push (@signals,"$sig $m");
	}
    }

    # get the tasks and functions
    @tasks = @functions = ();
    foreach $m (&rvp::get_modules($fdata)) {
	foreach $tf (&rvp::get_modules_t_and_f($fdata,$m)) {
	    ($t_type)=&rvp::get_modules_t_or_f($fdata,$m,$tf);
	    if ($t_type eq 'task') {  push (@tasks,"$tf $m");     }
	    else {                    push (@functions,"$tf $m"); }
	}
    }

    # sort and split them across files
    $index_info->{Files}    = calc_index($fdata,$navbar{Files},\@files, $indl/4);
    $index_info->{Modules}  = calc_index($fdata,$navbar{Modules},\@modules,$indl/8);
    $index_info->{Signals}  = calc_index($fdata,$navbar{Signals},\@signals, $indl/20);
    $index_info->{Tasks}    = calc_index($fdata,$navbar{Tasks},\@tasks, $indl/3);
    $index_info->{Functions}= calc_index($fdata,$navbar{Functions},\@functions, $indl/3);

    # now print all the indexes
    print_index($fdata,$index_info->{Files},'Files',\@files,\&print_file_index);
    print_index($fdata,$index_info->{Modules},'Modules',\@modules,\&print_module_index);
    print_index($fdata,$index_info->{Signals},'Signals',\@signals,\&print_signal_index);
    print_index($fdata,$index_info->{Tasks},'Tasks',\@tasks,\&print_tf_index);
    print_index($fdata,$index_info->{Functions},'Functions',\@functions,\&print_tf_index);
}

###############################################################################
# calculate all sorts of stuff about the index (also sorts the data)
#  returns a hash for the that is stored in $index_info->{type}
#
sub calc_index {
    my ($fdata,$fname, $data, $items_per_index) = @_;
    my ($first_char,$elem_first_char,$info,$page,$ofile,$i,$items);

    # do a case insensitive sort (but make sure it is determinate if the
    #  items only differ in case)
    @{$data} = sort { (uc($a) ne uc($b)) ? uc($a) cmp uc($b)  : 
		                           $a cmp $b            } @{$data};

    # work out the indexes
    $first_char=""; # make sure it will not match
    $page=$items=0;

    $info            = {};
    $info->{nb}        = {}; # navbar, labels and links eg {A}='hierarchy-fn#index--A'
    $info->{nb}{order} = []; #  the navbar order, array of other keys (A,B...)
    $info->{letters}   = {}; # hash mapping start letters to index files
    $info->{pages}     = 0;  # number of pages
    $info->{files}     = []; # array of hashes { name, start, end } indexed 1,2...

    for ($i=0;$i<scalar(@{$data});$i++) {
 	$elem_first_char=uc(substr($data->[$i],0,1));
	if ($elem_first_char ne $first_char) {
	    if ($items==0 || $items_per_index<$items) {
		if ($page) { $info->{files}[$page]{end} = $i; }
		$page++;
		$ofile=$fname;
		$ofile =~ s/.html$/.p$page.html/ if ($page != 1);
		$info->{files}[$page] = { name => $ofile, start => $i};
		$items=0;
	    }
	    $info->{letters}{$elem_first_char} = $ofile;
	    $first_char=$elem_first_char;
	    push(@{$info->{nb}{order}},$first_char);
	    $info->{nb}{$first_char} = "$ofile#index--$first_char";
	}
	$items++;
    }
    if ($page) {
	$info->{pages}=$page;
	$info->{files}[$page]{end} = $i;
    }
    else { # handle case where there was no data
	$info->{pages}=1;
	$info->{files}[1] = { name => $fname , start => 0 , end => 0 };
    }
    return $info;
}

###############################################################################
# Print one index - calls out to printfn to print each entry
#
sub print_index {
    my ($fdata,$info, $type, $data, $printfn) = @_;
    my ($i,$first_char,$elem_first_char,$page,$ofile);
    local (*OUT);


    for ($page=1;$page<=$info->{pages};$page++) {
	$ofile=$info->{files}[$page]{name};
	
	open(OUT,">$out_dir$ofile") || 
	    die "Error: ca not open file $out_dir$ofile to write: $!\n";
	push(@output_files,"$out_dir$ofile");
	print OUT "<!-- v2html $type index  -->\n";
	print OUT "<html><head>\n";
	print OUT "<title>$type index".(($page==1)?"":" page $page")."</title>\n";
	print OUT $style_sheet_link;
	print OUT "</head>\n";

	if ($js_sigs) {
	    # dummy function in case someone tries to do a search in the index 
	    print OUT "<script language=\"JavaScript\" type=\"text\/javascript\"><!--\n";
	    print_js_common(*OUT);
	    print OUT "function search ()     { return false; }\n";
	    print OUT "// -->\n";
	    print OUT "</script>\n";
	}

	print OUT "<body>\n";
	
	print OUT "<a name=\"top_of_page\"></a>\n";

	if ($page==1) { print_navbar(*OUT,0,$type,\%navbar,'','',0); }
	else          { print_navbar(*OUT,0,$type,\%navbar,"Prev Page",
				     $info->{files}[$page-1]{name}.'#bottom_of_page',
				     0); }
	print_navbar(*OUT,0,'',$info->{nb},'','',0);
	print OUT "<center><h3>$type index</h3></center>\n";
	
	$first_char=""; # make sure it will not match 
	
	for ($i=$info->{files}[$page]{start};$i<$info->{files}[$page]{end};$i++) {
	    $elem_first_char=uc(substr($data->[$i],0,1));
	    if ($elem_first_char ne $first_char) {
		$first_char=$elem_first_char;
		print OUT "<a name=\"index--$first_char\"></a>\n";
		print_navbar(*OUT,0,'',
			     { order=>[$first_char], $first_char=>"#top_of_page"},
			     '','',0);
	    }
	    &{$printfn}(*OUT,$fdata,$data->[$i]);
	}
	
	print_navbar(*OUT,0,'',$info->{nb},'','',0);
	if ($page==$info->{pages}) { print_navbar(*OUT,0,$type,\%navbar,'',''); }
	else          { print_navbar(*OUT,0,$type,\%navbar,"Next Page",
				     $info->{files}[$page+1]{name},0); }
	print_footer(*OUT,'',0,0);
	print OUT "</body>\n";
	print OUT "</html>\n";
	close(OUT);
    }

}

###############################################################################
# Called to print on entry in the file index
#
sub print_file_index {
    my ($out,$fdata,$data) = @_;
    my ($m,$ms,$qword,$title,$inc,$i,$comma,$inc_by);

    $title  = "<b><a name=\"$data\"></a>".
	"<a $frame_middle href=\"".hfile($data,1)."\">$data</a></b>\n";

    $ms=$comma='';
    foreach $m (sort &rvp::get_files_modules($fdata,$data)) {
	$qword = $m; quote_html(\$qword);
	if (&rvp::module_exists($fdata,$m)) {
	    $ms .= "$comma<a href=\"".index_link("Modules",$m)."\">$qword</a>&nbsp;";
	}
	else { $ms .= "$comma$qword&nbsp;"; }
	$comma=', ';
    }

    $inc=$comma='';
    foreach $i (sort &rvp::get_files_includes($fdata,$data)) {
	$qword = $i; quote_html(\$qword);
	if (&rvp::file_exists($fdata,$i)) {
	    $inc .= "$comma<a href=\"".index_link("Files",$i)."\">$qword</a>&nbsp;";
	}
	else { $inc .= "$comma$qword&nbsp;"; }
	$comma=', ';
    }

    $inc_by=$comma='';
    foreach $i (sort &rvp::get_files_included_by($fdata,$data)) {
	$qword = $i; quote_html(\$qword);
	if (&rvp::file_exists($fdata,$i)) {
	    $inc_by .= "$comma<a href=\"".index_link("Files",$i)."\">$qword</a>&nbsp;";
	}
	else { $inc_by .= "$comma$qword&nbsp;"; }
	$comma=', ';
    }

    print_itable( $out , $title  ,
		 [ "Full name:"  , &rvp::get_files_full_name($fdata,$data) ,
		   "Modules:"    , $ms  ,
		   "Includes:"   , $inc ,
		   "Included by:", $inc_by ]);

}

###############################################################################
# Called to print on entry in the module index
#
sub print_module_index {
    my ($out,$fdata,$data) = @_;
    my ($qword,$title,$inst,$m,$f,$i,$file,$inst_by,$tasks,$funcs,@t_and_f,$tf,$t_type,
	$comma,$fcomma,$m_line,$type);

    ($file,$m_line)=&rvp::get_modules_file($fdata,$data);
    $type=&rvp::get_modules_type($fdata,$data);
    $qword=$data; quote_html(\$qword);
    $title  = "<b><a name=\"$data\"></a>".
	"<a $frame_middle href=\"".
	    hfile($file,$m_line)."#$data\">$qword</a></b>\n";
    $title .= "<i>($type)</i>\n" unless $type eq 'module';

    $inst=$comma='';
    ($m,$f,$i) = &rvp::get_first_instantiation($fdata,$data );
    while ($m) {
	if (&rvp::module_exists($fdata,$m)) {
	    $inst.="$comma<a href=\"".index_link("Modules",$m)."\">$m:$i</a>&nbsp;";
	}
	else {
	    $inst.="$comma$m:$i&nbsp;";
	}
	$comma=', ';
	($m,$f,$i) = &rvp::get_next_instantiation($fdata);
    }

    $inst_by=$comma='';
    ($m,$f,$i) = &rvp::get_first_instantiator($fdata,$data );
    while ($m) {
	if (&rvp::module_exists($fdata,$m)) {
	    $inst_by.="$comma<a href=\"".index_link("Modules",$m)."\">$m:$i</a>&nbsp;";
	}
	else {
	    $inst_by.="$comma$m:$i&nbsp;";
	}
	$comma=', ';
	($m,$f,$i) = &rvp::get_next_instantiator($fdata);
    }


    $tasks=$funcs=$comma=$fcomma='';
    if ( @t_and_f = &rvp::get_modules_t_and_f($fdata,$data) ) {
	foreach $tf (sort @t_and_f) {
	    ($t_type)=&rvp::get_modules_t_or_f($fdata,$data,$tf);
	    if ($t_type eq 'function') { 
		$funcs.="$fcomma<a href=\"".index_link("Functions","${tf}___$data").
		    "\">$tf<\/a>&nbsp;";  
		$fcomma=', ';
	    }
	    else { 
		$tasks.="$comma<a href=\"".index_link("Tasks","${tf}___$data").
		    "\">$tf<\/a>&nbsp;";
		$comma=', ';
	    }
	}
    }


    print_itable( $out , $title ,
		 [ "File:" , "<a href=\"".index_link("Files",$file)."\">$file</a>" .
		            ((&rvp::module_ignored($fdata,$data)) ?
                              " (Warning: Duplicate definition found)" : "") ,
		   "Instantiates:" , $inst ,
		   "Instantiated by:" , $inst_by,
		   "Tasks:"           , $tasks , 
		   "Functions:"       , $funcs ]);

}

###############################################################################
# Called to print on entry in the Signal index
#
sub print_signal_index {
    my ($out,$fdata,$data) = @_;
    my ($qword,$sig,$m,$title,$s_line,$s_i_line,$s_type,$s_file,
	$s_pos,$s_neg,$s_type2,$im,$in,$p,$port_con,$comma,$con_to,$cts,$cti,$ctm);

    ($sig,$m) = split(' ',$data);

    ($s_line,undef,$s_i_line,$s_type,$s_file,$s_pos,$s_neg,$s_type2) = 
	&rvp::get_module_signal($fdata,$m,$sig);
    $s_type.=" $s_type2" if $s_type2;
    $s_type.=" (used in \@posedge)" if $s_pos;
    $s_type.=" (used in \@negedge)" if $s_neg;

    $qword="$sig : $m"; quote_html(\$qword);
    $title  = "<b><a name=\"$sig"."___$m\"></a>".
	"<a $frame_middle href=\"".
	    hfile($s_file,$s_line)."#$s_line\">$qword</a></b> : $s_type";

    $port_con=$comma='';
    ($im,$in,$p,)=&rvp::get_first_signal_port_con($fdata,$m,$sig);
    while ($im) {
	if (&rvp::module_exists($fdata,$im) && ($p !~ m/^[0-9]/)) {
	    $port_con.="$comma<a href=\"".index_link("Signals","${p}___$im")."\">$im:$in:$p</a>&nbsp;";
	}
	else { $port_con.="$comma$im:$in:$p&nbsp;"; }
	$comma=', ';
	($im,$in,$p,)=&rvp::get_next_signal_port_con($fdata);
    }
    
    $con_to=$comma='';
    ($cts,$ctm,$cti)=&rvp::get_first_signal_con_to($fdata,$m,$sig);
    while ($cts) {
	if (&rvp::module_exists($fdata,$ctm) && ($cts !~ m/^[0-9]/)) {
	    $con_to.="$comma<a href=\"".index_link("Signals","${cts}___$ctm")."\">$ctm:$cti:$cts</a>&nbsp;";
	}
	else { $con_to.="$comma$ctm:$cti:$cts&nbsp;"; }
	$comma=', ';
	($cts,$ctm,$cti)=&rvp::get_next_signal_con_to($fdata);
    }

    # Only print table if there are some portcons to save space
    if ($port_con || $con_to) {
	print_itable( $out , $title ,
		      [ "Connects down to:" , $port_con ,
		        "Connects up to:" , $con_to ]);
    }
    else {
	print_itable( $out , $title , []);
    }

}

###############################################################################
# Called to print on entry in the Tasks or Functions index
#
sub print_tf_index {
    my ($out,$fdata,$data) = @_;
    my ($qword,$tf,$m,$title,$t_type,$t_line ,$t_file,$t_anchor);

    ($tf,$m) = split(' ',$data);

    ($t_type,$t_line ,$t_file,$t_anchor)=&rvp::get_modules_t_or_f($fdata,$m,$tf);


    $qword="$tf"; quote_html(\$qword);
    $title  = "<b><a name=\"$tf"."___$m\"></a>".
	"<a $frame_middle href=\"".
	    hfile($t_file,$t_line)."#$t_anchor\">$qword</a></b>";

    print_itable( $out , $title , 
		 [ "File:" , "<a href=\"".index_link("Files",$t_file).
		  "\">$t_file</a>" , 
		  "Module:" , "<a href=\"".index_link("Modules",$m)."\">$m</a>" ]);

}

###############################################################################
# Print out a table in the index, called with the output file, the title and
#  a pointer to an array of table pairs (column 1 and column 2)
#
sub print_itable {
    my ($out,$title,$tab) = @_;
    my ($f1,$f2,$empty);
    print $out "&nbsp;$title\n";
    if (@{$tab}) {
	$empty=1;
	print $out "<div align=right><table cols=2 width=\"97%\">\n";
	while ($f1=shift(@{$tab})) {
	    $f2=shift(@{$tab});
	    die "print_itable internal error" unless (defined($f2));
	    if ($f2 ne '') {
		$empty=0;
		print $out "<tr><td valign=top width=\"17%\"><i>$f1</i></td>".
		    "<td valign=top width=\"83%\">$f2</td></tr>\n";
	    }
	}
	print $out "<tr><td></td></tr>\n" if ($empty); # NS does not like empty tables
	print $out "</table></div>\n";
    }
    else {
	print $out "<br>\n";
    }
}

sub index_link {
    my ($type,$elem) = @_;

    # debugging checks
    print "Error: Bad index link $type $elem\n" 
    	unless (exists($index_info->{$type}{letters}{uc(substr($elem,0,1))}));
    return $index_info->{$type}{letters}{uc(substr($elem,0,1))} . "#$elem";
}

###############################################################################
#   Hierarchy and frame printing
###############################################################################

###############################################################################
# Print out the hierarchy
#  arguments: output_file_name, javascript flag
#
sub print_hier {
    my ($h_file,$js,$hier_tops_p) = @_;
    my ($out_file,$m,$imod);
    local (*HIER,*JSF,*FT);

    # write out the blank printIt file - this is a work around for a NS6 bug (22681)
    open(FT,">$out_dir"."blank_printIt.html") || 
	die "Error: can not open file blank_printIt.html to write: $!\n ";
    push(@output_files,"$out_dir"."blank_printIt.html");
    print FT "<html><head>\n";
    print FT "<title></title>\n";
    print FT $style_sheet_link;
    print FT "</head><body onload=\"javascript:parent.printIt('',-1)\"></body></html>\n";
    close (FT);


    $out_file = $out_dir . $h_file;
    open(HIER,">$out_file") || 
	die "Error: can not open file $out_file to write: $!\n";
    push(@output_files,"$out_file");

    if (defined(@{$hier_tops_p})) {
        # check that all the hierarchy tops (specified with -ht)  exist
	foreach $module (@{$hier_tops_p}) {
	    die "Error: Did not find top module $module\n"
		if (!&rvp::module_exists($verilog_db,$module));
	}
    }
    else {
	# search for all hier tops - modules that are not instantiated
	#  but do instantiate at least one module that we have source for
	MOD_LOOP: foreach $m (sort &rvp::get_modules($verilog_db)) {
	    print "  checking if module $m is a top\n" if $debug;
	    if  (! &rvp::get_first_instantiator($verilog_db,$m)) {
		($imod) = &rvp::get_first_instantiation($verilog_db,$m );
		while ($imod) {
		    print "   checking instantiation $imod\n" if $debug;
		    if (&rvp::module_exists($verilog_db,$imod)) {
			push(@{$hier_tops_p},$m);
			next MOD_LOOP;
		    }
		    ($imod) = &rvp::get_next_instantiation($verilog_db);
		}
	    }
	}
    }

    if ($js) {
	print " doing js version\n" if $debug;
	$js_file = $out_file;
	$js_file =~ s/.html$//;
	$js_file = $js_file . ".js";
	open(JSF,">$js_file") || 
	    die "Error: can not open file $js_file to write: $!\n";

	# do the java script version first
	print_js_hier_head(*JSF,join(" ",@{$hier_tops_p}));
	print_hier_body(*JSF,$hier_tops_p,1);
	print_js_hier_tail(*JSF);
	close(JSF);
    }

    # now do the html version
    print " doing html version\n" if $debug;
    print_hier_head(*HIER,join(" ",@{$hier_tops_p}),$js,$js_file,$h_file);
    print_hier_body(*HIER,$hier_tops_p,0);
    print_hier_tail(*HIER,$js);
    close(HIER);
    print " done html version\n" if $debug;
}

###############################################################################
# Print out header information in hierarchy file
#
sub print_hier_head {
    my ($out,$t,$js,$js_file,$h_file) = @_;

    print " print_hier_head\n" if $debug;
    print $out "<!-- v2html hierarchy ";
    print $out "K=$cgi_key " if $cgi_script;
    print $out "-->\n";
    print $out "<html><head>\n";
    
    if ($js) {
	print_js_include( $out , $js_file);
	unlink($js_file) unless $frames; # do not need the javascript file anymore
    }

    print $out "<title>hierarchy: $t</title>\n";
    print $out $style_sheet_link;
    print $out "</head>\n";

    print $out "<noscript>" if ($js);

    print $out "<body>\n";


    print $out "<center><b>The Javascript features of this page are not ".
	"working in your browser. Either you do not have a Javascript capable".
	    " browser (NS3, IE4 or later) or you have Javascript".
		" disabled in your preferences.</b></center><br>"
		if ($js);
}

###############################################################################
# Print out the hierarchy
#  arguments: output_file_name, javascript flag
#
sub print_hier_body {
    my ($out,$hier_tops_p,$js) = @_;
    my ($f,$m,$m_line,$fb,@no_mods,$nm,@unconnected,$imod);

    print " print_hier_body\n" if $debug;
    $ul_id=0; # used for folding hierarchy

    print_navbar($out,$js,'Hierarchy',\%navbar,'','',$vert_frames);
    print_h_or_js($out, "<center><h3>$hier_comment</h3></center>\n",$js) if $hier_comment;

    #
    # Go through each module you were asked for
    #
    foreach $m (@{$hier_tops_p}) {
	($f,$m_line) = &rvp::get_modules_file($verilog_db,$m);
	print_h_or_js($out, "<h3>Hierarchy for " . $m . "</h3>\n",$js);
	print_h_or_js($out, "<nobr><ul>\n",$js);
	print_tree($out,$m,$m_line,$f,0,1,$js);
	print_h_or_js($out, "</ul></nobr>\n",$js);
	print_h_or_js($out, "<hr>\n",$js);
    }

    # 
    # now do files containing no modules
    #
    if ($print_no_mods) {
	foreach $f (&rvp::get_files($verilog_db)) {
	    push(@no_mods,$f) 
		if (0 == &rvp::get_files_modules($verilog_db,$f));
	}
	if (@no_mods) {
	    print_h_or_js($out, "<h3>Files containing no modules</h3>\n",$js);
	    print_h_or_js($out, "<ul>\n",$js);
	    foreach $f (@no_mods) {
		($fb = $f) =~ s/^.*\///;
		print_h_or_js($out, "<li>" . "<a $frame_code href=\"" 
			      . hfile($f,1) . "\">$fb</a>\n",$js);
		if ($output_index) {
		    print_h_or_js($out,"<a $frame_code href=\"".
				  index_link("Files",$fb)."\">$icon_i<\/a>\n",$js);
		}
	    }
	    print_h_or_js($out, "</ul>\n",$js);
	    print_h_or_js($out, "<hr>\n",$js);
	}
    }

    #
    # Now do unconnected modules
    #  (unreffed modules that do not instantiate any other modules
    #   that we have source for)
    #
    if ($print_unconnected) {
	MOD_LOOP: foreach $m (sort &rvp::get_modules($verilog_db)) {
	    print "  checking if module $m is unconnected\n" if $debug;
	    # the hier tops have been done already, so ignore them
	    foreach $imod (@{$hier_tops_p}) {
		if ($imod eq $m) { next MOD_LOOP; }
	    }
	    if  ( ! &rvp::get_first_instantiator($verilog_db,$m)) {
		($imod) = &rvp::get_first_instantiation($verilog_db,$m );
		while ($imod) { 
		    if (&rvp::module_exists($verilog_db,$imod)) {
			next MOD_LOOP;
		    }
		    ($imod) = &rvp::get_next_instantiation($verilog_db );
		} 
		# if we got here we are unconnected
		push(@unconnected,$m);
	    }
	}
	if (scalar(@unconnected) != 0) {
	    if ((scalar(@unconnected) == 1)&&(!defined(@{$hier_tops_p}))) { 
		print_h_or_js($out, "<h3>$unconnected[0]</h3>\n",$js);
	    }
	    else {
		print_h_or_js($out, "<h3>Unconnected modules</h3>\n",$js);
	    }
	    
	    print_h_or_js($out, "<nobr><ul>\n",$js);
	    foreach $m (@unconnected) {
		# even though we're unconnected print_tree is called
		#  because there may be submodules we do not have source for
		($f,$m_line) = &rvp::get_modules_file($verilog_db,$m);
		print_tree($out,$m,$m_line,$f,0,1,$js);
	    }
	    print_h_or_js($out, "</ul></nobr>\n",$js);
	    print_h_or_js($out, "<hr>\n",$js);
	}
    }
}

###############################################################################
# Recursively Print the hierarchical tree for a module
#
sub print_tree {
    my ($out,$m,$m_line,$f,$depth,$n_inst,$js) = @_;
    my (@t,$tt,$count,$this_ul_id,$this_ces_arg,$prev_ces_arg,$i,$imod,$tl,$tf);

    print " print_hier_tree($out,$m,$m_line,$f,$depth,$n_inst,$js)\n" if $debug;
    if ($js) {
	if ( defined($index_stack[0]) ) {
	    $prev_ces_arg = "ul_i_" . $index_stack[$#index_stack];
	}
	else {
	    $prev_ces_arg = "1";
	}
	print $out "  if ( $prev_ces_arg ) {\n";
    }

    print_h_or_js($out," " x $depth  . "<li>" . 
		   "<a $frame_code href=\"" . 
		   hfile($f,$m_line) . "#" . $m . "\">" . $m . "</a>\n",$js);
    if ($output_index) {
	print_h_or_js($out,"<a $frame_code href=\"".index_link("Modules",$m)."\">".
		      "$icon_i<\/a>\n",$js);
    }


    print_h_or_js($out," " x $depth  . "x $n_inst\n",$js) if ($n_inst!=1);
    print $out "  }\n" if ($js);

    @t=();
    if ( (($imod) = &rvp::get_first_instantiation($verilog_db,$m )) ||
	 ($t_and_f_in_hier && scalar(&rvp::get_modules_t_and_f($verilog_db,$m)))) {
	# get all the things it instantiates and call print tree on them
	while ($imod) {
	    push(@t,$imod);
	    ($imod) = &rvp::get_next_instantiation($verilog_db);
	}
	@t = sort( @t );
	$this_ul_id = $ul_id;
	$ul_id++;
	push(@index_stack,$this_ul_id);
	$this_ces_arg = "ul_i_$this_ul_id";
	if ($js) {
	    print $out "    $this_ces_arg = " .
		"$prev_ces_arg && check_expand_string(control,$this_ul_id);\n";
	    print_h_or_js($out,"<a name=\"ul_id_$this_ul_id\"></a>\n",1);
	    print $out "  if ( $this_ces_arg ) {\n";
	    print_h_or_js($out,"<a href=\"javascript:parent.printIt(\\'' + " . 
			   " new_expand_string(control,$this_ul_id,'C') + " .
			   " '\\', $this_ul_id)".
			   "\"> $icon_c</a>\n<ul>\n",1);
	    print $out "  }\n",; 
	    print $out "  else { \n";
	    print $out "    if ( $prev_ces_arg ) {\n";
	    print_h_or_js($out,"<a href=\"javascript:parent.printIt(\\'' + " . 
			   " new_expand_string(control,$this_ul_id,'X') + " .
			   " '\\', $this_ul_id)".
			   "\"> $icon_x</a>\n",1);
	    print $out "    }\n  }\n";
	    
	}
	else { 
	    print_h_or_js($out, "<ul> <!-- ul_id=$this_ul_id -->\n",0); 
	}
	for ($i=0;$i<=$#t;$i++) {
	    $tt = $t[$i];
	    $count=1;
	    while (($i<$#t) && ($t[$i] eq $t[$i+1])) { $i++; $count++; }

	    if ( ! &rvp::module_exists($verilog_db,$tt) ) {
		print $out "  if ( $this_ces_arg ) {\n" if ($js);
		print_h_or_js($out," " x $depth . " <li>$tt\n",$js);
		print_h_or_js($out," " x $depth . " x $count\n",$js) 
		    if ($count!=1);
		print_h_or_js($out,
			      " (not linked because of duplicate definition)\n",
			      $js) 
		    if (&rvp::module_ignored($verilog_db,$tt));
		print $out "  }\n" if ($js);
	    }
	    else {
		($tf,$tl) = &rvp::get_modules_file($verilog_db,$tt),
		print_tree($out,$tt,$tl,$tf,$depth+1,$count,$js);
	    }
	}
	if ($t_and_f_in_hier) {
	    print $out "  if ( $this_ces_arg ) {\n" if $js;
	    &print_hier_t_and_f($out,$m,$depth,$js);
	    print $out "  }\n" if $js;
	}
	if ($js) {
	    print $out "  if ( $this_ces_arg ) {\n";
	    print_h_or_js($out, "</ul>\n",1);
	    # Print the string if it is getting too long, this stops netscape's memory usage exploding
	    #  when viewing large hierarchies. Open the document before doing the first write.
	    print $out "     if (Text.length >5000) { if (!doc_open) { parent.upper.document.open(); doc_open=1; }".
		" parent.upper.document.write(Text); Text=''; }\n";
	    print $out "  }\n";
	}
	else { 
	    print_h_or_js($out, "</ul> <!-- ul_id=$this_ul_id -->\n",0); 
	}
	pop(@index_stack);
    }

}

sub print_hier_t_and_f {
    my($out,$m,$depth,$js) = @_;
    my (@t_and_f,$tf,$t_type,$t_line,$t_file,$t_anchor);

    if ( @t_and_f = &rvp::get_modules_t_and_f($verilog_db,$m) ) {
	foreach $tf (sort @t_and_f) {
	    ($t_type,$t_line ,$t_file,$t_anchor)=
		&rvp::get_modules_t_or_f($verilog_db,$m,$tf);
	    $t_type = 'func' if ($t_type eq 'function');
	    print_h_or_js($out," " x $depth  . "<li><i>$t_type:</i> " .
			  "<a $frame_code href=\"" . 
			  hfile($t_file,$t_line) . "#" . $t_anchor . "\">" . 
			  $tf . "</a>\n",$js);
	    if ($output_index) {
		if ($t_type eq 'task') {
		    print_h_or_js($out,"<a $frame_code href=\"".
				  index_link("Tasks","${tf}___$m")."\">".
				  "$icon_i<\/a>\n",$js);
		}
		else {
		    print_h_or_js($out,"<a $frame_code href=\"".
				  index_link("Functions","${tf}___$m")."\">".
				  "$icon_i<\/a>\n",$js);
		}
	    }
	}
    }

}

###############################################################################
# Either print a string directly or output some javascript
#  that will end up printing it
#
sub print_h_or_js {
    my ($out,$s,$js) = @_;



    if ($js) {
	$s =~ s/\n/\\n/g;
	$s =~ s|</|<\\/|g;
	print $out "      Text += '" . $s . "';\n";
    }
    else {
	$s =~ s|\\'|'|g; #'
	print $out $s;
    }
}

###############################################################################
# print the bottom of the hierarchy
#
sub print_hier_tail {
    my ($out,$js) = @_;

    print " print_hier_tail\n" if $debug;
    print_navbar($out,0,'Hierarchy',\%navbar,'','',$vert_frames);
    print_footer($out,'',$vert_frames,0);
    print $out "</body>\n";

    if ($js) {
	print $out "</noscript>\n";
	print $out " <frameset cols=\"100%,*\">\n";
	print $out "  <frame name=\"upper\" " .
	    "src=\"blank_printIt.html\">\n";
	print $out " </frameset>\n";
    }
    print $out "</html>\n";
}

###############################################################################
# Print the top of the javascript hierarchy (functions that
#  will end up printing the hierarchy)
#
sub print_js_hier_head {
    my ($out,$t) = @_;

    print_js_common($out);

  #####################JAVASCRIPT START##################################
    print $out <<EOF;

// dummy function in case someone tries to do a search in the hierarchy window
function search ()     { return false; } 

function check_expand_string (control,index) {
  if (control.charAt(0)=='A') {
    return 1;
  }
  else if ( index < control.length ) {
    return (control.charAt(index)=='X');
  }
  else {
    return 0;
  }
}

function new_expand_string (control,index,v) {
  var newString;
  if ( index < control.length ) {
    newString = control.substring(0,index) + v + 
           control.substring(index+1,control.length);
  }
  else {
      if (control == 'A') { newString = 'X';     }
      else                { newString = control; }
      for (var i=0; i<(index-control.length); i++) {
          if (control == 'A') { newString += 'X' }
          else                { newString += 'C' }
      }
    newString += v;
  }
  return newString;
}

function getCookie(Name) {
   var search = Name + "=";
   if (document.cookie.length > 0) { // if there are any cookies
      offset = document.cookie.indexOf(search) ;
      if (offset != -1) { // if cookie exists 
         offset += search.length ;
         // set index of beginning of value
         end = document.cookie.indexOf(";", offset) ;
         // set index of end of cookie value
         if (end == -1) 
            end = document.cookie.length;
         return unescape(document.cookie.substring(offset, end));
      } 
   }
   return '';
}

function setCookie(name, value) {
   var today = new Date();
   var expires = new Date();
   expires.setTime(today.getTime() + 1000*60*60*24*365);

   document.cookie = name + "=" + escape(value)
   + "; expires=" + expires.toGMTString();
}

function printIt (control,loc) {
    var Text='';
    var doc_open=0;
EOF
    #####################JAVASCRIPT END####################################
    print $out "  if (control.length==0) control=getCookie(\"v2html $t\");\n" 
	if $js_cookies;
    print $out "  if (control.length==0) control='C';\n";
    print $out "  setCookie(\"v2html $t\",control);\n"
	if ($js_cookies);


    print_h_or_js($out,"<html><head>\n",1);
    print_h_or_js($out,"<title>hierarchy: $t</title>$style_sheet_link</head>\n",1);
    print_h_or_js($out, "<body>",1);

}

###############################################################################
# Print out the end of the javascript hierarchy
#
sub print_js_hier_tail {
    my ($out) = @_;

    print_navbar($out,1,'Hierarchy',\%navbar,'','',$vert_frames);
    print_footer($out,'',$vert_frames,1);

  #####################JAVASCRIPT START##################################
    print $out <<EOF;

    if (!doc_open) parent.upper.document.open();
    parent.upper.document.write(Text);
    Text='';
    parent.upper.document.write('<\\/body><\\/html>');
    parent.upper.document.close();
    if (loc != -1) {
      if (is_nav5up) 
	// - 18 needed because this is the height of the icon (I think)
	parent.upper.scrollTo(0,parent.upper.document.anchors[loc].offsetTop-18);
      else if (is_nav4up) 
	parent.upper.scrollTo(0,parent.upper.document.anchors[loc].y);
      else if (is_ie4up)
        parent.upper.document.anchors[loc].scrollIntoView(true)        
    }
}

EOF
  #####################JAVASCRIPT END####################################
}

###############################################################################
# Print out the html that will include the javascript
#
sub print_js_include {
    my ($out , $jsf) = @_;

    # this does not work without server's mimetypes being configured:
    #    print $out "<script language=\"JavaScript\" src=\"$jsf\"></script>\n";

    # this works whatever (copy all the js code into current file!)
    print $out "<script language=\"JavaScript\" type=\"text\/javascript\"><!--\n";
    open (TTT,"<$jsf") || die "Error: can not open file $jsf to read: $!\n"; 
    while (<TTT>) { print $out $_; }
    close(TTT);
    print $out "// -->\n";
    print $out "</script>\n";
}
    
sub print_js_sigpopup {
    my ($out) = @_;

    # Be careful when writing this: comments get stripped out later
    #  rather crudely - so using // in a string for example will break!
  #####################JAVASCRIPT START##################################
    my $script = <<EOF;

var disabled=1;
if (!is_nav4up) {
  var event=false; // prevent from dieing ns3 and ie4up
}
var last_link=0;     // last link found in search
var last_class=null; // class of last link changed to highlighted

// main quick search function called when any link is clicked
function qs(e,t,extra_info_index) {
  var inc=0,bnum=0,i,j;
  if (disabled) return false;
  // buttons for signal window in order of extra info
  var sig_buttons = [ "Definition" , "Local Driver" , 
                      "Up to Input Driver" , "Find Source" , "Index"];

   if (is_nav4up || is_ie4up) {
    // test if quicksearch is wanted:
    //  forwards  = button 2  or        button 1 + control
    //  backwards = button 2 + shift or button 1 + shift

    if (((e.which==2) && (!(e.modifiers&Event.SHIFT_MASK))) ||
	((e.which==1) &&  (e.modifiers&Event.CONTROL_MASK)))   inc = 1;
    else if (((e.which==2) && (e.modifiers&Event.SHIFT_MASK)) ||
	     ((e.which==1) && (e.modifiers&Event.SHIFT_MASK))) inc = -1;

    if (inc == 0 && extra_info_index == 0) { // no quick search and no extra_info, so just return 
      return true;  // follow link as normal
    }

    var linkText = is_nav4up ? t.text : t.innerText;
    var linkY    = is_nav4up && ! is_nav5up ? t.y    : t.offsetTop;
    // find the index of the current link
    window.status="Searching...";
    if ((last_link==-1) || (document.links[last_link]!=t)) // try previous link first
      for (last_link=0;last_link<document.links.length;last_link++) 
	if (document.links[last_link] == t)  
	  break;

    if (inc != 0) { // do the quick search
      return search(linkText,linkY,last_link,inc,1);
    }
    else { // do something with the extra_info
      window.status="";
      extra_info_index--; // when passed, 0 means no data so decrement to get index
      if (extra_info[extra_info_index][0] != 'S') { // check the type is signal
	  return true;
      }
      //  open a window, or get a handle to an existing window - unfortunately
      //   if the window is open and has been resized manually it will be 
      //   changed back to its initial size (I do not know anyway around this
      //   apart from opening it with nosize then checking if it has already
      //   been written and if not closing it and opening one with default size.
      //   This would look very clunky though!)
      var w = window.open('','SignalPopUp','width=200,height=235');

      // check to see if the window is already written and if it is then
      //  if the latest file is in the same dir as the file that first 
      //  opened to window  - if no then close and reopen the window
      //  otherwise the old links go screwy
      if (null != w.document.forms[0]) {
	 if ((window.location.pathname.substring(0,window.location.pathname.lastIndexOf(dirSep)))!=
            (w.pn.substring(0,w.pn.lastIndexOf(dirSep)))) {
	   w.close();
	   w = window.open('','SignalPopUp','width=200,height=235');
	 }
      }

      w.focus(); // raise popup window (does not work on linux NS4.51)

      if (null == w.document.forms[0]) { // true if the window has not yet been written
	var Text = '<html><head></head>';
	

	// make some variables that are local to the popup window
        if (is_nav4up) { // can not get the script way to work in NS...
          w.loc = new Array(10);
          w.sel = null;
	  w.pn  = window.location.pathname;
        }
        else {     // ...can not get the w. way to work in IE
          Text += '<script>var loc = new Array(10);<\\/script>\\n';
          Text += '<script>var sel;<\\/script>\\n';
          Text += '<script>var pn = opener.location.pathname;<\\/script>\\n';
        }

	Text += '<body bgcolor="white">\\n';
	Text += '<form>';
	Text += '  <select onchange="opener.setbuttons(window);">\\n';
	// ns4 on windows does not grow the width so start it really wide
	Text += '  <option>---------------------------</option>\\n';
	// ns4 on windows does not grow the length and IE4 dies if
	//  I leave the field blank!
	for (j=0;j<9;j++) Text += '  <option>-</option>\\n';
	Text += '  </select>\\n';
	Text += '</form>';

	Text += '<table cellspacing=0 cellpadding=0>\\n';

	// length-1 because location 0 of extra_info is the type, so ignore it
        for (var i=0;i<(extra_info[extra_info_index].length-1);i++) {
	  Text += hbutton(sig_buttons[i], 
			  'opener.location=loc[sel.selectedIndex]['+i+'];',
			  bnum++);
        }
        Text += hbutton("Search Backwards", 
			'opener.search(sel.options[ sel.selectedIndex ].text,' +
			'0,opener.last_link,-1,0);',bnum++);
        Text += hbutton("Search Forwards",
			'opener.search(sel.options[ sel.selectedIndex ].text,' +
			'0,opener.last_link, 1,0);',bnum++);
        Text += hbutton("Close","window.close();",bnum++);

	Text += '</table>\\n';
	Text += '</body></html>\\n';

	w.document.open();
	w.document.write(Text);
	w.document.close();
	w.document.forms[0].elements[0].options[0].text  = linkText;
	// save space in the window code by defining this short cut
	w.sel = w.document.forms[0].elements[0]; // refer to the forms elements

	for (j=0;j<10;j++) w.loc[j] = new Array(sig_buttons.length);  
        copy_into_loc0(w,extra_info_index);
      }
      else {
	var opts = w.document.forms[0].elements[0].options;
	// this code is obsolete - I have to start at size 10 anyway
	//  because ns4 under windows will not grow the list dynamically
	if ( opts.length<10 ) { 
           w.loc[opts.length] = new Array;
           opts.length++; 
        }
	for (i=opts.length-2;i>=0;i--) {
	  opts[i+1].text=opts[i].text;
	  for (var j=0;j<w.loc[i].length;j++) w.loc[i+1][j] = w.loc[i][j];
	}
	opts[0].text  = linkText;
        copy_into_loc0(w,extra_info_index);
      }

      return false; 
    }
  }
  return true;
}

// Return the html for a button labeled with text that does the specified
//  action. Also needs bnum which is the number of the buttons image in the
//  imagesarray.
//
function hbutton (text,action,bnum) {
  return '  <tr><td><a href="" '+
    'onmousedown="'+
	'if (images['+bnum+'].src.match(/v2html-b2.gif/)) return false; ' +
	'images['+bnum+'].src=\\'v2html-b3.gif\\';" '+
    'onmouseup="'+
	'if (images['+bnum+'].src.match(/v2html-b2.gif/)) return false; ' +
	'images['+bnum+'].src=\\'v2html-b1.gif\\';" '+
    'onclick="'+
	// do not do anything if the button is greyed out
	'if (images['+bnum+'].src.match(/v2html-b2.gif/)) return false; ' +
	// do action
        action + 
       ' return false;">'+
    '<img border=0 src="v2html-b1.gif"></a></td>' +
    '<td style="font-family:sans-serif; font-weight:bold; font-size:14px;"> '+text+'</td></tr>\\n';
}

function copy_into_loc0 (w,extra_info_index) {
    for (var i=1;i<extra_info[extra_info_index].length;i++) {
	w.loc[0][i-1] = extra_info[extra_info_index][i];
    }
    w.document.forms[0].elements[0].selectedIndex=0;
    setbuttons(w);
}

function search(text,y,i,inc,relative) {
  var nextpage,wrappage,linkText,linkY;

  window.status="Searching...";
  if (last_class) document.links[i].className=last_class;

  while (1) {
    for (i+=inc;i<document.links.length && i>=0;i+=inc) {
      linkText = is_nav4up ? document.links[i].text : document.links[i].innerText;
      linkY    = is_nav4up && ! is_nav5up ? document.links[i].y    : document.links[i].offsetTop;
      if ((linkText == text) && (linkY != y)) {
	  window.status="";
          // NOTE: have not done relative (used up Quick search) for IE4
          //  because I have not got the button capture to work for QS under IE4
          if (is_nav4up) 
            if (relative) window.scrollBy(0,linkY - y);
            else          window.scrollTo(0,linkY); 
          else if (is_ie4up)
	    document.links[i].scrollIntoView(true); // IE put link at top of screen
	last_link=i;
	last_class=document.links[i].className;
	document.links[i].className='HI';
	return false;
      }
    }
    nextpage = (inc==1) ? next_page() : prev_page();
    wrappage = (inc==1) ? first_page() : last_page();
    if (nextpage!="" || wrappage!="") {
      if (nextpage=="") { // only ask when wrapping around
	if (!confirm(text + " not found. Search again from "+((inc==1)?"first":"last")+" page?"))
	  return false;
	nextpage=wrappage;
      }
      location=nextpage+ "?" + escape(text) + "&" + ( y - window.pageYOffset ) + "&" + inc;
      return false;
    }
    if (confirm(text + " not found. Search again from "+((inc==1)?"start":"end")+"?")) {
      if (inc==1) i=-1;
      else i=document.links.length;
    } else return false;
  }
  return true;
}

function loadqs() {
  var opt=location.search, text="", s="", y=0, si=0, inc=1;

  if (opt.length==0) return true;  // no query string
  for (var i=1;i<opt.length;i++) { // parse query string: search_text&y_pos&direction
    if (opt.charAt(i) != "&") 
      s += opt.charAt(i);
    else {
      if (text=="") text=unescape(s);
      else             y=s;
      s="";
    }
  }
  if (text=="") return true;
  if (s == "-1") { si=document.links.length-1; inc=-1; }
  window.scrollTo(0,0);
  search(text,y,si,inc);
  return true;
}
EOF
  #####################JAVASCRIPT END####################################

    if (!$debug) {
	# save space in each file 
	$script =~ s|//.*$||gm;  # strip comments
	$script =~ s|^\s+||gm;   # strip leading whitespace
	$script =~ s|^\n||gm;    # strip blank lines 
    }

    print $out "<script language=\"JavaScript\" type=\"text\/javascript\"><!--\n";
    print_js_common($out);
    print $out "// Unindented and uncommented to save spave ".
	"- look in v2html for a prettier version\n";
    print $out $script;
    print $out "// -->\n";
    print $out "</script>\n";

}


###############################################################################
# Print javascript that occurs in every file
#
sub print_js_common {
    my ($out) = @_;

  #####################JAVASCRIPT START##################################
    my $script= <<EOF;
// this code is a cut down version of the netscape detector code
var agt=navigator.userAgent.toLowerCase(); 
var is_nav  = ((agt.indexOf('mozilla')!=-1) &&
	       (agt.indexOf('spoofer')==-1) &&
	       (agt.indexOf('compatible') == -1) &&
	       (agt.indexOf('opera')==-1) &&
	       (agt.indexOf('webtv')==-1)); 
var is_major = parseInt(navigator.appVersion); 
var is_nav4up = (is_nav && (is_major >= 4)); 
var is_ie     = (agt.indexOf("msie") != -1); 
var is_ie4up  = (is_ie  && (is_major >= 4)); 
var is_nav5up = (is_nav && (is_major >= 5));

// dirSep stores the directory separator. Note IE file urls
// have \ _and_ / in - so look for \ and assume it is the separator
// if you find it. Otherwise use the unix /
var dirSep = (window.location.pathname.indexOf('\\\\') != -1) ? '\\\\' : '/' ;

// Grey out buttons that will do nothing
//  - called from the signal popup, so must be in all files to avoid errors
function setbuttons (wndw) {
  var i;

  // first do the buttons from extra_info (locations stored in loc)
  var sl=wndw.loc[ wndw.document.forms[0].elements[0].selectedIndex ];

  for (i=0;i<sl.length;i++) {
    if(sl[i]) wndw.document.images[i].src='v2html-b1.gif';
    else      wndw.document.images[i].src='v2html-b2.gif';
  }
  // now do the search buttons
  if ( wndw.document.forms[0].elements[0].options[ 
	 wndw.document.forms[0].elements[0].selectedIndex ].text != '-') {
    wndw.document.images[i  ].src='v2html-b1.gif';
    wndw.document.images[i+1].src='v2html-b1.gif';
  }
  else {
    wndw.document.images[i  ].src='v2html-b2.gif';
    wndw.document.images[i+1].src='v2html-b2.gif';
  }
}

EOF
  #####################JAVASCRIPT END####################################

    if (!$debug) {
	# save space in each file 
	$script =~ s|//.*$||gm;  # strip comments
	$script =~ s|^\s+||gm;   # strip leading whitespace
	$script =~ s|^\n||gm;    # strip blank lines 
    }
    print $out $script;
}


###############################################################################
# Print the frame.html file
#
sub print_frame_top {
    my ($f,$h,$title,$js,$vert_frames) = @_;
    my ($out_file);
    local (*FT);

    # first write out the blank file
    open(FT,">$out_dir"."blank.html") || 
	die "Error: can not open file blank.html to write: $!\n ";
    push(@output_files,"$out_dir"."blank.html");
    print FT "<html><head>\n";
    print FT "<title>verilog</title>\n";
    print FT $style_sheet_link;
    print FT "</head><body></body></html>\n";
    close (FT);

    
    # now output the frame top
    $out_file = $out_dir . $f;
    open(FT,">$out_file") || 
	die "Error: can not open file $out_file to write: $!\n ";
    push(@output_files,$out_file);

    print FT "<html><head>\n";

    if ($js) {
	print_js_include( *FT , $js_file);
	unlink($js_file); # do not need the javascript file anymore
    }

    print FT "<title>verilog view: $title</title>\n";
    print FT $style_sheet_link;
    print FT "</head>\n";

    print FT "<noscript>\n" if ($js);
    print FT frameset( $vert_frames, $h );
    
    if ($js) {
	print FT "</noscript>\n";
	print FT frameset($vert_frames,"blank_printIt.html");
    }
    print FT "</html>\n";

    close(FT);

}	

sub frameset {
    my ($vert_frames,$middle_page_url) = @_;
    my ($rval);
    if ($vert_frames) {
	$rval= "<frameset cols=\"30%,70%\">\n".
	       " <frame name=\"upper\"  src=\"$middle_page_url\">\n".
               " <frameset rows=\"90%,10%\">\n".
	       "  <frame name=\"middle\" src=\"blank.html\">\n".
	       "  <frame name=\"bottom\" src=\"blank.html\">\n".
	       " </frameset>\n";
    }
    else {
	$rval= "<frameset rows=\"20%,70%,10%\">\n".
	       " <frame name=\"upper\"  src=\"$middle_page_url\">\n".
	       " <frame name=\"middle\" src=\"blank.html\">\n".
	       " <frame name=\"bottom\" src=\"blank.html\">\n";
    }
    if ($middle_page_url !~ /^javascript/) {
	$rval .= "<body>\n<noframes>\n".
	         " Your browser does not support frames click\n".
                 " <a href=\"$middle_page_url\">here</a> to see the hierarchy\n".
		 "</noframes></body>\n";
    }
    $rval.="</frameset>\n";
    return $rval;

}


###############################################################################
# Output open an closed suitcase icons
#  scripts/encode_gif.pl can generate the print_gif code automagically
#
sub print_gifs {
    my ($out_dir,$print_xc,$print_i)=@_ ;

    if ($print_xc) {
	# uuencoded gif file for v2html-c.gif
	print_gif( "${out_dir}v2html-c.gif" ,
                  'M1TE&.#EA&P`2`,(``/C\^`````@@6+C,R)AD,#`P,/_______R\'Y!`$*``<`'."\n".
                  'M+``````;`!(```-:>!?<K##*&(2]-LP-*_[.PRU?"8Z>J6I;6KI8^,!7,-#V'."\n".
                  'MH.L"8^:WT&XG*/A`PZ2RJ($!E4NCPO6$#IF=FA6*S?:V45:V"NY2R%NSA*8J'."\n".
                  '.2%\'NN%PN&BUD>\'L"`#L`'."\n".
                  '`'."\n");
	# uuencoded gif file for v2html-x.gif
	print_gif( "${out_dir}v2html-x.gif" ,
                  'M1TE&.#EA%``2`,(``/C\^````+C,R`@@6#`P,,C\^/_______R\'Y!`$*``<`'."\n".
                  'M+``````4`!(```-->!?<K#"J(*JM049ZNWO3T%FB-PE#JJ8CFG\'MF!),\'`\T'."\n".
                  'M;)-XO7<]W6_F^Y%R1AXR60DR44Z45$2=HFB+E79+P"ZZX+"81H!\S@Y"(0$`'."\n".
                  '!.P``'."\n".
                  '`'."\n");

    }
    # uuencoded gif file for v2html-up.gif
    print_gif( "${out_dir}v2html-up.gif" ,
	       'M1TE&.#EA&P`2`*$``/C\^````+C,R/___R\'Y!`$*``,`+``````;`!(```(Z'."\n".
	       'MG(^IRQC18@KB24E%A7=EO7432%KB\)&:>:7JRD7N"\O/K=XWIN?[B?(!#RX6'."\n".
	       '/L!@[ZGY#U#+9C$H-!0`['."\n".
                  '`'."\n");
    if ($print_i) {
	# uuencoded gif file for v2html-i.gif
	print_gif( "${out_dir}v2html-i.gif" ,
		   'M1TE&.#EA!``\'`(```/____\``"\'Y!`$`````+``````$``<```((1`*&R9>N'."\n".
		   '$D"L`.P``'."\n".
		   '`'."\n");
    }

    if ($js_sigs) {
	print_gif( "${out_dir}v2html-b1.gif" ,
                  'M1TE&.#EA&P`2`,(``/C\^+BXN`@@6,C\^+C,R#`P,/_______R\'Y!`$*``<`'."\n".
                  'M+``````;`!(```-+>+K<_C#*$ZJ].%>FNQ9<,!!D:9ZE`"[5B+ZF&KHP++-B'."\n".
                  'L7=]*J]NK7NZ\'XE&&Q%CP2$N2C#YG:AF5$J"JK\';++2R]W\'"X,"F;SXX$`#L`'."\n".
                  '`'."\n");
	print_gif( "${out_dir}v2html-b2.gif" ,
                  'M1TE&.#EA&P`2`,(``/C\^+BXN`@@6+C,R,C\^#`P,/_______R\'Y!`$*``<`'."\n".
                  'M+``````;`!(```-0>+K<_C#*$P*]-N-=F?Y<*#36<)CHJ:;FZ!W$*K.RNY1S'."\n".
                  'MGMJ*%=/`&DE\';`U_Q1SO$FP>EKYD$"I5\'JNTY6C[[\'*_AT)##"Y[N^*)>LUN'."\n".
                  '$)```.P``'."\n".
                  '`'."\n");
	print_gif( "${out_dir}v2html-b3.gif" ,
                  'M1TE&.#EA&P`2`,(``/C\^#`P,`@@6+BXN+C,R/___________R\'Y!`$*``<`'."\n".
                  'M+``````;`!(```-(>+K<_C#*$X2]..O`1-6@-G0"89YHB@[C8JFPRI)Q;<YN'."\n".
                  'I:<>X\NZPWN$\'3`F)Q=-1EU2V?,PF82EU=EC8K\'8KY\'J]D[!X[$@``#L`'."\n".
                  '`'."\n"); #`)
    }
}

sub print_gif {
    my ($file,$data) = @_;

    print "Writing icon $file\n" unless $quiet;
    open(GIF,">$file") || 
	die "Error: can not open file $file to write: $!\n ";
    binmode(GIF);
    print GIF unpack("u",$data);
    close(GIF);
}


###############################################################################
# Output cascading style sheet
#
sub print_css {
    my ($out_dir)=@_ ;
    my ($c,$tag,$prop,$s,$checksum,$line);

    # do not overwrite
    if ( -r "${out_dir}v2html.css") {
	open(CSS,"<${out_dir}v2html.css") || 
	    die "Error: can not open file ${out_dir}v2html.css to check: $!\n ";

	$checksum=$line=0;
	while( defined($_=<CSS>)) { 
	    $checksum += unpack("%32C*",$_) * ($line + 73);
	    $checksum %= 65535;
	    $line++;
	}
	close(CSS);
	if (($checksum != 38677) &&   # the CSS generated by v2html 5.0 to 5.10
	    ($checksum != 17848) &&   # temp checksum for versions 5.11 to 5.14
	    ($checksum != 33561) &&   # temp checksum for versions to 6.14
	    ($checksum != 56981)      # checksum for versions later than 6.39
	    ) {
	    print "Not overwriting edited CSS ".
		"${out_dir}v2html.css (Checksum=$checksum)\n";
	    return;
	}
    }
    open(CSS,">${out_dir}v2html.css") || 
	die "Error: can not open file ${out_dir}v2html.css to write: $!\n ";

    # After changing the CSS run v2html in a blank directory twice
    #  the second time it should say:
    #  Not overwriting edited CSS new_html/v2html.css (Checksum=XXXXX)
    # Put the XXXXX value into the list of checksum above, so that newer v2html
    #  will overwrite unedited CSS files created by older v2html versions.
    print CSS <<EOF;
BODY { 	   /* main_body */
  background:#FFFFFF;
  color:#000000; 
}
A { /* default link */
  text-decoration:underline; 
  color:#08215A;
} 
TABLE.NB { /* navbar table */
  width:100%;
}
TABLE.NB TD { /* navbar table text */
  font-family:sans-serif;
  background:#BBCCCC;
  padding:0;
  border:outset;
  font-weight:bold;
  font-size:12px;
  text-decoration:none;
}
TABLE.NB A { /* navbar table links */
  color:#08215A;
  text-decoration:none;
}
A.HI { background:#FFFF00; } /* highlighted link found in search (not in NS4.x)*/

/* verilog language elements */
SPAN.C       { color:#0000FF; }				/* comment (non-link) */
A.C          { color:#0000FF; background:#CCCCFF; }	/* comment (link) */
SPAN.M       { color:#9933FF; font-weight:bold; }	/* compiler (non-link) */
SPAN.D       { color:#990099; }				/* define (non-link) */
A.D          { color:#990099; }				/* define (link) */
SPAN.F       { color:#CC0033; }				/* function (non-link) */
A.F          { color:#CC0033; }				/* function (link) */
SPAN.K       { color:#CC3300; }				/* keyword (non-link) */
SPAN.MM      { color:#6600FF; }				/* module (non-link) */
A.MM         { color:#6600FF; }				/* module (link) */
SPAN.PA      { color:#CC0066; }				/* parameter (non-link) */
A.PA         { color:#CC0066; }				/* parameter (link) */
SPAN.P       { color:#999999; }				/* pre-processor ignore (non-link) */
SPAN.S       { color:#009900; }				/* string (non-link) */
A.S          { color:#009900; }				/* string (link) */
SPAN.ST      { color:#9933FF; }				/* systemtask (non-link) */
SPAN.T       { color:#660033; }				/* task (non-link) */
A.T          { color:#660033; }				/* task (link) */

SPAN.SIO     { color:#00CC99; }				/* signal inout (non-link) */
A.SIO        { color:#00CC99; }				/* signal inout (link) */
SPAN.SIOR    { color:#009999; }				/* signal inout_reg (non-link) */
A.SIOR       { color:#009999; }				/* signal inout_reg (link) */
SPAN.SI      { color:#006600; }				/* signal input (non-link) */
A.SI         { color:#006600; }				/* signal input (link) */
SPAN.SIT     { color:#663333; }				/* signal integer (non-link) */
A.SIT        { color:#663333; }				/* signal integer (link) */
SPAN.SO      { color:#000066; }				/* signal output (non-link) */
A.SO         { color:#000066; }				/* signal output (link) */
SPAN.SOR     { color:#0000CC; }				/* signal output_reg (non-link) */
A.SOR        { color:#0000CC; }				/* signal output_reg (link) */
SPAN.SRL     { color:#663333; }				/* signal real (non-link) */
A.SRL        { color:#663333; }				/* signal real (link) */
SPAN.SR      { color:#FF9933; }				/* signal reg (non-link) */
A.SR         { color:#FF9933; }				/* signal reg (link) */
SPAN.SS0     { color:#CC6600; }				/* signal supply0 (non-link) */
A.SS0        { color:#CC6600; }				/* signal supply0 (link) */
SPAN.SS1     { color:#CC6600; }				/* signal supply1 (non-link) */
A.SS1        { color:#CC6600; }				/* signal supply1 (link) */
SPAN.STM     { color:#CC3333; }				/* signal time (non-link) */
A.STM        { color:#CC3333; }				/* signal time (link) */
SPAN.STI     { color:#CC6600; }				/* signal tri (non-link) */
A.STI        { color:#CC6600; }				/* signal tri (link) */
SPAN.ST0     { color:#CC6600; }				/* signal tri0 (non-link) */
A.ST0        { color:#CC6600; }				/* signal tri0 (link) */
SPAN.ST1     { color:#CC6600; }				/* signal tri1 (non-link) */
A.ST1        { color:#CC6600; }				/* signal tri1 (link) */
SPAN.STA     { color:#CC6600; }				/* signal triand (non-link) */
A.STA        { color:#CC6600; }				/* signal triand (link) */
SPAN.STR     { color:#CC6600; }				/* signal trireg (non-link) */
A.STR        { color:#CC6600; }				/* signal trireg (link) */
SPAN.SWA     { color:#CC6600; }				/* signal wand (non-link) */
A.SWA        { color:#CC6600; }				/* signal wand (link) */
SPAN.SW      { color:#CC6600; }				/* signal wire (non-link) */
A.SW         { color:#CC6600; }				/* signal wire (link) */
SPAN.SWO     { color:#CC6600; }				/* signal wor (non-link) */
A.SWO        { color:#CC6600; }				/* signal wor (link) */
SPAN.GV      { color:#CC6600; font-weight:bold }	/* V2001 genvar */
A.GV         { color:#CC6600; font-weight:bold }	/* V2001 genvar */
SPAN.AT      { color:#CC00CC; font-weight:bold }	/* V2001 attribute */
A.AT         { color:#CC00CC; font-weight:bold }	/* V2001 attribute */

EOF
    close(CSS);
}

###############################################################################
#   Converting verilog files as html
###############################################################################

###############################################################################
#  Convert a file to html
# 
sub convert {
    my ($f) = @_;
    my ($match,$start,$end,$length,$line,$previous,$last_pos,
	$text_s,$include,$fb,$out_file,$vstate,$out,$i);
    local (*F);

    $line = 1;
    $last_pos = 0;

    print "Converting $f\n" unless $quiet;
    open(F,"<$f") || die "Error: can not open file $f to read: $!\n";
    $/ = undef;
    $text_s = <F>;
    $/ = "\n";
    close(F);

    if ($tabstop!=0) {
	1 while ($text_s =~ s/(^|\n)([^\t\n]*)(\t+)/
	    $1. $2 . (" " x ($tabstop * length($3) - (length($2) % $tabstop)))
		/gsex);
    }


    $fb = ffile($f);

    # this stores the state needed in output_v
    $vstate = {};    
    $vstate->{context}         = '1';
    $vstate->{cur_inst}        = '$NONE'; # current instance
    $vstate->{cur_inst_exists} = 0;       # current instance can be linked to
    $vstate->{page}            = 0;       # page we're on
    $vstate->{rhs}             = 0;       # on right hand side of = or <=
    $vstate->{inst_link_done}  = 0;       # done the linking of the instance name
    $vstate->{line_started}    = 0;       # done initial stuff for line
    $vstate->{pre_ignore}      = 0;       # preprocessor told us to ignore 
                                          #  lines until this one
    $vstate->{name}            = '';      # name of module or t or f we are in
    $vstate->{type}            = '';      # type of context module,task or function
    $vstate->{lines}           = &rvp::get_files_stats( $verilog_db, $fb );
    $vstate->{page_nb}         = {};      # navbar for pages

    # we can put in shortened links (ie #x instead of file#x) unless we are using
    #  qs on a multipage file (because the ?query_string breaks with short links)
    $vstate->{short_links}     = (!$js_sigs) || ($vstate->{lines} < $lines_per_file);

    # store extra info for output at end of file in javascript array
    #  {NAME}{vindex} = number of index in javascript array
    #  {NAME}{value} = [] list of strings to store in array at this index
    $vstate->{extra_info}      = {};
    $vstate->{extra_info_last} = 0;

    # make page navbar for multipage files
    if ($vstate->{lines} > $lines_per_file) {
	$vstate->{page_nb}{order} = [ ];
	for ($i=1;(($i-1)*$lines_per_file)<$vstate->{lines};$i++) {
	    push ( @{$vstate->{page_nb}{order}} , $i );
	    $vstate->{page_nb}{$i}= hfile($f,(($i-1)*$lines_per_file)+1);
	}
    }

    if ($text_s) {
	while ($text_s =~ 
	        m%\G((/\*.*?\*/)|                # /* comments */
		     (\(\*.*?\*\))|              # (* attributes *)  V2001
		     (//.*?\n)|                  # // comment
		     (\`include\s+\".*?\")|      # include (string unblanked)
		     (\"(?:(?:\\\\)|(?:\\\")|([^\"]))*?\")| # string - ignore \\ and \"
		     (.*?                        # anything else followed by..
		      (?=(/\*|                   #      /*
			  \(\*|                  #      (*   V2001
			  //|                    #   or // 
			  \"|                    #   or quote
			  \`include\s+\".*?\"|   # or include
			  \Z)                    #  or end of string
		       ))
		     )%gsox ) {

	    $match  = $1;
	    
	    if ( ($vstate->{page}*$lines_per_file) < $line ) {
		convert_end_file($out,$f,$line-$lines_per_file,1,$vstate) 
		  if $vstate->{page};
		$vstate->{page}++;
		$out=convert_start_file($f,$line,$vstate->{page},$vstate->{lines},
					$vstate->{page_nb});
		$vstate->{file} = hfile($f,$line); # current html file
	    }

	    if ( $match =~ m%^/% ) { 
		# either sort of comment
		quote_html(\$match);
		# link mail addresses in comments
		$match =~ s/$mail_regexp/<a CLASS=C href=\"mailto:$1\">$1<\/a>/g;
		# turn urls into links
		$match =~ s/$http_regexp/<a CLASS=C href=\"$1\">$1<\/a>/g;
		if ($grey_ifdefed_out && $vstate->{pre_ignore}) {
		    print_with_font($out,"pp_ignore",$match);
		}
		else {
		    print_with_font($out,"comment",$match);
	        }
	    }
	    elsif ( $match =~ m%^\(\*% ) {
		# attribute
		quote_html(\$match);
		if ($grey_ifdefed_out && $vstate->{pre_ignore}) {
		    print_with_font($out,"pp_ignore",$match);
		}
		else {
		    print_with_font($out,"attribute",$match);
	        }
	    }
	    elsif ( $match =~ m%^\"% ) {
		# string
		quote_html(\$match);
		if ($grey_ifdefed_out && $vstate->{pre_ignore}) {
		    print_with_font($out,"pp_ignore",$match);
		}
		else {
		    print_with_font($out,"string",$match);
	        }
	    }
	    elsif ( $match =~ m%\`include(\s+)\"(.*?)\"% ) {
		# include
		if ($grey_ifdefed_out && $vstate->{pre_ignore}) {
		    quote_html(\$match);
		    print_with_font($out,"pp_ignore",$match);
		}
		else {
		    print_with_font($out,"compiler","`include");
		    print $out "$1";
		    $include = $2;
		    if ( &rvp::file_exists( $verilog_db, ffile($include) )) {
			print_link($out,$vstate->{file},$frame_middle,$js_sigs,
				   hfile($include,1),'',"&quot;$include&quot;",
				   "string",$vstate->{short_links},0);
		    }
		    else {
			print_with_font($out,"string", "&quot;$include&quot;");
		    }
		}
	    }
	    elsif ( $match =~ m%\A\s*\Z% ) {
		# whitespace
		print $out $match;
	    }
	    else {
		# verilog code (note: it can change $out if a new page is needed)
		$out=&output_v($out,$match,$line,$fb,$vstate,$f);
	    }
	    
	    $line += ($match =~ tr/\n/\n/);
	}
	print $out "\n";
    }
    else { # handle zero length files gracefully
	$out=convert_start_file($f,$line,1,$vstate->{lines},$vstate->{page_nb});
    }

    convert_end_file($out,$f,$line,0,$vstate);

}

sub convert_end_file {
    my ($out,$f,$line,$more,$vstate)=@_;
    my ($out_file,$next_file,$first_file,@extra_info_array,$e);
    print $out "</pre>\n";
    
    $first_file= (($vstate->{page}!=1)&&(!$more)) ? hfile($f,1) : ""; # used to wrap qs() on the last page
    $next_file = $more ? hfile($f,$line+$lines_per_file) : ""; # used to qs() to next page

    if (%{$vstate->{page_nb}}) {
	print_navbar($out,0,$vstate->{page},$vstate->{page_nb},($more?"Next":""),$next_file,0);
    }
    if ( (!$frames)  && ($output_hier || $output_index)) {
	print_navbar($out,0,'Verilog',\%navbar,'','',0);
    }
    if ($js_sigs) {
	print $out "<script language=\"JavaScript\"type=\"text\/javascript\"><!--\n";
	print $out "function next_page() { return \"$next_file\"; }\n";
	print $out "function first_page() { return \"$first_file\"; }\n";
	# put the values of extra info into the extra info array ordered by
	#  the index value for printing out
	foreach $e (keys %{$vstate->{extra_info}}) {
	    $extra_info_array[$vstate->{extra_info}{$e}{vindex}] = 
	      '"'. join('","',@{$vstate->{extra_info}{$e}{value}}) . '"';
	}
	print $out "var extra_info = [\n";
	print $out "[" . join("],\n[",@extra_info_array) . "]\n";
        print $out "];\n";
        print $out "disabled=0;\n";
	print $out "\/\/ -->\n<\/script>\n";
	# clear extra info
	$vstate->{extra_info} = {};
	$vstate->{extra_info_last} = 0;
    }

    print_footer($out,$f,0,0);
    print $out "</body>\n";
    print $out "</html>\n";

    close($out);

    if ($compress) {
	$out_file = $out_dir . hfile($f,$line);
	# In this case we do not want the $compress_extension on
	#  the file name
	$out_file =~ s/$compress_extension$//;
	system ( @compress_cmd , $out_file ) == 0 or die "System call failed";
    }
}

sub convert_start_file {
    my ($f,$line,$page,$lines,$page_nb)=@_;
    my ($out_file,$prev_file,$last_file);
    
    local (*C_OUT);
    
    # last file to blank if there only is one file
    $last_file= (hfile($f,$lines) eq hfile($f,0)) ? "" : hfile($f,$lines);
    $prev_file= ($page==1)? "" : hfile($f,$line-$lines_per_file);

    $out_file = $out_dir . hfile($f,$line);

    push(@output_files,$out_file);
    # In this case we do not want the $compress_extension on
    #  the file name
    $out_file =~ s/$compress_extension$// if $compress;
    print "Outputting $out_file\n" if $debug;

    open(C_OUT,">$out_file") || 
	die "Error: can not open file $out_file to write: $!\n";

    print C_OUT '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">'."\n";

    print C_OUT "<html><head>\n";
    print C_OUT "<title>$f" . (($page==1)?"":" page $page"). "</title>\n";
    print C_OUT $style_sheet_link;
    print C_OUT "</head>\n";
    print_js_sigpopup(*C_OUT) if ($js_sigs);
    print C_OUT "<body".($js_sigs ? " onload='loadqs();'" : "" ).">\n";

    if ($js_sigs) {
	print C_OUT "<script language=\"JavaScript\"type=\"text\/javascript\"><!--\n";
	print C_OUT "function prev_page() { return \"$prev_file\"; }\n";
	print C_OUT "function last_page() { return \"$last_file\"; }\n";
	print C_OUT "\/\/ -->\n<\/script>\n";
    }
    if ( (!$frames)  && ($output_hier || $output_index)) {
	print_navbar(*C_OUT,0,'Verilog',\%navbar,'','',0);
    }
    if (%{$page_nb}) {
	print_navbar(*C_OUT,0,$page,$page_nb,($prev_file)?"Prev":"",
		     $prev_file."#bottom_of_page",0);
    }
    print C_OUT "<pre>\n";
    return *C_OUT;
}

###############################################################################
# quote a html string
#
sub quote_html {
    my ($s) = @_;

    $$s =~ s/&/&amp;/g;
    $$s =~ s/</&lt;/g;
    $$s =~ s/>/&gt;/g;
    $$s =~ s/\"/&quot;/g;
}

###############################################################################
# print some text with html font information
#
sub print_with_font {
    my ($out,$fontname,$s) = @_;

    print $out "<span class=$classes{$fontname}>$s</span>";
}

###############################################################################
# print a link with class information
#
sub print_link {
    my ($out,$current_file,$target,$js_sigs,$link_file,$link_anchor,
	$link_text,$link_type,$short_links,$extra_data_index) = @_;
    my ($href,$class);

    $class='';
    $class=" class=$classes{$link_type}" if exists($classes{$link_type});


    $href='';
    $href.=$link_file unless $short_links && ($link_file eq $current_file) && $link_anchor;

    $href.="#$link_anchor" if $link_anchor;
    
    print $out "<a $target";
    print $out " onClick=\"return qs(event,this,$extra_data_index)\"" if ($js_sigs); # for quick search
    print $out " $class href=\"$href\">$link_text</a>";
}

###############################################################################
# Put all the stuff for a signal into the extra info array this is outputted
#  as a javascript array and then used in the qs() javascript function.
#  search for sig_buttons to see how it is used
# info should be pointer to:
#   [ [def_file,def_line],[a_file,a_line],[i_file,i_line],[src_file,src_line]
# Returns the index to be used in the qs call
sub signal_extra_info {
    my ($sig,$vstate,$index_ref,$info) = @_;

    my $ex_name= "S_${sig}___$vstate->{name}";

    unless (exists $vstate->{extra_info}{$ex_name}) {
	$vstate->{extra_info}{$ex_name} =  {
	    vindex => $vstate->{extra_info_last}++ ,
	    value  => [ 'S' ] };   # type of extra info
	foreach my $i (@$info) {
	    my $file = $i->[0];
	    my $line = $i->[1];
	    push(@{$vstate->{extra_info}{$ex_name}{value}},
		 ((($file eq "")||($line == -1)) ? "" :
		  hfile($file,$line)."#".$line));
	}
	push(@{$vstate->{extra_info}{$ex_name}{value}},$index_ref);
    }
    
    # Note that the index placed in the file starts at 1 
    #  because 0 means no extra info
    return ($vstate->{extra_info}{$ex_name}{vindex}+1);
}

###############################################################################
# output a chunk of verilog
#
sub output_v {
    my ($out,$s,$line,$file,$vstate,$sfile) = @_;
    my ($anchor,$linebuf,$word,$link_line,$on_def,$qword,$inst,$n,
	$new_context,$pre_ignore,$nextisdefine,$m,$ms,$f,$new_inst,$s_line,
	$s_a_line,$s_a_file,$s_i_line,$s_i_file,$s_type,$s_file,$s_type2,
	$t_type,$t_line,$t_file,$t_anchor,$p,$ex_index,$s_src_file,$s_src_line,
        $index_ref);

    # do a line at a time (so it can put down the anchors,
    #  and change the contexts and current instance).
    while ( $s =~ m/^(.*?(?:\n|\Z))/gm ) {
	$linebuf = $1;
	$nextisdefine=0; # for linking define after ifdef, define and undef
	
	if ( $line != $vstate->{line_started} ) {
	    # we are on a new line - first see if we need a new file
	    if ( ($vstate->{page}*$lines_per_file) < $line ) {
		convert_end_file($out,$sfile,$line-$lines_per_file,1,$vstate) 
		  if $vstate->{page};
		$vstate->{page}++;
		$out=convert_start_file($sfile,$line,$vstate->{page},$vstate->{lines},
					$vstate->{page_nb});
		$vstate->{file} = hfile($sfile,$line); # current html file
	    }
	    
	    # do the anchors
	    foreach $anchor ( &rvp::get_anchors($verilog_db,$file,$line) ) {
		print $out "<a name=\"$anchor\"></a>";
	    }
	    
	    # change the context if there is a new one
	    if ( $new_context = &rvp::get_context($verilog_db,$file,$line) ) {

		print " new context $new_context\n" if $debug;

		if ( &rvp::get_has_value_by_context($verilog_db,$file,$line) ) {
		    $vstate->{context} = $new_context;
		    ($vstate->{name},$vstate->{type}) =
			&rvp::get_context_name_type($verilog_db,$file,$line);
		}

		if ( (! $vstate->{pre_ignore}) && # not already ignoring
		     ($pre_ignore = &rvp::get_pre_ignore_by_context($verilog_db,
							       $file,$line))){
		    print "  ignoring until $pre_ignore\n" if $debug;
		    $vstate->{pre_ignore} = $pre_ignore;
		}

		if ( &rvp::get_module_start_by_context($verilog_db,$file,$new_context) &&
		    (($m,$f,$inst,$link_line) = &rvp::get_first_instantiator_by_context(
					   $verilog_db,$file,$new_context))) {
		    print " putting in up links\n" if $debug;
		    # put in the up links 
		    $n=0;
		    while ($m) {
			$n++;
			if ($n>32) {
			    print $out "<b><i>... (truncated)</i></b>";
			    last;
			}
			print $out "<a $frame_middle href=\"".
			    hfile($f,$link_line) ."#" . $m . "_" . $inst . "\">".
				"<img alt=\"[Up: $m $inst]\" align=bottom border=0 ". 
				    "src=\"v2html-up.gif\"><\/a>";
			($m,$f,$inst,$link_line)=&rvp::get_next_instantiator($verilog_db);
		    }
		    print $out "\n";
		}
	    }

	    # change the current inst  if there is a new one
	    if ( $new_inst = &rvp::get_inst_on_line($verilog_db,$file,$line) ) {
		$vstate->{cur_inst}= $new_inst;
		$vstate->{cur_inst_exists}=&rvp::module_exists($verilog_db,$new_inst);
	    }
	}
	# do not do all that stuff again for this line
	$vstate->{line_started} = $line;

	if ($grey_ifdefed_out && $vstate->{pre_ignore}) {
	    if ($vstate->{pre_ignore}==$line) {
		$vstate->{pre_ignore}=0;
	    }
	    else {
		if ( $linebuf =~ m/^\s*$/ ) {
		    print $out $linebuf;
		}
		else {
		    quote_html(\$linebuf);
		    print_with_font($out,"pp_ignore",$linebuf);
		}
		$line++;
		next;
	    }
	}

	# do a word at a time within the line
	foreach $word ( split /([.\`\$]?(?:$VID))/ , $linebuf ) {
	    $qword=$word;
	    quote_html(\$qword);

	    if ($word !~ m/[.\`\$]?$VID/o ) { # anything that is not a $VID
		# when we see a ; the next stuff is on the left had side
		# when we see a = (not == != === !==) or <= we are on rhs
		if    ($word =~ m/;/) { 
		    $vstate->{rhs}=0;
		    $vstate->{inst_link_done}  = 0;
		    $vstate->{cur_inst}        = '$NONE';
		    $vstate->{cur_inst_exists} = 0;
		}
		elsif ($word =~ m/((\A|[^=!])=(\Z|[^=!]))|<=/ ) { 
		    $vstate->{rhs}=1;
		}
		print $out $qword;
	    }
	    elsif ($nextisdefine) {
		if ((($f,$link_line)=&rvp::get_define($verilog_db,"`$word"))&&
		    ($js_sigs || ($link_line!=$line))) {
		    print_link($out,$vstate->{file},$frame_bottom,$js_sigs,
			       hfile($f,$link_line),$link_line,$qword,"define",
			       $vstate->{short_links},0);
		}
		else {
		    print_with_font($out,"define",$qword);
		}
		$nextisdefine=0;
	    }
	    elsif ($word =~ m/^\$($VID)/o ) {
		print_with_font($out,"systemtask",$qword);
	    }
	    elsif ($word =~ m/^\`/ ) {
		# colour link 'define 'timescale etc.
		if ( exists( $verilog_compiler_keywords_hash{$word} ) ) {
		    print_with_font($out,"compiler",$qword);
		    $nextisdefine = ($word eq "`ifdef" || $word eq "`define" ||
				     $word eq "`undef");
		}
		# link 'defines 
		elsif (($f,$link_line) = &rvp::get_define($verilog_db,$word)) {
		    print " linking define $word at $line\n" if $debug;
		    # do not link quote, makes qs work better because after `define or `ifdef
		    #  it appears without the quote. Also looks better
		    $qword=~s/^\`//; 
		    print_with_font($out,"define",'`');
		    print_link($out,$vstate->{file},$frame_bottom,$js_sigs,
			       hfile($f,$link_line),$link_line,$qword,"define",
			       $vstate->{short_links},0);
		}
		else {
		    print_with_font($out,"define",$qword);
		}
	    }
	    # link instance module names to the module definition
	    elsif ( $word eq $vstate->{cur_inst} ) {
		# check we have not already done it to cope with the case
		#  where the instance name is the same as the modules name
		if ( !$vstate->{inst_link_done} ) {
		    if ( $vstate->{cur_inst_exists} ) {
		      ($f,$link_line) = &rvp::get_modules_file($verilog_db,$word);
		      print " linking module $word at $line\n" if $debug;
		      print_link($out,$vstate->{file},$frame_middle,$js_sigs,
				 hfile($f,$link_line),$word,$qword,"module",
				 $vstate->{short_links},0);
		    }
		    else {
			# unlinkable instance
			print_with_font($out,"module",$qword);
		    }
		    $vstate->{inst_link_done}=1;
		}
		else {
		    print $out $qword;
		}
	    }
	    elsif ( $word eq $vstate->{name} && $vstate->{type} eq 'module' &&
		   $line == $vstate->{context} ) {
		print_with_font($out,"module",$qword);
		print $out "<a $frame_middle href=\"".
		    index_link("Modules",$word)."\">".
			"$icon_i<\/a>" if ($output_index);
	    }
	    # link .out( ) ports, set $rhs for .in( ) ports
	    elsif ($word =~ m/^\.($VID)/o &&  $vstate->{cur_inst_exists}) {
		if (($s_line,$s_a_line,undef,$s_type,$s_file,undef,undef,$s_type2,
		     undef,undef,undef,$s_a_file,undef) = 
		    &rvp::get_module_signal($verilog_db,$vstate->{cur_inst},$1)) {
		    $vstate->{rhs}=0;
		    $link_line = -1;
		    $f='';
		    $s_type2 = ($s_type2 eq 'reg') ? "_reg" : "";
		    if ($s_type eq 'output') {
			print " linking port .$1 at $line\n" if $debug;
			if ($s_a_line != -1) { $link_line = $s_a_line; $f = $s_a_file;}
			else                 { $link_line = $s_line;   $f = $s_file;}
		    }
		    if ($link_line != -1) {
			print_link($out,$vstate->{file},$frame_middle,$js_sigs,
				   hfile($f,$link_line),$link_line,$qword,
				   "signal_$s_type$s_type2",$vstate->{short_links},0);
		    }
		    else {
			print_with_font($out,"signal_$s_type$s_type2",$qword);
		    }
		    if ($s_type eq 'input') { $vstate->{rhs}=1; }
		}
		else {
		    # should only get here if there is a port used that
		    #  does not exist on the submodule
		    print $out $qword;
		}
	    }
	    # link signals
	    elsif (($s_line,$s_a_line,$s_i_line,$s_type,$s_file,$p,$n,$s_type2,
		    $s_src_file,$s_src_line,$s_a_file,$s_i_file) = 
		 &rvp::get_signal_by_context($verilog_db,$file,
					 $vstate->{context},$word)) {

		# figure out the link to link to the index
		if ($output_index && $vstate->{name} && 
		    ($vstate->{type} eq 'module')) {
		    $index_ref=index_link("Signals","${word}___$vstate->{name}");
		}
		else { $index_ref = ''; }
		# only do extra_info for module signals (not tasks or functions
		if ($vstate->{name} && ($vstate->{type} eq 'module')) {
		    $ex_index=signal_extra_info($word,$vstate,$index_ref,
						[ [$s_file, $s_line],
						  [$s_a_file, $s_a_line],
						  [$s_i_file, $s_i_line],
						  [$s_src_file,$s_src_line] ]);
		}
		else { $ex_index=0; }
		# link the definition to the driver if you can,
		#  otherwise do not link it to anything
		$on_def=(($s_file eq $file) && ($s_line == $line));
		$s_type2 = ($s_type2 eq 'reg') ? "_reg" : "";
		if (($vstate->{rhs} || $on_def) && ($s_a_line != -1)) {
		    $link_line = $s_a_line;
		    $f         = $s_a_file;
		}
		else {
		    # do not link to itself unless doing quick search
 		    if ($on_def && !$js_sigs) { $link_line = -1; $f =""; }
 		    else                 { $link_line = $s_line ; $f = $s_file; }
		}

		if ($on_def && ($s_i_line!=-1)) {
		    #  link to an instantiator
		    if ($s_i_file) {			
			print_link($out,$vstate->{file},$frame_middle,$js_sigs,
				   hfile($s_i_file,$s_i_line),$s_i_line,$qword,
				   "signal_$s_type$s_type2",$vstate->{short_links},
				   $ex_index);
		    }
		    else { # we only get here in certain strange include situations
			print_with_font($out,"signal_$s_type$s_type2",$qword);
		    }
		}
		elsif ($link_line != -1) {
		    print_link($out,$vstate->{file},$frame_middle,$js_sigs,
			       hfile($f,$link_line),$link_line,$qword,
			       "signal_$s_type$s_type2",$vstate->{short_links},$ex_index);
		}
		else {
		    print_with_font($out,"signal_$s_type$s_type2",$qword);
		}
		# put in index link - when on def, but not in quick search mode
		if ($index_ref && $on_def && !$js_sigs) {
		    print $out "<a $frame_middle href=\"$index_ref\">".
		      "$icon_i<\/a>";
		}

	    }
	    # link parameters
	    elsif (($f,$link_line)=
		   &rvp::get_parameter_by_context($verilog_db,$file,$vstate->{context},
					      $word)) {
		# do not link on definition line
		if (($f eq $file) && (($link_line == $line)&&!$js_sigs)) {
		    print_with_font($out,"parameter",$qword);
		}
		else {
		    print " linking parameter $word at $line\n" if $debug;
		    print_link($out,$vstate->{file},$frame_bottom,$js_sigs,
			       hfile($f,$link_line),$link_line,$qword,
			       "parameter",$vstate->{short_links},0);
		}
	    }
	    # tasks & functions
	    elsif (($t_type,$t_line,$t_file,$t_anchor)=
		   &rvp::get_t_or_f_by_context($verilog_db,$file,$vstate->{context},
					      $word)) {
		# do not link on definition line
		if (($t_file eq $file) && (($t_line == $line)&&!$js_sigs)) {
		    print_with_font($out,$t_type,$qword);
		}
		else {
		    print " linking $t_type $word at $line\n" if $debug;
		    print_link($out,$vstate->{file},$frame_middle,$js_sigs,
			       hfile($t_file,$t_line),$t_anchor,$qword,$t_type,
			       $vstate->{short_links},0);
		}
	    }
	    # colour begin end always etc.
	    elsif ( exists( $verilog_keywords_hash{$word} ) ) {
		print_with_font($out,"keyword",$qword);
	    }
	    else {
		print $out $qword;
	    }
	}
	$line++;
    }
    return $out;
}

#####The rest of this file is the rough verilog parser perl module#############
###############################################################################
#
# File:         rvp.pm
# RCS:          $Header: /home/marcus/revision_ctrl_test/oc_cvs/cvs/firewire/bin/v2html.pl,v 1.1 2002-03-07 02:03:39 johnsonw10 Exp $
# Description:  The Rough Verilog Parser Perl Module
# Author:       Costas Calamvokis
# Created:      Fri Apr 10 16:59:30 1998
# Modified:     
# Language:     Perl
#
# Copyright 1998-2001 Costas Calamvokis
# Copyright 1997      Hewlett-Packard Company
#
#  This file nay be copied, modified and distributed only in accordance
#  with the terms of the limited licence contained in the accompanying
#  file LICENCE.TXT.
#
###############################################################################
#

=head1 NAME

rvp - Rough Verilog Parser Perl Module

The basic idea is that first you call read_verilog will a list of all of your
files. The files are parsed and information stored away. You are then 
handed back a pointer to the information which you can use in calls
to the various get_ function to get information about the verilog design.

For Example:

 #!/usr/bin/perl -w
 require rvp;   # use the rough verilog parser

 # Read in all the files specified on the command line
 $vdb = &amp;rvp::read_verilog(\@ARGV,[],{},1,[],[],'');

 # Print out all the modules found
 foreach $module (&amp;rvp::get_modules($vdb)) { print &quot;$module\n&quot;; }

Unless you are doing something very strange, you can probably ignore all
of the functions that have the words 'context' or 'anchors' in them!

=cut

package rvp;


# This is commented out in the distribution because it means that
#  v2html will work even if the perl libraries are not installed
#  properly
#use strict;

use vars qw(@verilog_gatetype_keywords $verilog_gatetype_regexp 
	    @verilog_compiler_keywords
	    @verilog_sigs $verilog_sigs_regexp $quiet $debug $VID $takenArcs
            $baseEval $rvpEval $debugEval $languageDef $vid_vnum_or_string
            $version $problems);

BEGIN {
    $version = '$Header: /home/marcus/revision_ctrl_test/oc_cvs/cvs/firewire/bin/v2html.pl,v 1.1 2002-03-07 02:03:39 johnsonw10 Exp $'; #'
    $version =~ s/^\S+ \S+ (\S+) .*$/$1/;

    @verilog_sigs = qw(input    output  inout  
		       wire     tri     tri1   supply0 wand  triand tri0 
		       supply1  wor     time   trireg  
		       reg      integer real 

		       genvar
		       );
    #V2001

    $verilog_sigs_regexp = "\\b(" . 
	join("|",@verilog_sigs) . 
	    ")\\b";


    @verilog_gatetype_keywords = qw(and  nand  or  nor xor xnor  buf  bufif0 bufif1  
				    not  notif0 notif1  pulldown  pullup
				    nmos  rnmos pmos rpmos cmos rcmos   tran rtran  
				    tranif0  rtranif0  tranif1 rtran if1
				    );

    $verilog_gatetype_regexp = "\\b(" . 
	join("|",@verilog_gatetype_keywords) . 
	    ")\\b";
    
    @verilog_compiler_keywords = qw( 
     `celldefine            `define 
     `delay_mode_path       `disable_portfaults 
     `else                  `enable_portfaults
     `endcelldefine         `endif 
     `ifdef                 `include 
     `nosuppress_faults     `suppress_faults 
     `timescale             `undef
     `resetall              `delay_mode_distributed

     `default_nettype  `file `line `ifndef `elsif
    );    #`

    # a verilog identifier is this reg exp 
    #  a non-escaped identifier is A-Z a-z _ 0-9 or $ 
    #  an escaped identifier is \ followed by non-whitespace
    #   why \\\\\S+ ? This gets \\\S+ in to the string then when it
    #   it used we get it searching for \ followed by non-whitespace (\S+)
    $VID = '[A-Za-z_][A-Za-z_0-9\$]*|\\\\\S+';

    $quiet=0;
    $debug=0;

}

###########################################################################

=head1 read_verilog

reads in verilog files, parses them and stores results in an internal 
data structure (which I call a RVP database).

  Arguments:  - reference to array of files to read (can have paths)
              - reference to hash of defines with names as keys
              - reference to array of global includes - not used anymore,
                 just kept for backwards compatibility
              - quite flag. 1=be quiet, 0=be chatty.
              - reference to array of include directories
              - reference to array of library directories
              - library extension string (eg '.v') or reference to array of strings

  Returns:    - a pointer to the internal data structure.

  Example:
    $defines{'TRUE'}=1;  # same as +define+TRUE=1 on verilog cmd line
    $verilog_db = &rvp::read_verilog(\@files,[],\%defines,1,
				     \@inc_dirs,\@lib_dirs,\@lib_exts);

=cut
sub read_verilog {
    my ($files,$global_includes,$cmd_line_defines,$local_quiet,$inc_dirs,
	$lib_dirs,$lib_ext_arg,$exp)
	= @_;
    my ($file,$fb,$old_quiet,@search_files,@new_search_files,$lib_exts,$defines);

    my $fdata;

    die "read_verilog needs an array ref as arg 1" unless "ARRAY" eq ref $files;
    die "read_verilog needs an hash ref as arg 2" unless "HASH" eq ref $cmd_line_defines;
    die "read_verilog needs 0 or 1 as arg 3" unless $local_quiet==0 || $local_quiet==1;

    # be backwards compatible
    if (!defined($inc_dirs)) { $inc_dirs=[]; }
    if (!defined($lib_dirs)) { $lib_dirs=[]; }
    
    if (!defined($lib_ext_arg)) {  # no libexts given
	$lib_exts=['']; 
    }           
    elsif (!ref($lib_ext_arg))  {  # a string given
	$lib_exts=[$lib_ext_arg]; 
    }
    else {                         # an array ref given
	$lib_exts=$lib_ext_arg; 
    }


    # make the parser
    if (! defined &parse_line) {

	my $perlCode=makeParser( $debug ? [ $baseEval,$debugEval,$rvpEval ]:
				          [ $baseEval,$rvpEval ] ,
				 $debug );
	if ($debug) {
	    open(PC,">v2html-parser.pl");
	    print PC $perlCode;
	}
	eval($perlCode);
	print STDERR $@ if ($@);
    }

    if (! defined &parse_line) { die "Parse code generation failed";}

    $defines = {};
    foreach my $d (keys(%$cmd_line_defines)) {
	$defines->{$d}{value} = $cmd_line_defines->{$d};
    }

    $old_quiet=$quiet;
    $quiet=$local_quiet;
    # set up top of main data structure
    $fdata = {};
    $fdata->{files}               = {}; # information on each file
    $fdata->{modules}             = {}; # pointers to module info in {files}
    $fdata->{defines}             = {};
    $fdata->{ignored_modules}     = {}; # list of modules were duplicates were found
    $fdata->{unresolved_includes} = {}; # includes we have not found yet
    $fdata->{unresolved_modules}  = {}; # modules we have not found yet
    $fdata->{problems}            = []; # warning/confused messages
    $problems=$fdata->{problems};

    # go through all the files and find information
    @new_search_files = @{$files};
    while (@new_search_files) {
	@search_files = @new_search_files;
	@new_search_files = ();
	foreach $file (@search_files) {
	    search($file,$fdata,$defines,$inc_dirs);
	}
	push( @new_search_files , resolve_modules( $fdata, $lib_dirs, $lib_exts ) );
    }


    if ($debug) {
	checkCoverage();
    }

    # cross reference files' information
    print "Cross referencing\n" unless $quiet;
    cross_reference($fdata);
    
    $quiet=$old_quiet;

    foreach my $m ( keys %{$fdata->{unresolved_modules}} ) {
	# find somewhere it is instantiated for warning message
	my $file="";
	my $line="";
	foreach my $m2 (keys %{$fdata->{modules}}) {
	    foreach my $inst (@{$fdata->{modules}{$m2}{instances}}) {
		if ($inst->{module} eq $m) {
		    $file = $inst->{file};
		    $line = $inst->{line};
		    last;
		}
	    }
	}
	add_problem("Warning:$file:$line: Could not find module $m");
    }

    return $fdata;
} 

###########################################################################

=head1 get_problems

Return any problems that happened during parsing

  Arguments:  - Pointer to RVP database.

  Returns:    - array of strings of problems. Each one is:
                    "TYPE:FILE:LINE: description"

=cut
sub get_problems {
    my ($fdata) = @_;
    
    return (@{$fdata->{problems}});
}

###########################################################################

=head1 set_debug

Turns on debug printing in the parser.

  Returns:    - nothing

=cut
sub set_debug {
    $debug=1;
}

###########################################################################

=head1 unset_debug

Turns off debug printing in the parser.

  Returns:    - nothing

=cut
sub unset_debug {
    $debug=0;
}

###########################################################################

=head1 get_files

Get a list of all the files in the database.

  Arguments:  - Pointer to RVP database.

  Returns:    - list of all the files

  Example:   @all_files = &rvp::get_files($verilog_db);

=cut
sub get_files{
    my ($fdata) = @_;
    return keys %{$fdata->{files}};
}


###########################################################################

=head1 get_files_modules

Get a list of all the modules in a particular file.

  Arguments:  - Pointer to RVP database.
            - name of file

  Returns:    - list of module names

  Example:   @modules = &rvp::get_files_modules($verilog_db,$file);

=cut
sub get_files_modules{
    my ($fdata,$file) = @_;
    my (@modules,$m);

    foreach $m (keys %{$fdata->{files}{$file}{modules}}) {
	push(@modules,$m)
    }

    return @modules;
}


###########################################################################

=head1 get_files_full_name

Get the full name (including path) of a file.

  Arguments:  - Pointer to RVP database.
            - name of file

  Returns:    - full path name

  Example  $full_name = &rvp::get_files_full_name($verilog_db,$file);

=cut
sub get_files_full_name{
    my ($fdata,$file) = @_;

    return $fdata->{files}{$file}{full_name};

}

###########################################################################

=head1 get_files_stats

Get statistics about a file

  Arguments:  - Pointer to RVP database.
            - name of file

  Returns:    - number of lines in the file (more later...)

  Example  $full_name = &rvp::get_files_stats($verilog_db,$file);

=cut
sub get_files_stats{
    my ($fdata,$file) = @_;

    return $fdata->{files}{$file}{lines};

}

###########################################################################

=head1 file_exists

Test if a particular module file  in the database.

  Arguments:  - Pointer to RVP database.
            - file name to test.

  Returns:    - 1 if exists otherwise 0

  Example:   if (&rvp::file_exists($verilog_db,$file))....

=cut
sub file_exists{
    my ($fdata,$file) = @_;
    return exists($fdata->{files}{ffile($file)});
}

###########################################################################

=head1 get_modules

Get a list of all the modules in the database.

  Arguments:  - Pointer to RVP database.

  Returns:    - list of all the modules

  Example:   @all_modules = &rvp::get_modules($verilog_db);

=cut
sub get_modules{
    my ($fdata) = @_;
    return (keys %{$fdata->{modules}});
}


###########################################################################

=head1 get_modules_t_and_f

Get a list of all the tasks and functions in a particular module.

  Arguments:  - Pointer to RVP database.
              - name of module

  Returns:    - list of tasks and function names

  Example:    if ( @t_and_f = &rvp::get_modules_t_and_f($verilog_db,$m))...

=cut
# return a list of all the tasks and functions in a module
sub get_modules_t_and_f{
    my ($fdata,$module) = @_;

    return keys %{$fdata->{modules}{$module}{t_and_f}};
}

###########################################################################

=head1 get_modules_t_or_f

Get information on a task or function in a module.

  Arguments:  - Pointer to RVP database.
              - module name
              - task or function name

  Returns:    - A 4 element list: type (task or function), definition line,
                  file, anchor

  Example:    ($t_type,$t_line ,$t_file,$t_anchor)=
		&rvp::get_modules_t_or_f($verilog_db,$m,$tf);

=cut
sub get_modules_t_or_f{
    my ($fdata,$mod,$t_or_f) = @_;

    if (exists($fdata->{modules}{$mod}{t_and_f}{$t_or_f})) {
	return($fdata->{modules}{$mod}{t_and_f}{$t_or_f}{type},
	       $fdata->{modules}{$mod}{t_and_f}{$t_or_f}{line},
	       $fdata->{modules}{$mod}{t_and_f}{$t_or_f}{file},
	       $fdata->{modules}{$mod}{t_and_f}{$t_or_f}{anchor});
    }
    else {
	return ();
    }
}

###########################################################################

=head1 get_modules_signals

Get a list of all the signals in a particular module.

  Arguments:  - Pointer to RVP database.
              - name of module

  Returns:    - list of signal names

  Example:    if ( @signs = &rvp::get_modules_signals($verilog_db,$m))...

=cut
# return a list of all the tasks and functions in a module
sub get_modules_signals{
    my ($fdata,$module) = @_;

    return keys %{$fdata->{modules}{$module}{signals}};
}

###########################################################################

=head1 get_modules_file

Get the file name (no path) that a module is defined in.

  Arguments:  - Pointer to RVP database.
              - module name

  Returns:    - file name without path, and the line number module starts on

  Example:    ($f) = &rvp::get_modules_file($verilog_db,$m);

=cut
# get the file name that contains a module
sub get_modules_file{
    my ($fdata,$module) = @_;

    return ($fdata->{modules}{$module}{file},$fdata->{modules}{$module}{line});
}


###########################################################################

=head1 get_modules_type

Get the type of the module - It is one of: module, macromodule or primitive
(rvp treats these all as modules).

  Arguments:  - Pointer to RVP database.
              - module name

  Returns:    - type

  Example:    $t = &rvp::get_modules_type($verilog_db,$m);

=cut
# get the file name that contains a module
sub get_modules_type{
    my ($fdata,$module) = @_;

    return ($fdata->{modules}{$module}{type});
}

###########################################################################

=head1 get_files_includes

Get the file names (no path) of files included in a file.

  Arguments:  - Pointer to RVP database.
              - file name

  Returns:    - list of file names without paths

  Example:    @f = &rvp::get_files_includes($verilog_db,$file);

=cut
sub get_files_includes {
    my ($fdata,$f) = @_;
    my @includes_found = ();

    if (exists($fdata->{files}{$f})) {
	foreach my $inc ( keys %{$fdata->{files}{$f}{includes}} ) {
	    push(@includes_found,$inc);
	    # do the includes for the included file
	    push(@includes_found, get_files_includes($fdata,$inc));
	}
    }

    return @includes_found;
}

###########################################################################

=head1 get_files_included_by

Get the file names (no path) of files that included this file.

  Arguments:  - Pointer to RVP database.
              - file name

  Returns:    - list of file names without paths

  Example:    @f = &rvp::get_files_included_by($verilog_db,$file);

=cut
sub get_files_included_by {
    my ($fdata,$f) = @_;

    return @{$fdata->{files}{$f}{included_by}};
    
}


###########################################################################

=head1 module_ignored

Test if a particular module has been ignored because of duplicates found

  Arguments:  - Pointer to RVP database.
              - module name to test

  Returns:    - 1 if ignored otherwise 0

  Example:   if (&rvp::module_ignored($verilog_db,$module))....

=cut
sub module_ignored {
    my ($fdata,$module) = @_;
    return (exists($fdata->{modules}{$module}) && 
	    $fdata->{modules}{$module}{duplicate});
}

###########################################################################

=head1 module_exists

Test if a particular module exists in the database.

  Arguments:  - Pointer to RVP database.
            - module name to test

  Returns:    - 1 if exists otherwise 0

  Example:   if (&rvp::module_exists($verilog_db,$module))....

=cut
sub module_exists{
    my ($fdata,$module) = @_;
    return exists($fdata->{modules}{$module});
}

###########################################################################

=head1 get_ignored_modules

Return a list of the ignored modules. These are modules where duplicates
have been found.

  Arguments:  - Pointer to RVP database.

  Returns:    - List of ignored modules

  Example:    - foreach $module (&rvp::get_ignored_modules($verilog_db))....

=cut
sub get_ignored_modules {
    my ($fdata) = @_;
    my @ig =();
    foreach my $m (keys %{$fdata->{modules}}) {
	push(@ig, $m) if ($fdata->{modules}{$m}{duplicate});
    }
    return @ig;
}

###########################################################################

=head1 get_module_signal

Get information about a particular signal in a particular module.

  Arguments:  - Pointer to RVP database.
              - name of module
              - name of signal

  Returns:    - A list containing: 
                 - the line signal is defined
                 - the line signal is assigned first (or -1)
                 - line in instantiating module where an input 
                       is driven from (or -1)
                 - the type of the signal (input,output,reg etc)
                 - the file the signal is in
                 - posedge flag (1 if signal ever seen with posedge)
                 - negedge flag (1 if signal ever seen with negedge)
                 - second type (eg reg for a registered output)
                 - signal real source file
                 - signal real source line
                 - range string if any ( not including [ and ] )

  Note posedge and negedge information is propagated up the hierarchy to
  attached signals. It is not propagated down the hierarchy.

  Example:    ($s_line,$s_a_line,$s_i_line,$s_type,$s_file,$s_p,$s_n,
	       $s_type2,$s_r_file,$s_r_line,$range,$s_a_file,$s_i_file) = 
                      &rvp::get_module_signal($verilog_db,$m,$sig);

=cut
sub get_module_signal{
    my ($fdata,$module,$sig) = @_;
    
    if (exists( $fdata->{modules}{$module}{signals}{$sig} )) {
	return ($fdata->{modules}{$module}{signals}{$sig}{line},
		$fdata->{modules}{$module}{signals}{$sig}{a_line},
		$fdata->{modules}{$module}{signals}{$sig}{i_line},
		$fdata->{modules}{$module}{signals}{$sig}{type},
		$fdata->{modules}{$module}{signals}{$sig}{file},
		$fdata->{modules}{$module}{signals}{$sig}{posedge},
		$fdata->{modules}{$module}{signals}{$sig}{negedge},
		$fdata->{modules}{$module}{signals}{$sig}{type2},
		$fdata->{modules}{$module}{signals}{$sig}{source}{file},
		$fdata->{modules}{$module}{signals}{$sig}{source}{line},
		$fdata->{modules}{$module}{signals}{$sig}{range},
		$fdata->{modules}{$module}{signals}{$sig}{a_file},
		$fdata->{modules}{$module}{signals}{$sig}{i_file});
    }
    else {
	return ();
    }
}

###########################################################################

=head1 get_first_signal_port_con

Get the first port that this signal in this module is connected to.

  Arguments:  - Pointer to RVP database.
              - module name
              - signal name

  Returns:    - a 5 element list: instantiated module name, instance name
                  port name, line number and file

  Example:    ($im,$in,$p,$l,$f)=&rvp::get_first_signal_port_con($verilog_db,$m,$s);

=cut
sub get_first_signal_port_con{
    my ($fdata,$module,$signal) = @_;

    $fdata->{current_signal_port_con}       =0;
    $fdata->{current_signal_port_con_module}=$module;
    $fdata->{current_signal_port_con_module_signal}=$signal;

    return get_next_signal_port_con($fdata);
}

###########################################################################

=head1 get_next_signal_port_con

Get the next port that this signal in this module is connected to.

  Arguments:  - Pointer to RVP database.

  Returns:    - a 5 element list: instantiated module name, instance name
                  port name, line number and file

  Example:    ($im,$in,$p,$l,$f)=&rvp::get_next_signal_port_con($verilog_db);

=cut
sub get_next_signal_port_con{
    my ($fdata) = @_;
    my ($module,$signal,$i,$pcref);

    $module = $fdata->{current_signal_port_con_module};
    $signal = $fdata->{current_signal_port_con_module_signal};
    $i      = $fdata->{current_signal_port_con};

    $pcref = $fdata->{modules}{$module}{signals}{$signal}{port_con};
    if (@{$pcref} > $i ) {
	$fdata->{current_signal_port_con}++;
	return ( $pcref->[$i]{module},$pcref->[$i]{inst},$pcref->[$i]{port},
		$pcref->[$i]{line},$pcref->[$i]{file});
    }
    else {
	return ();
    }
}

###########################################################################

=head1 get_first_signal_con_to

Get the first signal that is connected to this port in an
instantiation of this module. This only works for instances that use
the .port(sig) notation.

  Arguments:  - Pointer to RVP database.
              - module name
              - signal name

  Returns:    - a 4 element list: signal connected to this port
                                  module signal is in
		                  instance (of this module) where the connection
			            occurs

  Example:    ($cts,$ctm,$cti)=&rvp::get_first_signal_con_to($verilog_db,$m,$s);

=cut
sub get_first_signal_con_to{
    my ($fdata,$module,$signal) = @_;

    $fdata->{current_signal_con_to}       =0;
    $fdata->{current_signal_con_to_module}=$module;
    $fdata->{current_signal_con_to_module_signal}=$signal;

    return get_next_signal_con_to($fdata);
}

###########################################################################

=head1 get_next_signal_con_to

Get the next signal that is connected to this port in an
instantiation of this module. This only works for instances that use
the .port(sig) notation.

  Arguments:  - Pointer to RVP database.
              - module name
              - signal name

  Returns:    - a 4 element list: signal connected to this port
                                  module signal is in
		                  instance (of this module) where the connection
			            occurs

  Example:    ($cts,$ctm,$cti)=&rvp::get_next_signal_con_to($verilog_db);

=cut
sub get_next_signal_con_to{
    my ($fdata) = @_;
    my ($module,$signal,$i,$ctref);

    $module = $fdata->{current_signal_con_to_module};
    $signal = $fdata->{current_signal_con_to_module_signal};
    $i      = $fdata->{current_signal_con_to};

    $ctref = $fdata->{modules}{$module}{signals}{$signal}{con_to};
    if (@{$ctref} > $i ) {
	$fdata->{current_signal_con_to}++;
	return ( $ctref->[$i]{signal},$ctref->[$i]{module},$ctref->[$i]{inst});
    }
    else {
	return ();
    }
}

###########################################################################

=head1 get_first_instantiator

Get the first thing that instantiates this module.

  Arguments:  - Pointer to RVP database.
              - module name

  Returns:    - a 4 element list: instantiating module, file, instance name, line

  Example:    
		($im,$f,$i) = &rvp::get_first_instantiator($verilog_db,$m );

=cut
# Get the first thing that instantiates or empty list if none.
#  Returns: { module, file, inst }
sub get_first_instantiator{
    my ($fdata,$module) = @_;

    if ( exists( $fdata->{modules}{$module} )) {
	$fdata->{current_instantiator}       =0;
	$fdata->{current_instantiator_module}=$module;
	return get_next_instantiator($fdata);
    }
    else {
	return ();
    }
}

###########################################################################

=head1 get_next_instantiator

Get the first thing that instantiates the module specified in 
get_first_instantiator (or _by_context).

  Arguments:  - Pointer to RVP database.

  Returns:    - a 4 element list: instantiating module, file, instance name, line

  Example:    
		($im,$f,$i) = &rvp::get_next_instantiator($verilog_db);

=cut
sub get_next_instantiator{
    my ($fdata) = @_;
    my ($module,$i);

    $module = $fdata->{current_instantiator_module};
    $i      = $fdata->{current_instantiator};

    if (@{$fdata->{modules}{$module}{inst_by}} > $i ) {
	$fdata->{current_instantiator}++;
	return ($fdata->{modules}{$module}{inst_by}[$i]{module},
	        $fdata->{modules}{$module}{inst_by}[$i]{file},
		$fdata->{modules}{$module}{inst_by}[$i]{inst},
		$fdata->{modules}{$module}{inst_by}[$i]{line} );
    }
    else {
	return ();
    }
}

###########################################################################

=head1 get_first_instantiation

Get the first thing that this module instantiates.

  Arguments:  - Pointer to RVP database.
              - module name

  Returns:    - a 4 element list: instantiated module name, file, 
                  instance name, and line number

  Example:    
		($im,$f,$i,$l) = &rvp::get_first_instantiation($verilog_db,$m);

=cut
sub get_first_instantiation{
    my ($fdata,$module) = @_;

    if ( exists( $fdata->{modules}{$module} )) {
	$fdata->{current_instantiation}       =0;
	$fdata->{current_instantiation_module}=$module;
	return get_next_instantiation($fdata);
    }
    else {
	return ();
    }
}

###########################################################################

=head1 get_next_instantiation

Get the next thing that this module instantiates.

  Arguments:  - Pointer to RVP database.

  Returns:    - a 4 element list: instantiated module name, file, 
                  instance name, and line number

  Example:    
		($im,$f,$i,$l) = &rvp::get_next_instantiation($verilog_db);

=cut
sub get_next_instantiation{
    my ($fdata) = @_;
    my ($module,$i);

    $module = $fdata->{current_instantiation_module};
    $i      = $fdata->{current_instantiation};

    if (@{$fdata->{modules}{$module}{instances}} > $i ) {
	$fdata->{current_instantiation}++;
	return ($fdata->{modules}{$module}{instances}[$i]{module},
	        $fdata->{modules}{$module}{instances}[$i]{file},
		$fdata->{modules}{$module}{instances}[$i]{inst_name},
		$fdata->{modules}{$module}{instances}[$i]{line} );
    }
    else {
	return ();
    }
}

###########################################################################

=head1 get_current_instantiations_port_con

Gets the port connections for the current instantiations (which is got
using get_first_instantiation and get_next_instantiation). If the 
instantiation does not use .port(...) syntax and rvp does not have the
access to the source of the module then the port names will be returned as
numbers in connection order starting at 0.

  Arguments:  - Pointer to RVP database.

  Returns:    - A hash (well, really a list that can be assigned to a hash). 
               The keys of the hash are the port names. The values of the
               hash is everything (except comments) that appeared in the 
               brackets in the verilog.

  Example:    %port_con = &rvp::get_current_instantiations_port_con($vdb);
	      foreach $port (keys %port_con) { ...

=cut
sub get_current_instantiations_port_con{
    my ($fdata) = @_;
    my ($module,$i);

    $module = $fdata->{current_instantiation_module};
    $i      = $fdata->{current_instantiation} -  1;

    if (@{$fdata->{modules}{$module}{instances}} > $i ) {
	return (%{$fdata->{modules}{$module}{instances}[$i]{connections}});
    }
    else {
	return {};
    }
}

###########################################################################

=head1 get_define

Find out where a define is defined

  Arguments:  - Pointer to RVP database.
              - name of the define

  Returns:    - where it is defined, list with two elements: file, line
                 if it does not exist it returns a empty list.

  Example:    ($f,$l) = &rvp::get_define($verilog_db,$word);

=cut
sub get_define{
    my ($fdata,$define,$t) = @_;

    die "Get define does not take three arguments anymore" if defined $t;

    if (exists( $fdata->{defines}{$define} )) {
	return ($fdata->{defines}{$define}{file},
		$fdata->{defines}{$define}{line})
    }
    else {
	return ();
    }
}

###########################################################################

=head1 get_context

Get the context (if any) for a line in a file.

  Arguments:  - Pointer to RVP database.
              - file name
              - line number

  Returns:    - line number if there is a context, zero if there is none.

  Example:    	$l = &rvp::get_context($verilog_db,$filename,$line);

=cut
sub get_context{
    my ($fdata,$file,$line) = @_;

    if ( exists( $fdata->{files}{$file}{contexts}{$line} )) {
	return $line;
    }
    else {
	return 0;
    }
}

###########################################################################

=head1 get_module_start_by_context

Test if the context is a module definition start.

  Arguments:  - Pointer to RVP database.
              - file number
              - line number

  Returns:    - module name if it is a module start, 0 otherwise

  Example:     if(&rvp::get_module_start_by_context($verilog_db,$filename,$line))..

=cut
# return true if the context for this line is a module start
sub get_module_start_by_context{
    my ($fdata,$file,$line) = @_;

    if ( exists( $fdata->{files}{$file}{contexts}{$line}{module_start})) {
	return $fdata->{files}{$file}{contexts}{$line}{module_start};
    }
    else {
	return 0;
    }
}

###########################################################################

=head1 get_has_value_by_context

Check if the context has a value (ie a new module or something). Contexts
that just turn on and off preprocessor ignoring do not have values.

  Arguments:  - Pointer to RVP database.
              - file
              - line

  Returns:    - 1 if there is a value, 0 otherwise

  Example:    if (&rvp::get_has_value_by_context($verilog_db,$file,$line))..

=cut
sub get_has_value_by_context{
    my ($fdata,$file,$line) = @_;

    return exists( $fdata->{files}{$file}{contexts}{$line}{value});
}

###########################################################################

=head1 get_context_name_type

Find the reason for a new context - is it a module / function or task.
Contexts that just turn on and off preprocessor ignoring do not have values.

  Arguments:  - Pointer to RVP database.
              - file
              - line

  Returns:    - name
              - type [ module | function | task ]

  Example:    ($n,$t)=&rvp::get_context_name_type($verilog_db,$file,$line);

=cut
sub get_context_name_type{
    my ($fdata,$file,$line) = @_;
    my ($name,$type);

    $type='';
    if (exists( $fdata->{files}{$file}{contexts}{$line}{value})) {
	$name= $fdata->{files}{$file}{contexts}{$line}{value}{name};
	if (exists( $fdata->{files}{$file}{contexts}{$line}{value}{type})) {
	    $type=$fdata->{files}{$file}{contexts}{$line}{value}{type};
	    $type='module' if ($type eq 'primitive' || $type eq 'macromodule');
	}
	return ($name,$type);
    }
    else {
	return ();
    }
}

###########################################################################

=head1 get_pre_ignore_by_context

Test if the context is preprocessor ignore.

  Arguments:  - Pointer to RVP database.
              - file 
              - line

  Returns:    - 1 if it is, 0 otherwise

  Example:    if (&rvp::get_pre_ignore_by_context($verilog_db,$file,$line))..

=cut
sub get_pre_ignore_by_context{
    my ($fdata,$file,$line) = @_;
    
    if (exists($fdata->{files}{$file}{contexts}{$line}{pre_ignore})) {
	return $fdata->{files}{$file}{contexts}{$line}{pre_ignore};
    }
    else {
	return 0;
    }

}

###########################################################################

=head1 get_first_instantiator_by_context

Get the first thing that instantiates this module using the context. The
context must be a module_start.

  Arguments:  - Pointer to RVP database.
              - file (for context)
              - line (for context)

  Returns:    - a 4 element list: instantiating module, file, instance name, line

  Example:    
	      @i=&rvp::get_first_instantiator_by_context($verilog_db,$f,$l );

=cut
sub get_first_instantiator_by_context{
    my ($fdata,$file,$line) = @_;

    # note: the second exists() checks that the module still exists as
    #  it could have been deleted because a duplicate was found
    if (exists($fdata->{files}{$file}{contexts}{$line}{module_start}) &&
	exists($fdata->{modules}
	       {$fdata->{files}{$file}{contexts}{$line}{module_start}}) &&
	exists($fdata->{files}{$file}{contexts}{$line}{value}{inst_by})) {
	$fdata->{current_instantiator}       =0;
	$fdata->{current_instantiator_module}=
	    $fdata->{files}{$file}{contexts}{$line}{module_start};
	return get_next_instantiator($fdata);
    }
    else {
	return ();
    }

}

###########################################################################

=head1 get_inst_on_line

Gets the instance name of a line in a file

  Arguments:  - Pointer to RVP database.
              - file 
              - line

  Returns:    - name if the line has an instance name, 0 otherwise

  Example:    if ( $new_inst = &rvp::get_inst_on_line($verilog_db,$file,$line) ) ...

=cut
sub get_inst_on_line{
    my ($fdata,$file,$line) = @_;

    if ( exists( $fdata->{files}{$file}{instance_lines}{$line})){
	return $fdata->{files}{$file}{instance_lines}{$line};
    }
    else {
	return 0;
    }
}

###########################################################################

=head1 get_signal_by_context

Same as get_module_signal but works by specifying a context.

  Arguments:  - Pointer to RVP database.
              - context file
              - context line
              - signal name

  Returns:    same as get_module_signal

  Example:    

=cut
# get a signal by context - returns: line, a_line, i_line, type, file
sub get_signal_by_context{
    my ($fdata,$file,$cline,$sig) = @_;

    my $sigp;

    # in tasks and functions signals can come from module (m_signals)
    #  or from the task or function itself (which gets precedence).
    if (exists( $fdata->{files}{$file}{contexts}{$cline}{value}{signals}{$sig} )) {
	print " found signal $sig\n" if $debug;
	$sigp=$fdata->{files}{$file}{contexts}{$cline}{value}{signals}{$sig};
    }
    elsif (exists( $fdata->{files}{$file}{contexts}{$cline}{value}{m_signals}{$sig} )) {
	print " found m_signal $sig\n" if $debug;
	$sigp=$fdata->{files}{$file}{contexts}{$cline}{value}{m_signals}{$sig};
    }
    else {
	return ();
    }

    return ($sigp->{line},
	    $sigp->{a_line},
	    $sigp->{i_line},
	    $sigp->{type},
	    $sigp->{file},
	    $sigp->{posedge},
	    $sigp->{negedge},
	    $sigp->{type2},
	    $sigp->{source}{file},
	    $sigp->{source}{line},
	    $sigp->{a_file},
	    $sigp->{i_file});
}

###########################################################################

=head1 get_t_or_f_by_context

Same as get_modules_t_or_f but works by specifying a context.

  Arguments:  - Pointer to RVP database.
              - context file
              - context line
              - task name

  Returns:    - same as get_modules_t_or_f

  Example:    

=cut
sub get_t_or_f_by_context{
    my ($fdata,$cfile,$cline,$t_or_f) = @_;

    if (exists($fdata->{files}{$cfile}{contexts}{$cline}{value}{t_and_f}{$t_or_f})) {
	return($fdata->{files}{$cfile}{contexts}{$cline}{value}{t_and_f}{$t_or_f}{type},
	       $fdata->{files}{$cfile}{contexts}{$cline}{value}{t_and_f}{$t_or_f}{line},
	       $fdata->{files}{$cfile}{contexts}{$cline}{value}{t_and_f}{$t_or_f}{file},
	       $fdata->{files}{$cfile}{contexts}{$cline}{value}{t_and_f}{$t_or_f}{anchor});
    }
    else {
	return ();
    }
}
###########################################################################

=head1 get_parameter_by_context

Return the file and line for a named parameter using context

  Arguments:  - Pointer to RVP database.
              - context file
              - context line
              - parameter name

  Returns:    - file and line of definition

  Example:    

=cut
sub get_parameter_by_context{
    my ($fdata,$cfile,$cline,$parameter) = @_;

    if (exists($fdata->{files}{$cfile}{contexts}{$cline}{value}{parameters_by_name}{$parameter})) {
	return($fdata->{files}{$cfile}{contexts}{$cline}{value}{parameters_by_name}{$parameter}{file},
	       $fdata->{files}{$cfile}{contexts}{$cline}{value}{parameters_by_name}{$parameter}{line});
    }
    else {
	return ();
    }
}
###########################################################################

=head1 get_anchors

Get the anchors for a line in a file.

  Arguments:  - Pointer to RVP database.

  Returns:    - a list of anchors

  Example:   foreach $anchor ( &rvp::get_anchors($verilog_db,$file,$line) ) ..

=cut
sub get_anchors{
    my ($fdata,$file,$line) = @_;

    if (exists($fdata->{files}{$file}{anchors}{$line})) {
	return @{$fdata->{files}{$file}{anchors}{$line}};
    }
    else {
	return ();
    }
}




###############################################################################
#  RVP internal functions from now on....
###############################################################################

###############################################################################
# search a file, putting the data in $fdata
#
sub search {
    my ($f,$fdata,$defines,$inc_dirs) = @_;

    my $verilog_compiler_keywords_regexp = "(?:" . 
	join("|",@verilog_compiler_keywords) . 
	    ")";


    my $file=ffile($f);
    my $line = 0;
    init_file($fdata->{files},$f);

    my $fh= open_file($f);


    my $rs = {};
    $rs->{modules}   = $fdata->{modules};
    $rs->{files}     = $fdata->{files};
    $rs->{unres_mod} = $fdata->{unresolved_modules};
    
    $rs->{module}   = '';
    $rs->{function} = '';
    $rs->{task}     = '';
    $rs->{t}        = undef; # temp store
    $rs->{p}        = undef;

    my $printline = 1000;

    my $ps = {};
    my $in_comment=0;
    my $in_attr=0; # V2001
    my $codeLine;
    my $nest=0;
    my $nest_at_ignore;
    my @ignore_from_elsif;
    my $ignoring=0;
    my @fileStack =();
    my $pp_ignore;
    while (1) {
	while (defined($codeLine = <$fh>)) {
	    $line++;
	    if ($line>$printline && !$quiet) {
		$printline+=1000;
		$|=1; # turn on autoflush
		print ".";
		$|=0 unless $debug; # turn off autoflush
	    }
	    
	    # deal quickly with blank lines
	    if ( $codeLine =~ m/^(\s*\n)/ ) {
		next;
	    }
	    
	    # end of multiline comment
	    if ($in_comment) { 
		# strip the end of the comment
		if ($codeLine =~ s%^.*?\*/%%) {    $in_comment=0;  }
		else {    next;  } # no close comment, skip the whole line
	    }
	    # V2001 end of multiline attribute
	    elsif ($in_attr) { 
		# strip the end of the attribute
		if ($codeLine =~ s%^.*?\*\)%%) {    $in_attr=0;  }
		else {    next;  } # no close attr, skip the whole line
	    }


	    # strip out comments - leave strings (but match strings so that
	    #  you don't get confused by comment start chars in strings
  	    if ($codeLine =~ 
                 s%(?:(/\*.*?\*/)|                             # $1 /* comments */
  		      (/\*.*\n)|                               # $2 /* comment
		      (\(\*.*?\*\))|                           # $3 (* attribute *)
  		      (\(\*.*\n)|                              # $4 (* attribute
  		      (//.*?\n)|                               # $5 // comment
  		      (\"(?:(?:\\\\)|(?:\\\")|(?:[^\"]))*?\")) # $6 string
  	           % defined($6) ? $6 : "" %gex                # leave strings
                ) {
		# if the last match was a multiline comment start ( /* ) set in_comment
		if    (defined($2)) { $in_comment=1; }  
		elsif (defined($4)) { $in_attr=1; }  
	    }

	    # handle ifdefs
	    if ($nest && $ignoring) {
		if ( $codeLine =~ m/^\s*\`ifdef\s+($VID)/ ) {
		    print " Found at line $line : endif (nest=$nest)\n" if $debug;
		    $nest++;
		}
		elsif ( $codeLine =~ m/^\s*\`(else|(?:elsif\s+($VID)))/ ) {
		    print " Found at line $line : $1 (nest=$nest)\n" if $debug;
		    if ($1 eq 'else' || exists( $defines->{$2} )) {
			# true elsif or plain else
			if ($nest == $nest_at_ignore && 
			    !$ignore_from_elsif[$nest]) {
			    $ignoring=0;
			    $$pp_ignore = $line;
			}
		    }
		}
		elsif ( $codeLine =~ m/^\s*\`endif/ ) {
		    print " Found at line $line : endif (nest=$nest)\n" if $debug;
		    if ($nest == $nest_at_ignore) {
			$ignoring=0;
			$$pp_ignore = $line;
		    }
		    $nest--;
		}
		next;
	    }
	    if ( $codeLine =~ m/^\s*\`(ifdef|ifndef)\s+($VID)/ ) {
		$nest++;
		print " Found at line $line : $1 $2 (nest=$nest)\n" if $debug;
		if ( (($1 eq 'ifdef' ) && !exists( $defines->{$2} )) ||
		     (($1 eq 'ifndef') &&  exists( $defines->{$2} ))) {
		    $ignoring=1;
		    $fdata->{files}{$file}{contexts}{$line}{pre_ignore} = 'XX';
		    $pp_ignore = \$fdata->{files}{$file}{contexts}{$line}{pre_ignore};
		    $nest_at_ignore=$nest;
		    $ignore_from_elsif[$nest]=0;
		}
		next;
	    }
	    if ( $codeLine =~ m/^\s*\`(else|(?:elsif\s+($VID)))/ ) {
		print " Found at line $line : $1 (nest=$nest)\n" if $debug;
		if ($nest) {
		    $ignoring=1;
		    $fdata->{files}{$file}{contexts}{$line}{pre_ignore} = 'XX';
		    $pp_ignore = \$fdata->{files}{$file}{contexts}{$line}{pre_ignore};
		    $nest_at_ignore=$nest;
		    # an ignore from an elsif means you will never stop ignoring
		    #   at this nest level
		    $ignore_from_elsif[$nest]=($1 ne 'else');
		}
		else {
		    add_problem("Warning:$file:$line: found $1 without \`ifdef");
		}
		next;
	    }
	    if ( $codeLine =~ m/^\s*\`endif/ ) {
		print " Found at line $line : endif (nest=$nest)\n" if $debug;
		if ($nest) {
		    $nest--;
		}
		else {
		    add_problem("Warning:$file:$line: found \`endif without \`ifdef");
		}
		next;
	    }
	    
	    if ( $codeLine =~ m/^\s*\`include\s+\"(.*?)\"/ ) {
		# revisit - need to check for recursive includes
		print " Found at line $line : include $1\n" if $debug;
		$fdata->{files}{$file}{includes}{ffile($1)}=$line;
		my $inc_file = $1;
		my $inc_file_and_path = scan_dirs($inc_file,$inc_dirs);
		if ($inc_file_and_path) {
		    push(@fileStack,$fh,$line,$f);
		    $f = $inc_file_and_path;
		    $file=ffile($f);
		    $line=0;

		    if (!exists($fdata->{files}{$file})) {
			init_file($fdata->{files},$f);
			$fdata->{files}{$file}{contexts}{"1"}{value} = 
			    $rs->{modules}{$rs->{module}};
		    }
		    print "\n Include: " unless $quiet;
		    $fh = open_file($f);
		}
		else {
		    add_problem("Warning:$file:$line: Include file $inc_file not found");
		    $fdata->{unresolved_includes}{ffile($1)}=$1;
		}
		next;
	    }

	    if ( $codeLine =~ m/^\s*\`define\s+($VID)(?:\s+(.*))?/ ) {
		my $def_name  = $1;
		my $def_value = defined($2) ? $2 : '';
		add_define($fdata->{defines}, $1 , $2 , $file, $line );
		add_anchor($fdata->{files}{$file}{anchors},$line,"");  
		# Don't handle nested defines at source
		#  revisit: does verilog do this? what if the nested define
		#   is defined later?
		$def_value =~ s/\s+$//; # remove whitespace from end of define
		$defines->{$def_name}{value} = $def_value;
		print " Found in $file line $line : define $def_name = $def_value\n"
		    if $debug;
		next;
	    }

	    if ( $codeLine =~ m/^\s*\`undef\s+($VID)/ ) {
		delete($defines->{$1});
		print " Found at line $line : undef $1\n" if $debug;
		next;
	    }


	    if ( $codeLine =~ m/^\s*$verilog_compiler_keywords_regexp/ ) {
		next;
	    }
	    expand_defines(\$codeLine,$defines,$file,$line);
	    parse_line($codeLine,$file,$line,$ps,$rs);
	}
	$fdata->{files}{$file}{lines} = $line;

	if (defined($pp_ignore) && $pp_ignore eq "XX") { # no endif
	    $$pp_ignore = $line;
	}

	close ($fh);

	# check if we were included from another file
	if (0==scalar(@fileStack)) {
	    print "Stack is empty\n" if $debug;
	    last;
	}
	else {
	    $f    = pop(@fileStack);
	    $line = pop(@fileStack);
	    $fh   = pop(@fileStack);
	    $file=ffile($f);
	    print "\n Back to $f" unless $quiet;
	}
    }

    print "\n" unless $quiet;

    checkEndState($file,$line,$ps);
    
}

sub open_file {
    my ($f) = @_;
    local (*F);

    print "Searching $f " unless $quiet;
    open(F,"<$f") || die "Error: can not open file $f to read: $!\n ";
    return *F;
}

###############################################################################
# for best use this should be called line by line, so that the
#  defines get the correct values when defines are defined multiple
#  times
# expects a string and hash of defines with the values like this
#   $defines->{DEF1}{value} = VAL1;
#   $defines->{DEF2}{value} = VAL2;
#
sub expand_defines {
    my ($bufp,$defines,$file,$line) = @_;
    
    while ( $$bufp =~ m/^(.*?)\`($VID)/ ) { 
	my $b = $1;
	my $d = $2;
	if (exists($defines->{$d}{value})) {
	    my $v = $defines->{$d}{value};
	    $$bufp =~ s/\`$d/$v/;
	}
	else {
	    if ($b =~ m/^\s*$/) {
		add_problem("Warning:$file:$line: unknown define: `$d, guessing it is a compiler directive");
		$$bufp='';
	    }
	    else {
		add_problem("Warning:$file:$line: found undefined define `$d");
		$$bufp =~ s/\`$d//;
	    }
	}
    }
}

###############################################################################
# Look through all the include directories for an include file
#
sub scan_dirs {
    my ($fname,$inc_dirs) = @_;
    my ($dir);

    if ( $fname =~ m|^/| ) { # an absolute path
      return "$fname" if ( -r "$fname" );
    }
    else {
      foreach $dir (@{$inc_dirs}) {
	  $dir =~ s|/$||;
	  return "$dir/$fname" if ( -r "$dir/$fname" );
      }
    }
    return '';
}

###############################################################################
# Take a look through the unresolved modules , delete any that have already
#  been found, and for the others look on the search path
#
sub resolve_modules {
    my ($fdata,$lib_dirs, $lib_exts)= @_;
    my ($m,$file,@resolved,$lib_ext);

    @resolved=();
    foreach $m (keys %{$fdata->{unresolved_modules}}) {
	if ( exists( $fdata->{modules}{$m} )) {
	    delete( $fdata->{unresolved_modules}{$m} );
	}
	else {
	    foreach $lib_ext (@{$lib_exts}) {
		if ($file = scan_dirs("$m$lib_ext",$lib_dirs)){
		    delete( $fdata->{unresolved_modules}{$m} );	
		    print "resolve_modules: found $m in $file\n" if $debug;
		    push(@resolved,$file);
		    last;
		}
	    }
	}
    }
    return @resolved;
}


###############################################################################
# Initialize fdata->{files}{FILE} which stores file data
#
sub init_file {
    my ($fdataf,$file) = @_;
    my ($fb);
    $fb = ffile($file);
    $fdataf->{$fb} = {};                 # set up hash for each file
    $fdataf->{$fb}{full_name} = $file;   
    $fdataf->{$fb}{anchors}  = {};
    $fdataf->{$fb}{modules}  = {};
    $fdataf->{$fb}{contexts} = {};
    $fdataf->{$fb}{includes} = {};
    $fdataf->{$fb}{inc_done} = 0;
    $fdataf->{$fb}{lines}    = 0;
    $fdataf->{$fb}{instance_lines} = {};
    $fdataf->{$fb}{included_by} = [];

}

###############################################################################
# Initialize fdata->{FILE}{modules}{MODULE} which stores 
#  module (or macromodule or primitive) data
#
sub init_module {
    my ($modules,$module,$file,$line,$type) = @_;


    die "Error: attempt to reinit module" if (exists($modules->{$module}));

    $modules->{$module}{line}     = $line;
    $modules->{$module}{name}     = $module;
    $modules->{$module}{type}     = $type;
    $modules->{$module}{end}       = -1;
    $modules->{$module}{file}      = $file;
    $modules->{$module}{t_and_f}   = {}; # tasks and functions
    $modules->{$module}{signals}   = {};
    $modules->{$module}{parameters}= [];
    $modules->{$module}{parameters_by_name}= {};
    $modules->{$module}{instances} = []; # things that this module instantiates
    $modules->{$module}{inst_by}   = []; # things that instantiated this module
    $modules->{$module}{port_order} = []; 
    $modules->{$module}{named_ports} = 1; # assume named ports in instantiations
    $modules->{$module}{duplicate} = 0;   # set if another definition is found

}

###############################################################################
# Initialize fdata->{FILE}{modules}{MODULE}{t_and_f}{TF} which
#  stores tasks and functions' data
#
sub init_t_and_f {
    my ($module,$type,$tf,$file,$line,$anchor) = @_;

    if (exists($module->{t_and_f}{$tf})) {
	add_problem("Warning:$file:$line new definition of $tf ".
		    "(discarding previous from ".
		    "$module->{t_and_f}{$tf}{file}:$module->{t_and_f}{$tf}{line})");
    }
    $module->{t_and_f}{$tf} = {};
    $module->{t_and_f}{$tf}{type}      = $type;
    $module->{t_and_f}{$tf}{name}      = $tf;
    $module->{t_and_f}{$tf}{line}      = $line;
    $module->{t_and_f}{$tf}{end}       = -1;
    $module->{t_and_f}{$tf}{file}      = $file;
    $module->{t_and_f}{$tf}{signals}   = {};
    $module->{t_and_f}{$tf}{anchor}    = $anchor;
    # point up at things to share with module:
    #  - task and functions
    #  - module signals
    $module->{t_and_f}{$tf}{t_and_f}    = $module->{t_and_f}; 
    $module->{t_and_f}{$tf}{parameters_by_name} = $module->{parameters_by_name}; 
    $module->{t_and_f}{$tf}{parameters} = $module->{parameters}; 
    $module->{t_and_f}{$tf}{m_signals}  = $module->{signals};
}

# note returns 1 if a signal is added (and an anchor needs to be dropped)
sub init_signal  { 
    my ($signals,$name,$type,$type2,$range,$file,$line,$warnDuplicate) = @_;

    if (exists( $signals->{$name} )) {
	if ($warnDuplicate) {
	    if (($signals->{$name}{type} eq "output")||
		($signals->{$name}{type} eq "inout") ||
		($signals->{$name}{type} eq "input")) {
		$signals->{$name}{type2}=$type;
	    }
	    elsif (($signals->{$name}{type} eq "reg")&&  # reg before output
		   (($type eq "output") ||
		    ($type eq "inout"))) {
		$signals->{$name}{type}=$type;
		$signals->{$name}{type2}="reg";
	    }
	    else {
		add_problem("Warning:$file:$line: ignoring another definition".
			    "of signal $name ($type) first seen at ".
			    "$signals->{$name}{file}:$signals->{$name}{line}");
	    }
	}
	return 0;
    }
    else {
	$signals->{$name} = { type     => $type, 
			      file     => $file,
			      line     => $line,
			      a_line   => -1,
			      a_file   => "",
			      i_line   => -1,
			      i_file   => "",
			      port_con => [],
			      con_to   => [],
			      posedge  => 0,
			      negedge  => 0,
			      type2    => $type2,
			      source   => { checked => 0, file => "" , 
					    line => "" },
			      range    => $range
			      };
	return 1;
    }
}

###############################################################################
# Add an anchor to the list of anchors that need to be put in
#  the file
#
sub add_anchor {
    my ($anchors,$line,$name) = @_;

    my ($a,$no_name_exists);

    if (! exists($anchors->{$line}) ) {
	$anchors->{$line} = [];
    }

    if ( $name ) {
	push( @{$anchors->{$line}} , $name );
    }
    else {
	# if no name is specified then you'll get the line number
	#  as the name, but make sure this only happens once
	$no_name_exists = 0;
	foreach $a ( @{$anchors->{$line}} ) {
	    if ($a eq $line) {
		$no_name_exists=1;
		last;
	    }
	}
	push( @{$anchors->{$line}} , $line ) unless ($no_name_exists);
    }
}

sub add_define {
    my ($defines,$def_name,$def_value,$file,$line) = @_;

    $def_value = '' if (!defined($def_value));
    $def_value =~ s/\s+$//; # remove whitespace from end of define

    my $name = '`'.$def_name;

    if (exists($defines->{$name})) {
	if (($defines->{$name}{file} ne $file) || ($defines->{$name}{line} != $line)) {
	    add_problem("Warning:$file:$line: ignoring another definition ".
			"of $def_name=\"$def_value\", ".
			"first was $def_name=\"$defines->{$name}{value}\" at ".
			"$defines->{$name}{file}:$defines->{$name}{line}");
	}
    }
    else {
	$defines->{$name}  = { line => $line, file => $file ,
			       value => $def_value };
    }

}

###############################################################################
#   Cross referencing
###############################################################################

###############################################################################
# Cross-reference all the files:
#  - find the modules and set up $fdata->{modules}
#  - store the data about where it is instatiated with each module
#  - check for self instantiation
#  - check for files with modules + instances outside modules
#  - set a_line for signals driven by output and i_line
#
sub cross_reference {
    my ($fdata) = @_;
    my ($f,$m,$fr,$mr,$m2,$inst,$sig,$sigp,$port_con,$param,$i,$port,$con_to);

    # stores the instantiation data in an 
    #  array so that we can easily tell which modules
    #  are disconnected and which are the tops of the
    #  hierarchy and makes it easier to go up
    foreach $m (keys %{$fdata->{modules}}) {
	print " Making inst_by for $m\n" if $debug;
	foreach $m2 (keys %{$fdata->{modules}}) {
	    foreach $inst (@{$fdata->{modules}{$m2}{instances}}) {
		if (($inst->{module} eq $m) &&
		    exists($fdata->{modules}{$m})) {
		    print "    inst by $m2\n" if $debug;
		    push( @{$fdata->{modules}{$m}{inst_by}}, 
			   { module => $m2,
			     file   => $inst->{file},
		             inst   => $inst->{inst_name} ,
			     line   => $inst->{line} } );
		}
	    }
	}
    }

    # Find any modules that appear to instantiate themselves
    #  (to prevent getting into infinite recursions later on)
    foreach $m (keys %{$fdata->{modules}}) {
	print " Checking  self instantiations for $m\n" if $debug;
	foreach $inst (@{$fdata->{modules}{$m}{instances}}) {
	    if ($inst->{module} eq $m) {
		add_problem("Warning:$inst->{file}:$inst->{line}: $m ".
			    "instantiates itself");
		$inst->{module} = '_ERROR_SELF_INSTANTIATION_'; 
		# remove the port con for all signals not attached
		foreach $sig (keys %{$fdata->{modules}{$m}{signals}}) {
		    $sigp = $fdata->{modules}{$m}{signals}{$sig};
		    my $port_con_ok=[];
		    foreach $port_con (@{$sigp->{port_con}}) {
			if ($port_con->{module} ne $m) { push(@$port_con_ok,$port_con); }
			else {  print " Deleting connection for $sig\n" if $debug; }
		    }
		    $sigp->{port_con} = $port_con_ok;
		}
	    }
	}
    }

    # Go through instances without named ports (port will be a number instead) and
    #  resolve name if you can, otherwise delete. These can appear in signal's port_con
    #  lists and in instances connections lists.
    foreach $m (keys %{$fdata->{modules}}) {
	if (0 == $fdata->{modules}{$m}{named_ports}) {
	    $f = $fdata->{modules}{$m}{file}; # for error messages
	    print " Resolving numbered port connections in $m\n" if $debug;
	    foreach $sig (keys %{$fdata->{modules}{$m}{signals}}) {
		print "   doing $sig\n" if $debug;
		$sigp = $fdata->{modules}{$m}{signals}{$sig};
		
		
		foreach $port_con (@{$sigp->{port_con}}) {
		    if ($port_con->{port} =~ m/^[0-9]/ ) {
			if ( exists( $fdata->{modules}{$port_con->{module}}) ) {
			    $m2 = $fdata->{modules}{$port_con->{module}};
			    if (defined($m2->{port_order}[$port_con->{port}])) {
				$port_con->{port}=$m2->{port_order}[$port_con->{port}];
			    }
			    else {
				add_problem("Warning:$port_con->{file}:$port_con->{line}:".
					    " could not resolve port number to name");
			    }
			}
		    }
		}
	    }

	    foreach $inst (@{$fdata->{modules}{$m}{instances}}) {
		if ( exists( $fdata->{modules}{$inst->{module}}) ) {
		    $m2 = $fdata->{modules}{$inst->{module}};
		    foreach $port (keys %{$inst->{connections}}) {
			last if ($port !~ m/^[0-9]/); # if any are named, all are named
			if (defined($m2->{port_order}[$port])) {
			    # move old connection to named port
			    $inst->{connections}{$m2->{port_order}[$port]} =
				$inst->{connections}{$port};
			    # remove old numbered port from hash
			    delete($inst->{connections}{$port});
			}
			else {
			    add_problem("Warning:$inst->{file}:$inst->{line}:".
					"could not resolve port number $port to name)");
			}
		    }
		}
	    }
	}
    }


    # Go through all the modules and each signal inside
    #  looking at whether the signal is connected to any outputs
    #   (set the a_line on the first one if it is not already set)
    #  Also, when you see a signal connected to an input (and that
    #   submod is only instantiated once) reach down into the submod
    #   and set the i_line of that signal, so that clicking on the
    #   input can pop you up to the line that input is driven in
    #   one of the instantiations
    foreach $m (keys %{$fdata->{modules}}) {
	print " Finding port connections in $m\n" if $debug;
	foreach $sig (keys %{$fdata->{modules}{$m}{signals}}) {
	    print "   checking signal $sig\n" if $debug;
	    $sigp = $fdata->{modules}{$m}{signals}{$sig};

	    foreach $port_con (@{$sigp->{port_con}}) {
		if ( exists( $fdata->{modules}{$port_con->{module}}) ) {
		    print "    connection to $port_con->{module}\n" if $debug;
		    $m2 = $fdata->{modules}{$port_con->{module}};
		    if (exists( $m2->{signals}{$port_con->{port}})) {
			push(@{$m2->{signals}{$port_con->{port}}{con_to}}, 
			     { signal => $sig , module => $m , inst => $port_con->{inst}});
			if ( ($m2->{signals}{$port_con->{port}}{type} eq 
			      'output') &&
			    ($sigp->{a_line} == -1)) {
			    $sigp->{driven_by_port}=1;
			    $sigp->{a_line} = $port_con->{line};
			    $sigp->{a_file} = $port_con->{file};
			    add_anchor($fdata->{files}{$port_con->{file}}{anchors},
				       $port_con->{line},'');
			}
			elsif ($m2->{signals}{$port_con->{port}}{type} eq 
			       'input') {
			    $m2->{signals}{$port_con->{port}}{driven_by_port}=1;
			    if (scalar(@{$m2->{inst_by}}) &&
				($m2->{signals}{$port_con->{port}}{i_line}==-1)) {
				$m2->{signals}{$port_con->{port}}{i_line}=
				  $port_con->{line};
				$m2->{signals}{$port_con->{port}}{i_file}=
				  $port_con->{file};
				add_anchor($fdata->{files}{$port_con->{file}}{anchors},
					   $port_con->{line},'');
				print "    set i_line $port_con->{port} ".
				    "$port_con->{file}:$port_con->{line}\n" if $debug;
			    }
			}
		    }
		}
	    }
	}
    }

    # find all signal sources
    foreach $m (keys %{$fdata->{modules}}) {
	print " Finding signal sources in $m\n" if $debug;
	foreach $sig (keys %{$fdata->{modules}{$m}{signals}}) {
	    $sigp = $fdata->{modules}{$m}{signals}{$sig};
	    next if $sigp->{source}{checked};
	    print "   finding signal source for $sig of $m\n" if $debug;
	    $sigp->{source} = find_signal_source($fdata,$sigp);
	}
    }
    
    # Index parameters by name
    foreach $m (keys %{$fdata->{modules}}) {
	$i=0;
	foreach $param (@{$fdata->{modules}{$m}{parameters}}) {
	    $param->{number}=$i++;
	    $fdata->{modules}{$m}{parameters_by_name}{$param->{name}}=$param;
	}
    }

    # propagate the posedge, negedge stuff up the hierarchy
    foreach $m (keys %{$fdata->{modules}}) {
	# only do the recursion for top level modules
	if ( 0== @{$fdata->{modules}{$m}{inst_by}} ) {
	    prop_edges($fdata,$m);
	}
    }
    
    # get included_by information
    foreach $f ( keys %{$fdata->{files}} ) {
	foreach $i (get_files_includes($fdata,$f)) {
	    if (exists $fdata->{files}{$i}) {
		push( @{$fdata->{files}{$i}{included_by}} , $f );
	    }
	}
    }
}

sub find_signal_source {
    my ($fdata,$sigp) = @_;
    my ($con_to,$port_con,$ret_val);

    if ($sigp->{source}{checked}) {
	print "     source already found\n" if $debug;
	$ret_val = $sigp->{source};
    }
    else {
	$ret_val =  { checked => 1, file => '' , line => '' };
	if (exists($sigp->{driven_by_port})) {
	    print "     drive by port\n" if $debug;
	    foreach $con_to (@{$sigp->{con_to}}) {
#		if ($fdata->{modules}{$con_to->{module}}{signals}{$con_to->{signal}}{type} eq 'input') {
		if ($sigp->{type} eq 'input') {
		    print "       following input $con_to->{signal} $con_to->{module} $con_to->{inst}\n" if $debug;
		    if (!exists($fdata->{modules}{$con_to->{module}}{signals}{$con_to->{signal}}{i_line})) { die "Error: $con_to->{signal} does not exist $!"; }
		    $ret_val = find_signal_source($fdata,
					      $fdata->{modules}{$con_to->{module}}{signals}{$con_to->{signal}});
		}
	    }
	    foreach $port_con (@{$sigp->{port_con}}) {
		if (exists ($fdata->{modules}{$port_con->{module}})) {
		    if (exists($fdata->{modules}{$port_con->{module}}{signals}{$port_con->{port}})) {
			if ($fdata->{modules}{$port_con->{module}}{signals}{$port_con->{port}}{type} eq 'output') {
			    print "       following output $port_con->{port} $port_con->{module} $port_con->{inst}\n" if $debug;
			    $ret_val = find_signal_source($fdata,
							  $fdata->{modules}{$port_con->{module}}{signals}{$port_con->{port}});
			}
		    }
		    else {
			add_problem("Warning:$port_con->{file}:$port_con->{line}:".
				    " Connection to nonexistent port ".
				    " $port_con->{port} of module $port_con->{module}");
		    }
		}
	    }
	}
	else {
	    if ($sigp->{a_line}==-1) {
		if ($sigp->{type} eq 'input') {
		    print "     signal is an input not driven at higher level\n" if $debug;
		    $ret_val =  { checked => 1, file => $sigp->{file} , line => $sigp->{line} };
		}
		else {
		    print "     signal has unknown source\n" if $debug;
		}
	    }
	    else {
		print "     signal is driven in this module\n" if $debug;
		$ret_val =  { checked => 1 , file => $sigp->{a_file} , line => $sigp->{a_line} };
	    }
	}
    }

    $sigp->{source} = $ret_val;
    return $ret_val;
}

###############################################################################
# Propagate posedge and negedge attributes of signals up the hierarchy
#
sub prop_edges {
    my ($fdata,$m) = @_;
    my ($imod,@inst,$sig,$sigp,$port_con,$m2);

    print "Prop_edges $m\n" if $debug;

    for ( ($imod) = &rvp::get_first_instantiation($fdata,$m ) ;
	  $imod;
	  ($imod) = &rvp::get_next_instantiation($fdata)) {
	push(@inst,$imod) if (exists( $fdata->{modules}{$imod}));
    }
    foreach $imod (@inst) { prop_edges($fdata,$imod); }

    # Propagate all the edges up the hierarchy
    foreach $sig (keys %{$fdata->{modules}{$m}{signals}}) {
	print "   checking signal $sig\n" if $debug;
	$sigp = $fdata->{modules}{$m}{signals}{$sig};
	
	foreach $port_con (@{$sigp->{port_con}}) {
	    if ( exists( $fdata->{modules}{$port_con->{module}}) ) {
		print "    connection to $port_con->{module}\n" if $debug;
		$m2 = $fdata->{modules}{$port_con->{module}};
		if (exists( $m2->{signals}{$port_con->{port}})) {
		    print "Propagating posedge on $sig from $port_con->{module} to $m\n" 
			if ($debug && (!$sigp->{posedge})  && $m2->{signals}{$port_con->{port}}{posedge});
		    $sigp->{posedge} |= $m2->{signals}{$port_con->{port}}{posedge};
		    $sigp->{negedge} |= $m2->{signals}{$port_con->{port}}{negedge};
		}
	    }
	}
    }
}


###############################################################################
# given a source file name work out the file without the path
#
sub ffile {
    my ($sfile) = @_;

    $sfile =~ s/^.*[\/\\]//;

    return $sfile;
}

sub add_problem {
    my ($p) = @_;

    if (!defined($problems)) {
	die "Error: problems array is not defined $!";
    }
    print "$p\n" if $debug;
    push (@{$problems},$p);
}

###############################################################################
# 
BEGIN {
$baseEval = {
  START => {
    MODULE => '$rs->{t}={ type=>$match, line=>$line };',
  },
  MODULE => {
    SIGNAL => '$rs->{t}={ type=>$match, range=>"", name=>"" , type2=>"" };',
    INST => '$rs->{t}={ mod=>$match, line=>$line, name=>"" , port=>0 , portName=>"" , vids=>[]};', 
  },
  MODULE_NAME => {
    NAME => 'my $nState="MODULE_PORTS"; 
             my $type = $rs->{t}{type};  $rs->{t}=undef;',
  },
  IN_CONCAT => {
    VID => 'push(@{$rs->{t}{vids}},{name=>$match,line=>$line}) if (exists($rs->{t}{vids}));',
  },
  IN_BRACKET => {
    VID => 'IN_CONCAT:VID',
  },
  SCALARED_OR_VECTORED => {
    TYPE => 'if ($match eq "reg") { $rs->{t}{type2} = "reg"; }'
  },
  SIGNAL_NAME => {
    VID => '$rs->{t}{name}=$match; $rs->{t}{line}=$line;',
  },
  SIGNAL_AFTER_EQUALS => {
    END => '$rs->{t}=undef;',
  },
  INST_NAME => {
    VID => '$rs->{t}{name}=$match;',
  },
  INST_PORTS => {
    COMMA => '$rs->{t}{port}++;',
  },
  INST_PORT_NAME => {
    NAME => '$rs->{t}{portName}=$match;
             $rs->{t}{vids} = [];', # throw away any instance parameters picked up
  },
  INST_NAMED_PORT_CON => {
    VID => 'push(@{$rs->{t}{vids}},{name=>$match,line=>$line});',
    END => 'if ($rs->{t}{portName} eq "") { $rs->{t}{portName}=$rs->{t}{port}++; }
                 my @vids = @{$rs->{t}{vids}};
                 my $portName = $rs->{t}{portName};
                 $rs->{t}{portName}=""; 
                 $rs->{t}{vids}=[];',
  },
  INST_NUMBERED_PORT => {
    COMMA   => 'INST_NAMED_PORT_CON:END',
    BRACKET => 'INST_NAMED_PORT_CON:END',
    VID => 'push(@{$rs->{t}{vids}},{name=>$match,line=>$line});',
  },
  INST_SEMICOLON => {
    SEMICOLON => '$rs->{t}=undef;',
  },
  SIGNAL_AFTER_NAME => {
    SEMICOLON => '$rs->{t}=undef;',
  },
  IN_EVENT_BRACKET => {
    EDGE => '$rs->{t}={ type=>$match };',
  },
  IN_EVENT_BRACKET_EDGE => {
    VID => 'my $edgeType = $rs->{t}{type}; $rs->{t}=undef;',
  },
  STMNT => {
    ASSIGN_OR_TASK => '$rs->{t}={ vids=>[{name=>$match,line=>$line}]};', 
    CONCAT             => '$rs->{t}={ vids=>[]};', 
  },
  STMNT_ASSIGN_OR_TASK => { # copy of STMNT_ASSIGN
    EQUALS    => 'my @vids = @{$rs->{t}{vids}}; $rs->{t}=undef;', 
# Revisit: this arc doesn't exist anymore - put this into smnt_semicolon
#    SEMICOLON => '$rs->{t}=undef;', 
    BRACKET   => '$rs->{t}=undef;', 
  },
  STMNT_ASSIGN => { # copy of STMNT_ASSIGN_OR_TASK
    EQUALS => 'STMNT_ASSIGN_OR_TASK:EQUALS',
  },
  IN_RANGE => {
    END => 'if (exists($rs->{t}{range})) {
                 $rs->{t}{range}=$fromLastPos;
           }',
  },
  ANSI_PORTS_TYPE => { # V2001 ansi ports
    TYPE =>  '$rs->{t}={ type=>$match, range=>"", name=>"" , type2=>"" };',
  },
  ANSI_PORTS_TYPE2 => { # V2001 ansi ports
    TYPE => 'if ($match eq "reg") { $rs->{t}{type2} = "reg"; }',
  },
  ANSI_PORTS_SIGNAL_NAME => { # V2001 ansi ports
    VID => '$rs->{t}{name}=$match; $rs->{t}{line}=$line;',
  },
};

############################################################
# debugEval
############################################################
$debugEval = {
  ANSI_PORTS_SIGNAL_NAME => {
    VID => 'print "Found $rs->{t}{type} $rs->{t}{name} $rs->{t}{range} [$line]\n";',
  },
  SIGNAL_NAME => {
    VID => 'print "Found $rs->{t}{type} $rs->{t}{name} $rs->{t}{range} [$line]\n";',
  },
  INST_BRACKET => {
    PORTS => 'print "found instance $rs->{t}{name} of $rs->{t}{mod} [$rs->{t}{line}]\n";',
  },
  INST_NAMED_PORT_CON => {
    END => 'my @vidnames; 
            foreach my $vid (@vids) {push @vidnames,$vid->{name};}
            print " Port $portName connected to ".join(",",@vidnames)."\n";',
  },
  INST_NUMBERED_PORT => {
    COMMA   => 'INST_NAMED_PORT_CON:END',
    BRACKET => 'INST_NAMED_PORT_CON:END',
  },
};


############################################################
# rvpEval
############################################################

$rvpEval = {
  MODULE => {
    ENDMODULE => 'if ((($rs->{p}{type} eq "primitive")&&($match ne "endprimitive"))||
                         (($rs->{p}{type} ne "primitive")&&($match eq "endprimitive"))){
		     add_problem("Warning:$file:$line: module of type".
                                 " $rs->{p}{type} ended by $match");
	          }
	          $rs->{modules}{$rs->{module}}{end} = $line;
	          $rs->{module}   = "";
	          $rs->{files}{$file}{contexts}{$line}{value}= { name=>"",type=>"" };
                  $rs->{p}= undef;',
  },
  MODULE_NAME => {
    NAME => 'if (exists($rs->{modules}{$match})) {
                 $nState = "IGNORE_MODULE";
	         $rs->{modules}{$match}{duplicate} = 1;
	         add_problem("Warning:$file:$line ignoring new definition of ".
                          "module $match, previous was at ".
		          "$rs->{modules}{$match}{file}:$rs->{modules}{$match}{line})");
             }
             else {
               $rs->{module}=$match;
               init_module($rs->{modules},$rs->{module},$file,$line,$type);
	       $rs->{files}{$file}{modules}{$rs->{module}} = $rs->{modules}{$rs->{module}};
  	       add_anchor($rs->{files}{$file}{anchors},$line,$rs->{module});
  	       $rs->{files}{$file}{contexts}{$line}{value}= $rs->{p}= $rs->{modules}{$rs->{module}};
  	       $rs->{files}{$file}{contexts}{$line}{module_start}= $rs->{module};
             }',
  },
  MODULE_PORTS => {
    VID => 'push(@{$rs->{p}{port_order}},$match);',
  },
  FUNCTION => {
    NAME => '$rs->{function}=$match;
                      init_t_and_f($rs->{modules}{$rs->{module}},"function",
		      $rs->{function},$file,$line,$rs->{module}."_".$rs->{function});
	              add_anchor($rs->{files}{$file}{anchors},$line,$rs->{module}."_".$rs->{function});
                      $rs->{files}{$file}{contexts}{$line}{value}= $rs->{p}= $rs->{modules}{$rs->{module}}{t_and_f}{$rs->{function}};',
  },
  TASK => {
    NAME => '$rs->{task}=$match;
  	              init_t_and_f($rs->{modules}{$rs->{module}},"task",
		                   $rs->{task},$file,$line,$rs->{module}. "_" .$rs->{task});
 	              add_anchor($rs->{files}{$file}{anchors},$line,$rs->{module}. "_" . $rs->{task});
                      $rs->{files}{$file}{contexts}{$line}{value}= $rs->{p}= $rs->{modules}{$rs->{module}}{t_and_f}{$rs->{task}};',
  },
  ENDTASK => {
    ENDTASK => '$rs->{modules}{$rs->{module}}{t_and_f}{$rs->{task}}{end} = $line;
                $rs->{task}="";
	        $rs->{files}{$file}{contexts}{$line}{value}= $rs->{p}= $rs->{modules}{$rs->{module}};',
  },
  T_SIGNAL => {
     SIGNAL => '$rs->{t}={ type=>$match, range=>"", name=>"" , type2=>"" };',
     ENDTASK => 'ENDTASK:ENDTASK',
  },
  ENDFUNCTION => {
      ENDFUNCTION => '$rs->{modules}{$rs->{module}}{t_and_f}{$rs->{function}}{end} = $line;
                     $rs->{function}="";
	             $rs->{files}{$file}{contexts}{$line}{value}= $rs->{p}= $rs->{modules}{$rs->{module}};',
  },
  F_SIGNAL => {
     SIGNAL => '$rs->{t}={ type=>$match, range=>"", name=>"" , type2=>"" };',
     ENDFUNCTION => 'ENDFUNCTION:ENDFUNCTION',
  },
  PARAM_NAME => {
    NAME => '$rs->{t}= { name => $match,file => $file, line => $line , value => "" };
             push(@{$rs->{p}{parameters}}, $rs->{t});
	     add_anchor($rs->{files}{$file}{anchors},$line,"");',
  },
  PARAM_AFTER_EQUALS => {
    COMMA     => '$rs->{t}{value} = $fromLastPos;',
    SEMICOLON => 'PARAM_AFTER_EQUALS:COMMA',
  },
  ASSIGN => {
    VID => 'if ( exists($rs->{p}{signals}{$match}) &&
		              ($rs->{p}{signals}{$match}{a_line} == -1)) {
	       $rs->{p}{signals}{$match}{a_line} = $line;
	       $rs->{p}{signals}{$match}{a_file} = $file;
               add_anchor($rs->{files}{$file}{anchors},$line,"");
	    }',
  },
  SIGNAL_NAME => {
    VID => 'init_signal($rs->{p}{signals},$match,$rs->{t}{type},$rs->{t}{type2},
                        $rs->{t}{range},$file,$line,1)
               && add_anchor($rs->{files}{$file}{anchors},$line,"");',
  },
  SIGNAL_AFTER_NAME => { # don't assign a_line for reg at definition, as this is 
                         #   only the initial value
    ASSIGN => 'if ( $rs->{p}{signals}{$rs->{t}{name}}{type} ne "reg" ) {
                  $rs->{p}{signals}{$rs->{t}{name}}{a_line}=$rs->{t}{line};
                  $rs->{p}{signals}{$rs->{t}{name}}{a_file}=$file;
	          add_anchor($rs->{files}{$file}{anchors},$rs->{t}{line},"");
               }',
  },
  INST_BRACKET => {
    PORTS => '$rs->{unres_mod}{$rs->{t}{mod}}=$rs->{t}{mod};
	      $rs->{files}{$file}{instance_lines}{$rs->{t}{line}} = $rs->{t}{mod};
	      push( @{$rs->{p}{instances}} , { module => $rs->{t}{mod} , 
					       inst_name => $rs->{t}{name} ,
					       file => $file,
					       line => $rs->{t}{line},
					       connections => {} });
	      add_anchor($rs->{files}{$file}{anchors},$rs->{t}{line},
                         $rs->{module}."_".$rs->{t}{name});',
  },
  INST_NAMED_PORT_CON => {
    END =>   'my $inst_num= $#{$rs->{p}{instances}};
              $rs->{p}{instances}[$inst_num]{connections}{$portName}=$fromLastPos;
	      foreach my $s (@vids) {
                init_signal($rs->{p}{signals},$s->{name},"wire","","",$file,$s->{line},0)
                    && add_anchor($rs->{files}{$file}{anchors},$s->{line},"");
		 # clear named_ports flag if port is a number
		 $rs->{p}{named_ports} = 0 if ($portName =~ /^[0-9]/ );
		 push( @{$rs->{p}{signals}{$s->{name}}{port_con}}, 
		        { port   => $portName ,
                          line   => $s->{line},
                          file   => $file,
		          module => $rs->{t}{mod} ,
		          inst   => $rs->{t}{name} });
              }',
  },
  INST_NUMBERED_PORT => {
    COMMA   => 'INST_NAMED_PORT_CON:END',
    BRACKET => 'INST_NAMED_PORT_CON:END',
  },
  IN_EVENT_BRACKET_EDGE => {
    VID => 'if (exists($rs->{p}{signals}{$match})) { 
               $rs->{p}{signals}{$match}{$edgeType}=1; };',
  },

  STMNT_ASSIGN_OR_TASK => { # copy of STMNT_ASSIGN
    EQUALS => 'foreach my $s (@vids) {
                 my $sigp = undef;
	         if ( exists($rs->{p}{signals}{$s->{name}} )) {
                      $sigp = $rs->{p}{signals}{$s->{name}};
                 }
	         elsif ( exists($rs->{p}{m_signals}) &&
                         exists($rs->{p}{m_signals}{$s->{name}}) ) {
                      $sigp = $rs->{p}{m_signals}{$s->{name}};
                 }
                 if (defined($sigp) && ($sigp->{a_line}==-1)) {
		      $sigp->{a_line}=$s->{line};
		      $sigp->{a_file}=$file;
		      add_anchor($rs->{files}{$file}{anchors},$s->{line},"");
	         }
               }',
  },
  STMNT_ASSIGN => { # copy of STMNT_ASSIGN_OR_TASK
    EQUALS => 'STMNT_ASSIGN_OR_TASK:EQUALS',
  },
  ANSI_PORTS_SIGNAL_NAME => { # V2001 ansi ports
    VID => 'init_signal($rs->{p}{signals},$match,$rs->{t}{type},$rs->{t}{type2},
                        $rs->{t}{range},$file,$line,1);
            push(@{$rs->{p}{port_order}},$match) if exists $rs->{p}{port_order};
            add_anchor($rs->{files}{$file}{anchors},$line,"");',
  },
};

############################################################
# language definition
############################################################

$vid_vnum_or_string = 
[ { arcName=> 'VID',    regexp=> '$VID' , nextState=> ['$ps->{curState}'] ,},
  { arcName=> 'NUMBER', regexp=> '$VNUM', nextState=> ['$ps->{curState}'] ,},
  { arcName=> 'STRING', regexp=> '\\"',   nextState=> ['IN_STRING','$ps->{curState}'],},
];

$languageDef =
[
 { 
 stateName =>     'START',
 confusedNextState => 'START',
 search => 
  [
   { arcName   => 'MODULE' ,        regexp => '\b(?:module|macromodule|primitive)\b',
     nextState => ['MODULE_NAME'] ,},
   { arcName   => 'CONFIG',        regexp => '\bconfig\b', # V2001
     nextState => ['CONFIG'] , },
   { arcName   => 'LIBRARY',        regexp => '\blibrary\b', # V2001
     nextState => ['LIBRARY'] , },
  ],
 },
 { 
 stateName =>     'MODULE',
 confusedNextState => 'MODULE',
 search => 
  [
   { arcName   => 'ENDMODULE' ,     regexp => '\b(?:end(?:module|primitive))\b',
     nextState => ['START'] ,  },
   { arcName   => 'FUNCTION',       regexp => '\bfunction\b',
     nextState => ['FUNCTION'] , },
   { arcName   => 'TASK',           regexp => '\btask\b',
     nextState => ['TASK'] ,  },
   { arcName   => 'PARAM',      regexp => '\bparameter\b',
     nextState => ['PARAM_NAME','MODULE'] ,  },
   { arcName   => 'SPECIFY',        regexp => '\bspecify\b',
     nextState => ['SPECIFY'] , },
   { arcName   => 'TABLE',          regexp => '\btable\b',
     nextState => ['TABLE'] ,  },
   { arcName   => 'EVENT_DECLARATION' ,    regexp => '\bevent\b' ,
     nextState => ['EVENT_DECLARATION'] ,  },
   { arcName   => 'DEFPARAM' ,       regexp => '\bdefparam\b' ,
     nextState => ['DEFPARAM'] , },
   { arcName   => 'GATE' ,           regexp => '$verilog_gatetype_regexp' ,
     nextState => ['GATE'] ,   },
   { arcName   => 'ASSIGN' ,         regexp => '\bassign\b' ,
     nextState => ['ASSIGN'] , },
   { arcName   => 'SIGNAL' ,         regexp => '$verilog_sigs_regexp' ,
     nextState => ['SCALARED_OR_VECTORED','MODULE'] , },
   { arcName   => 'INITIAL_OR_ALWAYS', regexp => '\b(?:initial|always)\b' ,
     nextState => ['STMNT','MODULE'] , },

   { arcName   => 'LOCAL_PARAM',    regexp => '\blocalparam\b', # V2001
     nextState => ['PARAM_NAME','MODULE'] ,  },
   { arcName   => 'GENERATE',       regexp => '\bgenerate\b', # V2001
     nextState => ['GENERATE'] , },


   { arcName   => 'INST',          regexp    => '$VID' ,
     nextState => ['INST_PARAM'] , },
   # don't put any more states here because $VID matches almost anything
   ],
 },################ END OF MODULE STATE
 {
 stateName =>     'MODULE_NAME',
 search =>   # $nState is usually MODULE_PORTS, but is set to
             #   IGNORE_MODULE when a duplicate module is found
  [ { arcName   => 'NAME',  regexp => '$VID' , nextState => ['$nState'] , }, ],
 },
 {
 stateName =>     'IGNORE_MODULE' ,  # just look for endmodule
 allowAnything => 1, 
 search => [ 
   { arcName   => 'ENDMODULE' , regexp    => '\bendmodule\b',
     nextState => ['START'], }, 
   @$vid_vnum_or_string, 
  ],
 },
 {
 stateName =>     'MODULE_PORTS' ,  # just look for signals until ;
 allowAnything => 1, 
 search => [ 
   { arcName   => 'TYPE' , regexp    => 'input|output|inout',  # V2001 ansi ports
     nextState => ['ANSI_PORTS_TYPE','MODULE'], resetPos => 1, }, 
   { arcName   => 'END', regexp    => ';' , nextState => ['MODULE'] , },
   @$vid_vnum_or_string, 
  ],
 },
 {
 stateName =>     'FUNCTION' , 
 search => [
    { arcName => 'RANGE', regexp => '\[', nextState => ['IN_RANGE','FUNCTION'] , },
    { arcName => 'TYPE',  regexp => 'real|integer' ,nextState => ['FUNCTION'] ,  },
    { arcName => 'SIGNED', regexp => 'signed' ,nextState => ['FUNCTION'] ,  }, # V2001
    { arcName => 'AUTO',   regexp => 'automatic' ,nextState => ['FUNCTION'] ,  }, # V2001
    { arcName => 'NAME',  regexp => '$VID' , nextState => ['FUNCTION_AFTER_NAME'] , 
    },
   ],
 },
 {
 stateName =>     'FUNCTION_AFTER_NAME' , 
 search => [
    { arcName => 'SEMICOLON', regexp => ';', nextState => ['F_SIGNAL'] , },
    { arcName => 'BRACKET',  regexp => '\(' ,   # V2001
      nextState => ['ANSI_PORTS_TYPE','STMNT','ENDFUNCTION'] ,  },
  ],
 },
 {
 stateName =>     'TASK' , 
 search => [
   { arcName => 'AUTO', regexp => '\bautomatic\b', nextState => ['TASK'],}, # V2001
   { arcName => 'NAME', regexp => '$VID', nextState => ['TASK_AFTER_NAME'],},],
 },
 {
 stateName =>     'TASK_AFTER_NAME' , 
 search => [
    { arcName => 'SEMICOLON', regexp => ';', nextState => ['T_SIGNAL'] , },
    { arcName => 'BRACKET',  regexp => '\(' ,   # V2001
      nextState => ['ANSI_PORTS_TYPE','STMNT','ENDTASK'] ,  },
  ],
 },
 { 
 stateName =>     'T_SIGNAL' , 
 failNextState => ['STMNT','ENDTASK'],
 search => [
   { arcName   => 'ENDTASK',        regexp => '\bendtask\b',
     nextState => ['MODULE'] , },
   { arcName   => 'SIGNAL' ,         regexp => '$verilog_sigs_regexp' ,
     nextState => ['SCALARED_OR_VECTORED','T_SIGNAL'] , },
   ],
 },
 {
 stateName =>     'ENDTASK',
 search => [
   { arcName   => 'ENDTASK',        regexp => '\bendtask\b',
     nextState => ['MODULE'] , },
   ],
 },
 { 
 stateName =>     'F_SIGNAL' , 
 failNextState => ['STMNT','ENDFUNCTION'],
 search => [
   { arcName   => 'ENDFUNCTION',     regexp => '\bendfunction\b',
     nextState => ['MODULE'] , },
   { arcName   => 'SIGNAL' ,         regexp => '$verilog_sigs_regexp' ,
     nextState => ['SCALARED_OR_VECTORED','F_SIGNAL'] , },
   ],
 },
 {
 stateName =>     'ENDFUNCTION',
 search => [
   { arcName   => 'ENDFUNCTION',     regexp => '\bendfunction\b',
     nextState => ['MODULE'] , },
   ],
 },
 {
 stateName =>     'PARAM_NAME',
 search => [
    { arcName   => 'NAME',  regexp    => '$VID' , 
      nextState => ['EQUAL','PARAM_AFTER_EQUALS'] , },
    { arcName   => 'RANGE', regexp    => '\[' ,
      nextState => ['IN_RANGE','PARAM_NAME'] , },
   ],
 },
 {
 stateName =>     'EQUAL',
 storePos => 1,
 search => [ { regexp    => '=' , }, ]
 },
 {
 stateName =>     'PARAM_AFTER_EQUALS',
 allowAnything => 1, 
 search => 
  [
   { arcName   => 'CONCAT',      regexp    => '{' ,
     nextState => ['IN_CONCAT','PARAM_AFTER_EQUALS'] ,  },
   { arcName   => 'COMMA',       regexp    => ',' ,
     nextState => ['PARAM_NAME'] ,    },
   { arcName   => 'SEMICOLON', 	 regexp    => ';' , },
   @$vid_vnum_or_string,
  ]
 },
 {
 stateName =>     'IN_CONCAT',
 allowAnything => 1, 
 search => 
  [
   { arcName   => 'CONCAT' ,   regexp    => '{' ,
     nextState => ['IN_CONCAT','IN_CONCAT'] ,     },
   { arcName   => 'END' ,      regexp    => '}' , }, # pop up
   @$vid_vnum_or_string,
  ]
 },
 {
 stateName =>     'IN_RANGE',
 allowAnything => 1, 
 search => 
  [
   { arcName   => 'RANGE' , regexp    => '\[' ,
     nextState => ['IN_RANGE','IN_RANGE'] , },
   { arcName   => 'END' ,   regexp    => '\]' , }, # pop up
   @$vid_vnum_or_string,
  ]
 },
 {
 stateName =>     'IN_BRACKET',
 allowAnything => 1, 
 search => 
  [
   { arcName   => 'BRACKET' ,  regexp    => '\(' ,
     nextState => ['IN_BRACKET','IN_BRACKET'] ,   },
   { arcName   => 'END' ,      regexp    => '\)' ,  }, # pop up
   @$vid_vnum_or_string,
  ]
 },
 { 
 stateName =>     'IN_STRING',
 allowAnything => 1, 
 search => 
  [ # note: put \" in regexp so that emacs colouring doesn't get confused
   { arcName   => 'ESCAPED_QUOTE' ,  regexp => '\\\\\\"' , # match \"
     nextState => ['IN_STRING'] , },
   # match \\ (to make sure that \\" does not match \"
   { arcName   => 'ESCAPE' ,  	     regexp => '\\\\\\\\' ,  
     nextState => ['IN_STRING'] , },
   { arcName   => 'END' ,  	     regexp => '\\"' , }, # match " and pop up
  ]
 },
 {
 stateName =>     'SPECIFY',
 allowAnything => 1, 
 search => [ { regexp => '\bendspecify\b' , nextState => ['MODULE'] ,}, 
	       @$vid_vnum_or_string,],
 },
 {
 stateName =>     'TABLE',
 allowAnything => 1, 
 search => [ { regexp => '\bendtable\b'   , nextState => ['MODULE'] ,},
	     @$vid_vnum_or_string,],
 },
 {
 stateName =>     'EVENT_DECLARATION' ,  # just look for ;
 allowAnything => 1,
 search => [ {	regexp    => ';' ,    nextState => ['MODULE'] , },
             @$vid_vnum_or_string,],
 },
 {
 stateName =>     'DEFPARAM' ,  # just look for ;
 allowAnything => 1,
 search => [ {	regexp    => ';' ,    nextState => ['MODULE'] , },
             @$vid_vnum_or_string,],
 },
 {
  # REVISIT: could find signal driven by gate here (is output always the first one??)
 stateName =>     'GATE' , 
 allowAnything => 1,
 search => [ {	regexp    => ';' ,    nextState => ['MODULE'] , },
             @$vid_vnum_or_string,],
 },
 {
 stateName =>     'ASSIGN',
 allowAnything => 1, 
 search => 
  [
   { arcName   => 'RANGE' ,   regexp    => '\[' ,
     nextState => ['IN_RANGE','ASSIGN'] ,      },
   { arcName   => 'EQUALS' ,  regexp    => '=' ,
     nextState => ['ASSIGN_AFTER_EQUALS'] ,    },
   @$vid_vnum_or_string,
  ]
 },
 {
 stateName =>     'ASSIGN_AFTER_EQUALS' , 
 allowAnything => 1,
  search => 
   [ 
    { arcName=>'COMMA',     regexp => ',',    
      nextState => ['ASSIGN'],},
    { arcName=>'CONCAT',    regexp => '{',
      nextState => ['IN_CONCAT','ASSIGN_AFTER_EQUALS'],},
    # don't get confused by function calls (which can also contain commas)
    {	arcName=>'BRACKET',   regexp => '\(',    
    	nextState => ['IN_BRACKET','ASSIGN_AFTER_EQUALS'],},
    {	arcName=>'END',       regexp => ';',    
    	nextState => ['MODULE'],},
    @$vid_vnum_or_string,
   ],
 },
 { # REVISIT: V2001 - the name of this is misleading now
 stateName =>     'SCALARED_OR_VECTORED',  # for signal defs
 failNextState => ['SIGNAL_RANGE'],
 search => [ { regexp => '\b(?:scalared|vectored)\b', nextState => ['SIGNAL_RANGE'],},
	     { arcName => 'TYPE' , regexp => '$verilog_sigs_regexp', # V2001
	       nextState => ['SCALARED_OR_VECTORED'],}, 
             { regexp => '\b(?:signed)\b', nextState => ['SCALARED_OR_VECTORED'],},], # V2001
 },
 { 
 stateName =>     'SIGNAL_RANGE',          # for signal defs
 storePos => 1,
 failNextState => ['SIGNAL_DELAY'],
 search => [ { regexp => '\[', nextState => ['IN_RANGE','SIGNAL_DELAY'],}, ],
 },
 {   
 stateName =>     'SIGNAL_DELAY',          # for signal defs
 failNextState => ['SIGNAL_NAME'],
 search => [ { regexp => '\#', nextState => ['SIGNAL_DELAY_VALUE'],},  ],
 },
 {  
 stateName =>     'SIGNAL_DELAY_VALUE',    # for signal defs
 search => 
  [ 
   { regexp => '\d+',  nextState => ['SIGNAL_NAME'],}, 
   { regexp => '$VID', nextState => ['SIGNAL_NAME'],}, 
   { regexp => '\(',   nextState => ['IN_BRACKET','SIGNAL_NAME'],}, 
  ],
 },
 { 
 stateName =>     'SIGNAL_NAME',           # for signal defs
  search => [ { arcName   => 'VID' , regexp    => '$VID',  
	       nextState => ['SIGNAL_AFTER_NAME'], }, ],
 },
 { # for signal defs
 stateName =>     'SIGNAL_AFTER_NAME',
 storePos => 1,
 search => 
  [ 
   { regexp => ',',  nextState => ['SIGNAL_NAME'],}, 
   { regexp => '\[', nextState => ['IN_RANGE','SIGNAL_AFTER_NAME'],}, # memories
   { arcName => 'SEMICOLON' , regexp => ';',},  # pop up
   { arcName => 'ASSIGN',     regexp => '=', nextState => ['SIGNAL_AFTER_EQUALS'],}
  ],
 },
 {
 stateName =>     'SIGNAL_AFTER_EQUALS' , 
 allowAnything => 1,
 search => 
   [ 
    { regexp => ',',    nextState => ['SIGNAL_NAME'],},
    { regexp => '{',    nextState => ['IN_CONCAT','SIGNAL_AFTER_EQUALS'],},
    { regexp => '\(',   nextState => ['IN_BRACKET','SIGNAL_AFTER_EQUALS'],},
    { arcName => 'END', regexp => ';', }, # pop up
    @$vid_vnum_or_string,
   ],
 },
 { 
 stateName =>     'INST_PARAM',
 storePos => 1,
 failNextState => ['INST_NAME'],
 search => [ { regexp => '\#', nextState=> ['BRACKET','IN_BRACKET','INST_NAME'],},],
 },
 {
 stateName =>     'INST_NAME',
 search => 
  [ 
   { arcName   => 'VID' ,       regexp => '$VID', 
     nextState => ['INST_RANGE'],      },
    # REVISIT: some code has instances with no names - this is allowed for primitive
    #  instances only - maybe it is OK for things defined as cells too?
    { arcName   => 'NO_NAME' ,   regexp => '\(', 
      nextState => ['INST_NO_NAME','MODULE'], },
  ],
 },
 { 
 stateName =>     'INST_NO_NAME' ,  
 allowAnything => 1,
 search => [ { regexp => ';' , }, @$vid_vnum_or_string,],
 },
 {
 stateName =>     'INST_RANGE',
 failNextState => ['INST_BRACKET'],
 search => [ { regexp => '\[', nextState => ['IN_RANGE','INST_BRACKET'],}, ],
 },
 {
 stateName =>     'INST_BRACKET',
 storePos => 1,
 search => [ { arcName => 'PORTS' , regexp => '\(', nextState => ['INST_PORTS'],},],
 },
 {
 stateName =>     'INST_PORTS',
 failNextState => ['INST_NUMBERED_PORT'],
 storePos => 1, # for numbered ports connection capturing
 search => 
  [ 
   { arcName => 'COMMA', regexp => ',',   nextState => ['INST_PORTS'], },
   { regexp => '\.',  nextState => ['INST_PORT_NAME'],  },
   { regexp => '\)',  nextState => ['INST_SEMICOLON','MODULE'], },
  ],
 },
 {
 stateName =>     'INST_PORT_NAME',
 search => [ { arcName   => 'NAME' , regexp => '$VID', 
	       nextState => ['INST_NAMED_PORT_BRACKET','INST_NAMED_PORT_CON',
		             'INST_NAMED_PORT_CON_AFTER'], }, ],
 },
 {
   stateName => 'INST_NAMED_PORT_BRACKET',
   storePos => 1,
   search => [ { regexp => '\(' , },] 
 },
 {
 stateName =>     'INST_NAMED_PORT_CON',
 allowAnything => 1, 
 search => 
  [
   { regexp => '\[' , nextState => ['IN_RANGE','INST_NAMED_PORT_CON'] , },
   { regexp => '\{' , nextState => ['IN_CONCAT','INST_NAMED_PORT_CON'] , },
   { regexp => '\(' , 
     nextState => ['INST_NAMED_PORT_CON','INST_NAMED_PORT_CON'], },
   { arcName => 'END', regexp    => '\)' , },   # pop up 
   @$vid_vnum_or_string,
  ]
 },
 {
 stateName =>     'INST_NAMED_PORT_CON_AFTER',
 search => 
  [ 
   { arcName => 'BRACKET', regexp => '\)' , 
     nextState => ['INST_SEMICOLON','MODULE']}, 
   { arcName => 'COMMA' ,  regexp => ',' ,  
     nextState => ['INST_DOT']}, 
  ]
 },
 { stateName => 'INST_DOT',     
   search => 
    [ 
     { regexp => '\.' , nextState => ['INST_PORT_NAME']}, 
     { regexp => ','  , nextState => ['INST_DOT']},   # blank port
    ] 
 },
 {
 stateName =>     'INST_NUMBERED_PORT',
 allowAnything => 1, 
 search => 
  [
   { regexp => '\[', nextState => ['IN_RANGE','INST_NUMBERED_PORT'],},
   { regexp => '\{', nextState => ['IN_CONCAT','INST_NUMBERED_PORT'],},
   { regexp => '\(', nextState => ['IN_BRACKET','INST_NUMBERED_PORT'],},
   { arcName => 'BRACKET' , regexp => '\)', nextState => ['INST_SEMICOLON','MODULE'], },
   { arcName => 'COMMA' ,   regexp => ',' , nextState => ['INST_NUMBERED_PORT'],
     storePos => 1, },
     @$vid_vnum_or_string,
  ]
 },
 { stateName => 'INST_SEMICOLON', 
   search => [ { arcName => 'SEMICOLON', regexp => ';'  , },] },
 {
 stateName =>     'STMNT',
 search => 
  [
   { arcName   => 'IF',	                    regexp => '\bif\b' ,
     nextState => ['BRACKET','IN_BRACKET','STMNT','MAYBE_ELSE'] ,},
   { arcName   => 'REPEAT_WHILE_FOR_WAIT',  regexp => '\b(?:repeat|while|for|wait)\b' ,
     nextState => ['BRACKET','IN_BRACKET','STMNT'] ,  },
   { arcName   => 'FOREVER', 	            regexp => '\bforever\b' ,
     nextState => ['STMNT'] , },
   { arcName   => 'CASE',                   regexp => '\bcase[xz]?\b' ,
     nextState => ['BRACKET','IN_BRACKET','CASE_ITEM'] , },
   { arcName   => 'BEGIN',	            regexp => '\bbegin\b' ,
     nextState => ['BLOCK_NAME','IN_SEQ_BLOCK'] , },
   { arcName   => 'FORK',	            regexp => '\bfork\b' ,
     nextState => ['BLOCK_NAME','IN_PAR_BLOCK'] , },
   { arcName   => 'DELAY',                  regexp => '\#' ,
     nextState => ['DELAY'] , },
   { arcName   => 'EVENT_CONTROL',	    regexp => '\@' ,
     nextState => ['EVENT_CONTROL'] , },
   { arcName   => 'SYSTEM_TASK',  	    regexp    => '\$$VID' ,
     nextState => ['SYSTEM_TASK'] , },
   { arcName   => 'DISABLE_ASSIGN_DEASSIGN_FORCE_RELEASE',
     regexp    => '\b(?:disable|assign|deassign|force|release)\b',
     nextState => ['STMNT_JUNK_TO_SEMICOLON'] , }, # just throw stuff away
   { arcName   => 'ASSIGN_OR_TASK',	   regexp => '$VID' ,
     nextState => ['STMNT_ASSIGN_OR_TASK'] , },
   { arcName   => 'CONCAT',	           regexp => '{' ,
     nextState => ['IN_CONCAT','STMNT_ASSIGN'] ,  },
   { arcName   => 'NULL',                  regexp => ';' ,
     }, # pop up
   { arcName   => 'POINTY_THING',	   regexp    => '->' , # not sure what this is!
     nextState => ['POINTY_THING_NAME'] ,  },
  ],
 },
 {
 stateName =>     'MAYBE_ELSE',
 failNextState => [] , # don't get confused, just pop the stack for the next state
 search => [{ arcName => 'ELSE', regexp => '\belse\b' , nextState => ['STMNT'],},]
 },
 {
 stateName =>     'BLOCK_NAME',
 failNextState => [] , # don't get confused, just pop the stack for the next state
 search => [{ arcName => 'COLON', regexp    => ':' , 
	      nextState => ['BLOCK_NAME_AFTER_COLON'] ,},]
 },
 {
 # REVISIT: can have parameter/reg/integer/real/time/event etc declarations after this
 stateName =>     'BLOCK_NAME_AFTER_COLON',
 search => [ { arcName   => 'VID', regexp    => '$VID' , }, ]
 },
 {
 stateName =>     'IN_SEQ_BLOCK',
 failNextState => ['STMNT','IN_SEQ_BLOCK'] , 
 search => [{ arcName   => 'END', regexp    => '\bend\b' , }, ]
 },
 {
 stateName =>     'IN_PAR_BLOCK',
 failNextState => ['STMNT','IN_PAR_BLOCK'] , 
 search => [{ arcName   => 'JOIN', regexp => '\bjoin\b' , }, ]
 },
 {
 stateName =>     'DELAY',
 search => 
  [
   { arcName => 'NUMBER',  regexp => '$VNUM', nextState => ['STMNT'], },
   { arcName => 'ID',      regexp => '$VID',  nextState => ['STMNT'], },
   { arcName => 'BRACKET', regexp => '\(',    nextState => ['IN_BRACKET','STMNT'],},
  ]
 },
 {
 stateName =>     'EVENT_CONTROL',
 search => 
  [
   { arcName => 'ID',      regexp => '$VID', nextState => ['STMNT'], },
   { arcName => 'STAR',    regexp => '\*', nextState => ['STMNT'], }, # V2001
   { arcName => 'BRACKET', regexp => '\(', 
     nextState => ['IN_EVENT_BRACKET','STMNT'], },
  ]
 },
 {
 stateName =>     'IN_EVENT_BRACKET',
 allowAnything => 1, 
 search => 
  [ 
   # must go before vid_vnum_or_string as posedge and negedge look like VIDs
   { arcName => 'EDGE' ,	   regexp    => '\b(?:posedge|negedge)\b' ,
     nextState => ['IN_EVENT_BRACKET_EDGE'] , },
   { arcName   => 'BRACKET' ,	   regexp    => '\(' ,
     nextState => ['IN_EVENT_BRACKET','IN_EVENT_BRACKET'] , },
   { arcName   => 'END' ,          regexp    => '\)' , }, # popup
   @$vid_vnum_or_string,
  ]
 },
 { # in theory there could be an expression here, I just take the first VID
 stateName =>     'IN_EVENT_BRACKET_EDGE',
 failNextState => ['IN_EVENT_BRACKET'] ,
 search => [{ arcName => 'VID', regexp => '$VID', nextState => ['IN_EVENT_BRACKET'],},],
 },
 {
 stateName =>     'STMNT_ASSIGN_OR_TASK',
 failNextState => ['STMNT_SEMICOLON'],
 search => 
  [
   { arcName => 'EQUALS',      	   regexp => '[<]?=',  
     nextState => ['STMNT_JUNK_TO_SEMICOLON'], },
   { arcName => 'RANGE',	   regexp => '\[',  
     nextState => ['IN_RANGE','STMNT_ASSIGN'],},
   { arcName => 'BRACKET',         regexp => '\(',     # task with params
     nextState => ['IN_BRACKET','STMNT_SEMICOLON'],  },
  ]
 },
 {
 stateName =>     'STMNT_ASSIGN',
 search => [{ arcName => 'EQUALS', regexp => '[<]?=', nextState => ['STMNT_JUNK_TO_SEMICOLON'],},],
 },
 {
 stateName =>     'SYSTEM_TASK',
 failNextState => ['STMNT_SEMICOLON'],
 search => 
  [
   { arcName => 'BRACKET',   	     regexp => '\(',  
     nextState => ['IN_BRACKET','STMNT_SEMICOLON'], },    ],
 },
 {
 stateName =>     'POINTY_THING_NAME',
 search => [{ arcName => 'VID', regexp => '$VID', nextState => ['STMNT_SEMICOLON'], }, ],
 },
 {
 stateName =>     'CASE_ITEM',
 allowAnything => 1, 
 search => 
  [
   { arcName => 'END',      	   regexp => 'endcase',  },
   { arcName => 'COLON',	   regexp => ':',  
     nextState => ['STMNT','CASE_ITEM'], },
   { arcName => 'DEFAULT',	   regexp => 'default',  
     nextState => ['MAYBE_COLON','STMNT','CASE_ITEM'], },
   # don't get confused by colons in ranges
   { arcName => 'RANGE',	   regexp => '\[',  
     nextState => ['IN_RANGE','CASE_ITEM'], },
    @$vid_vnum_or_string,
  ],
 },
 {
 stateName =>     'MAYBE_COLON',
 failNextState => [],
 search => [ { regexp    => ':' , }, ]
 },
 { # look for ;  but also allow the ending of a statement with an end 
   #   even though it is not really legal (verilog seems to accept it, so I do too)
 stateName =>     'STMNT_JUNK_TO_SEMICOLON' ,  
 allowAnything => 1,
 search => [ 
	     { regexp => ';' , }, 
	     { regexp => '\b(?:end|join)\b' , resetPos => 1, }, # popup and reset pos to
	     @$vid_vnum_or_string,                              #  before the end/join
	   ],
 },
 { 
 stateName => 'STMNT_SEMICOLON', 
 search => [ { regexp => ';'  , },
	     { regexp => '\b(?:end|join)\b' , resetPos => 1, }, 
	   ],
 },
 { stateName => 'BRACKET',   search => [ { regexp => '\(' , },] },
 { stateName => 'SEMICOLON', search => [ { regexp => ';'  , },] },
 # V2001
 {
 stateName =>     'CONFIG',
 allowAnything => 1, 
 search => [ { regexp => '\bendconfig\b' , nextState => ['START'] ,}, 
	       @$vid_vnum_or_string,],
 },
 {
 stateName =>     'LIBRARY' ,  # just look for ;
 allowAnything => 1,
 search => [ {	regexp    => ';' ,    nextState => ['START'] , },
             @$vid_vnum_or_string,],
 },
 {
 stateName =>     'GENERATE',
 allowAnything => 1, 
 search => [ { regexp => '\bendgenerate\b' , nextState => ['MODULE'] ,}, 
	       @$vid_vnum_or_string,],
 },



 { # V2001 ansi module ports
 stateName =>     'ANSI_PORTS_TYPE',  
 failNextState => ['ANSI_PORTS_TYPE2'],
 search => [ { arcName => 'TYPE' , regexp => 'input|output|inout', 
	       nextState => ['ANSI_PORTS_TYPE2'],},],
 },
 { # V2001 ansi module ports
 stateName =>     'ANSI_PORTS_TYPE2',  
 failNextState => ['ANSI_PORTS_SIGNAL_RANGE'],
 search => [ { arcName => 'TYPE' , regexp => '$verilog_sigs_regexp', 
	       nextState => ['ANSI_PORTS_TYPE2'],}, 
             { regexp => '\b(?:signed)\b', nextState => ['ANSI_PORTS_TYPE2'],},],
 },
 { # V2001 ansi module ports
 stateName =>     'ANSI_PORTS_SIGNAL_RANGE',          # for signal defs
 storePos => 1,
 failNextState => ['ANSI_PORTS_SIGNAL_NAME'],
 search => [ { regexp => '\[', nextState => ['IN_RANGE','ANSI_PORTS_SIGNAL_NAME'],}, ],
 },
 { # V2001 ansi module ports
 stateName =>     'ANSI_PORTS_SIGNAL_NAME',
  search => [ 
   # REVISIT: examples seem to say that , can seperate eg:
   #   input a, output b  - the TYPE arc is here for that. Is it true?
   { arcName   => 'TYPE' , regexp    => 'input|output|inout',  
     nextState => ['ANSI_PORTS_TYPE'], resetPos => 1, }, 
   { arcName   => 'VID' , regexp    => '$VID',  
     nextState => ['ANSI_PORTS_SIGNAL_AFTER_NAME'], }, 
  ],
 },
 { # V2001 ansi module ports
 stateName =>     'ANSI_PORTS_SIGNAL_AFTER_NAME',
 search => 
  [ 
   { regexp => ',',  nextState => ['ANSI_PORTS_SIGNAL_NAME'],}, 
   { regexp => '\[', nextState => ['IN_RANGE','ANSI_PORTS_SIGNAL_AFTER_NAME'],}, # memories
   { regexp => ';',  nextState => ['ANSI_PORTS_TYPE'] , }, 
   { regexp => '\)', nextState => ['SEMICOLON'], } # semicolon, then pop up
  ],
 },

];
}


############################################################
# make the parser, and return it as a string
############################################################


sub makeParser {
    my ($evalDefs,$genDebugCode) = @_;

    checkDataStructures($evalDefs);
    
    my $perlCode; # the perl code we are making
    
#    vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
    $perlCode .= <<EOF;
sub parse_line {

  my (\$code,\$file,\$line,\$ps,\$rs) = \@_;
EOF
#    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

    # Note had to change this!!!! to add ?: otherwise it breaks the next match
    #  REVISIT: can't I just change the global ones to these values?
    $perlCode.="  my \$verilog_gatetype_regexp = '\\\\b(?:" .
	        join("|",@verilog_gatetype_keywords) . ")\\\\b';\n";
    $perlCode.="  my \$verilog_sigs_regexp = '\\\\b(?:" . 
	        join("|",@verilog_sigs) . ")\\\\b';\n";

#    vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
    $perlCode .= <<EOF;

  my \$VID = '(?:[A-Za-z_][A-Za-z_0-9\$]*|\\\\\\\\\\S+)';
  # V2001: added [sS] - is this correct
  my \$VNUM= '(?:(?:[0-9]*\\'[sS]?[bBhHdDoO]\\s*[0-9A-Fa-f]+)|(?:[0-9]+))'; #'

  if (!exists(\$ps->{curState})){
      \$ps->{curState} = undef;
      \$ps->{prevState}= undef;
      \$ps->{nextStateStack}= ["START"];
      \$ps->{storing}= 0;
      \$ps->{stored}= "";
      \$ps->{confusedNextState}= "START";
  }

  my \$storePos = -1;
  my \$lastPos = 0;
  while (1) {


    \$lastPos = pos(\$code) if (defined(pos(\$code)));

    if ( \$code =~ m/\\G\\s*\\Z/gs ) {
	last;
    }
    else {
	pos(\$code) = \$lastPos;
    }
    
    \$code =~ m/\\G\\s*/gs ; # skip any whitespace

    \$ps->{prevState} = \$ps->{curState};
    \$ps->{curState} = pop(\@{\$ps->{nextStateStack}}) or
	die "Error: No next state after \$ps->{prevState} ".
	    "\$file line \$line :\n \$code";
   print "---- \$ps->{curState} \$file:\$line (".pos(\$code).")\\n" 
       if defined \$ps->{curState} && defined pos(\$code) && $genDebugCode;

    if (\$ps->{curState} eq 'CONFUSED') {
	my \$posMark = '';
	if (substr(\$code,length(\$code)-1,1) ne "\\n") { \$posMark.="\\n"; }
	\$posMark .= (" " x pos(\$code)) ."^";
	add_problem("Confused:\$file:\$line: in state \$ps->{prevState}:\\n".
		    "\$code".\$posMark);
	\@{\$ps->{nextStateStack}} = (\$ps->{confusedNextState});
	return; # ignore the rest of the line
    }

EOF
#    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  my $elsif = "if"; # first time it is an if, after that an elsif

  foreach my $state (@$languageDef) {
      my $stateName = $state->{stateName};
      my $allowAnything    = exists($state->{allowAnything}) && $state->{allowAnything};
      my $re = $allowAnything ? '' : '\G'; # allowAnything==0 forces a match 
      #  where we left off last time
      $perlCode.= "    $elsif (\$ps->{curState} eq \"$stateName\") {\n";
      
      if (exists($state->{confusedNextState})) {
	  $perlCode.= "      \$ps->{confusedNextState}=\"$state->{confusedNextState}\";\n";
      }
	  
      if (exists($state->{search})) {
	  my @searchTerms=();
	  foreach my $search (@{$state->{search}}) { 
	      push @searchTerms, $search->{regexp}; 
	  }
	  $re .= "(?:(". join(")|(",@searchTerms)."))";
	  
	  my $failNextState='';
	  
	  if (exists($state->{failNextState})) {
	      if (scalar(@{$state->{failNextState}}) != 0) {
		  $failNextState="\"".
		      join('","',reverse(@{$state->{failNextState}})).
			  "\"";
	      }
	      # else leave it set at nothing - means just popup
	  }
	  else {
	      $failNextState='"CONFUSED"';
	  }
	  $perlCode.= "        if (\$code =~ m/$re/gos) {\n";
	  
	  my $elsif2="if";
	  my $i=0;
	  foreach my $search (@{$state->{search}}) {
	      $i++;
	      
	      my $arcName = exists($search->{arcName}) ? $search->{arcName} : '';
	      
	      $perlCode.= "          $elsif2 (defined(\$$i)) {\n";
	      if ($genDebugCode) {
		  $perlCode.="           print \"----  -$arcName (\$$i)->\\n\";\n";
		  $perlCode.="           \$takenArcs->{'$stateName'}{$i}++;\n";
	      }
	      $elsif2="elsif";
	      if (exists($search->{resetPos}) && $search->{resetPos}) {
		  $perlCode.="           pos(\$code)=pos(\$code)-length(\$$i);\n";
	      }
	      if (exists($search->{arcName})) {
		  $perlCode.=  # "	      " . 
		      makeEvalCode($evalDefs,$stateName,
				   $search->{arcName},$i);
	      }
	      if (exists $search->{nextState}) {
		  $perlCode.= "	      push (\@{\$ps->{nextStateStack}}, \"".
		      join('","',reverse(@{$search->{nextState}}))."\");\n";
	      }
	      if (exists($search->{storePos}) && $search->{storePos}) {
		  $perlCode.= "       \$storePos       = pos(\$code)+length(\$$i);\n";
		  $perlCode.= "       \$ps->{storing}  = 1;\n";
		  $perlCode.= "       \$ps->{stored}   = '';\n";
	      }
	      $perlCode.= "	  }\n";
	  }
	  $perlCode.= "      }\n";
	  
	  if ($allowAnything) {
	      $perlCode.= "      else { ".
		  "push(\@{\$ps->{nextStateStack}},\"$stateName\"); last; }\n";
	  }
	  else {
	      $perlCode.= "      else { ".
		  "push(\@{\$ps->{nextStateStack}},$failNextState);".
		      " pos(\$code)=\$lastPos; }\n";
	  }
      }
      if (exists($state->{storePos}) && $state->{storePos}) {
	  $perlCode.= "      \$storePos       = pos(\$code);\n";
	  $perlCode.= "      \$ps->{storing}  = 1;\n";
	  $perlCode.= "      \$ps->{stored}   = '';\n";
      }
      $perlCode.= "    }\n";
      
      $elsif="elsif";
  }
  $perlCode.= "    else {\n";
  $perlCode.= "	      die \"Confused: Bad state \$ps->{curState}\";\n";
  $perlCode.= "    }\n";
  $perlCode.= "  }\n";
  $perlCode.= "  if (\$storePos!=-1) { \$ps->{stored}=substr(\$code,\$storePos);}\n";
  $perlCode.= "  elsif ( \$ps->{storing} ) {   \$ps->{stored} .= \$code; }\n";
  $perlCode.= "}\n";

  return $perlCode;
}

sub makeEvalCode {
    my ($evalDefs,$stateName,$arcName,$matchNo) = @_;

    my $eval='';

    foreach my $evalDef (@$evalDefs) {

	if (exists($evalDef->{$stateName}{$arcName})) {
	    if ( $evalDef->{$stateName}{$arcName} =~ m/^(.*?):(.*?)$/ ) {
		$eval.=$evalDef->{$1}{$2};
	    }
	    else {
		$eval.=$evalDef->{$stateName}{$arcName};
	    }
	    $eval.="\n";
	}
    }
    # replace $match variable with the actual number of the match
    $eval=~ s/\$match/\$$matchNo/g;

    # if fromLastPos is used then generate the code to work it out
    if ($eval =~ /\$fromLastPos/) {
	my $e;
	$e .= "my \$fromLastPos;\n";
	$e .= "if (\$storePos==-1) {\n"; # on another line
	$e .= "   \$fromLastPos=\$ps->{stored}."; # what was before
	$e .= "       substr(\$code,0,pos(\$code)-length(\$$matchNo));\n"; # some of this line
	$e .= "}\n";
	$e .= "else {\n";
	$e .= "   \$fromLastPos=substr(\$code,\$storePos,pos(\$code)".
	    "-\$storePos-length(\$$matchNo));\n";
	$e .= "}\n";
	$e .= "\$ps->{storing}=0;\n";
	$e .= "\$ps->{stored}='';\n";
	$eval = $e . $eval;

    }
    return $eval;
}

sub checkEndState {
  my ($file,$line,$ps) = @_;

  if (!exists($ps->{curState})){ 
      # parse_line was never called, file only contained comments, defines etc
      return;
  } 
  $ps->{prevState} = $ps->{curState};
  $ps->{curState} = pop(@{$ps->{nextStateStack}}) or
      add_problem("Confused:$file:$line:".
		  "No next state after $ps->{prevState} at EOF");

  if ($ps->{curState} ne 'START') {
      add_problem("Confused:$file:$line:".
		  " at EOF in state $ps->{curState}".
		  (($ps->{curState} eq 'CONFUSED')?
		   ",prevState was $ps->{prevState}":""));
  }
  if (@{$ps->{nextStateStack}}) {
      add_problem("Confused:$file:$line:".
		  " at EOF, state stack not empty: ".
		  join(" ",@{$ps->{nextStateStack}}));
  }

  # at the moment I don't check these:
  # $ps->{storing}= 0;  
  # $ps->{stored}= "";

}

sub checkDataStructures {
    my ($evalDefs) = @_;

    my %stateNames;
    my %statesUnused;

    foreach my $sp (@$languageDef) {
	die "Not hash!" unless ref($sp) eq "HASH";
	if (!exists($sp->{stateName})) {  die "State without name!"; }
	die "Duplicate state$sp->{stateName}" if exists $stateNames{$sp->{stateName}};
	$stateNames{$sp->{stateName}} = $sp;
    }

    %statesUnused = %stateNames;
    # check language def first
    foreach my $sp (@$languageDef) {
	my %t = %$sp;
	if (!exists($sp->{search})) {  die "State without search!"; }
	die "search $sp->{stateName} not array" unless ref($t{search}) eq "ARRAY";
	my %arcNames;
	foreach my $arc (@{$sp->{search}}) {
	    my %a = %$arc;
	    die "arc without regexp in $sp->{stateName}" unless exists $a{regexp}; 
	    delete $a{regexp};
	    if (exists($a{nextState})) {
		die "nextState not array"  unless ref($a{nextState}) eq "ARRAY";
		foreach my $n (@{$a{nextState}}) {
		    next if ($n =~ m/^\$/); #can't check variable ones
		    die "Bad Next state $n" 
			unless exists $stateNames{$n};
		    delete($statesUnused{$n}) if exists $statesUnused{$n};
		}
		delete $a{nextState};
	    }
	    if (exists($a{arcName})) {
		die "Duplicate arc $a{arcName}" if exists $arcNames{$a{arcName}};
		$arcNames{$a{arcName}} = 1;
		delete $a{arcName};
	    }
  	    delete $a{resetPos};
  	    delete $a{storePos};
	    foreach my $k (keys %a) {
		die "Bad key $k in arc of state $t{stateName}";
	    }
	}
	delete $t{stateName};
	delete $t{search};
	delete $t{allowAnything} if exists $t{allowAnything};

	if (exists($t{confusedNextState})) {
	    die "Bad Next confused state $t{confusedNextState}" 
		unless exists $stateNames{$t{confusedNextState}};
	    delete $t{confusedNextState};
	}
	
	foreach my $n (@{$t{failNextState}}) {
	    next if ($n =~ m/^\$/); #can't check variable ones
	    die "Bad Next fail state $n" 
		unless exists $stateNames{$n};
	    delete($statesUnused{$n}) if exists $statesUnused{$n};
	}
	delete $t{failNextState} if exists $t{failNextState};
	delete $t{storePos}      if exists $t{storePos};
	foreach my $k (keys %t) {
	    die "Bad key $k in languageDef state $sp->{stateName}";
	}
    }

    # REVISIT: MODULE PORTS looks like it is unused because it is got to
    #  by setting $nState - should have a flag in language def that turns
    #  off this check on a per state basis.
    foreach my $state (keys %statesUnused) { 
	#die "State $state was not used";
	print "Waring: State $state looks like it was not used" if $debug;
    }

    foreach my $evalDef (@$evalDefs) {
	foreach my $state (keys %$evalDef) { 
	    if (!exists($stateNames{$state})) {
		die "Couldn't find state $state";
	    }
	    my $statep = $stateNames{$state};
	    
	    foreach my $arc (keys %{$evalDef->{$state}}) {
		my $found = 0;
		foreach my $s (@{$statep->{search}}) {
		    if (exists($s->{arcName}) && ($s->{arcName} eq $arc)) {
			$found=1;
			last;
		    }
		}
		if ($found == 0) {
		    die "No arc $arc in state $state";
		}
		if ( $evalDef->{$state}{$arc} =~ m/^(.*?):(.*?)$/ ) {
		    die "No code found for $evalDef->{$state}{$arc}" 
			unless exists $evalDef->{$1}{$2};
		}
	    }
	}
    }
}


sub checkCoverage {


    print "\n\nCoverage Information:\n";
    foreach my $sp (@$languageDef) {
	if (!exists($takenArcs->{$sp->{stateName}})) {
	    print " State $sp->{stateName}: no arcs take (except fail maybe)\n";
	}
	else {
	    my $i=0;
	    foreach my $arc (@{$sp->{search}}) {
		$i++;
		if (!exists( $takenArcs->{$sp->{stateName}}{$i} )) {
		    my $arcName = $i;
		    $arcName = $arc->{arcName} if exists $arc->{arcName};
		    print " Arc $arcName of $sp->{stateName} was never taken\n";
		}
	    }
	}
    }
}


###########################################################################

# when doing require or use we must return 1
1;
