#!/usr/local/bin/perl
  
# $Id: gencrc.pl,v 1.1 2002-03-21 18:16:10 johnsonw10 Exp $
######################################################################
####                                                              ####
#### CRC xor equation generator                                   ####
####                                                              ####
#### This file is part of the firewire project                    ####
#### http://www.opencores.org/cores/firewire/                     ####
####                                                              ####
#### Description                                                  ####
#### This script generates CRC xor equations based on user's      ####
#### parameters (CRC width, data width, MSB, etc)                 ####
####                                                              ####
#### Author:                                                      ####
#### - johnsonw10@opencores.org                                   ####
####                                                              ####
######################################################################
####                                                              ####
#### Copyright (C) 2002 Authors and OPENCORES.ORG                 ####
####                                                              ####
#### This source file may be used and distributed without         ####
#### restriction provided that this copyright statement is not    ####
#### removed from the file and that any derivative work contains  ####
#### the original copyright notice and the associated disclaimer. ####
####                                                              ####
#### This source file is free software; you can redistribute it   ####
#### and/or modify it under the terms of the GNU Lesser General   ####
#### Public License as published by the Free Software Foundation; ####
#### either version 2.1 of the License, or (at your option) any   ####
#### later version.                                               ####
####                                                              ####
#### This source is distributed in the hope that it will be       ####
#### useful, but WITHOUT ANY WARRANTY; without even the implied   ####
#### warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ####
#### PURPOSE. See the GNU Lesser General Public License for more  ####
#### details.                                                     ####
####                                                              ####
#### You should have received a copy of the GNU Lesser General    ####
#### Public License along with this source; if not, download it   ####
#### from http://www.opencores.org/lgpl.shtml                     ####
####                                                              ####
######################################################################
#
# CVS Revision History
#
# $Log: not supported by cvs2svn $
#
#

# Usage: gencrc.pl <options>
#   Options:
#   -cw crc_width
#     8|10|16|32: default = 32
#     e.g. for CRC-32, crc_width = 32
#
#   -dw data_width
#     1|2|4|8|16|32|64|128|256: default = 8
#
#   -cmsb CRC_MSB
#     0: CRC_MSB = c[0]
#     1: CRC_MSB = c[cw-1]
#
#   -dmsb data_MSB
#     0: data_MSB = d[0]
#     1: data_MSB = d[dw-1]
#
#   -poly polynomial_coefficients_string
#     polynomial coefficients 0 - 32: default = Ethernet polynomial
#     e.g. for CRC8 polynomial 1 + x1 + x2 + x8, the option looks like
#     -poly "1 1 1 0 0 0 0 0 1"
#
#   -o out_file_name
#     output file name: default = crc_[cw]_d[dw].v
#
# End of usage

use strict;
use Getopt::Long;

my $version = "1.0";

sub usage {
    my $usage_began = 0;
    print "\n";
    open (THIS_FILE, "< $0");
    while (<THIS_FILE>) {
	if (/# Usage/) {$usage_began = 1;}
	if ($usage_began) {print;}
	if (/# End of usage/) {last;}
    }
    close (THIS_FILE);
    exit(1);
}

# optimize xor equations (x ^ x = 0) 
sub optimize_xor {
    my @c_tmp;
    my %o_hash;
    my $o_idx;  # optimized index

    my $key;
    my $value;

    my $j;

    @c_tmp = split(' ', $_[0]);

    for ($j = 0; $j <= $#c_tmp; $j++) {
	if (defined ($o_hash{$c_tmp[$j]})) {
	    $o_hash{$c_tmp[$j]} =
		$o_hash{$c_tmp[$j]} + 1;
	}
	else {$o_hash{$c_tmp[$j]} = 1;}
    }

    while (($key, $value) = each %o_hash) {
	if ($value % 2 != 0) {
	    $o_idx .= "$key ";
	}
    }

    return $o_idx;
}

# default options
my $d_width = 8;
my $c_width = 32;
my $d_msb = 1;
my $c_msb = 1;

my @poly = (1, 1, 1, 0, 1, 1, 0, 1,
	    1, 0, 1, 1, 1, 0, 0, 0,
	    1, 0, 0, 0, 0, 0, 1, 1,
	    0, 0, 1, 0, 0, 0, 0, 0, 1);

my $fn_opt;
my $poly_opt;

# Get command-line options
if (@ARGV > 0) {
    if (!GetOptions ('cw=i'   => \$c_width,
		     'dw=i'   => \$d_width,
		     'cmsb=i' => \$c_msb,
		     'dmsb=i' => \$d_msb,
		     'poly=s' => \$poly_opt,
		     'o=s'    => \$fn_opt,
		     'h'      => \&usage,
		     'help'   => \&usage)) {
	usage;
    }
}

#if ($c_width != 8 && $c_width != 12 && 
#    $c_width != 16 && $c_width != 32) {
#    die "\nERROR: Invalid CRC width.\n" . 
#	"Valid CRC width: 8, 12, 16, and 32.\n";
#}

if (!($d_width == 1 || $d_width == 2 || 
      $d_width == 4 || $d_width == 8 ||
      $d_width == 16 || $d_width == 32 ||
      $d_width == 64 || $d_width == 128 ||
      $d_width == 256)) {
    print "\nERROR: Invalid data width.\n";
    usage;
}

if ($c_msb > 0) {$c_msb = $c_width - 1;}
if ($d_msb > 0) {$d_msb = $d_width - 1;}

if ($poly_opt) {
    #print "poly_opt = $poly_opt\n";
    if ($poly_opt =~ /[^0-1 ]/) {
	die "\nERROR: Polynomial coefficients must be either 0 or 1.\n";
    }
    @poly = split (/ /, $poly_opt);
}

my $fn;

if ($fn_opt) {$fn = $fn_opt;}
else {$fn = "crc" . $c_width . "_" . "d" . $d_width . ".v";}

open (OUTFILE, "> $fn") or die "Couldn't open file $fn: $!\n\n";

if (@poly != ($c_width + 1)) {
    die "\nERROR: Invalid Poly length for CRC Width of $c_width.\n";
}

my $i;
my $j;

my $strlen = 0;
my $poly_str = "1";

for ($i = 1; $i <= $#poly; $i++) {
    if ($poly[$i]) {
	$poly_str .= " + x^$i";
	$strlen += 7;
	if ($strlen > 50) {
	    $poly_str .= "\n//                 ";
	    $strlen = 0;
	}
    }
}
# generate xor equations
print "\nGenerating xor equations...\n";

my @c_c_idx;
my @c_d_idx;

my @nc_d_idx;
my @nc_c_idx;

for ($i = 0; $i < $c_width; $i++) {
   $c_c_idx[$i] = $i;
}

for ($i = 0; $i < $d_width; $i++) {
    $nc_d_idx[0] = $c_d_idx[$c_width - 1] . " $i";
    $nc_c_idx[0] = $c_c_idx[$c_width - 1];

    for ($j = 1; $j < $c_width; $j++) {
	if ($poly[$j] == 1) {
	    $nc_d_idx[$j] = $c_d_idx[$j - 1] . " $c_d_idx[$c_width-1] $i";
	    $nc_c_idx[$j] = $c_c_idx[$j - 1] . " $c_c_idx[$c_width -1]";
	}
	else {
	    $nc_d_idx[$j] = $c_d_idx[$j - 1];
	    $nc_c_idx[$j] = $c_c_idx[$j - 1];
	}
    }

    for ($j = 0; $j < $c_width; $j++) {
	$c_d_idx[$j] = optimize_xor($nc_d_idx[$j]);
	$c_c_idx[$j] = optimize_xor($nc_c_idx[$j]);
    }
}  

my @c_d_tmp;
my @c_c_tmp;

for ($i = 0; $i < $c_width; $i++) {
    # sort d index numerically
    @c_d_tmp = split(' ', $c_d_idx[$i]);
    @c_d_tmp = sort {$a <=> $b} (@c_d_tmp);
    $c_d_idx[$i] = "";
    for ($j = 0; $j <= $#c_d_tmp; $j++) {
	$c_d_idx[$i] .= "$c_d_tmp[$j] ";
    }

    # sort c index numerically
    @c_c_tmp = split(' ', $c_c_idx[$i]);
    @c_c_tmp = sort {$a <=> $b} (@c_c_tmp);
    $c_c_idx[$i] = "";
    for ($j = 0; $j <= $#c_c_tmp; $j++) {
	$c_c_idx[$i] .= "$c_c_tmp[$j] ";
    }
}

print "Saving xor equations to $fn ...\n";
# add comments to the file
my $now_string = localtime;

print OUTFILE <<END_OF_HEADER;
// $fn was generated using $0 version $version
// $now_string
//
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2002 johnsonw10\@opencores and OPENCORES.ORG 
//
// This source is distributed in the hope that it will be       
// useful, but WITHOUT ANY WARRANTY; without even the implied   
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
// PURPOSE. See the GNU Lesser General Public License for more 
// details.    
//
// Parameters:
//     CRC Width  = $c_width
//     Data Width = $d_width
//     CRC MSB    = $c_msb
//     Data MSB   = $d_msb
//     Polynomial = $poly_str
//
/////////////////////////////////////////////////////////////////////////////

END_OF_HEADER

my $mod_name = $fn;
$mod_name =~ s/.v//;

print OUTFILE "\nmodule $mod_name;\n";
print OUTFILE "\n//CRC xor equations\n";

my $ii;
my $jj;

my $first_term;

# add verilog xor equations to the file
for ($i = 0; $ i < $c_width; $i++){
    $first_term = 1;
    $strlen = 0;
    @c_d_tmp = split(' ', $c_d_idx[$i]);
    @c_c_tmp = split(' ', $c_c_idx[$i]);
    
    $ii = ($c_msb) ? $i : ($c_width - 1 - $i);

    if (@c_d_tmp || @c_c_tmp) {
	print OUTFILE "assign nc[${ii}] = ";
    
	for ($j = 0; $j <= $#c_d_tmp; $j++) {
	    $jj = ($d_msb) ? $c_d_tmp[$j] : ($d_width - 1 - $c_d_tmp[$j]);

	    if ($first_term) {
		print OUTFILE "d[$jj]";
		$first_term = 0;
	    }
	    else {
		print OUTFILE " ^ d[$jj]";
	    }
	    $strlen += 8;
	    if ($strlen > 50) {
		print OUTFILE "\n              ";
		$strlen = 0;
	    }
	}

	for ($j = 0; $j <= $#c_c_tmp; $j++) {
	    $jj = ($c_msb) ? $c_c_tmp[$j] : ($c_width - 1 - $c_c_tmp[$j]);
	    if ($first_term) {
		print OUTFILE "c[$jj]";
		$first_term = 0;
	    }
	    else {
		print OUTFILE " ^ c[$jj]";
	    }
	    $strlen += 7;
	    if ($strlen > 50 && $j < $#c_c_tmp) {
		print OUTFILE "\n              ";
		$strlen = 0;
	    }
	}				
	print OUTFILE ";\n";
    }
}

print OUTFILE "\n\nendmodule";

close (OUTFILE);

print "\n$fn is successfully generated.\n";
