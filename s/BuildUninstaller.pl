#!/usr/bin/perl

=begin MetaInformation

	M E T A

	License:		Custom propretary, see LICENCE.md file
	Description:		Builds uninstaller after installation.
	Contact:		Dominik Bernhardt - domasprogrammer@gmail.com or https://github.com/DomAsProgrammer

=end MetaInformation

=begin VersionHistory

=end VersionHistory

=begin comment

	V A R I A B L E  N A M I N G

	str	string
	 L sql	sql code
	 L spf	sprintf() body.
	 L sha  Sha sum value
	 L cmd	command string
	 L ver	version number
	 L bin	binary data, also base64
	 L hex  hex coded data
	 L uri	path or url

	int	integer number
	 L cnt	counter
	 L pid	process id number
	 L tsp	seconds since period

	flt	floating point number

	bol	boolean

	mxd	unkown data (mixed)

	lop	loop header

	ref	reference
	 L rxp	regular expression
	 L are	array reference
	 L dsc	file discriptor (type glob)
	 L sub	anonymous subfunction	- DO NO LONGER USE, since Perl v5.26 functions can be declared lexically non-anonymous!
	 L har	hash array reference
	  L obj  object (very often)
	  L tbl  table (a hash array with PK as key OR a multidimensional array AND hash arrays as values)
	   L csh  a table from or for e.g. a database or REST API table, but cashed within Perl

	Using prefixes in caps means constants.

=end comment
=cut


##### L I B R A R I E S #####
### Default
use strict;
use warnings;
use feature qw( try unicode_strings current_sub fc );
use builtin qw( true false );
no feature qw( bareword_filehandles );
use open qw( :std :encoding(utf8) );
use utf8;
use Time::Piece;
use File::Basename;
use Encode qw( decode FB_QUIET );
## optionally
use Cwd qw(realpath);
#use File::Temp;
#use POSIX;
### MetaCPAN
#use Log::Log4perl qw(:easy);	# writes to manually configured log files

##### D E C L A R A T I O N #####

### Defaults
my ($strAppName, $uriAppPath)		= fileparse(realpath($0), qr/\.[^.]+$/);
my $verAppVersion			= q{0.1};
my $fltMinPerlVersion			= q{5.042000};		# $] but needs to be stringified!
my $strMinPerlVersion			= q{v5.42.0};		# $^V - nicer to read
my $pidParent				= $$;
my $objLock				= undef;

### System
#$|					= 1; # slurp mode
$ENV{LANG}				= q{C.UTF-8};
$ENV{LANGUAGE}				= q{C.UTF-8};
$ENV{LC_CTYPE}				= q{C.UTF-8};
$ENV{LC_ALL}				= undef;
$SIG{INT}				= sub {
	undef($objLock);
	print qq{\n};
	exit(120);
	};

### Logging
my $uriLogFile				= qq{/var/$strAppName.log};
my $intDefaultVerbose			= 2;		# WARN
my $intDefaultLogLevel			= 3;		# INFO

### Getopt::Long
my $intVerbose				= undef;
my $intLogLevel				= undef;

### Core
my $uriDistribution	= dirname($uriAppPath);
my $uriWorkDir		= qq{$uriDistribution/work};
my $uriBuildConfig	= qq{$uriDistribution/configuration.conf};
my $uriTemplate		= qq{$uriDistribution/templates/UninstallSafirbu.sh};
my $uriUninstaller	= qq{$uriWorkDir/UninstallSafirbu.sh};
my %strConfiguration			= (
	INSTALLDIR	=> undef,
	DEST		=> undef,
	);
my %harConfigs				= (
	safirbu		=> {
		sha		=> undef,
		uri		=> undef,
		},
	logrotate	=> {
		sha		=> undef,
		uri		=> undef,
		},
	tmpfiles	=> {
		sha		=> undef,
		uri		=> undef,
		},
	);
my $uriMainPath				= undef;
my @uriElements				= ();

### Searches
my $rxpOpt		= qr{\Q/opt/\E};
my $rxpMainPath		= qr{\Q%SINGLEPATH%\E};
my $rxpListFilesToDel	= qr{\Q%TODEL%\E};
my $rxpSafirbu		= qr{\Q%SAFIRBUURI%\E};
my $rxpOrigSafirbu	= qr{\Q%SAFIRBUSHA%\E};
my $rxpLogrotate	= qr{\Q%LOGROTATEURI%\E};
my $rxpOrigLogrotate	= qr{\Q%LOGROTATESHA%\E};
my $rxpTmpfiles		= qr{\Q%TMPFILESURI%\E};
my $rxpOrigTmpfiles	= qr{\Q%TMPFILESSHA%\E};
my $rxpWhitespaces	= qr{\s+};


##### F U N C T I O N S #####
sub GetHash {
	#TRACE(do { my $areArgs = \@_ ; sub { return(q{Start: } . Dumper({ areArgs => $areArgs })); } });
	my $uriFile	= shift;
	my $strHash	= '';

	if ( -e $uriFile ) {
		chomp($strHash	= qx(sha512sum "$uriFile"));	# Use system sha, like it will be used by the uninstaller.
		($strHash)	= split(m{$rxpWhitespaces}, $strHash);
		}

	return($strHash);
	}

sub SetupLoggers {
	TRACE(do { my $areArgs = \@_ ; sub { return(q{Start: } . Dumper({ areArgs => $areArgs })); } });
	my $intLogLevel	= shift;
	my $intVerbose				= shift;
	my @intLevels				= qw( FATAL ERROR WARN INFO DEBUG TRACE );
	my $strLogLevel				= ( $intLevels[$intLogLevel] // $intLevels[-1] ) ;
	my $strVerbosityLevel			= ( $intLevels[$intVerbose] // $intLevels[-1] ) ;
	my $strRootLogger			= ( ( $intLogLevel > $intVerbose ) ? $intLevels[$intLogLevel] : $intLevels[$intVerbose] ) // q{ALL};
	CORE::state $intCurrentVerbose		= undef;
	CORE::state $intCurrentLogLevel		= undef;
	#						DATE                PID  PRIO FILE:LINE MODULE
	my $strSimpleLogLayout			= q{%p> %m{indent,chomp}%n};
	my $strFullLogLayout			= qq{%d{yyyy-MM-dd}T%d{HH:mm:ss} %Q%P %F{1}::%L %M $strSimpleLogLayout};
	Log::Log4perl::Layout::PatternLayout::add_global_cspec(q{Q}, sub { return(( $$ == $pidParent ) ? q{P} : q{C}); });	# Decides between Child or Parent

	my %strConfiguration		= (
		q{log4perl.rootLogger}							=> qq{$strRootLogger,ScreenOUT,ScreenERR,Logfile},

		q{log4perl.filter.ScreenERR}						=> qq{Log::Log4perl::Filter::LevelRange},
		q{log4perl.filter.ScreenERR.LevelMin}					=> qq{WARN},
		q{log4perl.filter.ScreenERR.LevelMax}					=> qq{FATAL},
		q{log4perl.filter.ScreenERR.AcceptOnMatch}				=> true,

		q{log4perl.filter.ScreenOUT}						=> qq{Log::Log4perl::Filter::LevelRange},
		q{log4perl.filter.ScreenOUT.LevelMin}					=> qq{TRACE},
		q{log4perl.filter.ScreenOUT.LevelMax}					=> qq{INFO},
		q{log4perl.filter.ScreenOUT.AcceptOnMatch}				=> true,

		q{log4perl.appender.ScreenERR}						=> qq{Log::Log4perl::Appender::Screen},
		q{log4perl.appender.ScreenERR.stderr}					=> true,
		q{log4perl.appender.ScreenERR.utf8}					=> true,
		q{log4perl.appender.ScreenERR.Threshold}				=> $strVerbosityLevel,
		q{log4perl.appender.ScreenERR.Filter}					=> qq{ScreenERR},
		q{log4perl.appender.ScreenERR.layout}					=> qq{Log::Log4perl::Layout::PatternLayout},
		q{log4perl.appender.ScreenERR.layout.ConversionPattern}			=> ( $intVerbose >= 4 ) ? $strFullLogLayout : $strSimpleLogLayout,

		q{log4perl.appender.ScreenOUT}						=> qq{Log::Log4perl::Appender::Screen},
		q{log4perl.appender.ScreenOUT.stderr}					=> false,
		q{log4perl.appender.ScreenOUT.utf8}					=> true,
		q{log4perl.appender.ScreenOUT.Threshold}				=> $strVerbosityLevel,
		q{log4perl.appender.ScreenOUT.Filter}					=> qq{ScreenOUT},
		q{log4perl.appender.ScreenOUT.layout}					=> qq{Log::Log4perl::Layout::PatternLayout},
		q{log4perl.appender.ScreenOUT.layout.ConversionPattern}			=> ( $intVerbose >= 4 ) ? $strFullLogLayout : $strSimpleLogLayout,

		q{log4perl.appender.Logfile}						=> qq{Log::Log4perl::Appender::File},
		q{log4perl.appender.Logfile.filename}					=> $uriLogFile,
		q{log4perl.appender.Logfile.mode}					=> qq{append},
		q{log4perl.appender.Logfile.utf8}					=> true,
		q{log4perl.appender.Logfile.Threshold}					=> $strLogLevel,
		q{log4perl.appender.Logfile.recreate}					=> false,
		q{log4perl.appender.Logfile.layout}					=> qq{Log::Log4perl::Layout::PatternLayout},
		q{log4perl.appender.Logfile.layout.ConversionPattern}			=> $strFullLogLayout,
		);

	if ( ! Log::Log4perl->initialized()
	|| ! defined($intCurrentVerbose)
	|| ! defined($intCurrentLogLevel)
	|| $intCurrentVerbose != $intVerbose
	|| $intCurrentLogLevel != $intLogLevel ) {

		DEBUG(q{Reinitializing logger.});
		Log::Log4perl->init(\%strConfiguration);
		my $objLogger		= Log::Log4perl->get_logger();

		if ( $objLogger ) {
			TRACE(q{Logger initialized.});
			}
		else {
			LOGDIE(q{Can't initialize logger properly.});
			die q{Can't initialize logger properly.};
			return(false);
			}

		$intCurrentVerbose	= $intVerbose;
		$intCurrentLogLevel	= $intLogLevel;

		if ( $objLogger->is_debug()
		|| $objLogger->is_trace() ) {
			require Data::Dumper; 
			Data::Dumper->import();
			}
		}

	#TRACE()	# Stepwise checks
	#DEBUG();	# Data required for variable content checking
	#INFO();	# Output which is no error
	#WARN();	# For errors, which don't change the sequence
	#ERROR();	# For last(), redo(), and next()
	#FATAL();	# For exit(), and return()
	#LOGEXIT();
	#LOGWARN();
	#LOGDIE();

	return(true);
	}

sub IsDebug {
	if ( $intLogLevel >= 4 || $intVerbose >= 4 ) {
		return(true);
		}
	else {
		return(false);
		}
	}


##### M A I N #####

if ( @ARGV ) {
	@ARGV				= map { decode(q{utf8}, $_, FB_QUIET) } @ARGV;
	$harConfigs{safirbu}{uri}	= $ARGV[0];
	}
elsif ( ! -e $uriBuildConfig ) {
	print STDERR qq{\nMissing compile config file '$uriBuildConfig'!\n\n};
	exit(1);
	}
else {
	print STDERR qq{\nMissing Safirbu config file location!\n}
		. qq{Usage: $uriAppPath <...etc/safirbu/conf>\n\n};

	exit(2);
	}

chomp($strConfiguration{INSTALLDIR}	= qx(bash -c '. "$uriBuildConfig" ; echo \$INSTALLDIR'));
chomp($strConfiguration{DEST}		= qx(bash -c '. "$uriBuildConfig" ; echo \$DEST'));

if ( $strConfiguration{DEST} =~ m{$rxpOpt} ) {
	if ( fc($^O) eq fc(q{Linux}) ) {
		@uriElements			= (
			$strConfiguration{DEST},
			qq{$strConfiguration{DEST}/bin},
			qq{$strConfiguration{DEST}/sbin/safirbu},
			qw(/var/opt/lib/safirbu
			/var/opt/lib/safirbu/backup
			/var/opt/log/safirbu
			/var/opt/log/safirbu/jobs
			/etc/opt/safirbu/includes
			/etc/opt/safirbu/excludes
			/etc/opt/safirbu/jobs
			/var/lock/safirbu.d
			/usr/local/share/man/man5/safirbu-config.5.xz
			/usr/local/share/man/man8/safirbu.8.xz
			/etc/opt/safirbu/jobs/template.job.new
			));
		$harConfigs{tmpfiles}{uri}	= q{/etc/tmpfiles.d/safirbu.conf};
		}
	elsif ( fc($^O) eq fc(q{FreeBSD}) ) {
		@uriElements			= (
			$strConfiguration{DEST},
			qq{$strConfiguration{DEST}/bin},
			qq{$strConfiguration{DEST}/sbin/safirbu},
			qq{$strConfiguration{DEST}/var/lib/safirbu},
			qq{$strConfiguration{DEST}/var/lib/safirbu/backup},
			qq{$strConfiguration{DEST}/var/log/safirbu},
			qq{$strConfiguration{DEST}/var/log/safirbu/jobs},
			qq{$strConfiguration{DEST}/etc/safirbu},
			qq{$strConfiguration{DEST}/etc/safirbu/excludes},
			qq{$strConfiguration{DEST}/etc/safirbu/includes},
			qq{$strConfiguration{DEST}/etc/safirbu/jobs},
			qq{$strConfiguration{DEST}/var/lock/safirbu.d},
			qq{$strConfiguration{DEST}/etc/safirbu/jobs/job.template},
			q{/usr/local/share/man/man5/safirbu-config.5.xz},
			q{/usr/local/share/man/man8/safirbu.8.xz},
			);
		}
	}
elsif ( fc($strConfiguration{DEST}) eq fc(q{Linux}) ) {
	$uriMainPath			= $strConfiguration{INSTALLDIR} ? $strConfiguration{INSTALLDIR} : '';
	@uriElements			= (
		map { $strConfiguration{INSTALLDIR} . $_ } qw(
			/var/lib/safirbu/
			/var/lib/safirbu/backup
			/var/lib/safirbu/jobs
			/var/log/safirbu
			/var/log/safirbu/jobs
			/etc/safirbu/
			/etc/safirbu/excludes
			/etc/safirbu/includes
			/etc/safirbu/jobs
			/sbin/safirbu
			/usr/share/safirbu
			/var/lock/safirbu.d
			/usr/share/man/man5/safirbu-config.5.xz
			/usr/share/man/man8/safirbu.8.xz
			/usr/share/safirbu/template.job
			/usr/share/safirbu/Infrastructure.sql
			/etc/bash_completion.d/safirbu
			)
		);

	$harConfigs{logrotate}{uri}	= qq{$strConfiguration{INSTALLDIR}/etc/logrotate.d/safirbu},
	$harConfigs{tmpfiles}{uri}	= qq{$strConfiguration{INSTALLDIR}/etc/tmpfiles.d/safirbu.conf},
	}
elsif ( fc($strConfiguration{DEST}) eq fc(q{FreeBSD}) ) {
	$uriMainPath			= $strConfiguration{INSTALLDIR} ? $strConfiguration{INSTALLDIR} : '';
	@uriElements			= (
		map { $strConfiguration{INSTALLDIR} . $_ } qw(
			/var/lib/safirbu
			/var/lib/safirbu/backup
			/var/log/safirbu
			/var/log/safirbu/jobs
			/usr/local/etc
			/usr/local/etc/safirbu
			/usr/local/etc/safirbu/excludes
			/usr/local/etc/safirbu/includes
			/usr/local/etc/safirbu/jobs
			/usr/local/etc/logrotate.d
			/usr/local/share/safirbu
			/var/spool/lock/safirbu.d
			/usr/local/sbin/safirbu
			/usr/local/etc/bash_completion.d
			/usr/local/share/man/man5/safirbu-config.5.xz
			/usr/local/share/man/man8/safirbu.8.xz
			/usr/local/share/safirbu/template.job
			/usr/local/share/safirbu/Infrastructure.sql
			/usr/local/etc/bash_completion.d/safirbu
			)
		);
	$harConfigs{logrotate}{uri}	= qq{$strConfiguration{INSTALLDIR}/usr/local/etc/logrotate.d/safirbu};
	}
else {
	$uriMainPath			= $strConfiguration{DEST} ? $strConfiguration{DEST} : '';
	@uriElements			= (
		map { $strConfiguration{DEST} . $_ } qw(
			/var/lib/safirbu
			/var/lib/safirbu/backup
			/var/log/safirbu
			/var/log/safirbu/jobs
			/etc/safirbu
			/etc/safirbu/excludes
			/etc/safirbu/includes
			/etc/safirbu/jobs
			/sbin/safirbu
			/var/lock
			/var/lock/safirbu.d
			/usr/share/man/man5
			/usr/share/man/man8
			/usr/share/man/man5/safirbu-config.5.xz
			/usr/share/man/man8/safirbu.8.xz
			/etc/safirbu/jobs/template.job
			)
		);
	}

# Load hashes
foreach my $harConfig ( values(%harConfigs) ) {
	if ( defined($harConfig->{uri}) ) {
		$harConfig->{sha}	= GetHash($harConfig->{uri});
		}
	}

lopMakeRecursive: {
	my @uriDummy		= ();

	foreach my $uriElement ( @uriElements ) {
		my @strSingles	= split(q{/}, $uriElement);
		my $uriHelper	= '';

		foreach my $strSingle ( @strSingles ) {
			if ( $strSingle ) {	# Prevent /<root>
				$uriHelper .= qq{/$strSingle};

				push(@uriDummy, $uriHelper . '');
				}
			}

		
		}

	push(@uriElements, @uriDummy);
	}

lopMakeUnique: {
	my %cntSeen	= ();

	@uriElements	= sort { $a cmp $b }
		grep { ! $cntSeen{$_}++ }
		@uriElements;
	}

# Read DATA and write uninstaller.
if ( open(my $dscTemplate, q{<}, $uriTemplate)
&& open(my $dscUninstaller, q{>}, $uriUninstaller) ) {

	# Prepare searches
	my @harChanges		= (
		{ rxp	=> $rxpMainPath,	value	=> $uriMainPath // '', },
		{ rxp	=> $rxpListFilesToDel,	value	=> join(qq{\n}, @uriElements), },
		{ rxp	=> $rxpSafirbu,		value	=> $harConfigs{safirbu}{uri}, },
		{ rxp	=> $rxpOrigSafirbu,	value	=> $harConfigs{safirbu}{sha}, },
		{ rxp	=> $rxpLogrotate,	value	=> $harConfigs{logrotate}{uri} // '', },
		{ rxp	=> $rxpOrigLogrotate,	value	=> $harConfigs{logrotate}{sha} // '', },
		{ rxp	=> $rxpTmpfiles,	value	=> $harConfigs{tmpfiles}{uri} // '', },
		{ rxp	=> $rxpOrigTmpfiles,	value	=> $harConfigs{tmpfiles}{sha} // '', },
		);

	while ( my $strLine = readline($dscTemplate) ) {
		chomp($strLine);

		foreach my $harReplacement ( @harChanges ) {
			$strLine	=~ s{$harReplacement->{rxp}} {$harReplacement->{value}}g;
			}

		print $dscUninstaller qq{$strLine\n};
		}

	close($dscTemplate);
	close($dscUninstaller);
	}
else {
	die qq{Unable to read($uriTemplate) or write($uriUninstaller).\n};
	}

exit(0);

__DATA__
