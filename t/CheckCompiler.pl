#!/usr/bin/env perl

=begin meta

	Simple check script for libs.
	GPLv3, Dominik Bernhardt 2024JUN15 domasprogrammer@gmail.com

=end meta
=cut

use strict;
use warnings;
use version;
use ExtUtils::Installed;
use builtin qw(true false);
use feature qw(try);

$ENV{LANG}			= q{C.UTF-8};
$ENV{LANGUAGE}			= q{C.UTF-8};

my $obj_ExtUtils		= ExtUtils::Installed->new();
my %ver_InstalledModules	= map { $_ => $obj_ExtUtils->version($_) } $obj_ExtUtils->modules();
my $bol_FullColorSupport	= false;
my $cnt_Failures		= 0;
my $int_Length			= 7;
my $str_Printf			= undef;
my $rxp_VersionSyntax		= qr{^v*}i;
my %bol_RegularLibs		= ();
my %ver_RegularLibs		= (
	q{PAR::Packer}			=> q{1.063},
	q{Term::ANSIColor}		=> q{5.01},
	);

foreach my $uri_Lib ( keys(%ver_RegularLibs) ) {

	# Workaround for bad use on version numbers
	if ( ! defined($ver_InstalledModules{$uri_Lib}) ) {
		eval qq(use $uri_Lib;);

		if ( ! $@ ) {
			$ver_InstalledModules{$uri_Lib}	= eval qq(\$${uri_Lib}::VERSION);
			}
		}

	# Module is installed
	if ( exists($ver_InstalledModules{$uri_Lib}) ) {
		local $ver_InstalledModules{$uri_Lib}	= $ver_InstalledModules{$uri_Lib};
		local $ver_RegularLibs{$uri_Lib}	= $ver_RegularLibs{$uri_Lib};

		# Prepare version numbers for comparsion
		foreach my $ver_ToPrep ( $ver_InstalledModules{$uri_Lib}, $ver_RegularLibs{$uri_Lib} ) {
			if ( defined($ver_ToPrep)
			&& $ver_ToPrep ne '' ) {
				$ver_ToPrep		=~ s($rxp_VersionSyntax) (v);
				}
			}

		# Check version
		if ( ! defined($ver_RegularLibs{$uri_Lib})
		|| version->parse($ver_InstalledModules{$uri_Lib}) >= version->parse($ver_RegularLibs{$uri_Lib}) ) {
			$bol_RegularLibs{$uri_Lib}	= true;
			}
		else {
			$bol_RegularLibs{$uri_Lib}	= false;
			$cnt_Failures++;
			}
		}
	# Module is missing
	else {
		$bol_RegularLibs{$uri_Lib}	= false;
		$cnt_Failures++;
		}

	if ( $int_Length < length($uri_Lib . ( ( $ver_RegularLibs{$uri_Lib} ) ? qq{ $ver_RegularLibs{$uri_Lib}} : '' )) ) {
		$int_Length			= length($uri_Lib . ( ( $ver_RegularLibs{$uri_Lib} ) ? qq{ $ver_RegularLibs{$uri_Lib}} : '' ));
		}
	}

if ( $bol_RegularLibs{q{Term::ANSIColor}} ) {
	$bol_FullColorSupport			= true;
	}

$str_Printf		= qq{ %-${int_Length}s  %s%12s%s};

print join(qq{\n},
	sprintf($str_Printf, q{LIBRARY}, '', q{AVAILABILITY}, ''),
	( map {
		if ( $bol_FullColorSupport ) {
			sprintf($str_Printf, $_ . ( ( $ver_RegularLibs{$_} ) ? qq{ $ver_RegularLibs{$_}} : '' ), ( ( $bol_RegularLibs{$_} ) ? (color(q{green}), q{AVAILABLE}) : (color(q{red}), q{MISSING}) ), color(q{reset}));
			}
		else {
			sprintf($str_Printf, $_ . ( ( $ver_RegularLibs{$_} ) ? qq{ $ver_RegularLibs{$_}} : '' ), '', ( ( $bol_RegularLibs{$_} ) ? q{AVAILABLE} : q{MISSING} ), '');
			}
		} sort { $a cmp $b } keys(%bol_RegularLibs) )) . qq{\n};

exit($cnt_Failures);
