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
	q{Term::ANSIColor}		=> q{5.01},
	q{utf8}				=> undef,
	q{Time::Piece}			=> q{1.3401},
	q{File::Basename}		=> undef,
	q{POSIX}			=> undef,
	q{Cwd}				=> undef,
	q{Data::Dumper}			=> undef,
	q{Getopt::Long}			=> undef,
	q{Net::OpenSSH}			=> q{0.82},
	q{File::Path}			=> undef,
	q{DBI}				=> q{1.643},
	q{DBD::SQLite}			=> q{1.66},
	q{Encode}			=> q{3.08},
	q{Time::Local}			=> undef,
	q{Log::Log4perl}		=> q{1.54},
	q{IPC::LockTicket}		=> q{2.13},
	q{String::CRC32}		=> undef,
	q{Text::CSV}			=> q{2.06},
	q{Text::CSV_XS}			=> q{1.60},
	q{Sys::Hostname}		=> undef,
	q{Net::Domain}			=> undef,
	q{Net::Ping}			=> undef,
	#q{Any::Faile}			=> undef,	# Dummy - must always fail.
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

if ( ! $bol_RegularLibs{q{IPC::LockTicket}} ) {
	print STDERR qq{\nThe libraries 'IPC::LockTicket' (and it's dependencies) can be downloaded\nat https://github.com/DomAsProgrammer/ol9-specs/tree/main/RPMS .\n\n};
	}

exit($cnt_Failures);
