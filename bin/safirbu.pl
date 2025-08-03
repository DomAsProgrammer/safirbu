#!/usr/bin/env perl

=begin meta_information

=encoding utf8

	M E T A

	License:		GPLv3 - see license file or http://www.gnu.org/licenses/gpl.html
	Program-version:	0.15, (February 16th 2025)
	Description:		
	Contact:		Dominik Bernhardt - domasprogrammer@gmail.com or https://github.com/DomAsProgrammer

=end meta_information

=begin license

	L I C E N C E

	Backup system basically using rsync and checking via find and du.
	Copyright © 2023 Dominik Bernhardt

	Read all details on LICENCE.md

=end license

=begin version_history

	v0.1
	Init

	v0.2
	Beta
	Using Perl v5.40.0 now.

	v0.3
	<Changes not documented.>

	v0.4
	Added location and distribution dependent configuration
	file pathes.

	v0.5
	Changed configuration file name from conf to config.

	v0.6
	Changed libs Try and boolean to Perl's native variants.

	v0.7-v0.9
	Several small changes

	v0.10
	Implemented deep copy.
	Added missed defaults.

	v0.14
	Testing before changes.

	v0.15
	Installation works.

	v0.16
	Installed version is runable.

	v0.17
	Many tests and improvements done, ready for the last
	tests.

	v0.18
	Improved makefile and scripts.

	v0.19beta
	Tests are done. Ready for productive tests.

	v0.20
	Manuals are finished. Current Perl: v5.40.2

	v0.21
	Simple improvements on download and build for FreeBSD.

	v0.22
	Fixed Perl version to 5.40 .
	Fixed handling of wc on FreeBSD.

	v0.23
	Better logrotate settings.
	Better build instructions for FreeBSD.
	Bugfix on different source pathes than / on missing subsequent slash at
	the end of the source.
	Bugfix: crontab's shell (sh) on FreeBSD delivers variable, breaking du's
	behavior (BLOCKSIZE=K)
	Maybe unfixed bug: list's behavior for multiple pathes?

=end version_history

=begin milestones

	v1
	Fully operational application and all given functions are
	successfully tested.

	v2
	Watch function: Show status of running processes

	v3
	NCurses based terminal UI, fully operational for all
	functions.

	v4
	Own time and prepartions handle daemon.

=end milestones

=begin comment

	not     shall be used instead of `or return` in if
                clauses to allow multiple executions before the
                actual `return()`.


	V A R I A B L E  N A M I N G

	str	string
	 L sql	sql code
	 L spf	sprintf() code
	 L cmd	command string
	 L ver	version number
	 L bin	binary data, also base64
	 L hex  hex coded data
	 L uri	path or url

	int	integer number
	 L cnt	counter
	 L oct  octal number
	 L pid	process id number
	 L tsp	seconds since period

	flt	floating point number

	bol	boolean

	mxd	unkown data (mixed)

	lop	identifier for loop headers

	ref	reference
	 L rxp	regular expression
	 L are	array reference
	 L dsc	file discriptor (type glob)
	 L sub	anonymous subfunction	- DO NO LONGER USE, since Perl v5.26 functions can be declared lexically non-anonymous!
	 L har	hash array reference
	  L tbl	table (a hash array with PK as key OR a multidimensional array AND hash arrays as values)
	  L obj	object (very often)

	Any naming written in CAPS is a constant

=end comment
=cut


##### L I B R A R I E S #####

### Default
use strict;
use warnings;
no feature qw( bareword_filehandles );
use feature qw( unicode_strings current_sub fc try state );
use builtin qw( true false );
use open qw( :std :encoding(utf8) ); # Should be done by magic line -CSDAL but is NOT working (for par) https://perldoc.perl.org/perlrun#-C-%5Bnumber/list%5D
use utf8;
use Time::Piece;
use File::Basename;
use POSIX qw( setsid floor ceil );

### optionally
#use Term::ANSIColor;
use Cwd qw( realpath );
use Getopt::Long qw( :config no_ignore_case bundling );
use Net::OpenSSH;
use File::Path qw( make_path remove_tree );
use DBI;	# DBD::SQLite
use Encode qw( decode FB_QUIET );
use Time::Local qw( timelocal_modern );
use Storable qw( dclone );
use Net::Domain qw( hostfqdn );
use Sys::Hostname;
use Net::Ping;

### MetaCPAN
use Log::Log4perl qw( :easy );	# writes to manually configured log files
use String::CRC32;
#use Sys::Syslog;	# writes to messages/journalctl
#use Curses::UI;

### Independent
use IPC::LockTicket;


##### D E C L A R A T I O N #####
### Time CONSTANTS
use constant {
	INT_OneWeek			=> 7 * 24 * 60 ** 2,
	INT_OneDay			=> 24 * 60 ** 2,
	INT_OneHour			=> 60 ** 2,
	INT_OneMinute			=> 60,
	INT_OneSecond			=> 1,
	};
use constant ARE_Generations		=> qw(year month week day hour);

### ASCII art
use constant {
	STR_BorderVertical		=> q{│},
	STR_BorderHorizontal		=> q{─},
	STR_BorderCross4		=> q{┼},
	STR_BorderCrossFT		=> q{┬},
	STR_BorderCrossFL		=> q{├},
	STR_BorderCrossFR		=> q{┤},
	STR_BorderCrossFB		=> q{┴},
	STR_BorderCornerTL		=> q{┌},
	STR_BorderCornerTR		=> q{┐},
	STR_BorderCornerBL		=> q{└},
	STR_BorderCornerBR		=> q{┘},
	};

### Defaults
my ($str_AppName, $uri_AppPath)		= fileparse(realpath($0), qr{\.[^.]+$});	# Should now be something like uri_AppPath:=/usr/sbin/
(undef, $uri_AppPath)			= fileparse($uri_AppPath =~ s{/+$} {}r, qr{\.[^.]+$});	# Now it should be uri_AppPath:=/usr/
$uri_AppPath				=~ s{/+$} {}; # e.g. uri_AppPath:=/usr
my $ver_AppVersion			= q{v0.23};
our $VERSION				= $ver_AppVersion;
my $flt_MinPerlVersion			= q{5.040002};		# $] but needs to be stringified!
my $ver_MinPerlVersion			= q{v5.40.2};		# $^V - nicer to read
my $pid_Parent				= $$;
my $obj_StartTime			= localtime();
my $str_Hostname			= hostname;
my $str_FQDN				= hostfqdn;
if ( ! $str_FQDN ) {
	chomp($str_FQDN			= qx(hostname -f));
	}

### System
lop_ARGV: {
	@ARGV				= map { decode(q{utf8}, $_, FB_QUIET) } @ARGV;
	my @mxd_OriginalArgv		= ( @ARGV );

	sub RestoreARGV {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });

		@ARGV			= @mxd_OriginalArgv;

		DEBUG(sub { return(q{Restored ARGV to } . Dumper(\@ARGV)); });

		return(@ARGV);
		}
	}
$ENV{LANG}				= q{C.UTF-8};
$ENV{LANGUAGE}				= q{C.UTF-8};
$ENV{LC_ALL}				= undef;
$SIG{HUP}				= sub {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	print qq{\n};
	exit(120);
	};
$SIG{INT}				= sub {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	print qq{\n};
	exit(121);
	};

END {
	TRACE(q{Executing END block.});

	if ( GlobalsInitialized() ) {
		LOGWARN(q{Cleaning up...});
		GlobalPostRun();
		}
	}

## RegEx
my $rxp_Integer				= qr{^[+-]?[0-9]+$};
my $rxp_PositiveInteger			= qr{^\+?[0-9]+$};
my $rxp_Section				= qr{^\s*\[(.+)\]\s*$};
my $rxp_Comment				= qr{^\s*[;#]};
my $rxp_Pair				= qr{^\s*"?([^=]+?)"?\s*=\s*"?([^=]*?)"?\s*$}i;
my $rxp_Separator			= qr{"?\s*,\s*"?};
my $rxp_UnwantedCharsDirNames		= qr{[^a-z0-9]}i;
my $rxp_Suffixes			= qr{^\.(job|cfg|conf(ig(uration)?)?)$}in;
my $rxp_NewLine				= qr{[\r\n]+$}n;	# To remove newline/currage return at line end
my $rxp_Floating			= qr{^(-?[0-9]+)(?:\.([0-9]+))?$};
my $rxp_ExtractClockFree		= qr{([01]?[0-9]|2[0-3])[:.]?([0-5]?[0-9])h?}i; # $1 = hours, $2 = minute
my $rxp_Minute				= qr{^([0-5]?[0-9])m?$}i;
my $rxp_ExtractClock			= qr{^$rxp_ExtractClockFree$}i; # $1 = hours, $2 = minute
my $rxp_BinKey				= qr{^bin};
my $rxp_RunKey				= qr{^((?:client|server)(?:pre|post)(?:run|fail))$}i;
my $rxp_Colon				= qr{^:};
my $rxp_LeadingSlash			= qr{^/};
my $rxp_Slashes				= qr{/+};
my $rxp_AtLeastTwoSlashes		= qr{//+};
my $rxp_OnlySlashes			= qr{^/+$};
my $rxp_EndingSlashes			= qr{/*$};
my $rxp_RemoveLeadingChars		= qr{^(?:/|:)+};
my $rxp_ValidHostName			= qr{^[a-z0-9][a-z0-9_-]{0,61}[a-z0-9](\.[a-z0-9][a-z0-9_-]{0,61}[a-z0-9]){0,3}$}ni;
my $rxp_IPv4				= qr{^([0-9]{1,3})(?:\.([0-9]{1,3})){3}$};
my $rxp_IPv6				= qr{^([0-9a-f]{0,4})(:([0-9a-f]{0,4})){7}$}ni;
#my $rxp_ValidBFH			= qr{^(stop|continue|rollback|fail|retry)$}i; # Backup Failure Handle
my $rxp_Combinations			= qr{^(retry|continue)(?:\s*|[_-|/>])(retry|continue)$}i; # Backup Failure Handle
my $rxp_ValidBFH			= qr{^(stop|fail|(?:retry|continue)(?:(?:\s*|[_-|/>])(?:retry|continue))?|retry)$}i; # Backup Failure Handle
my $rxp_Suffix				= qr{\.[^.]+$};
my $rxp_Clock				= qr{(?:([01]?[0-9]|2[0-3])[:.]([0-5]?[0-9])h?|([01][0-9]|2[0-3])([0-5][0-9])h)}i; # Accepts 5:00, 05:00, 5:00h, 05.00h, 0500h, and more; declaring all the same time.
my $rxp_DayAndHourFree			= qr{(0?[1-9]|[1-2][0-9]|3[01])-?$rxp_ExtractClockFree}i; # $1 = day, $2 = hour, $3 = minute
my $rxp_DayAndHour			= qr{^$rxp_DayAndHourFree$}i; # $1 = day, $2 = hour, $3 = minute
my $rxp_DateAndHour			= qr{^(1[0-2]|0?[1-9])-?$rxp_DayAndHourFree$}; # $1 = month, $2 = day, $3 = hour, $4 = minute
my $rxp_Week				= qr{^([0-7])-$rxp_Clock$}; # 0=7=Sunday $1 = dow, $2 = hour, $1 = minute
my $rxp_DebugOption			= qr{^-{1,2}d(?:ebugg?(?:er|ing))$}i;
my $rxp_Directory			= qr{^[^\s]+_([0-9]{4})-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[0-1])T([01][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])[+-±]([0-5][0-9]):([0-5][0-9])};	# job_2024-03-19T18:00:00±00:00Y
my $rxp_DirectoryYear			= qr{${rxp_Directory}Y}n;
my $rxp_DirectoryMonth			= qr{${rxp_Directory}M}n;
my $rxp_DirectoryDay			= qr{${rxp_Directory}D}n;
my $rxp_DirectoryWeek			= qr{${rxp_Directory}W}n;
my $rxp_DirectoryHour			= qr{${rxp_Directory}H}n;
my $rxp_Localhost			= qr{^(?:\Qlocalhost\E|\Q127.0.0.1\E|\Q$str_Hostname\E|\Q$str_FQDN\E)$}i;
my $rxp_ClientRun			= qr{^client(pre|post)run$}n;
my $rxp_ClientKey			= qr{^client}i;
my $rxp_Quote				= qr{'};
my $rxp_BeginTwoQuotes			= qr{^''};
my $rxp_EndTwoQuotes			= qr{''$};
my $rxp_DoubleQuote			= qr{"};
my $rxp_PercentSign			= qr{\Q%\E};
my $rxp_StartOrEnd			= qr{^|$};
my $rxp_WHEREClauseReplace		= qr{\Q--<WHERE>--\E};
my $rxp_UIyes				= qr{^y(?:es?)?$}i;
my $rxp_SizingNumber			= qr{^\s*([0-9]+)(?:\s+.+)?$};
my $rxp_ValidUnits			= qr{^(?:b|[KkMmGgTtPpEeZzYy])$};
my $rxp_AllTemplates			= qr{\Q%\E[A-Z0-9]+\Q%\E};
my $rxp_EmptyLine			= qr{^\s*$};
my $rxp_UnwantedCharsQuoting		= qr{[^\w!%+,\-./:@^]};		# if it matches, there are unwanted characters
my $rxp_Backslash			= qr{\\};
my $rxp_SQLlikeCharacters		= qr{([%_])};
my $rxp_BoolValues			= qr{^([01]|TRUE)?$}in;
my $rxp_TagJob				= qr{\Q%JOB%\E};
my $rxp_TagPath				= qr{\Q%PATH%\E};
my $rxp_TagDestination			= qr{\Q%DESTINATION%\E};
my $rxp_TagLast				= qr{\Q%LAST%\E};
my $rxp_SizeKey				= qr{^int_(Delta)?Size$}i;

## Defaults
# System's applications
# Binaries (Config file only)
my $int_DefaultVerbose			= 2;		# WARN
my $int_DefaultLogLevel			= 3;		# INFO
my %int_MonthLastDays			= (
	1	=> 31,		# January
	2	=> do {
		my $obj_February	= localtime(timelocal_modern(0, 0, 0, 15, 1, $obj_StartTime->year));
		$obj_February->month_last_day + 0;
		},
	3	=> 31,
	4	=> 30,
	5	=> 31,
	6	=> 30,
	7	=> 31,
	8	=> 31,
	9	=> 30,
	10	=> 31,
	11	=> 30,
	12	=> 31,
	);
my %mxd_DefaultSSHoptions		= (
	batch_mode	=> 1,
	);

# Output
my $bol_Help				= false;
my $bol_ManPage				= false;
my $bol_Version				= false;
my $int_Verbose				= undef;
my $int_LogLevel			= undef;
my $bol_DryRun				= false;

# Behaviour
my $bol_Parallel			= false;
my $bol_Wait				= false;
my $bol_Fast				= false;

# Overrides
# Must be NULL, to determine if set or not set: NULL:=not set on command line, 1=TRUE, 0=FALSE
my $bol_NiceClient			= undef;
my $bol_NiceServer			= undef;
my $bol_ProtectHardLinks		= undef;
my $bol_PingCheck			= undef;

# Sizing and listing
my $bol_AskAgain			= false;
my $str_Unit				= undef;
my $bol_RemoveListEntry			= true;
my $bol_SelectList			= false;
my $bol_BatchMode			= false;

# Create job file options
my $str_Host				= undef;
my $str_BackupFailureHandling		= undef; # Backup failure handling
my $str_IPv46				= undef;
my $uri_RsyncSourceLocation		= undef;
my $uri_BinRsync			= undef;
my $uri_BinNice				= undef;
my $uri_BinIONice			= undef;
my $uri_BinDu				= undef;
my $uri_BinFind				= undef;
my $uri_BinWc				= undef;
my $int_Year				= undef;
my $int_Month				= undef;
my $int_Week				= undef;
my $int_Day				= undef;
my $int_Hour				= undef;
my $flt_Space				= undef;
my $str_Time				= undef;
my $cmd_ClientPreRun			= undef;
my $cmd_ClientPreFail			= undef;
my $cmd_ClientPostRun			= undef;
my $cmd_ClientPostFail			= undef;
my $cmd_ServerPreRun			= undef;
my $cmd_ServerPreFail			= undef;
my $cmd_ServerPostRun			= undef;
my $cmd_ServerPostFail			= undef;
my $cmd_GlobalPreRun			= undef;	# Main config only
my $cmd_GlobalPreFail			= undef;	# Main config only
my $cmd_GlobalPostRun			= undef;	# Main config only
my $cmd_GlobalPostFail			= undef;	# Main config only

# Misc
use constant STR_DummyLocation		=> q{<:NONE:>};
use constant STR_DATA			=> q{
__filestart:Usage:tratselif__
Usage: %APP_NAME% <sub-command> [--options] <file1|job1>[ <job2|file2>[ <jobN|fileN>]]
__fileend:Usage:dneelif__

__filestart:job_template:tratselif__
## (Lines starting with an # are treated as comments.)

# Source path, path or colon-prefixxed rsync module
Source				= %SOURCE%
# Should be FQDN, but can be used to have different job name and
# host name (no host name and no IP address ⇒ uses job name as
# host name)
Host Name			= %HOSTNAME%
IP v46				= %IPV46%
Ping Check			= %PINGCHECK%
Protect Hardlinks		= %PROTECTHARDLINKS%
Nice Client			= %NICECLIENT%

Destination			= %DESTINATION%
Space				= %SPACE%
Bin Rsync			= %BINRSYNC%

# Includes and excludes
# /etc/safirbu/jobs/{include,exclude}s/<job name> will be
# searched and used if found. The following settings
# is to add files for this setting which are not following the
# standard naming. Includes will appear first for rsync.
Include From			= %INCLUDEFROM%
Exclude From			= %EXCLUDEFROM%

# Appending
Server Pre Run			= %SERVERPRERUN%
Server Pre Fail		= %SERVERPREFAIL%
Client Pre Run			= %PRERUN%
Client Pre Fail		= %PREFAIL%
Backup Failure Handling	= %BACKUPFAILURE%
Client Post Run		= %POSTRUN%
Client Post Fail		= %POSTFAIL%
Server Post Run		= %SERVERPOSTRUN%
Server Post Fail		= %SERVERPOSTFAIL%

[Year]
# In general: Time Border setting is from given point + 24 hours.
# The first backup within this time window will be type "yearly".
# while this is valid. When shall the year backup run?
# (mm-DD-HHMMh, e.g. 09-03-1700h means the 24h start at March
# 9th at 5 PM and end at March 10th 4:59:59 PM)
Time Border			= %TIMEBORDERYEAR%
Quantity			= %QUANTITYYEAR%
Source				= %SOURCEYEAR%
Include From			= %INCLUDEFROMYEAR%
Exclude From			= %EXCLUDEFROMYEAR%
Server Pre Run			= %SERVERPRERUNYEAR%
Server Pre Fail		= %SERVERPREFAILYEAR%
Client Pre Run			= %PRERUNYEAR%
Client Pre Fail		= %PREFAILYEAR%
Backup Failure Handling	= %BACKUPFAILUREYEAR%
Client Post Run		= %POSTRUNYEAR%
Client Post Fail		= %POSTFAILYEAR%
Server Post Run		= %SERVERPOSTRUNYEAR%
Server Post Fail		= %SERVERPOSTFAILYEAR%

[Month]
# When shall the month backup run? (DD-HHMMh, e.g.
# 02-1500h means every month at 2nd at 3 PM, if the given day is
# later than the month has days, it will use the last day of
# month.)
Time Border			= %TIMEBORDERMONTH%
Quantity			= %QUANTITYMONTH%
Source				= %SOURCEMONTH%
Include From			= %INCLUDEFROMMONTH%
Exclude From			= %EXCLUDEFROMMONTH%
Server Pre Run			= %SERVERPRERUNMONTH%
Server Pre Fail		= %SERVERPREFAILMONTH%
Client Pre Run			= %PRERUNMONTH%
Client Pre Fail		= %PREFAILMONTH%
Backup Failure Handling	= %BACKUPFAILUREMONTH%
Client Post Run		= %POSTRUNMONTH%
Client Post Fail		= %POSTFAILMONTH%
Server Post Run		= %SERVERPOSTRUNMONTH%
Server Post Fail		= %SERVERPOSTFAILMONTH%

[Week]
# When shall the week backup run? (N Number between 0-7
# where 0=7=Sun)
# N-HHMM e.g. 5-1800 means every Frieday 6 PM
Time Border			= %TIMEBORDERWEEK%
Quantity			= %QUANTITYWEEK%
Source				= %SOURCEWEEK%
Include From			= %INCLUDEFROMWEEK%
Exclude From			= %EXCLUDEFROMWEEK%
Server Pre Run			= %SERVERPRERUNWEEK%
Server Pre Fail		= %SERVERPREFAILWEEK%
Client Pre Run			= %PRERUNWEEK%
Client Pre Fail		= %PREFAILWEEK%
Backup Failure Handling	= %BACKUPFAILUREWEEK%
Client Post Run		= %POSTRUNWEEK%
Client Post Fail		= %POSTFAILWEEK%
Server Post Run		= %SERVERPOSTRUNWEEK%
Server Post Fail		= %SERVERPOSTFAILWEEK%

[Day]
# When shall the day backup run? (HHMMh or HH:MM, e.g.
# 0000h or 00:00)
Time Border			= %TIMEBORDERDAY%
Quantity			= %QUANTITYDAY%
Source				= %SOURCEDAY%
Include From			= %INCLUDEFROMDAY%
Exclude From			= %EXCLUDEFROMDAY%
Server Pre Run			= %SERVERPRERUNDAY%
Server Pre Fail		= %SERVERPREFAILDAY%
Client Pre Run			= %PRERUNDAY%
Client Pre Fail		= %PREFAILDAY%
Backup Failure Handling	= %BACKUPFAILUREDAY%
Client Post Run		= %POSTRUNDAY%
Client Post Fail		= %POSTFAILDAY%
Server Post Run		= %SERVERPOSTRUNDAY%
Server Post Fail		= %SERVERPOSTFAILDAY%

[Hour]
# When shall the hour backup run? (MMm, e.g. 00m)
Quantity			= %QUANTITYHOUR%
Source				= %SOURCEHOUR%
Include From			= %INCLUDEFROMHOUR%
Exclude From			= %EXCLUDEFROMHOUR%
Server Pre Run			= %SERVERPRERUNHOUR%
Server Pre Fail		= %SERVERPREFAILHOUR%
Client Pre Run			= %PRERUNHOUR%
Client Pre Fail		= %PREFAILHOUR%
Backup Failure Handling	= %BACKUPFAILUREHOUR%
Client Post Run		= %POSTRUNHOUR%
Client Post Fail		= %POSTFAILHOUR%
Server Post Run		= %SERVERPOSTRUNHOUR%
Server Post Fail		= %SERVERPOSTFAILHOUR%

__fileend:job_template:dneelif__

__filestart:database_infrastructure:tratselif__
-- enforce foreign keys
PRAGMA foreign_keys = ON;

-- AUTOINCREMENT
-- ...is not required. INT PKs use the ROWID if
-- availabe. The only difference is: AUTOINCREMENT sees any tried
-- id as used some time ago and prevents reuse for more database
-- integrety.

-- from job names
CREATE TABLE jobs (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  UNIQUE (name)
  );

CREATE TABLE backup_status (
  job_id INTEGER NOT NULL,
  inode INTEGER NOT NULL,
  mtime INTEGER NOT NULL,
  dirname VARCHAR(200) NOT NULL,
  "path" TEXT NOT NULL,
  successful BOOLEAN NOT NULL,
  PRIMARY KEY (job_id, inode),
  UNIQUE (job_id, dirname),
  FOREIGN KEY (job_id) REFERENCES jobs(id) ON UPDATE CASCADE ON DELETE CASCADE
  ) WITHOUT ROWID;

CREATE TABLE source_groups (
  id INTEGER PRIMARY KEY,
  name VARCHAR NOT NULL, -- hex
  UNIQUE (name)
  );

CREATE INDEX idx_source_group
  ON source_groups (name);

CREATE TABLE source_pathes (
  id INTEGER PRIMARY KEY,
  "path" TEXT NOT NULL,
  UNIQUE ("path")
  );

CREATE INDEX idx_source_path
  ON source_pathes ("path");

-- Dummy for full directory listing
INSERT INTO source_pathes ("path")
  VALUES ('<:NONE:>'); -- STR_DummyLocation - must not be changed!!

CREATE TABLE source_allocs (
  sgroup_id INTEGER NOT NULL,
  path_id INTEGER NOT NULL,
  job_id INTEGER NOT NULL,
  PRIMARY KEY (sgroup_id,path_id,job_id),
  FOREIGN KEY (sgroup_id) REFERENCES source_groups (id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (path_id) REFERENCES source_pathes (id) ON UPDATE CASCADE ON DELETE CASCADE
  FOREIGN KEY (job_id) REFERENCES jobs (id) ON UPDATE CASCADE ON DELETE CASCADE
  ) WITHOUT ROWID;

-- this are the size run times
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY,
  time INTEGER NOT NULL,
  job_id INTEGER NOT NULL,
  UNIQUE (time,job_id),
  FOREIGN KEY (job_id) REFERENCES jobs (id) ON UPDATE CASCADE ON DELETE CASCADE
  );

-- increase speed on time
CREATE INDEX idx_task_time
  ON tasks (time);

CREATE TABLE notations (
  id INTEGER PRIMARY KEY,
  notation TEXT NOT NULL,
  UNIQUE (notation)
  );

CREATE INDEX idx_notations
  ON notations (notation);

-- actual data
CREATE TABLE backups (
  id INTEGER PRIMARY KEY,
  inode INTEGER NOT NULL,
  mtime INTEGER NOT NULL,
  nid TEXT NOT NULL,
  spath_id INTEGER NOT NULL,
  elements INTEGER NOT NULL,
  size INTEGER NOT NULL,
  UNIQUE (inode,mtime,spath_id),
  UNIQUE (nid,spath_id),
  FOREIGN KEY (spath_id) REFERENCES source_pathes (id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (nid) REFERENCES notations (id) ON UPDATE CASCADE ON DELETE CASCADE
  );

CREATE INDEX idx_backup_mtime_inode
  ON backups (inode,mtime);
CREATE INDEX idx_backup_notation
  ON backups (nid);

-- allocation table for m to n between tasks, backup, and notation (three dimensions)
CREATE TABLE mixed_alloc_delta (
  task_id INTEGER NOT NULL,
  backup_id INTEGER NOT NULL,
  delta_id INTEGER,
  delta_size INTEGER,
  PRIMARY KEY (task_id,backup_id),
  --UNIQUE (task_id,delta_id), -- Is no longer valid, since spath_id is part of backups table
  FOREIGN KEY (task_id) REFERENCES tasks (id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (backup_id) REFERENCES backups (id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (delta_id) REFERENCES backups (id) ON UPDATE CASCADE ON DELETE CASCADE
  ) WITHOUT ROWID;

-- increase speed on unique constraint
CREATE UNIQUE INDEX idx_allocation_unique
  ON mixed_alloc_delta (task_id,backup_id,delta_id);

-- increase speed on gathering all sizing tasks from a job
CREATE INDEX idx_task_id_index
  ON mixed_alloc_delta (task_id);

-- Join tables
CREATE VIEW complete AS
  SELECT
      jobs.id                             AS job_id,
      jobs.name                           AS job_name,
      tasks.id                            AS task_id,
      tasks.time                          AS task_time,
      backups.id                          AS backup_id,
      notations.notation                  AS notation,
      backups.inode                       AS backup_inode,
      backups.mtime                       AS backup_mtime,
      SUM(backups.size)                   AS backup_size,
      SUM(backups.elements)               AS backup_elements,
      CASE COUNT(*) WHEN COUNT(mixed_alloc_delta.delta_id) THEN mixed_alloc_delta.delta_id ELSE NULL           END AS delta_id,
      CASE COUNT(*) WHEN COUNT(mixed_alloc_delta.delta_size) THEN SUM(mixed_alloc_delta.delta_size) ELSE NULL  END AS delta_size,
      CASE COUNT(*) WHEN COUNT(deltas.inode) THEN deltas.inode ELSE NULL                                       END AS delta_inode,
      CASE COUNT(*) WHEN COUNT(deltas.mtime) THEN deltas.mtime ELSE NULL                                       END AS delta_mtime,
      source_groups.id                    AS sgroup_id,
      source_groups.name                  AS sgroup_name
    FROM jobs
    INNER JOIN tasks
      ON tasks.job_id = jobs.id
    INNER JOIN mixed_alloc_delta
      ON mixed_alloc_delta.task_id = tasks.id
    INNER JOIN backups
      ON mixed_alloc_delta.backup_id = backups.id
    INNER JOIN notations
      ON backups.nid = notations.id
    INNER JOIN (
      -- Unique pathes, especially for parents per group
      SELECT
        sp1.pid, sp1.gid, sp1.jid
      FROM (
        SELECT g.id gid, p."path", p.id pid, a.job_id jid
          FROM source_groups g
          INNER JOIN source_allocs a
            ON g.id = a.sgroup_id
          INNER JOIN source_pathes p
            ON a.path_id = p.id
        ) sp1
      LEFT JOIN (
        SELECT g.id gid, p."path", p.id pid, a.job_id jid
          FROM source_groups g
          INNER JOIN source_allocs a
            ON g.id = a.sgroup_id
          INNER JOIN source_pathes p
            ON a.path_id = p.id
        ) sp2
        ON sp1.gid = sp2.gid
        AND sp1.jid = sp2.jid
        AND ( sp1."path" LIKE sp2."path" || '%' OR sp2."path" LIKE sp1."path" || '%' )
        AND sp2."path" NOT LIKE sp1."path" || '%'
      WHERE sp2.pid IS NULL
      ) spathes
      ON backups.spath_id = spathes.pid
      AND jobs.id = spathes.jid
    INNER JOIN source_groups
      ON spathes.gid = source_groups.id
    INNER JOIN source_pathes sp
      ON spathes.pid = sp.id
    INNER JOIN ( -- Count how much pathes belong to each group
      SELECT g.id gid, COUNT(*) pathes
        FROM source_groups g
        INNER JOIN source_allocs a
          ON g.id = a.sgroup_id
        INNER JOIN source_pathes p
          ON a.path_id = p.id
        GROUP BY g.name, g.id
      ) gc -- Group Count
      ON source_groups.id = gc.gid 
    LEFT JOIN backups AS deltas
      ON mixed_alloc_delta.delta_id = deltas.id
  GROUP BY jobs.id, tasks.id, source_groups.id, notations.notation
    --HAVING COUNT(sp.id) = gc.pathes -- Omit grouped lines, which make no sense for the source path groups -- 20250713: not working, but preventing output for single sgroup elements
  ORDER BY jobs.name, tasks.time, source_groups.name, backups.mtime DESC;

__fileend:database_infrastructure:dneelif__
};
my %str_Data				= (	# __DATA__ block
	# <STR file name>		=> <STR content>,
	);

# rsync
my $int_PingTimeout			= 5;
my $str_RsyncRemoteShellOption		= q{-e 'ssh -o BatchMode=yes'};
my @int_RetryErrors			= (
	3,	# Selection error
	5,	# Protocol start error
	12,	# Protocol stream error
	22,	# Memory error
	23,	# Partial transfer error
	24,	# Vanished files
	30,	# Timeout - no data written
	35,	# Timeout - no connection
	);
my @str_RsyncDefaultOptions		= qw(
	-v
	-r
	-l
	-t
	-o
	-p
	-g
	-p
	-H
	-A
	-E
	-S
	-X
	-U
	-z
	--timeout=120
	--no-inc-recursive
	--numeric-ids
	);
	# --cc=sha1 is not available on RHEL, but on FreeBSD
	# --cc=md5 better let rsync decide on auto mode
	# --contimeout=120 only usalbe for rsync modules
my @uri_RsyncDefaultExcludes		= (
	# For UNIX
	qw(
		.gvfs
		*.cache/*
		*.thumbnails*
		*[Tt]rash/*
		*.backup*
		*.bak
		*.pipe
		*~
		proc/*
		sys/*
		dev/*
		run/*
		etc/mtab
		var/cache/apt/archives/*.deb
		var/cache/pacman/pkg/*
		var/lib/pacman/local/*
		*lost+found/*
		tmp/*
		mnt/*
		var/lock/*
		var/run/*
		var/tmp/*
		var/backup?/*
		*[Cc]ache/*
		),
	q{*[Cc]ode [Cc]ache/*},

	# For Windows:		(We do NOT backup the OS itself, because proper restore is impossible from UNIX systems)
	q{Program Files (x86)/Microsoft/*},
	qw(
		Windows/
		$Recycle.Bin/
		Temp/*
		*hiberfil.sys
		*pagefile.sys
		),
	);

# Configuration
my $uri_BasePath			= undef;
my $uri_MainConfig			= undef;
my $uri_JobsDir				= undef;
my $uri_ExcludesDir			= undef;
my $uri_IncludesDir			= undef;
my $uri_LockDir				= undef;
my $uri_Library				= qq{/var/lib/$str_AppName};
my $uri_LogDir				= qq{/var/log/$str_AppName};
my $uri_LogFile				= qq{$uri_LogDir/log};
my $uri_LogJobDir			= qq{$uri_LogDir/jobs};
lop_LocationSetup: {
	if ( $uri_AppPath eq q{/usr}
	&& fc($^O) eq fc(q{Linux}) ) {
		$uri_BasePath		= qq{/etc/$str_AppName};
		$uri_MainConfig		= qq{$uri_BasePath/config};
		$uri_JobsDir		= qq{$uri_BasePath/jobs};
		$uri_ExcludesDir	= qq{$uri_BasePath/excludes};
		$uri_IncludesDir	= qq{$uri_BasePath/includes};
		$uri_LockDir		= qq{/var/lock/$str_AppName.d};
		}
	elsif ( $uri_AppPath eq q{/usr/local}
	&& fc($^O) eq fc(q{FreeBSD}) ) {
		$uri_BasePath		= qq{/usr/local/etc/$str_AppName};
		$uri_MainConfig		= qq{$uri_BasePath/config};
		$uri_JobsDir		= qq{$uri_BasePath/jobs};
		$uri_ExcludesDir	= qq{$uri_BasePath/excludes};
		$uri_IncludesDir	= qq{$uri_BasePath/includes};
		$uri_LockDir		= qq{/var/spool/lock/$str_AppName.d};
		}
	elsif ( $uri_AppPath =~ m{^/opt/+[^/]+}
	&& fc($^O) eq fc(q{Linux}) ) {
		# FreeBSD doesn't know /opt - and shall use this like individual setup
		$uri_BasePath		= qq{/etc/opt/$str_AppName};
		$uri_MainConfig		= qq{$uri_BasePath/config};
		$uri_JobsDir		= qq{$uri_BasePath/jobs};
		$uri_ExcludesDir	= qq{$uri_BasePath/excludes};
		$uri_IncludesDir	= qq{$uri_BasePath/includes};
		$uri_LockDir		= qq{/var/lock/$str_AppName.d};
		$uri_Library		= qq{/var/opt/lib/$str_AppName};
		$uri_LogDir		= qq{/var/opt/log/$str_AppName};
		$uri_LogFile		= qq{$uri_LogDir/log};
		$uri_LogJobDir		= qq{$uri_LogDir/jobs};
		}
	else {
		$uri_BasePath		= qq{$uri_AppPath/etc/$str_AppName};
		$uri_MainConfig		= qq{$uri_BasePath/config};
		$uri_JobsDir		= qq{$uri_BasePath/jobs};
		$uri_ExcludesDir	= qq{$uri_BasePath/excludes};
		$uri_IncludesDir	= qq{$uri_BasePath/includes};
		$uri_LockDir		= qq{$uri_AppPath/var/lock/$str_AppName.d};
		$uri_Library		= qq{$uri_AppPath/var/lib/$str_AppName};
		$uri_LogDir		= qq{$uri_AppPath/var/log/$str_AppName};
		$uri_LogFile		= qq{$uri_LogDir/log};
		$uri_LogJobDir		= qq{$uri_LogDir/jobs};
		}

	if ( fc($^O) eq fc(q{FreeBSD}) ) {
		$ENV{BLOCKSIZE}		= 512;	# Overwrites command line parameter -B, but is set to K from BSD...
		}
	}
my $uri_Destination			= undef;
my $str_DirSyntax			= q{%1$s/%2$s/%2$s_%3$s%4$+03d:%5$02d};
my %har_JobsConfigs			= (	# Filled by ReadConfigurationFile()
	#<STR job name / file path>	=> {
		#uri_File		=> <URI full path to file>,
		#har_Content		=> {
		#	_		= {
		#		fc(q{key})	=> [ value1, value2, valueN ],
		#		fc(q{key})	=> [ value1, value2, valueN ],
		#		},
		#	fc(q{section})	= {
		#		fc(q{key})	=> [ value1, value2, valueN ],
		#		fc(q{key})	=> [ value1, value2, valueN ],
		#		},
		#	},
		#har_Config		=> {	# from har_NeededConfigKeys
		#	<section _> => {
		#		<key> => [ <values> ],
		#		},
		#	<section year/month/week/day/hour> => {
		#		<key> => [ <values> ],
		#		},
		#	<section> => {
		#		<key> => [ <values> ],
		#		},
		#	},
		#_str_JobName		=> <STR name got from configuration file>,
		#_rxp_JobFileSearch	=> <RXP Case insensetive search for _str_JobName>,
		#_uri_BackupLocation	=> <URI dest/jobname>,
		#_uri_DatabaseLocation	=> <URI dest/$str_DefaultDataBaseName>
		#_uri_LastSuccessful	=> <URI dest/jobname/backupname from successful according to database log>,
		#_are_LastSuccessful	=> <ARE (elements: HAR) of elements considered for _uri_LastSuccessful, youngest successful first, followed by youngest unsuccessful, followed by youngest stateless>
		#_str_NextGeneration	=> <STR (hour|day|week|month|year)>,
		#_uri_NextBackup	=> <URI full path>,
		#_uri_NextLog		=> <URI full path>,
		#_obj_Lock		=> <OBJ IPC::LockTicket object>,
		#_bol_HardLinkProtect	=> <BOL true if at least one backup shall be kept>
		#_str_Remote		=> <STR undef for localhost or the path how to connect>
		#_str_RemoteBAK		=> <STR undef for localhost or the path how to connect> - backup of _str_Remote through ClientPongs()
		#_bol_Succeeded		=> undef,	# undef = not ran
		#_har_TimeBorderUNIX	=> { <hour|day|week|month|year> => <TSP from timeborder> },
		#_har_LocationBlocks	=> { <hour|day|week|month|year> => <HEX sprintf(q{%08x}, crc32(qq{@uri_sources}))> },	# Allows to see if the sections have the same source path(es)
		#},
	MAIN		=> {
		uri_File		=> $uri_MainConfig,
		har_Content		=> {
			},
		},
	);
my %har_NeededConfigKeys		= (
	# section is the block started by [section] - except the very beginning without section ("default"), which is named _
	# key is the key of key=value pair
	# sequence decides if this is a single or multi line - undef is not multiline, a number describes the position
	# config name as key to make them unique
	# layer allows (if appearing) appearance in different file types and designates if it is mandatory (true) or not (false)

	# <fc and no space key name> => { <fc and no space section name> = { <BOL multi>, <HAR layer it may appear and if it is mandatory>, <REF to check given values>, <STR default value>, <STR override by cmd> },

	# Can be overwritten by command line
	loglevel	=> {
		_		=> { bol_multi => false, har_layer => { main => false },	ref_check => $rxp_Integer,	str_default => 0 },
		},
	verbositylevel	=> {
		_		=> { bol_multi => false, har_layer => { main => false },	ref_check => $rxp_Integer,	str_default => 0 },
		},

	# Command line options only used for create sub-command
	destination	=> {
		_		=> { bol_multi => false, har_layer => { job => false, main => true }, ref_check => \&IsDirectory,	str_default => qq{$uri_Library/backups} },
		},
	source		=> {
		_		=> { bol_multi => true, har_layer => { job => true },		ref_check => \&IsValidRsyncSource,		str_default => undef },
		year		=> { bol_multi => true, har_layer => { job => true },		ref_check => \&IsValidRsyncSource,		str_default => undef },
		month		=> { bol_multi => true, har_layer => { job => true },		ref_check => \&IsValidRsyncSource,		str_default => undef },
		week		=> { bol_multi => true, har_layer => { job => true },		ref_check => \&IsValidRsyncSource,		str_default => undef },
		day		=> { bol_multi => true, har_layer => { job => true },		ref_check => \&IsValidRsyncSource,		str_default => undef },
		hour		=> { bol_multi => true, har_layer => { job => true },		ref_check => \&IsValidRsyncSource,		str_default => undef },
		}, 
	hostname	=> {
		_		=> { bol_multi => false, har_layer => { job => false },		ref_check => $rxp_ValidHostName,		str_default => undef },
		}, 
	ipv46		=> {
		_		=> { bol_multi => false, har_layer => { job => false },		ref_check => \&IsValidIP,			str_default => undef },
		}, 
	niceserver	=> {
		_		=> { bol_multi => false, har_layer => { main => false },	ref_check => \&IsBoolean,		str_default => false,	str_override => undef },	# Override is set after GetOptions()
		},
	niceclient	=> {
		_		=> { bol_multi => false, har_layer => { job => false, main => false },	ref_check => \&IsBoolean,	str_default => false,	str_override => undef },	# Override is set after GetOptions()
		},
	pingcheck	=> {
		_		=> { bol_multi => false, har_layer => { job => false, main => false },	ref_check => \&IsBoolean,	str_default => true,	str_override => undef },	# Override is set after GetOptions()
		},
	protecthardlinks => {
		_		=> { bol_multi => false, har_layer => { job => false, main => false },	ref_check => \&IsBoolean,	str_default => true,	str_override => undef },	# Override is set after GetOptions()
		},
	binrsync	=> {
		_		=> { bol_multi => false, har_layer => { job => false, main => false }, ref_check => \&IsBinary,		str_default => &GetApplicationPath(q{rsync}), },
		},
	binnice		=> {
		_		=> { bol_multi => false, har_layer => { main => false },		ref_check => \&IsBinary,	str_default => &GetApplicationPath(q{nice}), },
		},
	binionice	=> {
		_		=> { bol_multi => false, har_layer => { main => false },		ref_check => \&IsBinary,	str_default => &GetApplicationPath(q{ionice}), },
		},
	bindu		=> {
		_		=> { bol_multi => false, har_layer => { main => false },		ref_check => \&IsBinary,	str_default => &GetApplicationPath(q{du}), },
		},
	binfind		=> {
		_		=> { bol_multi => false, har_layer => { main => false },		ref_check => \&IsBinary,	str_default => &GetApplicationPath(q{find}), },
		},
	binwc		=> {
		_		=> { bol_multi => false, har_layer => { main => false },		ref_check => \&IsBinary,	str_default => &GetApplicationPath(q{wc}), },
		},
	space		=> {
		_		=> { bol_multi => false, har_layer => { job => false, main => true }, ref_check => \&IsValidSpace,	str_default => 2.0 }, 
		},
	timeborder	=> {
		year		=> { bol_multi => false, har_layer => { job => false, main => true }, ref_check => $rxp_DateAndHour,	str_default => q{01-01-0000h} }, 
		month		=> { bol_multi => false, har_layer => { job => false, main => true }, ref_check => $rxp_DayAndHour,	str_default => q{01-0000h} }, 
		week		=> { bol_multi => false, har_layer => { job => false, main => true }, ref_check => $rxp_Week,		str_default => q{5-0000h} }, 
		day		=> { bol_multi => false, har_layer => { job => false, main => true }, ref_check => $rxp_Clock,		str_default => q{0000h} }, 
		#hour		=> { bol_multi => false, har_layer => { job => false, main => true }, ref_check => $rxp_Minute,		str_default => q{00m} }, 
		},
	quantity	=> {
		year		=> { bol_multi => false, har_layer => { job => false, main => true }, ref_check => $rxp_PositiveInteger, str_default => 3 }, 
		month		=> { bol_multi => false, har_layer => { job => false, main => true }, ref_check => $rxp_PositiveInteger, str_default => 12 }, 
		week		=> { bol_multi => false, har_layer => { job => false, main => true }, ref_check => $rxp_PositiveInteger, str_default => 4 }, 
		day		=> { bol_multi => false, har_layer => { job => false, main => true }, ref_check => $rxp_PositiveInteger, str_default => 7 }, 
		hour		=> { bol_multi => false, har_layer => { job => false, main => true }, ref_check => $rxp_PositiveInteger, str_default => 0 }, 
		},
	includefrom	=> {
		_		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => \&IsReadableTextFile,		str_default => undef }, 
		year		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => \&IsReadableTextFile,		str_default => undef }, 
		month		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => \&IsReadableTextFile,		str_default => undef }, 
		week		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => \&IsReadableTextFile,		str_default => undef }, 
		day		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => \&IsReadableTextFile,		str_default => undef }, 
		hour		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => \&IsReadableTextFile,		str_default => undef }, 
		},
	excludefrom	=> {
		_		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => \&IsReadableTextFile,		str_default => undef }, 
		year		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => \&IsReadableTextFile,		str_default => undef }, 
		month		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => \&IsReadableTextFile,		str_default => undef }, 
		week		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => \&IsReadableTextFile,		str_default => undef }, 
		day		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => \&IsReadableTextFile,		str_default => undef }, 
		hour		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => \&IsReadableTextFile,		str_default => undef }, 
		},
	clientprerun	=> {
		_		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		year		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		month		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		week		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		day		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		hour		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		},
	clientprefail	=> {
		_		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		year		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		month		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		week		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		day		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		hour		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		},
	clientpostrun	=> {
		_		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		year		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		month		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		week		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		day		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		hour		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		},
	clientpostfail	=> {
		_		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		year		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		month		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		week		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		day		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		hour		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		},
	serverprerun	=> {
		_		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		year		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		month		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		week		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		day		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		hour		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		},
	serverprefail	=> {
		_		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		year		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		month		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		week		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		day		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		hour		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		},
	backupfailurehandling	=> {
		_		=> { bol_multi => false, har_layer => { job => false, main => false }, ref_check => $rxp_ValidBFH,	str_default => q{stop} }, 
		year		=> { bol_multi => false, har_layer => { job => false, main => false }, ref_check => $rxp_ValidBFH,	str_default => q{stop} }, 
		month		=> { bol_multi => false, har_layer => { job => false, main => false }, ref_check => $rxp_ValidBFH,	str_default => q{stop} }, 
		week		=> { bol_multi => false, har_layer => { job => false, main => false }, ref_check => $rxp_ValidBFH,	str_default => q{stop} }, 
		day		=> { bol_multi => false, har_layer => { job => false, main => false }, ref_check => $rxp_ValidBFH,	str_default => q{stop} }, 
		hour		=> { bol_multi => false, har_layer => { job => false, main => false }, ref_check => $rxp_ValidBFH,	str_default => q{stop} }, 
		},
	serverpostrun	=> {
		_		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		year		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		month		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		week		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		day		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		hour		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		},
	serverpostfail	=> {
		_		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		year		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		month		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		week		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		day		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		hour		=> { bol_multi => true, har_layer => { job => false, main => false }, ref_check => undef,		str_default => undef }, 
		},
	globalprerun	=> {
		_		=> { bol_multi => true, har_layer => { main => false },			ref_check => undef,		str_default => undef }, 
		},
	globalprefail	=> {
		_		=> { bol_multi => true, har_layer => { main => false },			ref_check => undef,		str_default => undef }, 
		},
	globalpostrun	=> {
		_		=> { bol_multi => true, har_layer => { main => false },			ref_check => undef,		str_default => undef }, 
		},
	globalpostfail	=> {
		_		=> { bol_multi => true, har_layer => { main => false },			ref_check => undef,		str_default => undef }, 
		},
	);
my %har_SubCommands			= (
	backup		=> {
		bol_Active		=> false,	# Set to TRUE, when it was requested as argument
		},
	size		=> {
		bol_Active		=> false,	# Set to TRUE, when it was requested as argument
		},
	list		=> {
		bol_Active		=> false,	# Set to TRUE, when it was requested as argument
		},
	show		=> {				# Show configuration
		bol_Active		=> false,	# Set to TRUE, when it was requested as argument
		},
	#rollback	=> {
	#	bol_Active		=> false,	# Set to TRUE, when it was requested as argument
	#	},
	create		=> {
		bol_Active		=> false,	# Set to TRUE, when it was requested as argument
		},
	#watch		=> {
	#	bol_Active		=> false,	# Set to TRUE, when it was requested as argument
	#	},
	);

##### Database
use constant STR_DSN			=> q{DBI:SQLite:dbname=%s};
my $str_DefaultDataBaseName		= qq{_${str_AppName}_MetaData.db};

### SQL begin
use constant {
	SQL_PragmaForeignKeys		=> q{PRAGMA foreign_keys = ON},
	SQL_PragmaOptimize		=> q{PRAGMA optimize},
	SQL_PragmaJournalMode		=> q{PRAGMA journal_mode = DELETE},
	SQL_PragmaSynchronousNormal	=> q{PRAGMA synchronous = NORMAL},
	SQL_PragmaSynchronousOff	=> q{PRAGMA synchronous = OFF},
	SQL_Vacuum			=> q{VACUUM},
	SQL_Analyze			=> q{ANALYZE},
	};
my $sql_SelectStatusByJobAndDir		= q{SELECT
  successful
FROM backup_status
WHERE job_id = ( SELECT id FROM jobs WHERE name = ?1 LIMIT 1 )	-- ?1 replaces with first arguemnt for DBI::execute()
  AND ?2 LIKE dirname || '%' --ESCAPE '\\'
  OR dirname LIKE ?2 || '%' --ESCAPE '\\'
LIMIT 1 };
# AND ? LIKE dirname || '%' LIMIT 1
my $sql_InsertBackupStatus		= q{INSERT OR REPLACE INTO backup_status
( job_id, inode, mtime, dirname, "path", successful )
VALUES ( ( SELECT id FROM jobs WHERE name = ? LIMIT 1 ), ?, ?, ?, ?, ? ) };
my $sql_SelectSizingsByJobWithPathes	= q{SELECT
  jo.id                AS job_id,
  jo.name              AS job_name,
  tks.id               AS task_id,
  tks.time             AS task_time,
  bcks.id              AS backup_id,
  bcks.inode           AS backup_inode,
  bcks.mtime           AS backup_mtime,
  bcks.size            AS backup_size,
  bcks.elements        AS backup_elments,
  notations.notation   AS backup_notation,
  mad.delta_id         AS delta_id,
  dlts.inode           AS delta_inode,
  dlts.mtime           AS delta_mtime,
  mad.delta_size       AS delta,          -- real delta
  dlts.size            AS delta_size,     -- full size
  dlno.notation        AS delta_notation,
  spathes.id           AS spath_id,
  spathes."path"       AS spath
FROM jobs AS jo
INNER JOIN tasks tks
  ON jo.id = tks.job_id
  AND jo.name = ?
--<WHERE>--
INNER JOIN mixed_alloc_delta mad
  ON tks.id = mad.task_id
INNER JOIN backups bcks
  ON mad.backup_id = bcks.id
INNER JOIN notations
  ON bcks.nid = notations.id
INNER JOIN source_pathes spathes
  ON bcks.spath_id = spathes.id
LEFT JOIN backups dlts -- deltas
  ON dlts.id = mad.delta_id
LEFT JOIN notations dlno
  ON dlts.nid = dlno.id
ORDER BY tks.time DESC, spath, bcks.mtime DESC };
my $sql_SelectSizingsByJob		= q{SELECT
  jo.id                AS job_id,
  jo.name              AS job_name,
  tks.id               AS task_id,
  tks.time             AS task_time,
  bcks.id              AS backup_id,
  bcks.inode           AS backup_inode,
  bcks.mtime           AS backup_mtime,
  SUM(bcks.size)       AS backup_size,
  SUM(bcks.elements)   AS backup_elments,
  notations.notation   AS backup_notation,
  -- Deltas must be hidden if only a subpart has data
  CASE COUNT(*) WHEN COUNT(mad.delta_id) THEN mad.delta_id ELSE NULL           END AS delta_id,
  CASE COUNT(*) WHEN COUNT(dlts.inode) THEN dlts.inode ELSE NULL               END AS delta_inode,
  CASE COUNT(*) WHEN COUNT(dlts.mtime) THEN dlts.mtime ELSE NULL               END AS delta_mtime,
  CASE COUNT(*) WHEN COUNT(mad.delta_size) THEN SUM(mad.delta_size) ELSE NULL  END AS delta,          -- real delta
  CASE COUNT(*) WHEN COUNT(dlts.size) THEN SUM(dlts.size) ELSE NULL            END AS delta_size,     -- full size
  CASE COUNT(*) WHEN COUNT(dlno.notation) THEN dlno.notation ELSE NULL         END AS delta_notation,
  sgroups.id           AS sgroups_id,
  sgroups.name         AS sgroups_name
FROM jobs AS jo
INNER JOIN tasks tks
  ON jo.id = tks.job_id
  AND jo.name = ?
--<WHERE>--
INNER JOIN mixed_alloc_delta mad
  ON tks.id = mad.task_id
INNER JOIN backups bcks
  ON mad.backup_id = bcks.id
INNER JOIN notations
  ON bcks.nid = notations.id
INNER JOIN (
    -- Unique pathes, especially for parents per group
    SELECT
      sp1.pid, sp1.gid, sp1.jid
    FROM (
      SELECT g.id gid, p."path", p.id pid, a.job_id jid
        FROM source_groups g
        INNER JOIN source_allocs a
          ON g.id = a.sgroup_id
        INNER JOIN source_pathes p
          ON a.path_id = p.id
      ) sp1
    LEFT JOIN (
      SELECT g.id gid, p."path", p.id pid, a.job_id jid
        FROM source_groups g
        INNER JOIN source_allocs a
          ON g.id = a.sgroup_id
        INNER JOIN source_pathes p
          ON a.path_id = p.id
      ) sp2
      ON sp1.gid = sp2.gid
      AND ( sp1."path" LIKE sp2."path" || '%' OR sp2."path" LIKE sp1."path" || '%' )
      AND sp2."path" NOT LIKE sp1."path" || '%'
    WHERE sp2.pid IS NULL
  ) spathes
  ON bcks.spath_id = spathes.pid
  AND jo.id = spathes.jid
INNER JOIN source_groups sgroups
  ON spathes.gid = sgroups.id
INNER JOIN source_pathes sp
  ON spathes.pid = sp.id
INNER JOIN ( -- Count how much pathes belong to each group
  SELECT g.id gid, COUNT(*) pathes
    FROM source_groups g
    INNER JOIN source_allocs a
      ON g.id = a.sgroup_id
    INNER JOIN source_pathes p
      ON a.path_id = p.id
    GROUP BY g.name, g.id
  ) gc -- Group Count
  ON sgroups.id = gc.gid 
LEFT JOIN backups dlts -- deltas
  ON dlts.id = mad.delta_id
LEFT JOIN notations dlno
  ON dlts.nid = dlno.id
GROUP BY jo.id, tks.id, sgroups.id, notations.notation
  --HAVING COUNT(sp.id) == gc.pathes -- 20250713: not working, but preventing output for single sgroup elements
ORDER BY tks.time DESC, sgroups.name, bcks.mtime DESC };
my $sql_SelectSizingByJobAndTaskId	= $sql_SelectSizingsByJob =~ s{$rxp_WHEREClauseReplace} {  AND tks.id = ?}r;
my $sql_SelectSizingByJobTskAndPath	= $sql_SelectSizingsByJobWithPathes =~ s{$rxp_WHEREClauseReplace} {  AND tks.id = ?
  AND spath = ?}r;
my $sql_InnerJoinYoungestTask		= q{INNER JOIN (
  SELECT 
    jobs.id AS jid,
    MAX(tasks.time) AS youngest
  FROM jobs
  INNER JOIN tasks
    ON jobs.id = tasks.job_id
  GROUP BY jobs.id
  ) AS maxi
  ON jo.id = maxi.jid
  AND tks.time = maxi.youngest };
my $sql_SelectLastSizingByJob		= $sql_SelectSizingsByJob =~ s{$rxp_WHEREClauseReplace} {$sql_InnerJoinYoungestTask}r;
my $sql_SelectLastSizingByJobWithPath	= $sql_SelectSizingsByJobWithPathes =~ s{$rxp_WHEREClauseReplace} {$sql_InnerJoinYoungestTask}r;
my $sql_InsertJob			= q{INSERT OR IGNORE
INTO jobs
  ( name )
VALUES ( ? ) };
my $sql_InsertTaskTimeAndJob		= q{INSERT OR IGNORE
INTO tasks
  ( job_id, time )
VALUES ( ( SELECT id FROM jobs WHERE name = ? ), ? ) };
my $sql_InsertSourceGroup		= q{INSERT OR IGNORE
INTO source_groups
  ( name )
VALUES ( ? ) };
my $sql_SelectSourcePathesAndGroups	= q{SELECT DISTINCT
  sp."path" AS spath,
  sg.name AS sgroup_name
FROM source_groups AS sg
INNER JOIN source_allocs AS sa
  ON sg.id = sa.sgroup_id
  --AND sg.name = ?
INNER JOIN source_pathes AS sp
  ON sa.path_id = sp.id };
my $sql_InsertSourcePath		= q{INSERT OR IGNORE
INTO source_pathes
  ( "path" )
VALUES ( ? ) };
my $sql_InsertSourceAllocation		= q{INSERT OR IGNORE
INTO source_allocs
  ( sgroup_id, path_id, job_id )
VALUES (
    ( SELECT id FROM source_groups WHERE name = ? LIMIT 1 ),
    ( SELECT id FROM source_pathes WHERE "path" = ? LIMIT 1 ),
    ( SELECT id FROM jobs WHERE name = ? LIMIT 1 )
    ) };
my $sql_InsertNotation			= q{INSERT OR IGNORE
INTO notations
  ( notation )
VALUES ( ? ) };
my $sql_InsertBackupSizing		= q{INSERT
INTO backups
  ( size, elements, nid, inode, mtime, spath_id )
VALUES ( ?, ?, 
  ( SELECT id FROM notations WHERE notation = ? LIMIT 1 ),
  ?, ?,
  ( SELECT id FROM source_pathes WHERE "path" = ? LIMIT 1 )
  )
ON CONFLICT DO UPDATE
  SET size = excluded.size
    , elements = excluded.elements
    , nid = excluded.nid};
my $sql_InsertMxdAllocation		= q{INSERT
INTO mixed_alloc_delta
  ( delta_size, task_id, backup_id, delta_id )
VALUES (
  ?,
  ( SELECT t.id                                                          -- task_id
    FROM tasks t
    INNER JOIN jobs j
      ON t.job_id = j.id
      AND j.name = ?                                                     -- (ARG: _str_JobName)
    ORDER BY t.time DESC LIMIT 1
    ),
  ( SELECT b1.id FROM backups b1 WHERE b1.inode = ? AND b1.mtime = ? AND b1.spath_id = ( SELECT id FROM source_pathes WHERE "path" = ? LIMIT 1 ) LIMIT 1 ),  -- backup_id
  ( SELECT b2.id FROM backups b2 WHERE b2.inode = ? AND b2.mtime = ? AND b2.spath_id = ( SELECT id FROM source_pathes WHERE "path" = ? LIMIT 1 ) LIMIT 1 )   -- delta_id
  )
--ON CONFLICT DO UPDATE
  --SET delta_size = excluded.delta_size
    --, delta_id = excluded.delta_id};
my $sql_DeleteLastTaskByJob		= q{DELETE FROM tasks
WHERE id = (
  SELECT tasks.id
  FROM jobs
  INNER JOIN tasks
    ON jobs.id = tasks.job_id
    AND jobs.name = ?
  ORDER BY time DESC
  LIMIT 1
  )};
my $sql_SelectTasksByJob		= q{SELECT
  t.id,
  t.time
FROM jobs AS j
INNER JOIN tasks AS t
  ON j.id = t.job_id
  AND j.name = ?
ORDER BY time};
### SQL end


##### S U B F U N C T I O N S #####
sub NormalizePath {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $str_Element		= shift;

	if ( $str_Element !~ m{$rxp_OnlySlashes} ) {
		$str_Element	=~ s{$rxp_EndingSlashes} {};
		}
	$str_Element		=~ s{$rxp_Slashes} {/};

	DEBUG(qq{Returning data: "$str_Element"});

	return($str_Element);
	}

sub ShellQuote {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my @str_Elements	= @_;

	lop_Quoting:
	foreach my $str_Argument ( @str_Elements ) {
		TRACE(qq{Quoting "$str_Argument".});

		if ( ! defined($str_Argument)
		|| $str_Argument eq '' ) {
			$str_Argument	= q{''};
			next(lop_Quoting);
			}

		$str_Argument		= NormalizePath($str_Argument);

		if ( $str_Argument =~ m{$rxp_UnwantedCharsQuoting} ) {
			TRACE(q{Found unwanted characters.});

			$str_Argument	=~ s{$rxp_Backslash} {\\\\}g;
			$str_Argument	=~ s{$rxp_Quote} {'\\''}g;

			# Simplify multiple quotes
			$str_Argument	=~ s{((?:'\\''){2,})}
				{q{'"} . (q{'} x (length($1) / 4)) . q{"'}}ge;

			$str_Argument	= qq{'$str_Argument'};
			$str_Argument	=~ s{$rxp_BeginTwoQuotes} {};
			$str_Argument	=~ s{$rxp_EndTwoQuotes} {};
			}
		}

	DEBUG(qq{Returning data: "@str_Elements"});

	return(qq{@str_Elements});
	}

lop_ForkEnvironment: {
	my @_pid_Children	= ();

	sub PrepareForkParent {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });

		$SIG{CHLD}	= q{IGNORE};
		$SIG{CLD}	= q{IGNORE};

		DEBUG(q{Children handle set to IGNORE.});

		return(true);
		}

	sub ParentAftercare {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });

		$SIG{CHLD}	= q{DEFAULT};
		$SIG{CLD}	= q{DEFAULT};

		DEBUG(q{Children handle reset to DEFAULT.});

		return(true);
		}

	sub WaitForChildren {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });

		my $int_Maximum		= shift;

		local $SIG{CHLD}	= q{IGNORE};
		local $SIG{CLD}		= q{IGNORE};

		DEBUG(sprintf(q{Started at %s with threshold %d.}, scalar(localtime(time)), $int_Maximum));

		while ( @_pid_Children ) {

			@_pid_Children	= grep { kill(0 => $_) } @_pid_Children;

			TRACE(sub { sprintf(qq{%d %s still running: @_pid_Children},
				scalar(@_pid_Children),
				( scalar(@_pid_Children) == 1 ? q{child is} : q{children are} ),
				)});

			if ( scalar(@_pid_Children) <= $int_Maximum ) {
				DEBUG(qq{Count of children below threshold of $int_Maximum. Continuing...});

				return(true);
				}
			else {
				TRACE(qq{Count of children is over threshold of $int_Maximum. Waiting...});

				Time::HiRes::sleep(0.1);
				}
			}

		DEBUG(qq{No children running. Continuing...});

		return(true);
		}

	sub RunAsChild {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });

		my $sub_CodeBlock	= shift;
		my $uri_STDERRLog	= undef;
		my $pid_Child		= undef;
		my $int_SessionID	= undef;
		my sub PrepareChildFork;
		my sub ChildAftercare;

		sub PrepareChildFork {
			TRACE(q{Preparing child.});

			TRACE(q{Setting SIG Child back to default for forked process.});
			$SIG{CHLD}	= q{DEFAULT};
			$SIG{CLD}	= q{DEFAULT};

			TRACE(q{Preparing STDERR log.});
			$uri_STDERRLog	= qq{$uri_LogJobDir/C$$.err};

			if ( ! -d $uri_LogJobDir ) {
				TRACE(qq{Creating "$uri_LogJobDir".});
				make_path($uri_LogJobDir);
				chmod(0750, $uri_LogJobDir);
				}

			TRACE(q{Changing CWD to root.});
			chdir(q{/});

			TRACE(q{Generating new seed.});
			srand();

			TRACE(q{Redirecting STDIO.});
			open(STDIN, "<", q{/dev/null});
			open(STDOUT, ">", q{/dev/null});
			open(STDERR, ">", $uri_STDERRLog);

			TRACE(q{Changing session ID.});
			$int_SessionID	= POSIX::setsid();
			if ( $int_SessionID ) {
				DEBUG(qq{Prepare succeeded, running in session $int_SessionID.});
				return(true);
				}
			else {
				FATAL(q{setsid() failed!});
				return(false);
				}
			}
		sub ChildAftercare {
			TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
			my $mxd_Return	= shift;

			if ( -e $uri_STDERRLog
			&& ! -s $uri_STDERRLog ) {
				TRACE(qq{No errors have been logged. Cleaning empty file.});
				unlink($uri_STDERRLog);
				}

			DEBUG(qq{Done. Exiting.});
			exit( $mxd_Return ? 0 : 110);
			}

		TRACE(q{Spawning child.});
		$pid_Child		= fork;

		if ( $pid_Child ) {
			TRACE(qq{Child $pid_Child spawned.});

			# Parent
			push(@_pid_Children, $pid_Child);
			return(true);
			}
		elsif ( defined($pid_Child) ) {
			TRACE(q{Child starting.});
			# Child
			PrepareChildFork();

			my $mxd_Return	= $sub_CodeBlock->();
			DEBUG(sub { return(q{Threaded function returned: } . Dumper({ mxd_Return => $mxd_Return })); });

			# This exits
			ChildAftercare($mxd_Return);

			LOGWARN(q{This should not happen but exiting anyway.});
			exit($mxd_Return ? 0 : 110);
			}
		else {
			LOGDIE(qq{Can not fork!});
			}
		}
	}

sub IsReadableTextFile {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $uri_Element		= shift;

	if ( ! $uri_Element ) {
		FATAL(q{Got no value to check!});

		return(undef);
		}
	elsif ( -e $uri_Element
	&& -T realpath($uri_Element)
	&& -r realpath($uri_Element) ) {
		DEBUG(qq{"$uri_Element" is a readable text file.});

		return(true);
		}
	else {
		FATAL(qq{"$uri_Element" is no readable file.});

		return(false);
		}
	}

sub IsDirectory {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $uri_Element		= shift;

	if ( ! $uri_Element ) {
		FATAL(q{Got no value to check!});

		return(undef);
		}
	elsif ( -e $uri_Element
	&& -d realpath($uri_Element)
	&& -w realpath($uri_Element) ) {
		DEBUG(qq{"$uri_Element" is a writeable directory.});

		return(true);
		}
	else {
		FATAL(qq{"$uri_Element" is no writable directory.});

		return(false);
		}
	}

sub IsBinary {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $uri_Element		= shift;

	if ( ! defined($uri_Element) ) {
		FATAL(q{Got no value to check!});
		return(undef);
		}

	if ( ! $uri_Element ) {
		FATAL(q{Got no value to check!});
		return(undef);
		}
	elsif ( -e $uri_Element
	&& ( -B realpath($uri_Element)
	|| -T realpath($uri_Element) )
	&& -x realpath($uri_Element) ) {
		DEBUG(qq{"$uri_Element" is a binary.});

		return(true);
		}
	else {
		FATAL(qq{"$uri_Element" is no binary.});

		return(false);
		}
	}

sub IsValidSpace {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $flt_Space		= shift;				# hours

	if ( $flt_Space !~ m{$rxp_Floating}				# Not floating point number
	|| $flt_Space < ( (INT_OneSecond - 0.01) / INT_OneHour ) ) {	# Not 1 second at least
		FATAL(qq{Value $flt_Space is to short.});

		return(false);
		}

	DEBUG(qq{Value $flt_Space is enough.});

	return(true);
	}

sub ReadDataBlock {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });

	if ( %str_Data ) {	# If filled, __SUB__ was already ran.
		DEBUG(q{Was already done.});

		return(\%str_Data);
		}

	my $rxp_FileStart	= qr{^\Q__filestart:\E(.+)\Q:tratselif__\E$};
	my $rxp_FileEnd		= qr{^\Q__fileend:\E(.+)\Q:dneelif__\E$};
	my $str_Reading		= undef;
	my $cnt_Line		= 0;
	my @rxp_Variables	= (
		{ rxp => qr{\Q%APP_NAME%\E},		str => $str_AppName,	},	# str_AppName
		{ rxp => qr{\Q%EXEC_PATH%\E},		str => $0,		},
		{ rxp => qr{\Q%FULL_EXEC_PATH%\E},	str => realpath($0),	},
		);

	TRACE(q{Loading __DATA__.});
		foreach my $str_Line ( split(m{\n}, STR_DATA, -1) ) {
			$cnt_Line++;
			chomp($str_Line);

			# End
			if ( $str_Line =~ m{$rxp_FileEnd}
			&& $1 eq $str_Reading ) {

				# Apply variables
				foreach my $har_Variable ( @rxp_Variables ) {
					TRACE(qq{Applying Regex "$har_Variable->{rxp}"});
					$str_Data{$str_Reading}	=~ s{$har_Variable->{rxp}} {$har_Variable->{str}}sg;
					}

				TRACE(qq{Reached EOF of "$str_Reading" from __DATA__ block.});
				$str_Reading		= undef;
				}
			# Reading
			elsif ( defined($str_Reading) ) {
				TRACE(sprintf(q{%5s  %s}, $cnt_Line, $str_Line));
				$str_Data{$str_Reading}	.= qq{$str_Line\n};
				}
			# Start
			elsif ( $str_Line =~ m{$rxp_FileStart} ) {
				$str_Reading		= $1;
				TRACE(qq{Starting to read "$str_Reading" from __DATA__ block.});
				TRACE(qq{Got following lines:});

				$str_Data{$str_Reading}	= '';
				}
			# Must not happen
			elsif ( $str_Line ne '' ) {
				FATAL(qq{__DATA__ block invalid: Line $cnt_Line doesn't belong to any file.});
				return(undef);
				}
			}

	TRACE(q{__DATA__ Done.});

	# Makes output only on >=DEBUG state
	DEBUG(sub { return(q{Loaded DATA structure: } . Dumper({ str_Data => \%str_Data })); });

	return(\%str_Data);
	}

sub CreateMainConfigFile {
	#INFO(qq{There's a copy at the end of the application's Perl variant ($0) of a main config template, but this is just to keep things together.});
	LOGDIE(qq{Reinstall or extract the installation package to restore it. Or better: restore it from your backup!});
	}

sub LoadDefaultConfiguration {
	TRACE(qq{Loading default config.});

	if ( ! -e $har_JobsConfigs{MAIN}{uri_File} ) {
		FATAL(qq{Main config file "$har_JobsConfigs{MAIN}{uri_File}" is missing!});
		CreateMainConfigFile($har_JobsConfigs{MAIN}{uri_File});
		return(false);
		}

	# Load main file
	$har_JobsConfigs{MAIN}	= ReadConfigurationFile($har_JobsConfigs{MAIN}{uri_File}, q{main});
	if ( ! $har_JobsConfigs{MAIN} ) {
		FATAL(qq{Error on reading "$har_JobsConfigs{MAIN}{uri_File}".});
		return(false);
		}

	#chomp($str_Hostname	= qx(hostname 2> /dev/null));
	if ( $str_Hostname ) {
		DEBUG(qq{Got hostname:="$str_Hostname"});
		}
	else {
		LOGDIE(q{Got no hostname.});
		}

	SetupLoggers(
		do { 
			if ( defined($int_LogLevel) ) {
				TRACE(qq{Using log level from command line.});
				$int_LogLevel;
				}
			elsif ( defined($har_JobsConfigs{MAIN}{har_Config}{_}{loglevel}[0]) ) {
				TRACE(qq{Using log level from main config file.});
				$har_JobsConfigs{MAIN}{har_Config}{_}{loglevel}[0];
				}
			else {
				TRACE(qq{Using default log level.});
				$int_DefaultLogLevel;
				}
			},
		do { 
			if ( defined($int_Verbose) ) {
				TRACE(qq{Using verbosity level from command line.});
				$int_Verbose;
				}
			elsif ( defined($har_JobsConfigs{MAIN}{har_Config}{_}{verbositylevel}[0]) ) {
				TRACE(qq{Using verbosity level from main config file.});
				$har_JobsConfigs{MAIN}{har_Config}{_}{verbositylevel}[0];
				}
			else {
				TRACE(qq{Using default verbosity level.});
				$int_DefaultVerbose;
				}
			},
		) or return(false);

	# Load jobs
	if ( -d $uri_JobsDir ) {
		TRACE(qq{Collecting data from "$uri_JobsDir"});

		if ( opendir(my $dsc_DirectoryHandle, $uri_JobsDir) ) {
			TRACE(qq{Opened "$uri_JobsDir".});

			while ( my $str_Inode = readdir($dsc_DirectoryHandle) ) {
				my $uri_FullPath			= qq{$uri_JobsDir/$str_Inode};
				my ($str_Name, undef, $str_Suffix)	= fileparse($uri_FullPath, $rxp_Suffix);
				$str_Name				= fc($str_Name);

				TRACE(qq{Checking file:\nuri_FullPath:="$uri_FullPath"\nstr_Name:="$str_Name"\nstr_Suffix:="$str_Suffix"});
				
				if ( -e $uri_FullPath
				&& -T realpath($uri_FullPath)
				&& -s realpath($uri_FullPath)
				&& $str_Suffix =~ m{$rxp_Suffixes} ) {	# Is a job file
					TRACE(qq{Looks like a configuration file.});

					if ( defined($har_JobsConfigs{$str_Name}) ) {
						WARN(qq{Job "$str_Name" was loaded from more than one file. Files are read without suffix and case folded. (i.e. case-insensitive)});
						}

					$har_JobsConfigs{$str_Name}	= ReadConfigurationFile($uri_FullPath);
					}
				else {
					TRACE(qq{Looks unlike a configuration file - nothing done.});
					}

				TRACE(qq{Check for "$uri_FullPath" finished.});
				}

			closedir($dsc_DirectoryHandle);
			TRACE(qq{Finished "$uri_JobsDir".});
			return(true);
			}
		else {
			FATAL(qq{Failed to opendir "$uri_JobsDir"});
			return(false);
			}
		}
	else {
		FATAL(qq{Missing jobs directory "$uri_JobsDir"});
		return(false);
		}
	}

sub ReadConfigurationFile {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $uri_ConfigFile	= shift;
	my $str_Layer		= shift;
	$str_Layer		= defined($str_Layer) && fc($str_Layer) eq fc(q{main})
		? q{main}
		: q{job};
	my %har_Config		= ();
	my sub LoadContent;
	my sub BuildConfiguration;
	my sub CalculateLocationBlocks;
	my sub CalculateTimeBordersUNIX;
	my sub GetName;
	my sub getFilesFromDir;

	sub LoadContent {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $uri_File	= shift;
		my $str_Section	= q{_};
		my %har_Content	= ();
		my $cnt_Line	= 0;

		if ( open(my $dsc_FileHandle, '<', $uri_File) ) {
			TRACE(qq{Entering section "$str_Section":});

			lop_Line:
			while ( my $str_Line = readline($dsc_FileHandle) ) {
				$cnt_Line++;
				chomp($str_Line);

				if ( $str_Line =~ m{$rxp_Comment} ) {
					TRACE(qq{Omitting commented line "$str_Line".});
					next(lop_Line);
					}
				elsif ( $str_Line eq '' ) {
					TRACE(qq{Omitting empty line.});
					next(lop_Line);
					}
				elsif ( $str_Line =~ m{$rxp_Pair} ) {
					my $str_Key						= $1;
					my $str_Value						= $2;
					$str_Key						= fc($str_Key =~ s{$rxp_UnwantedCharsDirNames} {}rg);
					$str_Value						=~ s{^"|"$} {}g;
					TRACE(qq{Looks like a proper pair: "$str_Line".\nKey:="$str_Key"\nValue:="$str_Value"});

					if ( ! exists($har_Content{$str_Section}{$str_Key}) ) {
						TRACE(qq{Creating new key "$str_Key" in section "$str_Section".});
						$har_Content{$str_Section}{$str_Key}	= [];
						}

					# If the whole EXPR is a string of length zero split() returns an empty array
					push(@{$har_Content{$str_Section}{$str_Key}}
						, ( $str_Value ne ''
							? split(m{$rxp_Separator}, $str_Value, -1)
							: $str_Value
							)
						);

					TRACE(sub { sprintf(q{Read line %d as section.key:="%s.%s" and values:=[%s].}
						, $cnt_Line
						, $str_Section
						, $str_Key
						, join(q{,}, map { qq{"$_"} } split(m{$rxp_Separator}, $str_Value)));
						});
					}
				elsif ( $str_Line =~ m{$rxp_Section} ) {
					$str_Section	= fc($1 =~ s{$rxp_UnwantedCharsDirNames} {}rg);

					if ( defined($str_Section)
					&& $str_Section ne '' ) {
						TRACE(qq{Entering section "$str_Section":});
						}
					else {
						LOGDIE(qq{Section '$str_Section' of "$uri_File" is invalid. Only use a-z and 0-9.});
						}
					}
				else {
					WARN(qq{Unrecognized line "$str_Line".});
					}
				}

			close($dsc_FileHandle);

			DEBUG(sub { return(qq{Loaded content: } . Dumper({ har_Content => \%har_Content })); });

			return(\%har_Content);
			}
		else {
			ERROR(qq{Can't open "$uri_File".});
			return(undef);
			}
		}
	sub BuildConfiguration {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $har_Content	= shift;
		my $str_Layer	= shift;
								# WORK Dieſe Kopie erſtellt unnötige Duplikate!
		my %har_Config	= fc($str_Layer) eq fc(q{main}) ? () : do {	# If it is job, copy from MAIN config
			my %har_Copy		= ();

			TRACE(q{Copying main config.});

			# Load a default setting from MAIN
			foreach my $har_Pair (
			grep { defined($har_NeededConfigKeys{$_->{str_key}}{$_->{str_section}}{har_layer}{job}) }
			map { my $str_key = $_; map { { str_key => $str_key, str_section => $_ } } keys(%{$har_NeededConfigKeys{$str_key}}) } keys(%har_NeededConfigKeys)
			) {
				TRACE(sub { return(qq{Working on } . Dumper({ har_Pair => $har_Pair, layers => defined($har_NeededConfigKeys{$har_Pair->{str_key}}{$har_Pair->{str_section}}{har_layer}{job}) ? $har_NeededConfigKeys{$har_Pair->{str_key}}{$har_Pair->{str_section}}{har_layer}{job} : q{NULL} })); });

				if ( defined($har_JobsConfigs{MAIN}{har_Config}{$har_Pair->{str_section}})
				&& defined($har_JobsConfigs{MAIN}{har_Config}{$har_Pair->{str_section}}{$har_Pair->{str_key}})
				&& ref($har_JobsConfigs{MAIN}{har_Config}{$har_Pair->{str_section}}{$har_Pair->{str_key}}) eq q{ARRAY} ) {
					if ( ! defined($har_Copy{$har_Pair->{str_section}}) ) {
						$har_Copy{$har_Pair->{str_section}}	= {
							$har_Pair->{str_key}	=> dclone($har_JobsConfigs{MAIN}{har_Config}{$har_Pair->{str_section}}{$har_Pair->{str_key}}),
							};
						}
					else {
						$har_Copy{$har_Pair->{str_section}}{$har_Pair->{str_key}}	= # ARE
							dclone($har_JobsConfigs{MAIN}{har_Config}{$har_Pair->{str_section}}{$har_Pair->{str_key}});
						}
					}
				}

			DEBUG(sub { return(q{Settings loaded from main config: } . Dumper({ har_Copy => \%har_Copy })); });

			# Return
			%har_Copy;
			};

		TRACE(sub { return(qq{Building $str_Layer configuration from content and config: }
			. Dumper({ har_Config => \%har_Config, })
			. Dumper({ har_Content => $har_Content })); });
		my $bol_Failed	= false;

		# Check all needed config keys
		TRACE(qq{Working on "$uri_ConfigFile".});
		foreach my $str_Key ( keys(%har_NeededConfigKeys) ) {

			lop_ConfigSection:
			foreach my $str_Section (
			map { $_->{str_key} }									# Return only the regular value
			sort { $a->{int_sort} <=> $b->{int_sort} }						# Sort it _ (general section) first
			map { { str_key => $_, int_sort => ( $_ eq q{_} ? 1 : 3 ) } }			# Sorting mechanism
			grep { defined($har_NeededConfigKeys{$str_Key}{$_}{har_layer}{$str_Layer}) }		# Skip not applying settings, but faster than if below...
			keys(%{$har_NeededConfigKeys{$str_Key}}) ) {						# Nested hash
				TRACE(qq{Checking key:="$str_Key" in section:="$str_Section".});

				# Skip not applying settings (obsolete through grep in header)
				if ( ! defined($har_NeededConfigKeys{$str_Key}{$str_Section}{har_layer}{$str_Layer}) ) {
					TRACE(sub { sprintf(qq{Key "%s" in section "%s" is not meant to be part of %s config file},
						$str_Key,
						$str_Section,
						( $str_Layer eq q{main}
							? q{main}
							: q{a job}
							),
						); });
					next(lop_ConfigSection);
					}

				# Apply hierarchically
				if ( ( $str_Section ne q{_}
				&& defined($har_Config{_})
				&& defined($har_Config{_}{$str_Key}) 
				&& ref($har_Config{_}{$str_Key}) eq q{ARRAY}
				&& scalar(@{$har_Config{_}{$str_Key}}) > 0 )
				||
				(  defined($har_Content->{$str_Section})
				&& defined($har_Content->{$str_Section}{$str_Key})
				&& ref($har_Content->{$str_Section}{$str_Key}) eq q{ARRAY}
				&& scalar(@{$har_Content->{$str_Section}{$str_Key}}) > 0 ) ) {
					TRACE(qq{$str_Section.$str_Key carries options we are going to apply.});

					# Create whole section and key if not existing
					if ( ! defined($har_Config{$str_Section}) ) {
						TRACE(qq{Creating new config section "$str_Section" with key "$str_Key".});
						$har_Config{$str_Section}					= {
							$str_Key		=> [],
							};
						}
					# Create non-existing key
					elsif ( ! defined($har_Config{$str_Section}{$str_Key}) ) {
						TRACE(qq{Creating new config key "$str_Key".});
						$har_Config{$str_Section}{$str_Key}				= [];
						}

					# Apply mutli-values
					if ( $har_NeededConfigKeys{$str_Key}{$str_Section}{bol_multi} ) {
						TRACE(qq{$str_Section.$str_Key is an array.});
						my @mxd_Values						= ();

						foreach my $str_Sctn ( ( $str_Section eq q{_} ? ( q{_} ) : ( q{_}, $str_Section ) ) ) {	# _ must only run once
							TRACE(qq{Working on str_Sctn:='$str_Sctn'.});

							if ( defined($har_Content->{$str_Sctn})
							&& defined($har_Content->{$str_Sctn}{$str_Key})
							&& ref($har_Content->{$str_Sctn}{$str_Key}) eq q{ARRAY} ) {
								TRACE(sub { return(qq{Newline cleanup:\nstr_Layer:="$str_Layer"\nstr_Sctn:="$str_Sctn"\nstr_Key:="$str_Key"\nDump: }
									. Dumper({ qq{har_Content->{$str_Sctn}{$str_Key}} => $har_Content->{$str_Sctn}{$str_Key} })); });
								push(@mxd_Values, map { s{$rxp_NewLine} {}gr } @{$har_Content->{$str_Sctn}{$str_Key}});
								}
							}

						TRACE(sub { return(Dumper({ mxd_Values => \@mxd_Values })); });

						foreach my $mxd_Value ( @mxd_Values ) {
							if ( $mxd_Value ne '' ) {
								TRACE(qq{Adding value "$mxd_Value" to key: $str_Section.$str_Key.});
								push(@{$har_Config{$str_Section}{$str_Key}}, $mxd_Value);
								}
							else {
								TRACE(qq{Emptied $str_Section.$str_Key on request. (Empty value.)});
								$har_Config{$str_Section}{$str_Key}		= [];
								}
							}
						}
					# Apply single-values
					else {
						TRACE(qq{$str_Section.$str_Key is a single value.});
						foreach my $str_Sctn ( q{_}, ( $str_Section ne q{_} ? $str_Section : () ) ) {
							if ( defined($har_Content->{$str_Sctn})
							&& defined($har_Content->{$str_Sctn}{$str_Key})
							&& ref($har_Content->{$str_Sctn}{$str_Key}) eq q{ARRAY} ) {
								if ( @{$har_Content->{$str_Sctn}{$str_Key}} ) {
									TRACE(qq{Setting $str_Section.$str_Key:="$har_Content->{$str_Sctn}{$str_Key}[-1]".});
									$har_Config{$str_Section}{$str_Key}		= [ $har_Content->{$str_Sctn}{$str_Key}[-1] =~ s{$rxp_NewLine} {}gr ];
									}
								else {
									TRACE(qq{Setting $str_Section.$str_Key:=NULL .});
									$har_Config{$str_Section}{$str_Key}		= [];
									}
								}
							}
						}
					}
				else {
					TRACE(q{Got no value.});
					}

				DEBUG(sub { return(q{Adding done, dump before cleanup: } . Dumper({ har_Config => \%har_Config })); });

				# Delete empty keys
				TRACE(qq{Cleanup for $str_Section.$str_Key .});
				if ( defined($har_Config{$str_Section})
				&& defined($har_Config{$str_Section}{$str_Key})
				&& ref($har_Config{$str_Section}{$str_Key}) eq q{ARRAY} ) {
					TRACE(q{Is an array.});
					if ( scalar(@{$har_Config{$str_Section}{$str_Key}}) == 0	# Empty array or
					|| $har_Config{$str_Section}{$str_Key}[-1] eq '' ) {		# Last value is empty
						TRACE(qq{Deleting $str_Section.$str_Key because it carries no information.});

						$har_Config{$str_Section}{$str_Key}				= [];
						delete($har_Config{$str_Section}{$str_Key});
						}
					}
				# If the section has no keys
				if ( defined($har_Config{$str_Section})
				&& ! %{$har_Config{$str_Section}} ) {
					TRACE(qq{The whole section "$str_Section" is empty - purging it entirely.});
					delete($har_Config{$str_Section});
					}
				TRACE(q{Cleanup done.});

				# Check if mandatory settings are set
				TRACE(qq{Checking if $str_Section.$str_Key is a mandatory setting. (Must not be emtpy.)});
				if ( $har_NeededConfigKeys{$str_Key}{$str_Section}{har_layer}{$str_Layer}		# If TRUE setting is mandatory
				&&
				(  ! defined($har_Config{$str_Section})
				|| ! defined($har_Config{$str_Section}{$str_Key}) ) ) {
					FATAL(qq{Key "$str_Key" in } . ( $str_Section eq q{_} ? q{general section} : qq{section [$str_Section]} ) . qq{ in file "$uri_ConfigFile" is mandatory, but got effectivly no value.});
					$bol_Failed			= true;
					}
				# Check given values
				elsif ( defined($har_Config{$str_Section})
				&& defined($har_Config{$str_Section}{$str_Key})
				&& ref($har_Config{$str_Section}{$str_Key}) eq q{ARRAY}
				&& @{$har_Config{$str_Section}{$str_Key}} ) {
					TRACE(q{Found values.});
					TRACE(qq{Making field special checks for $str_Section.$str_Key .});
					if ( ( ref($har_NeededConfigKeys{$str_Key}{$str_Section}{ref_check}) eq q{CODE}
					&& grep { ! $har_NeededConfigKeys{$str_Key}{$str_Section}{ref_check}($_) } @{$har_Config{$str_Section}{$str_Key}} )
					||
					( ref($har_NeededConfigKeys{$str_Key}{$str_Section}{ref_check}) eq q{Regexp}
					&& grep { $_ !~ m{$har_NeededConfigKeys{$str_Key}{$str_Section}{ref_check}} } @{$har_Config{$str_Section}{$str_Key}} ) ) {
						TRACE(q{Failed!}); # To keep track if not happend by RegEx.

						if ( ref($har_NeededConfigKeys{$str_Key}{$str_Section}{ref_check}) eq q{Regexp} ) {
							# Some output for RegEx tests
							FATAL(qq{Invalid value for $str_Section.$str_Key for "$har_NeededConfigKeys{$str_Key}{$str_Section}{ref_check}"!});
							}

						$bol_Failed	= true;
						}
					else {
						DEBUG(qq{Setting $str_Section.$str_Key seems to be valid.});
						}
					TRACE(q{Field special checks done.});
					}
				# Setting empty non-mandatory values to defaults
				elsif ( defined($har_NeededConfigKeys{$str_Key}{$str_Section}{str_default}) ) {
					TRACE(qq{Empty and not mandatory setting for $str_Section.$str_Key, but has default values.});
					$har_Config{$str_Section}{$str_Key}	= [ $har_NeededConfigKeys{$str_Key}{$str_Section}{str_default} ];
					}
				TRACE(q{Mandatory check done.});

				# Overrides config file value and default value
				if ( defined($har_NeededConfigKeys{$str_Key}{$str_Section}{str_override}) ) {
					TRACE(qq{Setting $str_Section.$str_Key:='$har_Config{$str_Section}{$str_Key}[0]' will be overwritten with '$har_NeededConfigKeys{$str_Key}{$str_Section}{str_override}' by shell option.});
					$har_Config{$str_Section}{$str_Key}	= [ $har_NeededConfigKeys{$str_Key}{$str_Section}{str_override} ];
					}

				lop_OptimizeBFH:
				foreach my $str_Section ( keys(%har_Config) ) {
					if ( defined($har_Config{$str_Section}{backupfailurehandling})
					&& ref($har_Config{$str_Section}{backupfailurehandling}) eq q{ARRAY}
					&& @{$har_Config{$str_Section}{backupfailurehandling}} ) {
						TRACE(sprintf(q{Preparing of '%s.backupfailurehandling': [%s].}, $str_Section, join(q{,}, map { qq{"$_"} } @{$har_Config{$str_Section}{backupfailurehandling}})));

						if ( my @str_Helper = $har_Config{$str_Section}{backupfailurehandling}[0] =~ m{$rxp_Combinations} ) {
							@{$har_Config{$str_Section}{backupfailurehandling}}	= @str_Helper;
							}

						@{$har_Config{$str_Section}{backupfailurehandling}}		= MakeListUnique(map { lc($_) } @{$har_Config{$str_Section}{backupfailurehandling}});

						TRACE(sprintf(q{Preparing of '%s.backupfailurehandling': [%s].}, $str_Section, join(q{,}, map { qq{"$_"} } @{$har_Config{$str_Section}{backupfailurehandling}})));
						}
					}
				}
			}

		if ( $bol_Failed ) {
			FATAL(qq{Failure occured in "$uri_ConfigFile".});
			return(undef);
			}
		else {
			DEBUG(sub { return(qq{Effective $str_Layer config: } . Dumper({ har_Config => \%har_Config })); });
			return(\%har_Config);
			}
		}
	sub CalculateLocationBlocks {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $har_Config		= shift;
		my %int_Blocks		= ( map { $_ => undef } ARE_Generations );

		foreach my $str_Section ( keys(%int_Blocks) ) {
			if ( defined($har_Config->{$str_Section}{source})
			&& ref($har_Config->{$str_Section}{source}) eq q{ARRAY}
			&& scalar(@{$har_Config->{$str_Section}{source}}) > 0 ) {
				TRACE(q{Got locations.});

				$int_Blocks{$str_Section}	= sprintf(q{%08x}, crc32(join(q{ }, sort { crc32($a) <=> crc32($b) } @{$har_Config->{$str_Section}{source}})));
				}
			else {
				TRACE(qq{Source is missing in section $str_Section.});
				}
			}

		DEBUG(sub { return(q{Dump:}, Dumper({ int_Blocks => \%int_Blocks })); });

		return(\%int_Blocks);
		}
	sub CalculateTimeBordersUNIX {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $har_Config		= shift;
		my $tsp_StartTime	= $obj_StartTime->epoch() . '';
		my %tsp_TimeBorder	= (
			year	=> undef,
			month	=> undef,
			week	=> undef,
			day	=> undef,
			);

		# Calculate time borders from human readable form to UNIX time stamps
		foreach my $str_Section ( keys(%tsp_TimeBorder) ) {
			TRACE(qq{Checking generation "$str_Section".});

			if ( defined($har_Config->{$str_Section}{timeborder}[0]) ) {
				TRACE(qq{...is set to "$har_Config->{$str_Section}{timeborder}[0]".});
				my $str_TimeBorder		= $har_Config->{$str_Section}{timeborder}[0];
				my $tsp_PeriodStart		= undef;

				if ( $str_Section eq q{year}
				&& $str_TimeBorder =~ m{$rxp_DateAndHour} ) {
					TRACE(q{Section is "year".});

					$tsp_PeriodStart	= timelocal_modern(0, $4, $3,
						( $2 > $int_MonthLastDays{$1 + 0} ? $int_MonthLastDays{$1 + 0} : $2 ),
						($1 - 1),
						$obj_StartTime->year);

					# Plausibility check: PeriodStart can't be more than 360 days in the future -> reduce year by one
					if ( ( $tsp_PeriodStart - $tsp_StartTime ) > ( 360 * INT_OneDay ) ) {
						DEBUG(qq{'$tsp_PeriodStart' seems inplausible.});

						$tsp_PeriodStart	= timelocal_modern(0, $4, $3,
							( $2 > $int_MonthLastDays{$1 + 0} ? $int_MonthLastDays{$1 + 0} : $2 ),
							($1 - 1),
							( $obj_StartTime->year - 1 ));

						DEBUG(qq{Recalculated to '$tsp_PeriodStart'.});
						}
					}
				elsif ( $str_Section eq q{month}
				&& $str_TimeBorder =~ m{$rxp_DayAndHourFree} ) {
					TRACE(q{Section is "month"});

					$tsp_PeriodStart	= timelocal_modern(0, $3, $2,
						( $1 > $int_MonthLastDays{$obj_StartTime->mon} ? $int_MonthLastDays{$obj_StartTime->mon} : $1 ),
						$obj_StartTime->_mon,
						$obj_StartTime->year);

					# Plausibility check: PeriodStart can't be more than 26 days in the future -> reduce month by one
					if ( ( $tsp_PeriodStart - $tsp_StartTime ) > ( 26 * INT_OneDay ) ) {
						TRACE(qq{'$tsp_PeriodStart' seems inplausible.});

						$tsp_PeriodStart	= timelocal_modern(0, $3, $2,
							( $1 > $int_MonthLastDays{$obj_StartTime->mon} ? $int_MonthLastDays{$obj_StartTime->mon} : $1 ),
							do {
								if ( $obj_StartTime->mon == 1 ) { 				# If it is January
									( 11, ( $obj_StartTime->year - 1 ));			# Last month is December last year
									}
								else {
									(( $obj_StartTime->_mon - 1 ), $obj_StartTime->year );	# Last month is current month minus one in same year
									}
								});

						TRACE(qq{Recalculated to '$tsp_PeriodStart'.});
						}
					}
				elsif ( $str_Section eq q{week}
				&& $str_TimeBorder =~ m{$rxp_Week} ) {
					TRACE(q{Section is "week"});

					my $int_Weekday		= $1;
					my $int_Hour		= $2;
					my $int_Minute		= $3;
					$int_Weekday		= $int_Weekday == 7 ? 0 : $int_Weekday;	# enforce 0 to 6

					# If weekday is today only this is required, but this is the base of all following calculations, too.
					$tsp_PeriodStart	= timelocal_modern(0, $int_Minute, $int_Hour, $obj_StartTime->mday, $obj_StartTime->_mon, $obj_StartTime->year);

					# Weekday was yesterday
					if ( ( $obj_StartTime->_wday == 0 ? 6 : ( $obj_StartTime->_wday - 1 ) ) == $int_Weekday ) {
						$tsp_PeriodStart	-= INT_OneDay;
						}
					# Any other day
					elsif ( $obj_StartTime->_wday != $int_Weekday ) {
						$tsp_PeriodStart	-= ( (($obj_StartTime->_wday + 7) - $int_Weekday) > 7
							? ($obj_StartTime->_wday - $int_Weekday)
							: (($obj_StartTime->_wday + 7) - $int_Weekday) ) * INT_OneDay;
						}
					}
				elsif ( $str_Section eq q{day}
				&& $str_TimeBorder =~ m{$rxp_Clock} ) {
					my $int_Hour		= $1 // $3;
					my $int_Minute		= $2 // $4;

					if ( ! defined($int_Minute) || ! defined($int_Hour) ) {
						FATAL(qq{Can't distunguish time string "$str_TimeBorder".});
						return(undef);
						}

					$tsp_PeriodStart	= timelocal_modern(0, $int_Minute, $int_Hour, $obj_StartTime->mday, $obj_StartTime->_mon, $obj_StartTime->year);

					# Plausibility check: Day can't start after now
					if ( $tsp_PeriodStart > $tsp_StartTime ) {
						$tsp_PeriodStart	-= INT_OneDay;
						}
					}
				#elsif ( $str_Section eq q{hour}
				#&& $str_TimeBorder =~ m{$rxp_Minute} ) {
					#}

				$tsp_TimeBorder{$str_Section}	= $tsp_PeriodStart;
				}
			else {
				FATAL(qq{Missing time border for section "$str_Section".});
				return(undef);
				}
			}

		DEBUG(sub { return(q{Returning data: } . Dumper({ tsp_TimeBorder => \%tsp_TimeBorder })); });

		return(\%tsp_TimeBorder);
		}
	sub GetName {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Path		= shift;

		DEBUG(qq{File path "$str_Path"...});
		( $str_Path )		= fileparse($str_Path, $rxp_Suffix);
		$str_Path		= fc($str_Path);
		DEBUG(qq{...decodes to name "$str_Path".});

		return($str_Path);
		}
	sub getFilesFromDir {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Search	= shift;	# Already foldcased (fc()) by GetName()
		my @uri_Dirs	= @_;
		my @uri_Matches	= ();

		foreach my $uri_Directory ( @uri_Dirs ) {
			TRACE(qq{Searching in "$uri_Directory".});

			if ( opendir(my $dsc_Dir, $uri_Directory) ) {

				while ( my $str_Element = readdir($dsc_Dir) ) {
					TRACE(qq{Testing Element "$str_Element".});

					if ( fc($str_Element) eq $str_Search ) {
						TRACE(qq{Matches!});

						my $uri_Element	= qq{$uri_Directory/$str_Element};

						if ( -T realpath($uri_Element) ) {
							$uri_Element	=~ s{$rxp_AtLeastTwoSlashes} {/}g;

							TRACE(qq{Adding "$uri_Element" to matches.});

							push(@uri_Matches, $uri_Element);
							}
						}
					}

				closedir($dsc_Dir);
				TRACE(qq{"$uri_Directory" done.});
				}
			else {
				ERROR(qq{Can't read directory "$uri_Directory".});
				}
			}

		DEBUG(sub { return(q{Matches found: } . Dumper({uri_Matches => \@uri_Matches})); });

		return(\@uri_Matches);
		}

	TRACE(qq{Reading config file "$uri_ConfigFile".});
	%har_Config			= (
		uri_File			=> $uri_ConfigFile,
		_str_JobName			=> GetName($uri_ConfigFile),
		har_Content			=> LoadContent($uri_ConfigFile),
		);

	lop_ControlFiles:
	foreach my ( $str_Key, $uri_Dir ) ( q{excludefrom}, $uri_ExcludesDir, q{includefrom}, $uri_IncludesDir ) {

		if ( ! defined($har_Config{har_Content})
		|| ref($har_Config{har_Content}) ne q{HASH} ) {
			DEBUG(q{Got no file content.});

			last(lop_ControlFiles);
			}

		if ( -d $uri_Dir ) {
			my $are_SameNamedFiles	= getFilesFromDir($har_Config{_str_JobName}, $uri_Dir);

			if ( scalar(@{$are_SameNamedFiles}) == 0 ) {
				next(lop_ControlFiles);
				}

			foreach my $str_Section ( ARE_Generations ) {
				if ( defined($har_Config{har_Content}{$str_Section})
				&& defined($har_Config{har_Content}{$str_Section}{$str_Key})
				&& ref($har_Config{har_Content}{$str_Section}{$str_Key}) eq q{ARRAY} ) {
					TRACE(qq{Adding matches to '$str_Section'.'$str_Key'.});

					push(@{$har_Config{har_Content}{$str_Section}{$str_Key}}, @{ dclone($are_SameNamedFiles) });
					}
				elsif ( defined($har_Config{har_Content}{$str_Section})
				&& ref($har_Config{har_Content}{$str_Section}) eq q{HASH} ) {
					TRACE(qq{Creating key '$str_Section'.'$str_Key' with matches.});

					$har_Config{har_Content}{$str_Section}{$str_Key}	= dclone($are_SameNamedFiles);
					}
				else {
					TRACE(qq{Creating section and key '$str_Section'.'$str_Key' with matches.});

					$har_Config{har_Content}{$str_Section}			= {
						$str_Key		=> dclone($are_SameNamedFiles),
						};
					}
				}
			}
		}

	$har_Config{har_Config}			= BuildConfiguration($har_Config{har_Content}, $str_Layer);
	if ( ! defined($har_Config{har_Config}) ) {
		FATAL(qq{Unable to generate configuration from "$uri_ConfigFile".});
		return(undef);
		}

	$har_Config{_uri_BackupLocation}	= qq{$har_Config{har_Config}{_}{destination}[-1]/$har_Config{_str_JobName}} =~ s{$rxp_Slashes} {/}gr;
	$har_Config{_uri_DatabaseLocation}	= qq{$har_Config{har_Config}{_}{destination}[-1]/$str_DefaultDataBaseName} =~ s{$rxp_Slashes} {/}gr;
	$har_Config{_obj_Lock}			= IPC::LockTicket->New(qq{$uri_LockDir/$har_Config{_str_JobName}.lck} =~ s{$rxp_Slashes} {/}gr, 0600);
	$har_Config{_har_TimeBorderUNIX}	= CalculateTimeBordersUNIX($har_Config{har_Config});
	$har_Config{_har_LocationBlocks}	= CalculateLocationBlocks($har_Config{har_Config});

	#TRACE(q{Database initialisation requires global pre-runs.});
	#GlobalPreRun() or return(false);
	#InitDatabase($har_Config{_uri_DatabaseLocation});
	#GlobalPostRun();

	DEBUG(sub { return(qq{Configuration loaded: } . Dumper({ har_Config => \%har_Config })); });

	return(\%har_Config);
	}

sub InitDatabase {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $uri_Target		= shift;

	if ( -s $uri_Target ) {
		TRACE(q{Database found.});
		}
	elsif ( ! -s $uri_Target ) {
		TRACE(qq{Database "$uri_Target" not found. Creating.});
		foreach my $sql_Statement ( split(q{;}, $str_Data{database_infrastructure}) ) {
			if ( ! QueryDB($uri_Target, $sql_Statement) ) {
				FATAL(qq{Statement >$sql_Statement< failed.});
				GlobalPostRun();
				return(false);
				}
			}
		}
	elsif ( ! -B $uri_Target ) {
		FATAL(qq{Element "$uri_Target" does not look like a SQLite database!});
		GlobalPostRun();
		return(false);
		}

	DEBUG(q{Done.});
	return(true);
	}

sub ShowVersion () {
	#TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	print qq{$str_AppName $ver_AppVersion, running on Perl $^V\n};
	}

sub Usage {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	print $str_Data{Usage};
	exit($_[0]);
	}

sub ShowManpage () {
	#TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });

	LOGDIE(qq{Use: man $str_AppName});
	}

sub CheckEnvironment {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $bol_Errors		= false;

	if ( $< != 0 ) { # Root's uid is 0
		my $str_Username	= $ENV{LOGNAME}
			// $ENV{USER}
			// getpwuid($<);

		FATAL(qq{"$str_Username" is not privileged to run this application.});
		$bol_Errors	= true;
		}

	if ( qq{$]} < $flt_MinPerlVersion ) {
		FATAL(qq{Perl $^V is insufficient. You need at least Perl $ver_MinPerlVersion to run $str_AppName!});
		$bol_Errors	= true;
		}

	if ( $bol_Errors ) {
		exit(7);
		}

	return(true);
	}

lop_LoggingENV: {
	my $bol_DebuggingActive		= undef;

	sub IsDebugging {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });

		if ( $bol_DebuggingActive ) {
			TRACE(q{Debugging active.});
			return(true);
			}
		else {
			INFO(q{Debugging disabled.});
			return(false);
			}
		}

	sub SetupLoggers {
		my $are_Args		= dclone(\@_);
		my $int_LogLevel	= shift;
		my $int_Verbose		= shift;
		my @int_Levels		= qw( FATAL ERROR WARN INFO DEBUG TRACE );
		my $str_LogLevel	= $int_Levels[$int_LogLevel] // $int_Levels[-1];
		my $str_VerbosityLevel	= $int_Levels[$int_Verbose] // $int_Levels[-1];
		my $str_RootLogger	= ( $int_LogLevel > $int_Verbose ? $int_Levels[$int_LogLevel] : $int_Levels[$int_Verbose] ) // q{ALL};
		state $int_CurrentVerbose	= undef;
		state $int_CurrentLogLevel	= undef;
		#						DATE                PID  PRIO FILE:LINE MODULE
		my $str_SimpleLogLayout			= q{%p> %m{indent,chomp}%n};
		#my $str_FullLogLayout			= qq{%d{yyyy-MM-dd}T%d{HH:mm:ss} %Q%P %F{1}::%L %M $str_SimpleLogLayout};
		my $str_FullLogLayout			= qq{%D %Q%P %F{1}::%L %M $str_SimpleLogLayout};
		Log::Log4perl::Layout::PatternLayout::add_global_cspec(q{Q}, sub { return( $$ == $pid_Parent ? q{P} : q{C}); });	# Decides between Child or Parent
		Log::Log4perl::Layout::PatternLayout::add_global_cspec(q{D}, sub () {
			state $obj_Now			= undef;	# Do not unset this variable to increase speed
			$obj_Now			= localtime();

			return(sprintf(q{%s%+03d:%02d},
				$obj_Now->datetime,
				$obj_Now->tzoffset->hours,
				$obj_Now->tzoffset->minutes % 60,
				));
			});

		my %str_Configuration		= (
			q{log4perl.rootLogger}							=> qq{$str_RootLogger,ScreenOUT,ScreenERR,Logfile},

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
			q{log4perl.appender.ScreenERR.Threshold}				=> $str_VerbosityLevel,
			q{log4perl.appender.ScreenERR.Filter}					=> qq{ScreenERR},
			q{log4perl.appender.ScreenERR.layout}					=> qq{Log::Log4perl::Layout::PatternLayout},
			q{log4perl.appender.ScreenERR.layout.ConversionPattern}			=> $int_Verbose >= 4 ? $str_FullLogLayout : $str_SimpleLogLayout,

			q{log4perl.appender.ScreenOUT}						=> qq{Log::Log4perl::Appender::Screen},
			q{log4perl.appender.ScreenOUT.stderr}					=> false,
			q{log4perl.appender.ScreenOUT.utf8}					=> true,
			q{log4perl.appender.ScreenOUT.Threshold}				=> $str_VerbosityLevel,
			q{log4perl.appender.ScreenOUT.Filter}					=> qq{ScreenOUT},
			q{log4perl.appender.ScreenOUT.layout}					=> qq{Log::Log4perl::Layout::PatternLayout},
			q{log4perl.appender.ScreenOUT.layout.ConversionPattern}			=> $int_Verbose >= 4 ? $str_FullLogLayout : $str_SimpleLogLayout,

			q{log4perl.appender.Logfile}						=> qq{Log::Log4perl::Appender::File},
			q{log4perl.appender.Logfile.filename}					=> $uri_LogFile,
			q{log4perl.appender.Logfile.mode}					=> qq{append},
			q{log4perl.appender.Logfile.utf8}					=> true,
			q{log4perl.appender.Logfile.Threshold}					=> $str_LogLevel,
			q{log4perl.appender.Logfile.recreate}					=> false,
			q{log4perl.appender.Logfile.layout}					=> qq{Log::Log4perl::Layout::PatternLayout},
			q{log4perl.appender.Logfile.layout.ConversionPattern}			=> $str_FullLogLayout,
			);

		if ( ! Log::Log4perl->initialized()
		|| ! defined($int_CurrentVerbose)
		|| ! defined($int_CurrentLogLevel)
		|| $int_CurrentVerbose != $int_Verbose
		|| $int_CurrentLogLevel != $int_LogLevel ) {

			TRACE(q{Reinitializing logger.});
			Log::Log4perl->init(\%str_Configuration);
			my $obj_Logger		= Log::Log4perl->get_logger();

			if ( $obj_Logger ) {
				TRACE(q{Logger initialized.});
				}
			else {
				LOGDIE(q{Can't initialize logger properly.});
				die q{Can't initialize logger properly.};
				return(false);
				}

			$int_CurrentVerbose	= $int_Verbose;
			$int_CurrentLogLevel	= $int_LogLevel;

			if ( $obj_Logger->is_debug()
			|| $obj_Logger->is_trace() ) {
				require Data::Dumper; 
				Data::Dumper->import();

				$bol_DebuggingActive	= true;
				}
			else {
				$bol_DebuggingActive	= false;
				}
			}

		#TRACE()	# Stepwise checks, e.g. for loops
		#DEBUG();	# Data required for variable content checking, mostly used for Data::Dumper()
		#INFO();	# Output which is no error but should be told about. (Mostly logged only)
		#WARN();	# For errors, which doesn't change the sequence, doesn't omitt anything
		#ERROR();	# For redo(), and next() or last()
		#FATAL();	# For exit(), and return(), sometimes last()
		#LOGEXIT();
		#LOGWARN();	# This also triggers Perl's warn function
		#LOGDIE();	# Instead of die

		DEBUG(sub { return(q{Start settings: } . Dumper({ are_Args => $are_Args })); });

		return(true);
		}
	}

sub GetApplicationPath {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $str_App	= shift;
	my $uri_App	= undef;
	my $cmd_Request	= qq{which "$str_App" 2> /dev/null};

	TRACE(qq{Executing >$cmd_Request<.});
	chomp($uri_App	= qx($cmd_Request));

	if ( $uri_App ) {
		DEBUG(qq{Found "$uri_App".});
		return($uri_App);
		}
	else {
		DEBUG(qq{No app found for "$str_App".});
		return(undef);
		}
	}

sub CheckForSystemApplications {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $bol_Succeeded	= true;

	lop_CheckDefaults:
	foreach my $str_Key ( grep { $_ =~ m{$rxp_BinKey} } keys(%har_NeededConfigKeys) ) {
		foreach my $str_Section ( keys(%{$har_NeededConfigKeys{$str_Key}}) ) {

			if ( defined($har_NeededConfigKeys{$str_Key}{$str_Section}{str_default})
			&& IsBinary($har_NeededConfigKeys{$str_Key}{$str_Section}{str_default}) ) {
				DEBUG(qq{"$har_NeededConfigKeys{$str_Key}{$str_Section}{str_default}" is valid.});

				if ( ! -x $har_NeededConfigKeys{$str_Key}{$str_Section}{str_default} ) {
					$bol_Succeeded	= false;
					WARN(qq{"$har_NeededConfigKeys{$str_Key}{$str_Section}{str_default}" is not executable as it should be.});
					}
				}
			elsif ( defined($har_NeededConfigKeys{$str_Key}{$str_Section}{str_default})
			&& -e $har_NeededConfigKeys{$str_Key}{$str_Section}{str_default}
			&& -T realpath($har_NeededConfigKeys{$str_Key}{$str_Section}{str_default})
			&& -x $har_NeededConfigKeys{$str_Key}{$str_Section}{str_default} ) {
				DEBUG(qq{"$har_NeededConfigKeys{$str_Key}{$str_Section}{str_default}" is not a binary as expected, but an executable script.});
				}

			TRACE(sprintf(qq{$str_Section.$str_Key:=%s}, ( defined($har_NeededConfigKeys{$str_Key}{$str_Section}{str_default}) ? qq{"$har_NeededConfigKeys{$str_Key}{$str_Section}{str_default}"} : q{NULL} )));
			}
		}

	DEBUG(sprintf(q{Check is %s.}, $bol_Succeeded
		? q{successful}
		: q{failed}
		));

	return($bol_Succeeded);
	}

sub IsBoolean {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $mxd_Value		= shift;

	if ( ! defined($mxd_Value)
	|| $mxd_Value =~ m{$rxp_BoolValues} ) {
		DEBUG(sprintf(q{Given %s is recognized as a boolean %s.}, ( defined($mxd_Value) ? qq{"$mxd_Value"} : q{NULL} ), ( $mxd_Value ? q{TRUE} : q{FALSE} )));

		return(true);
		}
	else {
		FATAL(sprintf(qq{Given %s is not a boolean. Valid values are: 0, 1, TRUE, and "".}, ( defined($mxd_Value) ? qq{"$mxd_Value"} : q{NULL} )));

		return(false);
		}
	}

sub IsValidIP {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $str_IP		= shift;

	# IPv4
	if ( $str_IP
	&& $str_IP =~ m{$rxp_IPv4} ) {
		my $cnt_Octets	= 0;

		foreach my $int_Part ( split(m{\.}, $str_IP) ) {
			$cnt_Octets++;

			if ( ! defined($int_Part)
			|| $int_Part < 0
			|| $int_Part > 255 ) {
				FATAL(qq{Is no valid IPv4 address.});

				return(undef);
				}
			}

		if ( $cnt_Octets != 4 ) {
			FATAL(qq{Is no valid IPv4 address.});

			return(undef);
			}

		DEBUG(qq{Is an IPv4 address.});

		return(4);
		}
	# IPv6
	elsif ( $str_IP =~ m{$rxp_IPv6} ) {
		DEBUG(qq{Is an IPv6 address.});

		return(6);
		}
	# Invalid
	else {
		INFO(qq{"$str_IP" is no valid IP address.});

		return(undef);
		}
	}

sub PrepareSubCommands {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my @str_SubCommands	= ();
	my @str_EverythingElse	= ();
	# Allows commands to be separated either by white spaces or commas.
	@ARGV			= map { split(q{,}, $_) } @ARGV;

	lop_MakeUnique: {
		my %cnt_Seen	= ();

		@ARGV		= grep { ! $cnt_Seen{$_}++ } @ARGV;
		}

	TRACE(sub { return(qq{Checking ARGV:=[} . ( join(q{,}, map { "$_" } @ARGV) ) . q{] if any is part of } . ( join(q{, }, sort { $a cmp $b } keys(%har_SubCommands)) ) . q{.}); });

	while ( my $str_Argument = shift(@ARGV) ) {
		my $str_FCArgument	= fc($str_Argument);
		TRACE(qq{Argument supplied: "$str_Argument" (folded: "$str_FCArgument").});

		if ( defined($har_SubCommands{$str_FCArgument}) ) {
			TRACE(qq{Sub-command "$str_Argument" activated.});

			$har_SubCommands{$str_FCArgument}{bol_Active}	= true;
			push(@str_SubCommands, $str_FCArgument);
			}
		else {
			TRACE(q{Argument is not a sub-command.});

			if ( $str_Argument =~ m{$rxp_Slashes} ) {
				TRACE(q{Argument is a path.});

				push(@str_EverythingElse, $str_Argument);
				}
			elsif ( $str_Argument eq q{ALL} ) {
				TRACE(q{Argument is a request for all jobs.});

				push(@str_EverythingElse, $str_Argument);
				}
			else {
				TRACE(q{Argument is a job's name. Using folded string.});

				push(@str_EverythingElse, $str_FCArgument);
				}
			}
		}

	@ARGV			= @str_EverythingElse;
	TRACE(sub { return(qq{New ARGV:=[} . ( join(q{,}, map { "$_" } @ARGV) ) . q{].}); });

	if ( scalar(@str_SubCommands) > 2 ) {		# To many
		FATAL(qq{To many sub-commands set: can't only run a limited amount of sub-commands at the});
		FATAL(qq{same time. (See "$0" --help and $str_AppName(1) )});
		exit(6);
		}
	elsif ( scalar(@str_SubCommands) == 2 ) {
		if ( grep { my $str_Given = fc($_) ; not grep { $_ eq $str_Given } qw(backup size) } @str_SubCommands ) {
			FATAL(qq{The sub-commands [} . join(q{,}, map { qq{"$_"} } @str_SubCommands) . q{] can not be ran together.});
			exit(8);
			}
		# Otherwise it's backup and size
		}
	elsif ( scalar(@str_SubCommands) < 1 ) {
		FATAL(qq{No sub-command found. (See "$0" --help and $str_AppName(8) )});
		exit(5);
		}
	# Otherwise it is only one fitting

	DEBUG(q{Sub-commands look good.});

	return(true);
	}

sub RunCommandRemotely {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my %mxd_ReturnData	= (
		str_IPhostname		=> shift,
		cmd_RemoteCommand	=> shift,
		int_ReturnCode		=> undef,
		are_ReturnData		=> [],
		);
	my $obj_OSSH			= Net::OpenSSH->new($mxd_ReturnData{str_IPhostname}, %mxd_DefaultSSHoptions);
	my $dsc_ProcessHandle		= undef;
	my $pid_Child			= undef;

	if ( $obj_OSSH->error() ) {
		FATAL(qq{Unable to establish a ssh connection to "$mxd_ReturnData{str_IPhostname}":\n} . $obj_OSSH->error());
		return(undef);
		}

	if ( ! $mxd_ReturnData{cmd_RemoteCommand} ) {
		FATAL(qq{Got no command to execute. Why is this function called anyway?});
		}

	( $dsc_ProcessHandle, $pid_Child )	= $obj_OSSH->pipe_out({}, qq{$mxd_ReturnData{cmd_RemoteCommand} 2>&1});
	DEBUG(qq{Executing >$mxd_ReturnData{cmd_RemoteCommand}< on host "$mxd_ReturnData{str_IPhostname}", remote PID $pid_Child\nOutput:});

	while ( my $str_Output = readline($dsc_ProcessHandle) ) {
		$str_Output	= decode(q{utf8}, $str_Output, FB_QUIET);
		chomp($str_Output);
		push(@{$mxd_ReturnData{are_ReturnData}}, MergeWithISOtime($str_Output));
		DEBUG($str_Output);
		}

	close($dsc_ProcessHandle);
	$mxd_ReturnData{int_ReturnCode}		= $? >> 8;

	$obj_OSSH->disconnect();

	if ( defined($mxd_ReturnData{int_ReturnCode}) ) {

		DEBUG(sub { return(qq{Answer from $mxd_ReturnData{str_IPhostname} } . Dumper({ mxd_ReturnData => \%mxd_ReturnData, })); });
		return(\%mxd_ReturnData);
		}

	DEBUG(q{Got answer: NULL});
	return(undef);
	}

sub RunShellCommand {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $int_ReturnStatus	= undef;
	my %mxd_ReturnData	= (
		cmd_Line		=> shift,
		int_ReturnCode		=> undef,
		are_ReturnData		=> [],
		);

	if ( ! $mxd_ReturnData{cmd_Line} ) {
		FATAL(q{Got no command?!});
		return(undef);
		}
	elsif ( open(my $dsc_Shell, q{-|}, $mxd_ReturnData{cmd_Line}) ) {
		DEBUG(qq{Executing >$mxd_ReturnData{cmd_Line}<\nOutput:});

		while ( my $str_Output = readline($dsc_Shell) ) {
			chomp($str_Output);
			push(@{$mxd_ReturnData{are_ReturnData}}, MergeWithISOtime($str_Output));
			DEBUG($str_Output);
			}

		close($dsc_Shell);
		$mxd_ReturnData{int_ReturnCode}	= $? >> 8;
		DEBUG(qq{Command exited with return code "$mxd_ReturnData{int_ReturnCode}".});
		}
	else {
		FATAL(qq{Can't even start command >$mxd_ReturnData{cmd_Line}<.});
		return(undef);
		}

	DEBUG(sub { return(q{Command finished: } . Dumper({ mxd_ReturnData => \%mxd_ReturnData })); });

	return(\%mxd_ReturnData);
	}

sub RunJobShellCommands {	# Also required by GlobalRuns (i.e. MAIN config)
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $str_Job		= shift;
	my $str_Section		= shift;
	my $str_Key		= shift;
	my $har_ReturnData	= undef;

	my @har_CmdReplaces	= (
		{ rxp => $rxp_TagJob,		txt => $har_JobsConfigs{$str_Job}{_str_JobName} },
		{ rxp => $rxp_TagPath,		txt => ( $har_JobsConfigs{$str_Job}{_uri_NextBackup} ? $har_JobsConfigs{$str_Job}{_uri_NextBackup} : '' ) },
		{ rxp => $rxp_TagDestination,	txt => $har_JobsConfigs{$str_Job}{_uri_BackupLocation} },
		{ rxp => $rxp_TagLast,		txt => $har_JobsConfigs{$str_Job}{_uri_LastSuccessful} },
		);

	local $SIG{CLD}		= q{DEFAULT};
	local $SIG{CHLD}	= q{DEFAULT};

	if ( defined($har_JobsConfigs{$str_Job}{har_Config}{$str_Section})
	&& defined($har_JobsConfigs{$str_Job}{har_Config}{$str_Section}{$str_Key})
	&& ref($har_JobsConfigs{$str_Job}{har_Config}{$str_Section}{$str_Key}) eq q{ARRAY} ) {
		TRACE(qq{Running "$str_Job" job's shell commands of $str_Section.$str_Key .});

		lop_SingleLineExecution:
		foreach my $cmd_Line ( @{$har_JobsConfigs{$str_Job}{har_Config}{$str_Section}{$str_Key}} ) {

			foreach my $har_SearchAndReplace ( @har_CmdReplaces ) {
				$cmd_Line 		=~ s{$har_SearchAndReplace->{rxp}} {$har_SearchAndReplace->{txt}}g;
				}

			if ( $str_Key =~ m{$rxp_ClientKey}	# Client pre/post run/fail
			&& $har_JobsConfigs{$str_Job}{_str_Remote}
			&& $str_Key =~ m{$rxp_ClientRun} ) {
				$har_ReturnData		= RunCommandRemotely($har_JobsConfigs{$str_Job}{_str_Remote}, $cmd_Line);

				if ( ! defined($har_ReturnData)
				|| $har_ReturnData->{int_ReturnCode} ) {	# Only 0 means success
					FATAL(qq{>$cmd_Line< on $har_JobsConfigs{$str_Job}{_str_Remote} FAILED:\n} . ( defined($har_ReturnData) ? join(qq{\n}, @{$har_ReturnData->{are_ReturnData}}) : q{NULL} ));
					}
				}
			else {
				$har_ReturnData		= RunShellCommand($cmd_Line);

				if ( ! defined($har_ReturnData)
				|| $har_ReturnData->{int_ReturnCode} ) {	# Only 0 means success
					FATAL(qq{>$cmd_Line< FAILED:\n} . ( defined($har_ReturnData) ? join(qq{\n}, @{$har_ReturnData->{are_ReturnData}}) : q{NULL} ));
					}
				}

			if ( $har_JobsConfigs{$str_Job}{_uri_BackupLocation}
			&& ! -d $har_JobsConfigs{$str_Job}{_uri_BackupLocation} ) {
				make_path($har_JobsConfigs{$str_Job}{_uri_BackupLocation});
				}
			if ( $har_JobsConfigs{$str_Job}{_uri_NextLog}
			&& open(my $dsc_LogHandle, q{>>}, $har_JobsConfigs{$str_Job}{_uri_NextLog}) ) {
				print $dsc_LogHandle qq{>$cmd_Line< }
					. ( defined($har_ReturnData) &&  ! $har_ReturnData->{int_ReturnCode} ? q{succeded} : q{failed} )
					. qq{ and returned:\n}
					. ( defined($har_ReturnData) ? join('', @{$har_ReturnData->{are_ReturnData}}) : q{NULL} )
					. qq{\n};

				if ( defined($har_ReturnData)
				&& $har_ReturnData->{int_ReturnCode} ) {	# Only 0 means success
					$har_ReturnData	= undef;

					last(lop_SingleLineExecution);
					}
				}
			elsif ( ! $har_JobsConfigs{$str_Job}{_uri_NextLog} ) {
				DEBUG(qq{>$cmd_Line< returned:\n} . join('', @{$har_ReturnData->{are_ReturnData}}));
				}
			else {
				WARN(qq{Unable to write to '$har_JobsConfigs{$str_Job}{_uri_NextLog}'.});
				}
			}

		DEBUG(q{Done.});
		}
	else {
		DEBUG(q{No commands given. Nothing to do. (Success.)});

		$har_ReturnData	= {};
		}

	return($har_ReturnData);
	}

sub MergeWithISOtime {
	my $str_Text	= shift;
	my $str_ISOtime	= GetISOdateTime();
	my @str_Text	= ();

	if ( $str_Text ) {
		foreach my $str_Line ( split(m{$rxp_NewLine}, $str_Text, -1) ) {
			push(@str_Text, qq{$str_ISOtime  $str_Line\n});
			}
		}
	else {
		push(@str_Text, qq{$str_ISOtime  \n});
		}

	return(join('', @str_Text));
	}

sub GetISOdateTime {
	my $obj_Now	= localtime();

	return(sprintf(q{%s%+03d:%02d},
		$obj_Now->datetime,
		$obj_Now->tzoffset->hours,
		$obj_Now->tzoffset->minutes % 60,
		));
	}

lop_GlobalRuns: {
	my $_obj_GlobalPreRan	= IPC::LockTicket->New(qq{${str_AppName}_Globals}, 0600)
		or die qq{FATAL ERROR on init lop_GlobalRuns!};
	my $_bol_GlobalPreRan	= false;
	my sub _TransportChecker;
	my sub GlobalPreFail;
	my sub GlobalPostFail;

	sub _TransportChecker {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $har_Transport	= shift;

		if ( defined($har_Transport)
		&& ref($har_Transport) eq q{HASH}
		&& defined($har_Transport->{bol_InitDone})
		&& defined($har_Transport->{are_PIDsInProgress})
		&& ref($har_Transport->{are_PIDsInProgress}) eq q{ARRAY} ) {
			DEBUG(q{Transport data look good.});
			return(true);
			}
		else {
			DEBUG(q{Transport data look bad.});
			return(false);
			}
		}

	sub GlobalPreFail	{
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		RunJobShellCommands(q{MAIN}, q{_}, q{globalprefail});
		return(false);
		}
	sub GlobalPostFail	{
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		RunJobShellCommands(q{MAIN}, q{_}, q{globalpostfail});
		return(false);
		}

	sub GlobalsInitialized {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $har_Transport	= undef;

		if ( $_bol_GlobalPreRan ) {
			try {
				# dies if MainLock is not done yet
				TRACE(q{Trying to load custom data.});
				$har_Transport		= $_obj_GlobalPreRan->GetCustomData();
				TRACE(q{Try succeeded.});
				}
			catch ($str_Error) {
				FATAL(q{Try failed. MainLock() not ran yet.});
				return(false);
				}

			if ( _TransportChecker($har_Transport) ) {
				return($har_Transport->{bol_InitDone});
				}
			else {
				return(false);
				}
			}
		else {
			return(false);
			}
		}

	sub GlobalPreRun {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });

		TRACE(q{Acquiring lock...});
		$_obj_GlobalPreRan->MainLock(true) or LOGDIE(q{FATAL ERROR: Not locked.});
		TRACE(q{Got lock.});

		TRACE(q{Acquiring token...});
		$_obj_GlobalPreRan->TokenLock() or LOGDIE(q{FATAL ERROR: Unable to acquire token.});
		TRACE(q{Got token.});

		my $har_Transport		= $_obj_GlobalPreRan->GetCustomData(); # {
			# bol_InitDone		=> <BOL true after init>,
			# are_PIDsInProgress	=> [ <PIDs of processes which depend on a done INIT> ],
			# };
		DEBUG(sub { return(q{Dump of GetCustomData(): } . Dumper({ har_Transport => $har_Transport })) });

		if ( _TransportChecker($har_Transport) ) {
			push(@{$har_Transport->{are_PIDsInProgress}}, $$);
			TRACE(sub { sprintf(qq{Adding myself (%d) to list; new list is [%s].}, $$, join(q{,}, @{$har_Transport->{are_PIDsInProgress}})); });
			}
		else {
			TRACE(qq{har_Transport is empty. Creating structure.});
			$har_Transport		= {
				bol_InitDone		=> false,
				are_PIDsInProgress	=> [ $$ ],
				};
			}

		if ( ! $har_Transport->{bol_InitDone} ) {
			TRACE(q{Global Pre Runs were not ran yet. Executing them. (If any.)});

			if ( RunJobShellCommands(q{MAIN}, q{_}, q{globalprerun}) ) {
				DEBUG(q{Global Pre Runs succeeded.});
				$har_Transport->{bol_InitDone}	= true;
				}
			else {
				DEBUG(q{Global Pre Runs failed.});
				GlobalPreFail();
				TRACE(q{Disposing token...});
				$_obj_GlobalPreRan->TokenUnlock();
				TRACE(q{Token freed.});
				return(false);
				}
			}

		TRACE(sub { return(q{Writing har_Transport back. Dump: } . Dumper({ har_Transport => $har_Transport })); });
		if ( ! $_obj_GlobalPreRan->SetCustomData($har_Transport) ) {
			FATAL(q{Unable to write shm back. Calling Global Post Run to reverse changes.});
			GlobalPostRun();
			TRACE(q{Disposing token...});
			$_obj_GlobalPreRan->TokenUnlock();
			TRACE(q{Token freed.});
			return(false);
			}

		$_bol_GlobalPreRan	= true;

		TRACE(q{Done});
		TRACE(q{Disposing token...});
		$_obj_GlobalPreRan->TokenUnlock();
		TRACE(q{Token freed.});
		return(true);
		}

	sub GlobalPostRun {
		TRACE(q{Acquiring token...});
		$_obj_GlobalPreRan->TokenLock();
		TRACE(q{Got token.});

		local $SIG{CHLD}		= q{IGNORE};
		local $SIG{CLD}			= q{IGNORE};

		my $har_Transport		= $_obj_GlobalPreRan->GetCustomData();
		TRACE(sub { return(q{Dump of custom data block: } . Dumper({ har_Transport => $har_Transport })); });

		if ( _TransportChecker($har_Transport) ) {
			# Remove myself and not running processes
			$har_Transport->{are_PIDsInProgress}		=
				[ grep { $_ != $$ && kill(0 => $_) } @{$har_Transport->{are_PIDsInProgress}} ];

			if ( ! @{$har_Transport->{are_PIDsInProgress}}
			&& $har_Transport->{bol_InitDone} ) {
				TRACE(q{No more processes requrie the globals initialized. Running global post runs.});

				if ( RunJobShellCommands(q{MAIN}, q{_}, q{globalpostrun}) ) {
					TRACE(q{Global Post Run done.});
					$har_Transport->{bol_InitDone}	= false;
					}
				else {
					ERROR(q{Global Post Run failed!});
					}
				}
			}

		TRACE(sub { return(q{Saving har_Transport back. Dump: } . Dumper({ har_Transport => $har_Transport })); });
		if ( ! $_obj_GlobalPreRan->SetCustomData($har_Transport) ) {
			FATAL(q{Unable to write shm back. Calling Global Post Run to reverse changes.});
			TRACE(q{Disposing token...});
			$_obj_GlobalPreRan->TokenUnlock();
			TRACE(q{Token freed.});
			return(false);
			}

		DEBUG(q{Done.});
		TRACE(q{Disposing token...});
		$_obj_GlobalPreRan->TokenUnlock();
		TRACE(q{Token freed.});
		TRACE(q{Disposing lock...});
		$_obj_GlobalPreRan->MainUnlock();
		TRACE(q{Lock freed.});

		$_bol_GlobalPreRan	= false;

		return(true);
		}

	sub QueryDB {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $uri_Database	= shift;
		my $sql_Statement	= shift;
		my $are_Arguments	= shift;	# For ? in Statement
		my @har_Results		= ();
		my $obj_Database	= undef;
		my $cnt_Retries		= 3;
		my $bol_NestedArray	= false;
		my sub _InterruptHandler;

		sub _InterruptHandler {
			FATAL(q{Interrupted by user.});

			if ( $bol_NestedArray ) {
				$obj_Database->rollback();
				}

			$obj_Database->disconnect();

			TRACE(q{Disposing token...});
			$_obj_GlobalPreRan->TokenUnlock();
			TRACE(q{Token freed.});

			GlobalPostRun() or exit(121);
			exit(120);
			}

		# Duplicate of start
		#DEBUG(sub { return(q{Got arguments: } . Dumper({
		#	uri_Database		=> $uri_Database,
		#	sql_Statement		=> $sql_Statement,
		#	are_Arguments		=> $are_Arguments
		#	})); });

		if ( defined($are_Arguments)
		&& ref($are_Arguments) ne q{ARRAY} ) {
			LOGDIE(qq{FATAL ERROR: Given argument is not an array.});
			}

		TRACE(q{Acquiring token...});
		$_obj_GlobalPreRan->TokenLock();
		TRACE(q{Got token.});
		local $SIG{INT}	= \&_InterruptHandler;
		local $SIG{HUP}	= \&_InterruptHandler;

		lop_Retry: {
			try {
				my $obj_StatementHandle	= undef;
				my $are_Columns		= [];
				TRACE(q{Connecting to database.});
				$obj_Database		= DBI->connect(
					sprintf(STR_DSN, $uri_Database),
					( $ENV{USER} // $ENV{LOGNAME} ),
					'',
					{
						AutoCommit	=> true,
						RaiseError	=> true,
						PrintError	=> false,
						},
					) or LOGDIE(qq{FATAL: Can't connect to database "$uri_Database".});

				TRACE(q{Setting up foreign keys via >} . SQL_PragmaForeignKeys . q{<.});
				$obj_Database->do(SQL_PragmaForeignKeys);
				TRACE(q{Fixating journal mode to file via >} . SQL_PragmaJournalMode . q{<.});
				$obj_Database->do(SQL_PragmaJournalMode);
				TRACE(q{Increasing write speed via >} . SQL_PragmaSynchronousNormal . q{<.});
				$obj_Database->do(SQL_PragmaSynchronousNormal);

				TRACE(qq{Preparing >$sql_Statement<.});
				$obj_StatementHandle	= $obj_Database->prepare($sql_Statement);

				TRACE(q{Executing...});
				if ( ref($are_Arguments) eq q{ARRAY} ) {
					if ( ref($are_Arguments->[0]) eq q{ARRAY} ) {
						TRACE(q{Got a nested array.});

						TRACE(q{Increasing write speed further via >} . SQL_PragmaSynchronousOff . q{<.});
						$obj_Database->do(SQL_PragmaSynchronousOff);

						$obj_Database->begin_work;
						$bol_NestedArray			= true;
						foreach my $har_Row ( @{$are_Arguments} ) {
							TRACE(sub { sprintf(q{Inserting har_Row:=[%s]}, join(q{,}, map { defined($_) ? qq{"$_"} : q{NULL} } @{$har_Row})); });
							$obj_StatementHandle->execute(@{$har_Row});

							if ( defined($obj_StatementHandle->{NAME}) ) {
								TRACE(q{Fetching data (if any).});
								$are_Columns		= $obj_StatementHandle->{NAME};

								while ( my @mxd_Row = $obj_StatementHandle->fetchrow_array() ) {
									push(@har_Results, { map { $are_Columns->[$_] => decode(q{utf8}, $mxd_Row[$_], FB_QUIET) } 0 .. $#{$are_Columns} });
									}
								}
							}
						$obj_Database->commit;
						$bol_NestedArray			= false;
						}
					else {
						TRACE(sub { sprintf(q{...are_Arguments:=[%s]}, join(q{,}, map { defined($_) ? qq{"$_"} : q{NULL} } @{$are_Arguments})); });
						$obj_StatementHandle->execute(@{$are_Arguments});
						}
					}
				else {
					TRACE(q{Executing basic statment.});
					$obj_StatementHandle->execute();
					}

				if ( ! $bol_NestedArray
				&& defined($obj_StatementHandle->{NAME}) ) {
					TRACE(q{Fetching data (if any).});
					$are_Columns		= $obj_StatementHandle->{NAME};

					while ( my @mxd_Row = $obj_StatementHandle->fetchrow_array() ) {
						# SQLite is not utf8 safe so we need to translate it manually!
						push(@har_Results, { map { $are_Columns->[$_] => decode(q{utf8}, $mxd_Row[$_], FB_QUIET) } 0 .. $#{$are_Columns} });
						}
					}

				#TRACE(sub { return(q{Dump: } . Dumper({ har_Results => \@har_Results })); });

				$obj_Database->do(SQL_PragmaOptimize);
				$obj_Database->disconnect();
				}
			catch ($str_Error) {
				ERROR(qq{Database access failed: $str_Error});

				if ( $DBI::err ) {
					ERROR(qq{DBI reports "$DBI::err":="$DBI::errstr".});
					}

				if ( $cnt_Retries-- > 0 ) {
					INFO(qq{Retrying... ($cnt_Retries/3)});
					if ( $bol_NestedArray ) {
						$obj_Database->rollback();
						}
					sleep(5);
					redo(lop_Retry);
					}
				else {
					FATAL(q{Unable to process the query!});
					if ( $bol_NestedArray ) {
						$obj_Database->rollback();
						}
					$obj_Database->do(SQL_PragmaOptimize);
					$obj_Database->disconnect();
					TRACE(q{Disposing token...});
					$_obj_GlobalPreRan->TokenUnlock();
					TRACE(q{Token freed.});
					FATAL(q{Query failed.});
					return(undef);
					}
				}
			}

		TRACE(q{Disposing token...});
		$_obj_GlobalPreRan->TokenUnlock();
		TRACE(q{Token freed.});

		DEBUG(sub { return(qq{Query succeeded. Database result dump: } . Dumper({ har_Results => \@har_Results })); });

		# Empty array ref is success, undef is failure
		return(\@har_Results);
		}
	}

sub GetBackupDirectories {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $uri_JobDirectory	= shift;
	my @har_Directories	= (
		# {
		#	uri_Path	=> <URI full path>,
		#	str_Name	=> <STR dir name>,
		#	str_Generation	=> <STR Generation (year|month|week|day|hour)>,
		#	bol_Succeeded	=> <BOL>,
		#	tsp_mtime	=> <TSP mtime of folder>,
		#	int_statinode	=> <INT inode by stat()>,
		#	tsp_statmtime	=> <TSP mtime by stat()>,
		#	},
		);

	if ( ! GlobalsInitialized() ) {
		LOGDIE(qq{FATAL: Programmatical failure: GlobalPreRun not run or failed!});
		}
	elsif ( -e $uri_JobDirectory
	&& -d realpath($uri_JobDirectory)
	&& opendir(my $dsc_DirectoryHandle, $uri_JobDirectory) ) {
		while ( my $str_Name = readdir($dsc_DirectoryHandle) ) {
			my $uri_Path	= qq{$uri_JobDirectory/$str_Name};
			$uri_Path	= NormalizePath($uri_Path);

			TRACE(qq{Processing "$uri_Path".});

			if ( -d realpath($uri_Path)
			&& $str_Name =~ m{$rxp_Directory} ) {
				push(@har_Directories, {
					uri_Path	=> $uri_Path,
					str_Name	=> $str_Name,
					str_Generation	=> GetGenerationByDirName($str_Name),
					bol_Succeeded	=> GetBackupStatusFromDB((fileparse($uri_JobDirectory))[1,0], $str_Name),
					tsp_mtime	=> GetSetMtime($uri_Path),	# Used for backup status
					int_statinode	=> do { my @stat = stat($uri_Path); $stat[1]; },
					tsp_statmtime	=> do { my @stat = stat($uri_Path); $stat[9]; },	# Used for sizing
					});
				}
			}
		closedir($dsc_DirectoryHandle);

		DEBUG(sub { return(q{Found directories: } . Dumper({ har_Directories => \@har_Directories })); });
		}
	elsif ( -e $uri_JobDirectory
	&& -d realpath($uri_JobDirectory) ) {
		FATAL(qq{Unable to open "$uri_JobDirectory".});
		return(undef);
		}
	else {
		DEBUG(qq{"$uri_JobDirectory" - No such file or directory.});
		}

	return(\@har_Directories);
	}

sub GetSetMtime {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $uri_DirName		= shift;
	my $uri_Realpath	= realpath($uri_DirName);
	my $tsp_SetMtime	= undef;
	my($str_DirName)	= fileparse($uri_DirName);

	TRACE(qq{Checking "$uri_DirName".});

	if ( $str_DirName =~ m{$rxp_Directory} ) {
		TRACE(q{Matched!});
		$tsp_SetMtime	= timelocal_modern($6, $5, $4, $3, $2 - 1, $1);
		if ( $tsp_SetMtime ) {
			TRACE(qq{Got tsp_SetMtime:=$tsp_SetMtime .});
			}
		else {
			LOGDIE(qq{timelocal_modern() failed.});
			}
		}
	else {
		TRACE(q{No parseable directory, using stat().});
		(undef,undef,undef,undef,undef,undef,undef,undef,undef,	# Ignore 9 to get 10
		$tsp_SetMtime)	= stat($uri_Realpath);
		}

	DEBUG(sprintf(q{Time calculated: "%s".}, scalar(localtime($tsp_SetMtime))));

	return($tsp_SetMtime);
	}

sub GetGenerationByDirName {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $str_DirName		= shift;
	my $str_Generation	= undef;

	if ( $str_DirName =~ m{$rxp_DirectoryHour} ) {
		$str_Generation	= q{hour};
		}
	elsif ( $str_DirName =~ m{$rxp_DirectoryDay} ) {
		$str_Generation	= q{day};
		}
	elsif ( $str_DirName =~ m{$rxp_DirectoryWeek} ) {
		$str_Generation	= q{week};
		}
	elsif ( $str_DirName =~ m{$rxp_DirectoryMonth} ) {
		$str_Generation	= q{month};
		}
	elsif ( $str_DirName =~ m{$rxp_DirectoryYear} ) {
		$str_Generation	= q{year};
		}
	else {
		FATAL(q{No generation matching.});
		}

	DEBUG(qq{Generation:=$str_Generation});

	return($str_Generation);
	}

sub GetBackupStatusFromDB {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $uri_Destination	= shift;
	my $str_Job		= shift;
	my $str_DirName		= shift;
	my $uri_Database	= $har_JobsConfigs{$str_Job}{_uri_DatabaseLocation};

	if ( ! GlobalsInitialized() ) {
		LOGDIE(qq{FATAL: Programmatical failure: GlobalPreRun not run or failed!});
		}

	if ( $uri_Database
	&& -e $uri_Database ) {
		#my $str_SQLescaped	= $str_DirName =~ s{$rxp_SQLlikeCharacters} {\\$1}rg;
		#my $are_Result		= QueryDB($uri_Database, $sql_SelectStatusByJobAndDir, [ $str_Job, $str_SQLescaped ]);
		my $are_Result		= QueryDB($uri_Database, $sql_SelectStatusByJobAndDir, [ $str_Job, $str_DirName ]);

		if ( ref($are_Result) ) {
			# Value of are_Result was logged by QueryDB().
			if ( defined($are_Result->[0]{successful}) ) {
				DEBUG(qq{Got successful:="$are_Result->[0]{successful}".});

				return( $are_Result->[0]{successful} ? true : false);
				}
			else {
				DEBUG(qq{Got NULL for "$str_DirName".});

				return(undef);
				}
			}
		else {
			DEBUG(qq{Query failed - assuming NULL.});

			return(undef);
			}
		}
	else {
		DEBUG(qq{"$uri_Database": No such file.});

		return(undef);
		}
	}

sub ExpandARGV {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });

	if ( grep { $_ eq q{ALL} } @ARGV ) {
		DEBUG(q{Argument requests all known jobs.});
		@ARGV		= sort { $a cmp $b } keys(%har_JobsConfigs);
		}

	if ( ! IsDebugging() ) {
		@ARGV		= grep { $_ ne q{MAIN} } @ARGV;
		}

	DEBUG(sprintf(q{Returning ARGV:=[%s]}, join(q{,}, map { qq{"$_"} } @ARGV)));

	return(@ARGV);
	}

sub ShowConfiguration {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my @str_ActiveJobs		= ExpandARGV();

	if ( ! $har_SubCommands{show}{bol_Active} ) {
		DEBUG(q{Show is not active.});
		return(true);
		}

	TRACE(q{Loading Data::Dumper.});
	require Data::Dumper;
	Data::Dumper->import();
	TRACE(q{Loaded.});

	print qq{This are dumps of the jobs how they were loaded.\n};
	foreach my $str_Job ( @str_ActiveJobs ) {
		print Dumper({ $str_Job => $har_JobsConfigs{$str_Job}{har_Config} });
		}

	TRACE(q{Done.});

	return(true);
	}

sub BackupAndSize {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my @str_ActiveJobs		= ExpandARGV();
	my sub ClientAnswersSSH;
	my sub ClientPongs;
	my sub DBInsertJob;
	my sub DBProtocolBackupStatus;
	my sub GetLastBackup;
	my sub GetLastSuccessful;
	my sub GetNextGeneration;
	my sub PrepareJob;
	my sub ServerPreRun;
	my sub ClientPreRun;
	my sub ClientPostRun;
	my sub ServerPostRun;
	my sub ServerPreFail;
	my sub ClientPreFail;
	my sub ClientPostFail;
	my sub ServerPostFail;
	my sub Cleanup;
	my sub Backup;
	my sub Sizing;
	my sub _FastSequenceSteps;
	my sub _FastSequenceCleanup;
	my sub FastSequence;
	my sub ParallelFastSequence;
	my sub _NormalSequenceSteps;
	my sub NormalSequence;
	my sub ParallelNormalSequence;

	if ( ! $har_SubCommands{backup}{bol_Active}
	&& ! $har_SubCommands{size}{bol_Active} ) {
		DEBUG(q{Weither backup nor sizing is active.});
		return(true);
		}
	elsif ( scalar(@str_ActiveJobs) < 1 ) {
		FATAL(qq{To few arguments! One required.});
		return(false);
		}

	## Prepare for Children if neccessary
	#if ( ! $bol_Wait
	#|| $bol_Parallel ) {
	#	$SIG{CHLD}				= q{IGNORE};
	#	$SIG{CLD}				= q{IGNORE};
	#	TRACE(q{$SIG{CLD} and $SIG{CHLD} are now set to IGNORE.});
	#	}

	sub ClientAnswersSSH {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job			= shift;
		my $cmd_Remotely		= q{hostname -f 2>/dev/null || echo ; }		# 0=hostname, 1=rsync path, 2=nice path, 3=ionice path
			. q{which rsync 2>/dev/null || echo ; }
			. ( $har_JobsConfigs{$str_Job}{har_Config}{_}{niceclient}[0]
				? q{which nice 2>/dev/null || echo ; }
					. q{which ionice 2>/dev/null || echo }
					. q{uname -s || echo }
				: '' );
		my $har_ReturnData		= RunCommandRemotely($har_JobsConfigs{$str_Job}{_str_Remote}, $cmd_Remotely);
		my $bol_Return			= true;

		# Success
		if ( defined($har_ReturnData) ) {
			DEBUG(qq{Reply from $har_JobsConfigs{$str_Job}{_str_Remote} for `$har_ReturnData->{cmd_RemoteCommand}`:\n} . join('', @{$har_ReturnData->{are_ReturnData}}));

			if ( $har_ReturnData->{int_ReturnCode} ) {
				DEBUG(qq{Execution failed.});
				return(false);
				}

			if ( ! defined($har_JobsConfigs{$str_Job}{har_Config}{_}{hostname}[0])
			&& defined($har_ReturnData->{are_ReturnData}[0])
			&& $har_ReturnData->{are_ReturnData}[0] =~ m{$rxp_ValidHostName} ) {
				$har_JobsConfigs{$str_Job}{har_Config}{_}{hostname}[0] = $har_ReturnData->{are_ReturnData}[0];

				TRACE(qq{No hostname was set through configuration. Talking name given by host itself: "$har_ReturnData->{are_ReturnData}[0]".});
				}

			if ( $har_ReturnData->{are_ReturnData}[1] ) {
				DEBUG(qq{Found remote rsync at '$har_JobsConfigs{$str_Job}{_str_Remote}:$har_ReturnData->{are_ReturnData}[1]'.});
				}
			else {
				FATAL(qq{No rsync found on '$har_JobsConfigs{$str_Job}{_str_Remote}' (for job '$str_Job').});

				$bol_Return			= false;
				}

			if ( $har_JobsConfigs{$str_Job}{har_Config}{_}{niceclient}[0] ) {
				my $str_RemoteSystemType	= undef;

				# System
				if ( $har_ReturnData->{are_ReturnData}[4] ) {
					DEBUG(qq{Remote system looks like a '$har_ReturnData->{are_ReturnData}[4]'.});

					$str_RemoteSystemType	= $har_ReturnData->{are_ReturnData}[4];
					}
				else {
					WARN(qq{Got no reply from `uname -s`.});

					$str_RemoteSystemType	= '';
					}

				# Nice
				if ( $har_ReturnData->{are_ReturnData}[2] ) {
					DEBUG(qq{Found remote nice at '$har_JobsConfigs{$str_Job}{_str_Remote}:$har_ReturnData->{are_ReturnData}[2]'.});
					}
				else {
					FATAL(qq{No nice found on '$har_JobsConfigs{$str_Job}{_str_Remote}' (for job '$str_Job').});

					$bol_Return		= false;
					}

				# IONice
				if ( $har_ReturnData->{are_ReturnData}[3] ) {
					DEBUG(qq{Found remote ionice at '$har_JobsConfigs{$str_Job}{_str_Remote}:$har_ReturnData->{are_ReturnData}[3]'.});
					}
				else {
					if ( fc($str_RemoteSystemType) ne fc(q{FreeBSD}) ) {
						FATAL(qq{No ionice found on '$har_JobsConfigs{$str_Job}{_str_Remote}' (for job '$str_Job').});

						$bol_Return	= false;
						}
					else {
						INFO(qq{FreeBSD has no ionice.});
						}
					}
				}
			}
		else {
			FATAL(qq{Unable to ssh to '$har_JobsConfigs{$str_Job}{_str_Remote}' (for job '$str_Job') at all.});

			$bol_Return	= false;
			}

		return($bol_Return);
		}

	sub ClientPongs {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job			= shift;

		if ( ! $har_JobsConfigs{$str_Job}{har_Config}{_}{pingcheck}[0] ) {
			DEBUG(qq{Ping is disabled by user.});

			return(true);
			}
		elsif ( defined($har_JobsConfigs{$str_Job}{_str_Remote}) ) {
			my $int_Family		= IsValidIP($har_JobsConfigs{$str_Job}{_str_Remote});
			my $bol_PingSuccess	= undef;
			my $str_IPv46		= undef;
			my $obj_Ping		= defined($int_Family) && $int_Family == 6
				? Net::Ping->new(q{icmpv6})
				: Net::Ping->new(q{icmp});

			if ( defined($int_Family)
			&& $int_Family == 6 ) {
				TRACE(q{Pinging via IPv6.});
				}
			else {
				TRACE(q{Pinging via IPv4.});
				}

			if ( $obj_Ping ) {
				TRACE(q{Created Net::Ping object.});
				}
			else {
				TRACE(q{Unable to create Net::Ping object.});
				return(undef);
				}

			TRACE(q{Pinging...});
			($bol_PingSuccess, undef, $str_IPv46) = defined($int_Family) && $int_Family == 6
				? $obj_Ping->ping($har_JobsConfigs{$str_Job}{_str_Remote}, $int_PingTimeout / 2, 6)
				: $obj_Ping->ping($har_JobsConfigs{$str_Job}{_str_Remote}, $int_PingTimeout / 2, 4);

			# IPv6 failed
			if ( defined($bol_PingSuccess)
			&& ! $bol_PingSuccess
			&& defined($int_Family)
			&& $int_Family == 6 ) {
				TRACE(q{No pong recieved. Trying IPv4.});

				$obj_Ping				= Net::Ping->new(q{icmp});
				($bol_PingSuccess, undef, $str_IPv46)	= $obj_Ping->ping($har_JobsConfigs{$str_Job}{_str_Remote}, $int_PingTimeout / 2, 4);
				}
			# IPv4 failed
			elsif ( defined($bol_PingSuccess)
			&& ! $bol_PingSuccess ) {
				TRACE(q{No pong recieved. Trying IPv6.});

				$obj_Ping				= Net::Ping->new(q{icmpv6});
				($bol_PingSuccess, undef, $str_IPv46)	= $obj_Ping->ping($har_JobsConfigs{$str_Job}{_str_Remote}, $int_PingTimeout / 2, 6);
				}

			if ( ! defined($int_Family)
			&& $bol_PingSuccess
			&& ( $str_IPv46 =~ m{$rxp_IPv4}
			|| $str_IPv46 =~ m{$rxp_IPv6} ) ) {
				TRACE(qq{Remote address "$har_JobsConfigs{$str_Job}{_str_Remote}" looks not like a IP address. Setting to recieved "$str_IPv46".});

				$har_JobsConfigs{$str_Job}{_str_RemoteBAK}	= $har_JobsConfigs{$str_Job}{_str_Remote};
				$har_JobsConfigs{$str_Job}{_str_Remote}		= $str_IPv46;
				}
			elsif ( ! defined($bol_PingSuccess) ) {
				TRACE(qq{"$har_JobsConfigs{$str_Job}{_str_Remote}": Bad IP address or host not found.});
				}

			DEBUG(q{Host "} . ( $har_JobsConfigs{$str_Job}{_str_RemoteBAK} // $har_JobsConfigs{$str_Job}{_str_Remote} ) . q{" is } . ( $bol_PingSuccess ? '' : q{un} ) . q{reachable.});
			$obj_Ping->close();
			return($bol_PingSuccess);
			}
		else {
			DEBUG(q{Host ist local.});
			return(true);
			}
		}

	sub DBInsertJob {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job			= shift;
		my $are_Result			= undef;

		InitDatabase($har_JobsConfigs{$str_Job}{_uri_DatabaseLocation}) or return(undef);

		$are_Result	= QueryDB($har_JobsConfigs{$str_Job}{_uri_DatabaseLocation}, $sql_InsertJob, [
			$har_JobsConfigs{$str_Job}{_str_JobName},
			]);

		if ( defined($are_Result) ) {
			DEBUG(q{Success.});

			return(true);
			}
		else {
			DEBUG(q{Failure.});

			return(false);
			}
		}

	sub DBProtocolBackupStatus {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;

		if ( ! GlobalsInitialized() ) {
			LOGDIE(qq{FATAL: Programmatical failure: GlobalPreRun not run or failed!});
			}

		InitDatabase($har_JobsConfigs{$str_Job}{_uri_DatabaseLocation}) or return(undef);

		if ( $har_JobsConfigs{$str_Job}{_uri_DatabaseLocation}
		&& -e $har_JobsConfigs{$str_Job}{_uri_NextBackup} ) {

			DBInsertJob($str_Job) or return(false);

			my $are_Result	= QueryDB($har_JobsConfigs{$str_Job}{_uri_DatabaseLocation}, $sql_InsertBackupStatus, [
				$har_JobsConfigs{$str_Job}{_str_JobName},
				do {
					my @stat	= stat($har_JobsConfigs{$str_Job}{_uri_NextBackup});
					( $stat[1] , $stat[9] );	# inode and mtime
					},
				do {
					my @str_Dir	= fileparse($har_JobsConfigs{$str_Job}{_uri_NextBackup});
					$str_Dir[0];
					},
				$har_JobsConfigs{$str_Job}{_uri_NextBackup},
				$har_JobsConfigs{$str_Job}{_bol_Succeeded},
				]);

			if ( defined($are_Result) ) {
				DEBUG(q{Success.});
				return(true);
				}
			else {
				DEBUG(q{Failure.});
				return(false);
				}
			}
		}

	sub GetLastBackup {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;
		my $uri_Searched	= undef;
		my $are_ExistingBackups	= GetBackupDirectories($har_JobsConfigs{$str_Job}{_uri_BackupLocation}) or LOGDIE(qq{Reading directory failed.});

		if ( @{$are_ExistingBackups} ) {
			($uri_Searched)	= map { $_->{uri_Path} } sort { $a->{tsp_mtime} <=> $b->{tsp_mtime} } @{$are_ExistingBackups};
			}

		DEBUG(qq{Returning path: } . ( defined($uri_Searched) ? qq{"$uri_Searched"} : q{NULL} ));

		return($uri_Searched);
		}

	sub GetLastSuccessful {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;
		my $uri_Searched	= undef;
		my $are_ExistingBackups	= GetBackupDirectories($har_JobsConfigs{$str_Job}{_uri_BackupLocation}) or LOGDIE(qq{Reading directory failed.});

		if ( @{$are_ExistingBackups} ) {
			TRACE(q{Got existing backups.});

			# Sort by date, youngest first
			@{$are_ExistingBackups}				= sort { $b->{tsp_mtime} <=> $a->{tsp_mtime} } @{$are_ExistingBackups};

			# Sort by status, but every block is still sorted youngest first
			$har_JobsConfigs{$str_Job}{_are_LastSuccessful}	= [
				( grep { defined($_->{bol_Succeeded}) && $_->{bol_Succeeded} } @{$are_ExistingBackups} ),
				( grep { defined($_->{bol_Succeeded}) && ! $_->{bol_Succeeded} } @{$are_ExistingBackups} ),
				( grep { ! defined($_->{bol_Succeeded}) } @{$are_ExistingBackups} ),
				];

			# The youngest and most successful will be returned (legacy)
			($uri_Searched)					= map { $_->{uri_Path} } @{$har_JobsConfigs{$str_Job}{_are_LastSuccessful}};
			}

		DEBUG(qq{Returning path: } . ( defined($uri_Searched) ? qq{"$uri_Searched"} : q{NULL} ));

		return($uri_Searched);
		}

	sub GetNextGeneration {
		#TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job					= shift;
		my $tsp_StartTime				= $obj_StartTime->epoch() . '';

		TRACE(qq{Calculating generation for Job:="$str_Job" at StartTime:="$tsp_StartTime".});

		lop_FindSection:
		foreach my $str_Section ( map { (ARE_Generations)[$_] } 0 .. $#{[ARE_Generations]} -2 ) {
			TRACE(qq{Checking generation "$str_Section".});
			if ( defined($har_JobsConfigs{$str_Job}{_har_TimeBorderUNIX}{$str_Section})
			&& $har_JobsConfigs{$str_Job}{har_Config}{$str_Section}{quantity}[0] > 0 ) {
				TRACE(qq{...which is set to "$har_JobsConfigs{$str_Job}{_har_TimeBorderUNIX}{$str_Section}".});
				my $tsp_PeriodStart		= $har_JobsConfigs{$str_Job}{_har_TimeBorderUNIX}{$str_Section};
				my $tsp_PeriodEnd		= $tsp_PeriodStart + INT_OneDay - 1;

				if ( $tsp_PeriodStart < $tsp_StartTime < $tsp_PeriodEnd ) {
					DEBUG(qq{Returning "$str_Section".});
					return($str_Section);
					}
				}
			elsif ( $har_JobsConfigs{$str_Job}{har_Config}{$str_Section}{quantity}[0] > 0 ) {
				TRACE(q{...which is set to NULL.});
				FATAL(qq{Missing time border for section "$str_Section".});
				return(undef);
				}
			}

		DEBUG(q{Returning "} . (ARE_Generations)[-2] . q{".});
		return((ARE_Generations)[-2]);
		}

	sub PrepareJob {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job						= shift;
		my $str_NameLast					= undef;
		my $tsp_LastBackup					= undef;
		my $are_ExistingBackups					= GetBackupDirectories($har_JobsConfigs{$str_Job}{_uri_BackupLocation});

		$har_JobsConfigs{$str_Job}{_uri_LastBackup}		= GetLastBackup($str_Job);
		$har_JobsConfigs{$str_Job}{_uri_LastSuccessful}		= GetLastSuccessful($str_Job);
		$har_JobsConfigs{$str_Job}{_str_NextGeneration}		= GetNextGeneration($str_Job) or return(false);
		$har_JobsConfigs{$str_Job}{_uri_NextBackup}		= sprintf($str_DirSyntax,
			$har_JobsConfigs{$str_Job}{har_Config}{_}{destination}[0],
			$har_JobsConfigs{$str_Job}{_str_JobName},
			$obj_StartTime->datetime,
			$obj_StartTime->tzoffset->hours,
			$obj_StartTime->tzoffset->minutes % INT_OneMinute,
			);

		($tsp_LastBackup)					=
			map { $_->{tsp_mtime} }
			sort { $b->{tsp_mtime} <=> $a->{tsp_mtime} }
			@{$are_ExistingBackups};

		TRACE(qq{Checking for next run, given:\n} .
			qq{str_NameLast:=} . ( defined($str_NameLast) ? qq{"$str_NameLast"} : q{NULL} ) . qq{\n} .
			qq{tsp_LastBackup:=} . ( defined($tsp_LastBackup) ? qq{"$tsp_LastBackup"} : q{NULL} )
			);

		if ( defined($tsp_LastBackup)
		&& ( $obj_StartTime->epoch - $tsp_LastBackup ) < ( $har_JobsConfigs{$str_Job}{har_Config}{_}{space}[0] * INT_OneHour - 1 ) ) {
			INFO(sprintf(q{Job %s ran %s ago, but shall only run every %s.},
				$har_JobsConfigs{$str_Job}{_str_JobName},
				HumanReadableTimeSpan($obj_StartTime->epoch - $tsp_LastBackup),
				HumanReadableTimeSpan($har_JobsConfigs{$str_Job}{har_Config}{_}{space}[0] * INT_OneHour),
				));
			return(false);
			}
		$tsp_LastBackup						= undef;	# Reset

		($str_NameLast, $tsp_LastBackup)			=
			map { ( $_->{str_Name}, $_->{tsp_mtime} ) }
			sort { $b->{tsp_mtime} <=> $a->{tsp_mtime} }
			grep { $_->{str_Generation} ne q{hour} }
			@{$are_ExistingBackups};

		TRACE(qq{Checking for next generation, given:\n} .
			qq{str_NameLast:=} . ( defined($str_NameLast) ? qq{"$str_NameLast"} : q{NULL} ) . qq{\n} .
			qq{tsp_LastBackup:=} . ( defined($tsp_LastBackup) ? qq{"$tsp_LastBackup"} : q{NULL} )
			);

		# Check if variables are set
		if ( defined($str_NameLast)
		&& defined($tsp_LastBackup)

		&& ( $har_JobsConfigs{$str_Job}{har_Config}{hour}{quantity}[0] > 0	# Only if hourly are activated
		&& ( ( ( $har_JobsConfigs{$str_Job}{_str_NextGeneration} eq q{year}	&& $str_NameLast =~ m{$rxp_DirectoryYear} )
		|| ( $har_JobsConfigs{$str_Job}{_str_NextGeneration} eq q{month}	&& $str_NameLast =~ m{$rxp_DirectoryMonth} )
		|| ( $har_JobsConfigs{$str_Job}{_str_NextGeneration} eq q{week}		&& $str_NameLast =~ m{$rxp_DirectoryWeek} ) )
		&& ( $obj_StartTime->epoch - $tsp_LastBackup ) < ( INT_OneDay - 60 ) )	# Not even a day has passed since

		||	# For day time border must be considered as well!

		( ( $har_JobsConfigs{$str_Job}{_str_NextGeneration} eq q{day}		&& $str_NameLast =~ m{$rxp_DirectoryDay} )
		# 	last backup		time border for daily				now			would be right, so it is negated
		&& !( $tsp_LastBackup < $har_JobsConfigs{$str_Job}{_har_TimeBorderUNIX}{day} < $obj_StartTime->epoch ) ) ) ) {
			TRACE(q{NextGeneration:=hour});

			$har_JobsConfigs{$str_Job}{_str_NextGeneration}	= q{hour};
			}

		# Append generation identifier
		$har_JobsConfigs{$str_Job}{_uri_NextBackup}		.= uc(substr($har_JobsConfigs{$str_Job}{_str_NextGeneration}, 0, 1));
		$har_JobsConfigs{$str_Job}{_uri_NextLog}		= $har_JobsConfigs{$str_Job}{_uri_NextBackup} . q{.log};
		$har_JobsConfigs{$str_Job}{_bol_HardLinkProtect}	=
			$har_JobsConfigs{$str_Job}{har_Config}{_}{protecthardlinks}[0] && $har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{quantity}[0] <= 1
				? true		# delete later
				: false;	# delete earlier

		TRACE(sub { return(q{Dump of updated fields: } . Dumper({
			qq{har_JobsConfigs{$str_Job}{_uri_LastBackup}}		=> $har_JobsConfigs{$str_Job}{_uri_LastBackup},
			qq{har_JobsConfigs{$str_Job}{_uri_LastSuccessful}}	=> $har_JobsConfigs{$str_Job}{_uri_LastSuccessful},
			qq{har_JobsConfigs{$str_Job}{_str_NextGeneration}}	=> $har_JobsConfigs{$str_Job}{_str_NextGeneration},
			qq{har_JobsConfigs{$str_Job}{_uri_NextBackup}}		=> $har_JobsConfigs{$str_Job}{_uri_NextBackup},
			})); });

		# Setting up remote path name
		if ( ( ! $har_JobsConfigs{$str_Job}{har_Config}{_}{hostname}[0]
		&& ! $har_JobsConfigs{$str_Job}{har_Config}{_}{ipv46}[0]
		&& ( $har_JobsConfigs{$str_Job}{_str_JobName} =~ m{$rxp_Localhost}
		|| fc($har_JobsConfigs{$str_Job}{_str_JobName}) eq fc($str_Hostname) ) )
		||
		( ! $har_JobsConfigs{$str_Job}{har_Config}{_}{ipv46}[0]
		&& defined($har_JobsConfigs{$str_Job}{har_Config}{_}{hostname}[0])
		&& $har_JobsConfigs{$str_Job}{har_Config}{_}{hostname}[0] =~ m{$rxp_Localhost} )
		||
		( $har_JobsConfigs{$str_Job}{har_Config}{_}{ipv46}[0]
		&& $har_JobsConfigs{$str_Job}{har_Config}{_}{ipv46}[0] =~ m{$rxp_Localhost} ) ) {
			TRACE(qq{Job "$str_Job" is localhost.});
			$har_JobsConfigs{$str_Job}{_str_Remote}	= undef;
			}
		elsif ( $har_JobsConfigs{$str_Job}{har_Config}{_}{ipv46}[0] ) {
			TRACE(qq{Job "$str_Job" shall be reached via IP "$har_JobsConfigs{$str_Job}{har_Config}{_}{ipv46}[0]".});
			$har_JobsConfigs{$str_Job}{_str_Remote}	= $har_JobsConfigs{$str_Job}{har_Config}{_}{ipv46}[0];
			}
		elsif ( $har_JobsConfigs{$str_Job}{har_Config}{_}{hostname}[0] ) {
			TRACE(qq{Job "$str_Job" shall be reached via hostname "$har_JobsConfigs{$str_Job}{har_Config}{_}{hostname}[0]".});
			$har_JobsConfigs{$str_Job}{_str_Remote}	= $har_JobsConfigs{$str_Job}{har_Config}{_}{hostname}[0];
			}
		elsif ( $har_JobsConfigs{$str_Job}{_str_JobName} ) {
			TRACE(qq{Job "$str_Job" shall be reached via name "$har_JobsConfigs{$str_Job}{_str_JobName}".});
			$har_JobsConfigs{$str_Job}{_str_Remote}	= $har_JobsConfigs{$str_Job}{_str_JobName};
			}
		else {
			LOGDIE(q{FATAL ERROR - This situation must not happen.});
			}

		# Check connection possibilities
		if ( defined($har_JobsConfigs{$str_Job}{_str_Remote}) ) {
			TRACE(qq{Checking network capabilities to reach "$har_JobsConfigs{$str_Job}{_str_Remote}".});

			if ( ! ClientPongs($str_Job) ) {
				INFO(qq{Can not run backup for job $str_Job: host "$har_JobsConfigs{$str_Job}{_str_Remote}" did not pong.});

				return(false);
				}
			if ( ! ClientAnswersSSH($str_Job) ) {
				INFO(qq{Can not run backup for job $str_Job: host "$har_JobsConfigs{$str_Job}{_str_Remote}" can not be reached by OpenSSH.});

				return(false);
				}
			}
		else {
			TRACE(q{Client is localhost.});
			}

		DEBUG(sub { return(q{Dump of updated configuration: } . Dumper({ $str_Job => $har_JobsConfigs{$str_Job} })); });
		#DEBUG(qq{Job "$str_Job" accessable } . ( defined($har_JobsConfigs{$str_Job}{_str_Remote}) ? qq{via "$har_JobsConfigs{$str_Job}{_str_Remote}".} : q{on localhost.}));

		return(true);
		}

	sub ServerPreRun {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;
		my $str_Key		= q{serverprerun};
		my $sub_Failure		= \&ServerPreFail;

		if ( RunJobShellCommands($har_JobsConfigs{$str_Job}{_str_JobName}, $har_JobsConfigs{$str_Job}{_str_NextGeneration}, $str_Key) ) {
			DEBUG(qq{Succeeded.});
			return(true);
			}
		else {
			DEBUG(qq{Failed!});
			$sub_Failure->($str_Job);
			return(false);
			}
		}

	sub ClientPreRun {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;
		my $str_Key		= q{clientprerun};
		my $sub_Failure		= \&ClientPreFail;

		if ( RunJobShellCommands($har_JobsConfigs{$str_Job}{_str_JobName}, $har_JobsConfigs{$str_Job}{_str_NextGeneration}, $str_Key) ) {
			DEBUG(qq{Run succeeded.});
			return(true);
			}
		else {
			DEBUG(qq{Failed!});
			$sub_Failure->($str_Job);
			return(false);
			}
		}

	sub ClientPostRun {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;
		my $str_Key		= q{clientpostrun};
		my $sub_Failure		= \&ClientPostFail;

		if ( RunJobShellCommands($har_JobsConfigs{$str_Job}{_str_JobName}, $har_JobsConfigs{$str_Job}{_str_NextGeneration}, $str_Key) ) {
			DEBUG(qq{Succeeded.});
			return(true);
			}
		else {
			DEBUG(qq{Failed!});
			$sub_Failure->($str_Job);
			return(false);
			}
		}

	sub ServerPostRun {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;
		my $str_Key		= q{serverpostrun};
		my $sub_Failure		= \&ServerPostFail;

		if ( RunJobShellCommands($har_JobsConfigs{$str_Job}{_str_JobName}, $har_JobsConfigs{$str_Job}{_str_NextGeneration}, $str_Key) ) {
			DEBUG(qq{Succeeded.});
			return(true);
			}
		else {
			DEBUG(qq{Failed!});
			$sub_Failure->($str_Job);
			return(false);
			}
		}

### Failure handles
	sub ServerPreFail {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;
		my $str_Key		= q{serverprefail};

		if ( RunJobShellCommands($har_JobsConfigs{$str_Job}{_str_JobName}, $har_JobsConfigs{$str_Job}{_str_NextGeneration}, $str_Key) ) {
			DEBUG(qq{Succeeded.});
			}
		else {
			DEBUG(qq{Failed!});
			}

		return(false);
		}

	sub ClientPreFail {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;
		my $str_Key		= q{clientprefail};

		TRACE(qq{Starting.});
		if ( RunJobShellCommands($har_JobsConfigs{$str_Job}{_str_JobName}, $har_JobsConfigs{$str_Job}{_str_NextGeneration}, $str_Key) ) {
			DEBUG(qq{Succeeded.});
			}
		else {
			DEBUG(qq{Failed!});
			}

		return(false);
		}

	sub ClientPostFail {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;
		my $str_Key		= q{clientpostfail};

		TRACE(qq{Starting.});
		if ( RunJobShellCommands($har_JobsConfigs{$str_Job}{_str_JobName}, $har_JobsConfigs{$str_Job}{_str_NextGeneration}, $str_Key) ) {
			DEBUG(qq{Succeeded.});
			}
		else {
			DEBUG(qq{Failed!});
			}

		return(false);
		}

	sub ServerPostFail {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;
		my $str_Key		= q{serverpostfail};

		TRACE(qq{Starting.});
		if ( RunJobShellCommands($har_JobsConfigs{$str_Job}{_str_JobName}, $har_JobsConfigs{$str_Job}{_str_NextGeneration}, $str_Key) ) {
			DEBUG(qq{Succeeded.});
			}
		else {
			DEBUG(qq{Failed!});
			}

		return(false);
		}

	sub Cleanup {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job			= shift;
		my $cnt_Deleted			= q{0E0};
		my $are_ExistingBackups		= GetBackupDirectories($har_JobsConfigs{$str_Job}{_uri_BackupLocation});
		my @har_FormerBackups		=
			sort { $b->{tsp_mtime} <=> $a->{tsp_mtime} }	# Newest first
			grep { $_->{str_Generation} eq $har_JobsConfigs{$str_Job}{_str_NextGeneration} }
			@{$are_ExistingBackups};

		if ( scalar(@har_FormerBackups) >= $har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{quantity}[0] ) {
			my @har_ToDelete	= ( @{ dclone(\@har_FormerBackups) } );

			# Remove newest from delete list
			splice(@har_ToDelete, 0,
				($har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{quantity}[0] - ( ( $bol_Fast || $har_JobsConfigs{$str_Job}{_bol_HardLinkProtect} )
					? 0
					: 1
					))
				);

			# Delete oldest first
			foreach my $uri_Delete ( map { $_->{uri_Path} } sort { $a->{tsp_mtime} <=> $b->{tsp_mtime} } @har_ToDelete ) {
				my $uri_DelLog	= qq{$uri_Delete.log};

				if ( -e $uri_Delete ) {
					TRACE(qq{Deleting "$uri_Delete".});
					remove_tree($uri_Delete);
					TRACE(qq{Deleted "$uri_Delete".});
					}

				if ( -e $uri_DelLog ) {
					TRACE(qq{Deleting "$uri_DelLog".});
					remove_tree($uri_DelLog);
					TRACE(qq{Deleted "$uri_DelLog".});
					}

				$cnt_Deleted++;
				}
			}

		DEBUG(sprintf(q{Deleted %d director%s.}, $cnt_Deleted, ( $cnt_Deleted == 1 ? q{y} : q{ies} )));

		return($cnt_Deleted);
		}

	sub Backup {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job			= shift;
		my $bol_BackupSucceeded		= true;
		my @int_GoodRsyncReturnCodes	= ( 0, 24 );
		my $bol_RunPostFails		= false;
		my $bol_Stop			= false;

		if ( $har_SubCommands{backup}{bol_Active}
		&& ! $bol_SelectList ) {	# Disables backup
			TRACE(q{Backup is active.});
			}
		else {
			if ( $har_SubCommands{backup}{bol_Active}
			&& $bol_SelectList ) {
				INFO(q{Backup is not compatible with --ask .});
				}

			DEBUG(q{Backup is disabled.});
			return(true);
			}

		if ( -d $har_JobsConfigs{$str_Job}{_uri_NextBackup} ) {
			WARN(qq{Backup "$har_JobsConfigs{$str_Job}{_uri_NextBackup}" exists already.});
			}

		DEBUG(sprintf(q{Running backups for job "%s" on locations [%s].},
			$har_JobsConfigs{$str_Job}{_str_JobName},
			join(q{,}, map { qq{"$_"} } @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{source}}),
			));

		lop_BackupSources:
		foreach my $uri_Source ( @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{source}} ) {
			$uri_Source			= NormalizePath($uri_Source);
			my $uri_SimpleSource		= $uri_Source =~ s{$rxp_RemoveLeadingChars} {}gr;
			my @cmd_Backup			= ();
			my $int_ReturnCode		= undef;
			my $int_PostponeSeconds		= 300;
			my $cnt_InfiniteBlocker		= 3;
			my @uri_RsyncDefaultExcludes	= @uri_RsyncDefaultExcludes;	# Localize
			my @uri_UsedLocations		= ();
			my sub InstantRollback;
			my sub InstantSingleRollback;

			TRACE(qq{uri_SimpleSource:="$uri_SimpleSource"});

			if ( $har_JobsConfigs{MAIN}{har_Config}{_}{niceserver}[0] ) {
				TRACE(q{Being nice to the server is requested.});

				if ( IsBinary($har_JobsConfigs{MAIN}{har_Config}{_}{binnice}[0]) ) {
					push(@cmd_Backup, ShellQuote($har_JobsConfigs{MAIN}{har_Config}{_}{binnice}[0]), q{-n 19});
					}
				else {
					WARN(qq{"$har_JobsConfigs{MAIN}{har_Config}{_}{binnice}[0]" not found or not a binary.});
					}
				if ( IsBinary($har_JobsConfigs{MAIN}{har_Config}{_}{binionice}[0]) ) {
					push(@cmd_Backup, ShellQuote($har_JobsConfigs{MAIN}{har_Config}{_}{binionice}[0]), q{-c 3});
					}
				else {
					WARN(qq{"$har_JobsConfigs{MAIN}{har_Config}{_}{binionice}[0]" not found or not a binary.});
					}
				}

			# Rsync itself
			if ( IsBinary($har_JobsConfigs{$str_Job}{har_Config}{_}{binrsync}[0]) ) {
				push(@cmd_Backup, ShellQuote($har_JobsConfigs{$str_Job}{har_Config}{_}{binrsync}[0]));
				}
			else {
				LOGDIE(qq{Rsync path "$har_JobsConfigs{$str_Job}{har_Config}{_}{binrsync}[0]" is invalid.});
				}

			# SSH if it is 
			if ( $har_JobsConfigs{$str_Job}{_str_Remote} ) {
				TRACE(qq{Job is for remote host, setting remote shell:="$str_RsyncRemoteShellOption".});
				push(@cmd_Backup, $str_RsyncRemoteShellOption);
				}
			# Localhost is backup system and must not backup the backups
			elsif ( $har_JobsConfigs{$str_Job}{har_Config}{_}{destination}[0] ) {
					my $uri_LocalDest	= $har_JobsConfigs{$str_Job}{har_Config}{_}{destination}[0] . '';
					$uri_LocalDest		=~ s{$rxp_LeadingSlash} {};
					$uri_LocalDest		=~ s{$rxp_EndingSlashes} {/*};

					TRACE(qq{Job is for localhost, adding "$uri_LocalDest" to exclude list.});
					push(@uri_RsyncDefaultExcludes, $uri_LocalDest);
				}
			else {
				LOGDIE(q{Destination not found.});
				}

			if ( @str_RsyncDefaultOptions ) {
				TRACE(sub { return(q{Adding default options for rsync: } . Dumper({ str_RsyncDefaultOptions => \@str_RsyncDefaultOptions })); });

				push(@cmd_Backup, @str_RsyncDefaultOptions);
				}

			if ( $har_JobsConfigs{$str_Job}{har_Config}{_}{niceclient}[0] ) {
				TRACE(q{Being nice to the client is requested.});

				push(@cmd_Backup, q{--rsync-path='nice -n 19 ionice -c 3 rsync'});
				}

			# Include files from config
			if ( ref($har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{includefrom}) eq q{ARRAY}
			&& @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{includefrom}} ) {
				TRACE(q{Adding include files.});
				push(@cmd_Backup,
					map { ShellQuote(q{--include-from}, $_) }
					grep { -e $_ && -T realpath($_) }
					@{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{includefrom}});
				}

			if ( @uri_RsyncDefaultExcludes ) {
				TRACE(q{Adding default excludes.});
				push(@cmd_Backup,
					map { ShellQuote(qq{--exclude}, $_) }
					@uri_RsyncDefaultExcludes);
				}

			# Exclude files from config
			if ( ref($har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{excludefrom}) eq q{ARRAY}
			&& @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{excludefrom}} ) {
				TRACE(q{Adding exclude files.});
				push(@cmd_Backup, map { ( q{--exclude-from}, $_ ) } grep { -e $_ && -T realpath($_) } @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{excludefrom}});
				}

			# Hard link destination
			lop_FindBestHardlinkDir:
			foreach my $har_LastSuccessful ( @{$har_JobsConfigs{$str_Job}{_are_LastSuccessful}} ) {	# going from youngest successful to oldest statless crossing failed
				my $uri_FullPath	= undef;

				if ( defined($har_LastSuccessful->{uri_Path}) ) {
					$uri_FullPath			= qq{$har_LastSuccessful->{uri_Path}/$uri_SimpleSource};
					DEBUG(qq{Checking link destination "$uri_FullPath".});
					}
				else {
					DEBUG(q{Got no path.});
					next(lop_FindBestHardlinkDir);
					}

				# If it doesn't exist, any further checks are useless.
				if ( ! -e $uri_FullPath ) {
					TRACE(sprintf(q{%s :  No such file or directory.}, ShellQuote($uri_FullPath)));
					next(lop_FindBestHardlinkDir);	# Not a failure
					}
				# Was already used to hardlink or is non-relevant
				elsif ( !( grep { qq{$uri_Source/} =~ m{^\Q$_/\E}
				|| qq{$_/} =~ m{^\Q$uri_Source/\E} }
				grep { my $uri_Used = $_ ; not grep { qq{$uri_Used/} =~ m{^\Q$_/\E} } @uri_UsedLocations }
				@{$har_JobsConfigs{$str_Job}{har_Config}{$har_LastSuccessful->{str_Generation}}{source}} ) ) {
					TRACE(qq{No sources of intrest found.});
					next(lop_FindBestHardlinkDir);	# Not a failure
					}

				TRACE(qq{Adding hard link destination "$uri_FullPath".});
				push(@cmd_Backup, ShellQuote(q{--link-dest}, $uri_FullPath));

				# Mark as used
				push(@uri_UsedLocations, @{$har_JobsConfigs{$str_Job}{har_Config}{$har_LastSuccessful->{str_Generation}}{source}});

				# If we get the same target or one of it's parents, we got the most recent data. Thats all we need.
				if ( grep { qq{$uri_Source/} =~ m{^\Q$_/\E} }
				@{$har_JobsConfigs{$str_Job}{har_Config}{$har_LastSuccessful->{str_Generation}}{source}} ) {
					TRACE(qq{"$uri_FullPath" has all we need to link properly.});
					last(lop_FindBestHardlinkDir);
					}
				}

			# Source host and path (or module)
			if ( IsRsyncModule($uri_Source) ) {
				TRACE(qq{Source "$uri_Source" is a rsync daemon module.});
				push(@cmd_Backup, ( $har_JobsConfigs{$str_Job}{_str_Remote} // q{localhost} ) . qq{:$uri_Source}); # uri_Source has a colon already
				}	
			else {
				TRACE(qq{Source "$uri_Source" is a path.});
				my $uri_SourcePrep	= $uri_Source . '';		# Copy
				$uri_SourcePrep		= ShellQuote($uri_SourcePrep);	# Removes last slash
				$uri_SourcePrep		=~ s{$rxp_EndingSlashes} {/};	# Source must have an ending slash
				#									hostname / IP address				nothing (localhost)
				push(@cmd_Backup, ( ( defined($har_JobsConfigs{$str_Job}{_str_Remote}) ? qq{$har_JobsConfigs{$str_Job}{_str_Remote}:} : '' ) . $uri_SourcePrep ));
				}

			lop_SpecificDestination: {
				my $uri_SpecificDestination	= qq{$har_JobsConfigs{$str_Job}{_uri_NextBackup}/$uri_SimpleSource};
				my $cnt_InfiniteBlocker		= 3;

				push(@cmd_Backup, ShellQuote($uri_SpecificDestination));
				TRACE(qq{Added source specific target directory "$uri_SpecificDestination" and preparing it.});

				if ( ! -d $uri_SpecificDestination ) {

					make_path($uri_SpecificDestination);
					TRACE(qq{Created source specific target directory "$uri_SpecificDestination".});

					while ( $cnt_InfiniteBlocker--
					&& ! -d $uri_SpecificDestination ) {
						WARN(qq{Created directory "$uri_SpecificDestination" not appeared on file system yet. ($cnt_InfiniteBlocker/3)});
						sleep(1);
						}
					}
				}

			TRACE(q{Adding redirects.});
			push(@cmd_Backup, q{2>&1});

			sub InstantRollback {
				TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
				if ( -e $har_JobsConfigs{$str_Job}{_uri_NextBackup} ) {
					TRACE(qq{Removing "$har_JobsConfigs{$str_Job}{_uri_NextBackup}".});
					remove_tree($har_JobsConfigs{$str_Job}{_uri_NextBackup});
					}
				elsif ( $har_JobsConfigs{$str_Job}{_uri_NextBackup} ) {
					WARN(qq{"$har_JobsConfigs{$str_Job}{_uri_NextBackup}" not found. Has it ever been created?!});
					}
				}

			sub InstantSingleRollback {
				TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
				if ( -e qq{$har_JobsConfigs{$str_Job}{_uri_NextBackup}/$uri_SimpleSource} ) {
					TRACE(qq{Removing "$har_JobsConfigs{$str_Job}{_uri_NextBackup}/$uri_SimpleSource".});
					remove_tree(qq{$har_JobsConfigs{$str_Job}{_uri_NextBackup}/$uri_SimpleSource});
					}
				elsif ( qq{$har_JobsConfigs{$str_Job}{_uri_NextBackup}/$uri_SimpleSource} ) {
					WARN(qq{"$har_JobsConfigs{$str_Job}{_uri_NextBackup}/$uri_SimpleSource" not found. Has it ever been created?!});
					}
				}

			lop_RunRsync: {
				my sub InfiniteRetry;

				sub InfiniteRetry {
					TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
					$cnt_InfiniteBlocker					= 3;	# Reset

					# Check return code
					if ( grep { $int_ReturnCode == $_ } @int_RetryErrors ) {
						INFO(qq{"$str_Job" - Waiting $int_PostponeSeconds seconds before retrying.});

						sleep($int_PostponeSeconds);
						if ( $int_PostponeSeconds < 3600 ) {
							$int_PostponeSeconds				= sprintf(q{%.0f}, $int_PostponeSeconds * 1.5);

							if ( $int_PostponeSeconds > 3600 ) {
								$int_PostponeSeconds			= 3600;
								}
							}

						TRACE(qq{Restarting lop_RunRsync.});
						return(true);
						}
					else {
						DEBUG(sprintf(q{Error %s not matching any of RetryErrorCodes:=[%s].},
							$int_ReturnCode,
							join(q{,}, map { qq{"$_"} } @int_RetryErrors),
							));
						$har_JobsConfigs{$str_Job}{_bol_Succeeded}		= false;
						return(false);
						}
					}

				# Open log
				if ( open(my $dsc_LogHandle, q{>>}, $har_JobsConfigs{$str_Job}{_uri_NextLog}) ) {
					print $dsc_LogHandle GetISOdateTime() . qq{Executing backup via \n@cmd_Backup\n\n};

					# Start Rsync
					if ( open(my $dsc_ProcessHandle, q{-|}, qq{@cmd_Backup}) ) {
						DEBUG(qq{Job $har_JobsConfigs{$str_Job}{_str_JobName}: Backup executing via >@cmd_Backup<});

						while ( my $str_Output = readline($dsc_ProcessHandle) ) {
							chomp($str_Output);
							print $dsc_LogHandle MergeWithISOtime($str_Output);	# Write to log first

							# MILESTONE: Do something to check status of rsync
							#chomp($str_Output);
							}

						{ no autodie;
							close($dsc_ProcessHandle);
							$int_ReturnCode		= $? >> 8;
							}

						if ( $int_ReturnCode ) {
							print $dsc_LogHandle MergeWithISOtime(qq{rsync had errors.});
							}
						print $dsc_LogHandle MergeWithISOtime(qq{rsync exited with '$int_ReturnCode'\n});
						}
					else {
						FATAL(qq{Can't execute >@cmd_Backup<});
						print $dsc_LogHandle MergeWithISOtime(qq{Execution failed.});
						}
					close($dsc_LogHandle);
					}
				else {
					FATAL(qq{Can't write to log "$har_JobsConfigs{$str_Job}{_uri_NextLog}".});
					return(undef);
					}

				if ( defined($int_ReturnCode)
				&& grep { $int_ReturnCode == $_ } @int_GoodRsyncReturnCodes ) {
					INFO(qq{Backup of "$har_JobsConfigs{$str_Job}{_str_JobName}" succeeded.});
					$bol_BackupSucceeded							= true;
					$har_JobsConfigs{$str_Job}{_bol_Succeeded}				= true;
					}
				elsif ( $cnt_InfiniteBlocker <= 0
				|| defined($int_ReturnCode)
				&& $int_ReturnCode == 255 ) {
					ERROR(sprintf(q{Failed to backup "%s" next step(s): [%s].},
						$uri_Source,
						join(q{,}, map { qq{"$_"} } @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}}),
						));

					if ( scalar(@{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}}) == 1 ) {
						TRACE(q{Backup failed.});

						if ( fc(q{continue}) eq fc($har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}[0]) ) {
							TRACE(qq{Backup failure handling is "$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}[0]".});
							$bol_BackupSucceeded					= true;	# already set
							$har_JobsConfigs{$str_Job}{_bol_Succeeded}		= false;
							}
						elsif ( fc(q{fail}) eq fc($har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}[0]) ) {
							TRACE(qq{Backup failure handling is "$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}[0]".});
							$bol_BackupSucceeded					= false;
							$har_JobsConfigs{$str_Job}{_bol_Succeeded}		= false;
							$bol_RunPostFails					= true;
							}
						elsif ( fc(q{stop}) eq fc($har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}[0]) ) {
							TRACE(qq{Backup failure handling is "$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}[0]".});
							$bol_BackupSucceeded					= false;
							$har_JobsConfigs{$str_Job}{_bol_Succeeded}		= false;
							#return($bol_BackupSucceeded);
							}
						elsif ( fc(q{rollback}) eq fc($har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}[0]) ) {
							TRACE(qq{Backup failure handling is "$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}[0]".});
							InstantRollback();
							$bol_BackupSucceeded					= false;
							$har_JobsConfigs{$str_Job}{_bol_Succeeded}		= false;
							#return($bol_BackupSucceeded);
							}
						elsif ( fc(q{retry}) eq fc($har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}[0]) ) {
							TRACE(qq{Backup failure handling is "$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}[0]".});
							InfiniteRetry() && redo(lop_RunRsync);
							}
						}
					elsif ( scalar(@{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}}) == 2 ) {
						TRACE(q{Backup failed.});

						if ( scalar(grep { fc($_) ne fc(q{retry}) && fc($_) ne fc(q{continue}) } @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}}) == 0 ) {
							TRACE(sprintf(q{Setting is %s,%s.}, @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}}));

							$cnt_InfiniteBlocker					= 3;	# Reset

							# Check return code
							if ( grep { $int_ReturnCode == $_ } @int_RetryErrors ) {
								INFO(qq{"$str_Job" - Waiting $int_PostponeSeconds seconds before retrying.});
								sleep($int_PostponeSeconds);

								if ( $int_PostponeSeconds < 3600 ) {
									$int_PostponeSeconds				= sprintf(q{%.0f}, $int_PostponeSeconds * 1.5);

									if ( $int_PostponeSeconds > 3600 ) {
										$int_PostponeSeconds				= 3600;
										}

									TRACE(qq{Restarting lop_RunRsync.});
									redo(lop_RunRsync);
									}
								elsif ( $int_PostponeSeconds >= 3600 ) {
									$bol_BackupSucceeded					= true;
									$har_JobsConfigs{$str_Job}{_bol_Succeeded}		= false;
									}
								}
							else {
								DEBUG(sprintf(q{Error %s not matching any of RetryErrorCodes:=[%s].},
									$int_ReturnCode,
									join(q{,}, map { qq{"$_"} } @int_RetryErrors),
									));
								$har_JobsConfigs{$str_Job}{_bol_Succeeded}		= false;
								#return(false);
								}
							} 
						elsif ( false
						&& WORK()
						&& scalar(grep { fc($_) ne fc(q{retry})
						&& fc($_) ne fc(q{fail}) } @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}}) == 0 ) {
							die qq{WORK\n};
							FATAL(q{Not implemented yet!});	# stop
							$har_JobsConfigs{$str_Job}{_bol_Succeeded}		= false;
							#return(false);
							} 
						elsif ( scalar(grep { fc($_) ne fc(q{retry}) && fc($_) ne fc(q{rollback}) } @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}}) == 0 ) {
							TRACE(sprintf(q{Setting is %s,%s.}, @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}}));

							# Rollback
							InstantSingleRollback();

							# Retry
							InfiniteRetry() && redo(lop_RunRsync);
							} 
						elsif ( scalar(grep { fc($_) ne fc(q{rollback}) && fc($_) ne fc(q{continue}) } @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}}) == 0 ) {
							TRACE(sprintf(q{Setting is %s,%s.}, @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}}));

							InstantRollback();

							$bol_BackupSucceeded					= true;
							$har_JobsConfigs{$str_Job}{_bol_Succeeded}		= false;
							#return($bol_BackupSucceeded);
							} 
						elsif ( scalar(grep { fc($_) ne fc(q{rollback}) && fc($_) ne fc(q{fail}) } @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}}) == 0 ) {
							TRACE(sprintf(q{Setting is %s,%s.}, @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}}));

							InstantRollback();

							$bol_BackupSucceeded					= false;
							$har_JobsConfigs{$str_Job}{_bol_Succeeded}		= false;
							$bol_RunPostFails					= true;
							$bol_Stop						= true;
							} 
						else {
							WARN(qq{Invalid combination of backup failure handles: @{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}}.});
							$har_JobsConfigs{$str_Job}{_bol_Succeeded}		= false;
							#return(false);
							} 
						}
					elsif ( scalar(@{$har_JobsConfigs{$str_Job}{har_Config}{$har_JobsConfigs{$str_Job}{_str_NextGeneration}}{backupfailurehandling}}) == 0 ) {
						# Same as "stop"
						TRACE(q{Got no value how to handle failures. Fallback to 'stop' method.});
						$har_JobsConfigs{$str_Job}{_bol_Succeeded}			= false;
						#return(false);
						}
					else {
						LOGWARN(q{More than two options set for backupfailurehandling - fallback to default.});
						$har_JobsConfigs{$str_Job}{_bol_Succeeded}			= false;
						#return(false);
						}
					}
				# "backupfailurehandling" handle must apply here!
				# 24 is not an error on running systems - files may vanish from time to time
				elsif ( defined($int_ReturnCode)
				&& $cnt_InfiniteBlocker-- > 0
				&& !( grep { $int_ReturnCode == $_ } @int_GoodRsyncReturnCodes ) ) {
					if ( grep { $_ eq q{-X} } @cmd_Backup ) {
						ERROR(q{Execution of rsync failed. Retrying without -X option.});
						@cmd_Backup			= grep { $_ ne q{-X} } @cmd_Backup;
						}

					TRACE(qq{Restarting lop_RunRsync. ($cnt_InfiniteBlocker/3)});
					redo(lop_RunRsync);
					}
				}
			}

		if ( $bol_RunPostFails ) {
			DEBUG(q{Failing on purpose.});
			ClientPostFail($str_Job);
			ServerPostFail($str_Job);
			}
		#if ( $bol_Stop ) {
			#DEBUG(q{Stop requested.});
			#return($bol_BackupSucceeded);
			#}

		# Protocolling
		DBProtocolBackupStatus($str_Job);
		DEBUG(sprintf(q{Done. Backup %s.}, $bol_BackupSucceeded ? q{successful} : q{failed}));

		return($bol_BackupSucceeded);
		}

	sub Sizing {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;
		my $tsp_StartTime	= undef;
		my $bol_Succeeded	= true;
		my sub SetStartTimeFromJungestBackupDirectory;
		my sub DBInsertTask;
		my sub GetLastSizedDirectories;
		my sub DeleteLastTask;

		sub SetStartTimeFromJungestBackupDirectory {
			TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
			my $uri_Backup	= shift;
			my @stat	= stat($uri_Backup);

			$tsp_StartTime	= $stat[9];
			DEBUG(qq{Set start time tsp_StartTime:=$tsp_StartTime .});

			return($tsp_StartTime);
			}

		sub DBInsertTask {
			TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });

			QueryDB($har_JobsConfigs{$str_Job}{_uri_DatabaseLocation}, $sql_InsertTaskTimeAndJob, [
				$har_JobsConfigs{$str_Job}{_str_JobName},
				$tsp_StartTime,
				]) or return(false);

			return(true);
			}

		sub GetLastSizedDirectories {
			TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
			my $str_Job	= shift;
			my $are_Result	= undef;

			$are_Result	= QueryDB($har_JobsConfigs{$str_Job}{_uri_DatabaseLocation}, $sql_SelectLastSizingByJobWithPath, [
				$har_JobsConfigs{$str_Job}{_str_JobName},
				]) or return(undef);

			DEBUG(sub { return(q{Last sized directories dump: } . Dumper({ are_Result => $are_Result })); });
			return($are_Result);
			}

		sub DeleteLastTask {
			TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
			my $str_Job	= shift;

			if ( ! $str_Job ) {
				return(false);
				}

			QueryDB($har_JobsConfigs{$str_Job}{_uri_DatabaseLocation}, $sql_DeleteLastTaskByJob, [ $har_JobsConfigs{$str_Job}{_str_JobName} ]) or return(false);

			return(true);
			}

		if ( $har_SubCommands{size}{bol_Active} ) {
			TRACE(q{Sizing is active.});
			my $har_FSDirs		= {};
			my $are_FSDirs		= [];
			my $har_DBDirs		= {};
			my $tsp_TaskTime	= undef;
			my @cmd_Joiner		= ( q{;} );
			my @cmd_NULLtemplate	= ( q{echo "NULL"} );
			my @cmd_ZeroTemplate	= ( q{echo "0"} );
			my @cmd_NiceTemplate	= ();
			#														freebsd		linux
			my @cmd_DuTemplate	= ( ShellQuote($har_JobsConfigs{MAIN}{har_Config}{_}{bindu}[0]), ( $^O eq q{freebsd} ? q{-A -B 512 -s} : q{-b -s} ) );	# we want --apparent-size, so we get the real size on disk
			my @cmd_FindPreTemplate	= ( ShellQuote($har_JobsConfigs{MAIN}{har_Config}{_}{binfind}[0]) );
			my @cmd_WcPostTemplate	= ( q{|}, ShellQuote($har_JobsConfigs{MAIN}{har_Config}{_}{binwc}[0]), q{-l} );
			my $uri_FormerSPath	= '';
			my %bol_DoneLocBlocks	= (	# Only one block is required
				# <STR crc32 location name>	=> <BOL true>,
				);
			my @cmd_Sizing		= (	# Three lines here mean one line at har_ToSize and four lines of output
				# du -B1 -s <fromer> <current>	# delta
				# du -B1 -s <current>		# size
				# find <current> | wc -l	# elements
				);
			my @har_ToSize		= (
				# { HAR
					# int_Size		=> undef,						# INT size
					# int_Elements		=> undef,						# INT elements
					# str_Notation		=> $are_FSDirs->[$int_Index]{str_Name},			# STR notation
					# int_Inode		=> $are_FSDirs->[$int_Index]{int_statinode},		# INT inode
					# tsp_Mtime		=> $are_FSDirs->[$int_Index]{tsp_mtime},		# TSP mtime
					# str_JobName		=> $har_JobsConfigs{$str_Job}{_str_JobName},		# STR job name
					# int_DeltaSize		=> undef,						# INT delta
					# int_DeltaInode	=> $are_FSDirs->[$int_Index - 1]{int_statinode},	# INT delta inode
					# tsp_DeltaMtime	=> $are_FSDirs->[$int_Index - 1]{tsp_mtime},		# TSP delta mtime
					# uri_Source		=> $uri_Source,						# URI required for later re-colleciton
					# }
				);
			my @are_Jobs		= (
				# [ARE <STR _str_JobName> ],
				);
			my @str_BHeaderSequence	= qw(int_Size int_Elements str_Notation int_Inode tsp_Mtime uri_Source);
			my $int_BHsortPosition	= 4;	# tsp_Mtime
			my @are_Backups		= (		# known from database
				# [ARE <INT size>, <INT elements>, <STR notation>, <INT inode>, <TSP mtime>, <STR source path> ],
				);
			my @str_AHeaderSequence	= qw(int_DeltaSize str_JobName int_Inode tsp_Mtime uri_Source int_DeltaInode tsp_DeltaMtime uri_Source);
			my $int_AHsortPosition	= 3;	# backup_mtime
			my @are_Allocations	= (
				# [ARE <INT delta>, <STR _str_JobName of job>, <INT backup_inode>, <TSP backup_mtime>, <INT delta_inode>, <TSP delta_mtime>, ],
				);
			my %har_DuplicateCheck	= (
				bol_Notations			=> {},
				bol_LocationBlocks		=> {},
				bol_Sources			=> {},
				);
			my sub LastBackupAndLastSizingDiffer;
			my sub LoadFSdirectories;
			my sub LoadDBdirectories;

			if ( $har_JobsConfigs{MAIN}{har_Config}{_}{niceserver}[0] ) {
				TRACE(q{Beeing nice to the server is requested.});

				if ( IsBinary($har_JobsConfigs{MAIN}{har_Config}{_}{binnice}[0]) ) {
					push(@cmd_NiceTemplate, ShellQuote($har_JobsConfigs{MAIN}{har_Config}{_}{binnice}[0]), q{-n 19});
					}
				else {
					WARN(qq{"$har_JobsConfigs{MAIN}{har_Config}{_}{binnice}[0]" not found or not a binary.});
					}
				if ( IsBinary($har_JobsConfigs{MAIN}{har_Config}{_}{binionice}[0]) ) {
					push(@cmd_NiceTemplate, ShellQuote($har_JobsConfigs{MAIN}{har_Config}{_}{binionice}[0]), q{-c 3});
					}
				else {
					WARN(qq{"$har_JobsConfigs{MAIN}{har_Config}{_}{binionice}[0]" not found or not a binary.});
					}
				}
			else {
				TRACE(q{Server niceness was not requested.});
				}

			DEBUG(sub { return(q{Prebuilt commands: } . Dumper({
				cmd_NULLtemplate	=> \@cmd_NULLtemplate,
				cmd_NiceTemplate	=> \@cmd_NiceTemplate,
				cmd_DuTemplate		=> \@cmd_DuTemplate,
				cmd_FindPreTemplate	=> \@cmd_FindPreTemplate,
				cmd_WcPostTemplate	=> \@cmd_WcPostTemplate,
				})); });

			sub LastBackupAndLastSizingDiffer {
				TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
				my $har_LastDBBackup		= undef;
				my $har_LastFSBackup		= undef;

				if ( defined($har_DBDirs)
				&& defined($har_FSDirs) ) {
					TRACE(q{Found directories in database and on file system.});

					($har_LastDBBackup)	= values(%{$har_DBDirs});						# All elements hold the same task_time
					($har_LastFSBackup)	= sort { $b->{tsp_mtime} <=> $a->{tsp_mtime} } values(%{$har_FSDirs});	# But we want the newest from here
					}

				if ( defined($har_LastDBBackup)
				&& defined($har_LastFSBackup)
				&& $har_LastDBBackup->{task_time} == $har_LastFSBackup->{tsp_mtime} ) {
					DEBUG(q{Sizing already done.});

					return(false);
					}
				else {
					DEBUG(q{Sizing required.});

					return(true);
					}
				}

			sub LoadFSdirectories {
				TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
				my $str_Job	= shift;
				my $are_FSDirs	= GetBackupDirectories($har_JobsConfigs{$str_Job}{_uri_BackupLocation});
				my $har_FSDirs	= undef;

				if ( $are_FSDirs ) {
					TRACE(q{Got directories from file system.});

					$har_FSDirs	= {
						map { $_->{int_statinode} => $_ }
						@{$are_FSDirs}
						};
					}
				else {
					TRACE(q{Disposing lock...});
					$har_JobsConfigs{$str_Job}{_obj_Lock}->MainUnlock();
					TRACE(q{Lock freed.});

					DEBUG(q{Failure happened.});
					return(undef);
					};

				DEBUG(sub { return(q{Dump of return data: } . Dumper({
					har_FSDirs	=> $har_FSDirs,
					})); });

				return($har_FSDirs);
				}

			sub LoadDBdirectories {
				TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
				my $str_Job	= shift;
				my $uri_Source	= shift;
				my $are_DBDirs	= GetLastSizedDirectories($har_JobsConfigs{$str_Job}{_str_JobName});
				my $har_DBDirs	= undef;

				if ( ! defined($uri_Source) ) {
					$uri_Source	= STR_DummyLocation;
					TRACE(qq{Set uri_Source:=} . ( defined($uri_Source) ? qq{"$uri_Source"} : q{NULL}));
					}

				if ( $are_DBDirs ) {
					TRACE(q{Got directories from database.});

					$har_DBDirs = {
						map { $_->{backup_inode} => $_ }
						grep { $_->{spath} eq $uri_Source }
						@{$are_DBDirs}
						};
					}
				else {
					TRACE(q{Disposing lock...});
					$har_JobsConfigs{$str_Job}{_obj_Lock}->MainUnlock();
					TRACE(q{Lock freed.});

					DEBUG(q{Failure happened.});
					return(undef);
					};

				DEBUG(sub { return(q{Dump of return data: } . Dumper({
					har_DBDirs	=> $har_DBDirs,
					})); });

				return($har_DBDirs);
				}

			TRACE(q{Starting.});
			TRACE(q{Acquiring lock...});
			if ( ! $har_JobsConfigs{$str_Job}{_obj_Lock}->MainLock() ) {
				ERROR(qq{Unable to acquire lock for $str_Job.});
				return(false);
				}
			TRACE(q{Got lock.});

			if ( ! InitDatabase($har_JobsConfigs{$str_Job}{_uri_DatabaseLocation}) ) {
				FATAL(qq{Database "$har_JobsConfigs{$str_Job}{_uri_DatabaseLocation}" can't be created.});
				TRACE(q{Disposing lock...});
				$har_JobsConfigs{$str_Job}{_obj_Lock}->MainUnlock();
				TRACE(q{Lock freed.});
				return(false);
				}

			$har_FSDirs	= LoadFSdirectories($str_Job) or return(false);
			$har_DBDirs	= LoadDBdirectories($str_Job) or return(false);

			DEBUG(sub { return(q{Lists to compare: } . Dumper({
				har_FSDirs	=> $har_FSDirs,
				har_DBDirs	=> $har_DBDirs,
				})); });

			if ( $bol_SelectList
			|| LastBackupAndLastSizingDiffer() ) {
				lop_AskUser1: {
					if ( ! LastBackupAndLastSizingDiffer() ) {	# It was the user
						TRACE(q{Sizing on user request.});
						print q{Do you really want to overwrite the last sizing? yes|[N]o: };
						chomp(my $str_UserInput	= <STDIN>);

						if ( defined($str_UserInput)
						&& $str_UserInput =~ m{$rxp_UIyes} ) {
							TRACE(qq{User aggreed with '$str_UserInput'.});
							print qq{Okay! We're on it.\n};
							}
						else {
							TRACE(qq{User disaggreed with '$str_UserInput'.});
							print qq{Disagreed. Doing nothing.\n};
							last(lop_AskUser1);
							}

						# Delete if aggreed
						DeleteLastTask($str_Job);

						# Update sized list
						$har_DBDirs		= LoadDBdirectories($str_Job) or return(false);
						}

					# Size
					$are_FSDirs	= GetBackupDirectories($har_JobsConfigs{$str_Job}{_uri_BackupLocation});

					if ( ! $are_FSDirs ) {
						TRACE(q{Disposing lock...});
						$har_JobsConfigs{$str_Job}{_obj_Lock}->MainUnlock();
						TRACE(q{Lock freed.});
						return(false);
						}

					# Sort, youngest on top
					@{$are_FSDirs}	= sort { $b->{tsp_mtime} <=> $a->{tsp_mtime} } @{$are_FSDirs};
					DEBUG(sub { return(q{Elements iternating on: } . Dumper({
						are_FSDirs	=> $are_FSDirs,
						})); });

					# Permutation of directories with source pathes
					@{$are_FSDirs}	=
						map {
							my $har_FSdir = dclone($_);
							map { { %{$har_FSdir}, uri_Source => $_ } }
							# 				Depth first
							( STR_DummyLocation, ( sort { $b cmp $a } @{$har_JobsConfigs{$str_Job}{har_Config}{$har_FSdir->{str_Generation}}{source}} ) )
							}
						@{$are_FSDirs};

					DEBUG(sub { return(q{Elements iternating on after permutation: } . Dumper({
						are_FSDirs	=> $are_FSDirs,
						})); });

					lop_Sizing:
					for ( my $int_Index = 0 ; $int_Index < scalar(@{$are_FSDirs}) ; $int_Index++ ) {
						my $int_DeltaIndex	= $int_Index - 1;	# -1 means "no delta found"
						my $har_DBDirs		= LoadDBdirectories($str_Job, $are_FSDirs->[$int_Index]{uri_Source}) or return(false);	# Localized!!

						TRACE(sub { return(q{Dump of current element: } . Dumper({
							qq{are_FSDirs->[$int_Index]}	=> $are_FSDirs->[$int_Index],
							})); });

						if ( ! defined($tsp_TaskTime) ) {
							$tsp_TaskTime		= $are_FSDirs->[$int_Index]{tsp_mtime};
							TRACE(sub { return(sprintf(q{Time for current sizing is tsp_TaskTime:='%s' (%s).}, $tsp_TaskTime, scalar(localtime($tsp_TaskTime)))); });
							}

						# Sort dummies
						if ( $are_FSDirs->[$int_Index]{uri_Source} eq STR_DummyLocation ) {
							TRACE(q{Current position is a dummy.});

							push(@are_Backups, [
								-1,							# INT backup size
								-1,							# INT backup elements
								$are_FSDirs->[$int_Index]{str_Name},			# STR backup notation
								$are_FSDirs->[$int_Index]{int_statinode},		# INT backup inode
								$are_FSDirs->[$int_Index]{tsp_mtime},			# TSP backup mtime
								$are_FSDirs->[$int_Index]{uri_Source},			# STR source path (STR_DummyLocation)
								]);

							push(@are_Allocations, [
								-1,							# INT delta size
								$har_JobsConfigs{$str_Job}{_str_JobName},		# STR job name
								$are_FSDirs->[$int_Index]{int_statinode},		# INT backup inode
								$are_FSDirs->[$int_Index]{tsp_mtime},			# TSP backup mtime
								$are_FSDirs->[$int_Index]{uri_Source},			# STR source path (STR_DummyLocation)

								( defined($are_FSDirs->[$int_DeltaIndex])		# INT delta inode
									? $are_FSDirs->[$int_DeltaIndex]{int_statinode}
									: undef ),

								( defined($are_FSDirs->[$int_DeltaIndex])		# TSP delta mtime
									? $are_FSDirs->[$int_DeltaIndex]{tsp_mtime}
									: undef ),

								$are_FSDirs->[$int_Index]{uri_Source},			# STR source path (STR_DummyLocation)
								]);
											
							# No need to do anything else with this
							TRACE(q{Dummy is done.});
							next(lop_Sizing);
							}

						# Backwards loop to find a fitting delta
						lop_FindDelta:
						for ( undef ; $int_DeltaIndex >= 0 ; $int_DeltaIndex-- ) {

							#if ( grep { qq{$are_FSDirs->[$int_Index]{uri_Source}/} =~ m{^\Q$_/\E} }
							#@{$har_JobsConfigs{$str_Job}{har_Config}{$are_FSDirs->[$int_DeltaIndex]{str_Generation}}{source}} ) {
							#	last(lop_FindDelta);
							#	}
							if ( qq{$are_FSDirs->[$int_Index]{uri_Source}/} =~ m{^\Q$are_FSDirs->[$int_DeltaIndex]{uri_Source}/\E} ) {
								TRACE(qq{Delta is on index $int_DeltaIndex.});
								last(lop_FindDelta);
								}
							} # If the whole loop was done, int_DeltaIndex is -1 => there is no delta

						TRACE(sub { return(q{Dump of delta element: } . Dumper({
							qq{are_FSDirs->[$int_DeltaIndex]}	=> $int_DeltaIndex == -1
								? undef
								: $are_FSDirs->[$int_DeltaIndex],
							})); });

						if ( $int_DeltaIndex <= -1 ) {
							$int_DeltaIndex		= undef;
							}

						#DEBUG(sub { return(q{Full dump: } . Dumper({ are_FSDirs => $are_FSDirs, are_DBDirs => $are_DBDirs })); });

						# Known DIR
						# Current dir is known to DB and inode is correct
						if ( defined($har_DBDirs->{$are_FSDirs->[$int_Index]{int_statinode}})

						# Backup mtime is same
						&& $are_FSDirs->[$int_Index]{tsp_mtime} == $har_DBDirs->{$are_FSDirs->[$int_Index]{int_statinode}}{backup_mtime}

						# It has a delta
						&& ( ( defined($int_DeltaIndex)

						# Former dir is known to DB
						&& defined($har_DBDirs->{$are_FSDirs->[$int_DeltaIndex]{int_statinode}})

						# Delta inode is still the same
						&& ( defined($har_DBDirs->{$are_FSDirs->[$int_Index]{int_statinode}}{delta_inode})
						&& $are_FSDirs->[$int_DeltaIndex]{int_statinode} == $har_DBDirs->{$are_FSDirs->[$int_Index]{int_statinode}}{delta_inode} )

						# Delta mtime is still the same
						&& ( defined($har_DBDirs->{$are_FSDirs->[$int_Index]{int_statinode}}{delta_mtime})
						&& $are_FSDirs->[$int_DeltaIndex]{tsp_mtime} == $har_DBDirs->{$are_FSDirs->[$int_Index]{int_statinode}}{delta_mtime} ) )
						
						||

						# No delta was found for are_FSDirs->[int_DeltaIndex]
						( ! defined($int_DeltaIndex)

						# Database entry has also no delta
						&& ! defined($har_DBDirs->{$are_FSDirs->[$int_Index]{int_statinode}}{delta_inode})

						# Database entry has also no delta
						&& ! defined($har_DBDirs->{$are_FSDirs->[$int_Index]{int_statinode}}{delta_mtime}) ) ) ) {

							my $int_CurrentInode	= $are_FSDirs->[$int_Index]{int_statinode};
							TRACE(qq{int_CurrentInode:=$int_CurrentInode is known to database and same as on file system.});

							push(@are_Backups, [
								$har_DBDirs->{$int_CurrentInode}{backup_size},			# INT backup size
								$har_DBDirs->{$int_CurrentInode}{backup_elments},		# INT backup elements
								$har_DBDirs->{$int_CurrentInode}{backup_notation},		# STR backup notation
								$int_CurrentInode,						# INT backup inode
								$har_DBDirs->{$int_CurrentInode}{backup_mtime},			# TSP backup mtime
								$har_DBDirs->{$int_CurrentInode}{spath},			# STR source path
								]);

							push(@are_Allocations, [
								$har_DBDirs->{$int_CurrentInode}{delta},			# INT delta
								$har_JobsConfigs{$str_Job}{_str_JobName},			# STR job name
								$int_CurrentInode,						# INT backup inode
								$har_DBDirs->{$int_CurrentInode}{backup_mtime},			# TSP backup mtime
								$har_DBDirs->{$int_CurrentInode}{spath},			# STR source path
								$har_DBDirs->{$int_CurrentInode}{delta_inode},			# INT delta inode
								$har_DBDirs->{$int_CurrentInode}{delta_mtime},			# TSP delta mtime
								$har_DBDirs->{$int_CurrentInode}{spath},			# STR source path
								]);
							}
						# Unknown or changed DIR
						else {
							TRACE(qq{'$are_FSDirs->[$int_Index]{str_Name}' is unknown to database or delta differes.});

							if ( @cmd_Sizing
							&& $cmd_Sizing[-1] ne $cmd_Joiner[-1] ) {
								push(@cmd_Sizing, @cmd_Joiner);

								}

# DONE? (Test it!)
# WORK Sizing for partial existing elements must !NOT! have a delta on targets, they don't have a listing later - while they may size against these for accuracy.
# Das Problem ist: Delta sollte NULL sein, existierte aber, weil es zum Sizen verwendet wurde.

							# If it should exist
							if ( defined($int_DeltaIndex) ) {
								TRACE(q{Got delta.});

								if ( -e qq{$are_FSDirs->[$int_DeltaIndex]{uri_Path}/$are_FSDirs->[$int_Index]{uri_Source}}
								&& -e qq{$are_FSDirs->[$int_Index]{uri_Path}/$are_FSDirs->[$int_Index]{uri_Source}} ) {
									TRACE(q{All relevant elements exist.});

									push(@cmd_Sizing,
										@cmd_NiceTemplate,
										@cmd_DuTemplate,
										ShellQuote(qq{$are_FSDirs->[$int_DeltaIndex]{uri_Path}/$are_FSDirs->[$int_Index]{uri_Source}},
											qq{$are_FSDirs->[$int_Index]{uri_Path}/$are_FSDirs->[$int_Index]{uri_Source}}),
										@cmd_Joiner,
										);
									}
								elsif ( -e qq{$are_FSDirs->[$int_DeltaIndex]{uri_Path}/$are_FSDirs->[$int_Index]{uri_Source}} ) {
									TRACE(q{Only delta element exists.});

									# Delta is the size of the delta directory if the current is missing.
									push(@cmd_Sizing,
										@cmd_ZeroTemplate, @cmd_Joiner,

										@cmd_NiceTemplate,
										@cmd_DuTemplate,
										ShellQuote(qq{$are_FSDirs->[$int_DeltaIndex]{uri_Path}/$are_FSDirs->[$int_Index]{uri_Source}}),
										@cmd_Joiner,
										);
									}
								elsif ( -e qq{$are_FSDirs->[$int_Index]{uri_Path}/$are_FSDirs->[$int_Index]{uri_Source}} ) {
									TRACE(q{Only current element exists.});

									# Delta is the size of the current directory if the delta is missing.
									push(@cmd_Sizing,
										@cmd_ZeroTemplate, @cmd_Joiner,

										@cmd_NiceTemplate,
										@cmd_DuTemplate,
										ShellQuote(qq{$are_FSDirs->[$int_Index]{uri_Path}/$are_FSDirs->[$int_Index]{uri_Source}}),
										@cmd_Joiner,
										);
									}
								}
							# If 'there may no delta exist'
							else {
								TRACE(q{There is no delta.});

								push(@cmd_Sizing,
									(@cmd_NULLtemplate, @cmd_Joiner) x 2,	# skip delta sizing
									);
								}

							if ( -e qq{$are_FSDirs->[$int_Index]{uri_Path}/$are_FSDirs->[$int_Index]{uri_Source}} ) {
								TRACE(q{But the current directory exists.});

								push(@cmd_Sizing,
									@cmd_NiceTemplate, @cmd_DuTemplate, ShellQuote(qq{$are_FSDirs->[$int_Index]{uri_Path}/$are_FSDirs->[$int_Index]{uri_Source}}), @cmd_Joiner,
									@cmd_NiceTemplate, @cmd_FindPreTemplate, ShellQuote(qq{$are_FSDirs->[$int_Index]{uri_Path}/$are_FSDirs->[$int_Index]{uri_Source}}), @cmd_WcPostTemplate,
									);
								}
							# Prevent sizing of non-existing elements!
							else {
								TRACE(q{Nothing found, just adding dummies, to keep up the counts.});

								push(@cmd_Sizing,
									@cmd_ZeroTemplate, @cmd_Joiner,
									@cmd_ZeroTemplate,
									);
								}

							push(@har_ToSize, {
								int_Size		=> undef,						# INT size
								int_Elements		=> undef,						# INT elements
								str_Notation		=> $are_FSDirs->[$int_Index]{str_Name},			# STR Notation
								uri_Source		=> $are_FSDirs->[$int_Index]{uri_Source},		# URI Source Path
								int_Inode		=> $are_FSDirs->[$int_Index]{int_statinode},		# INT inode
								tsp_Mtime		=> $are_FSDirs->[$int_Index]{tsp_mtime},		# TSP mtime
								str_JobName		=> $har_JobsConfigs{$str_Job}{_str_JobName},		# STR job name
								int_DeltaSize		=> undef,						# INT delta

								int_DeltaInode		=> ( defined($int_DeltaIndex)				# INT delta inode
									? $are_FSDirs->[$int_DeltaIndex]{int_statinode}
									: undef ),

								tsp_DeltaMtime		=> ( defined($int_DeltaIndex)				# TSP delta mtime
									? $are_FSDirs->[$int_DeltaIndex]{tsp_mtime}
									: undef ),
								});
							}
						}

					DEBUG(sub { return(q{Data before sizing: } . Dumper({
						har_ToSize	=> \@har_ToSize,
						})); });

					if ( @cmd_Sizing
					&& open(my $dsc_Sizing, q{-|}, qq{@cmd_Sizing}) ) {
						DEBUG(qq{Running sizing via >@cmd_Sizing<.});

						my $cnt_Line				= -1;
						my %str_PercentName			= (
							0		=> undef,		# not required
							25		=> q{int_DeltaSize},
							50		=> q{int_Size},
							75		=> q{int_Elements},
							);

						while ( my $str_Line = readline($dsc_Sizing) ) {
							chomp($str_Line);
							TRACE(qq{Got line: $str_Line});

							my $int_Value			= undef;

							# int_Index for har_ToSize indices, int_Part to distinguish type
							my ($int_Index, $int_Part)	=		# index = 0, 1, 2, ... ; part = 0, 25, 50, 75, 0, 25, 50, 75
								map { $_ + 0 }				# 3 Make it to numbers
								sprintf(q{%.2f}, ++$cnt_Line / 4)	# 1 Force decimal positions for regex...
								=~ m{^([0-9]+)\.([0-9]+)$};		# 2 ...to grep them separatly and return them as LIST

							if ( $str_Line =~ m{$rxp_SizingNumber} ) {
								$int_Value		= $1;
								TRACE(qq{Got value:=$int_Value .});
								}

							TRACE(qq{int_Index:=$int_Index, int_Part:=$int_Part, int_Value:=} . ( $int_Value // q{NULL} ));

							if ( defined($str_PercentName{$int_Part}) ) {
								$har_ToSize[$int_Index]{$str_PercentName{$int_Part}}		= $int_Value;

								# FreeBSD's du gives us the count of 512-byte blocks.
								if ( $^O eq q{freebsd}
								&& defined($har_ToSize[$int_Index]{$str_PercentName{$int_Part}})
								&& $str_PercentName{$int_Part} =~ m{$rxp_SizeKey} ) {
									TRACE(qq{System is FreeBSD and du requires postprocessing: multiplying $har_ToSize[$int_Index]{$str_PercentName{$int_Part}} sectors by 512 to get bytes.});
									$har_ToSize[$int_Index]{$str_PercentName{$int_Part}}	*= 512;
									$int_Value						*= 512;
									}

								TRACE(sprintf(q{Setting %s:=%s.}, $str_PercentName{$int_Part}, ( defined($int_Value) ? qq{"$int_Value"} : q{NULL} )));
								}
							}

						close($dsc_Sizing);
						}
					elsif ( @cmd_Sizing ) {
						FATAL(qq{Unable to run sizing >@cmd_Sizing<.});
						return(false);
						}

					DEBUG(sub { return(q{Sized: } . Dumper({
						har_ToSize	=> \@har_ToSize,
						})); });

					# Add sized positions to regular arrays
					foreach my $har_Sized ( @har_ToSize ) {
						push(@are_Backups,	[ map { $har_Sized->{$_} } @str_BHeaderSequence ]);
						push(@are_Allocations,	[ map { $har_Sized->{$_} } @str_AHeaderSequence ]);
						}

					# Shouldn't be required at all because @har_ToSize was sorted this way in the first place indirectly through are_FSDirs' sorting
					@are_Backups			= sort { $b->[$int_BHsortPosition] <=> $a->[$int_BHsortPosition] } @are_Backups;
					@are_Allocations		= sort { $b->[$int_AHsortPosition] <=> $a->[$int_AHsortPosition] } @are_Allocations;

					# Will be logged by QueryDB()
					#TRACE(sub { return(q{Final arrays for saving: } . Dumper({
					#	are_Backups	=> \@are_Backups,
					#	are_Allocations	=> \@are_Allocations,
					#	})); });

					if ( defined($tsp_TaskTime) ) {

						# Loop header
						foreach my ( $sql_Statement, $are_Data ) (

						# Add job
						$sql_InsertJob, [ $har_JobsConfigs{$str_Job}{_str_JobName} ],

						# Add task
						$sql_InsertTaskTimeAndJob, [ $har_JobsConfigs{$str_Job}{_str_JobName}, $tsp_TaskTime ],

						# Add source_groups
						$sql_InsertSourceGroup, [
							map { [ $_ ] }
							grep { ! $har_DuplicateCheck{bol_LocationBlocks}{$_}++ }
							values(%{$har_JobsConfigs{$str_Job}{_har_LocationBlocks}})
							],

						# Add source_pathes
						$sql_InsertSourcePath, [
							map { [ $_ ] }
							grep { ! $har_DuplicateCheck{bol_Sources}{$_}++ }
							STR_DummyLocation, ( grep { $_ } map { ( @{$har_JobsConfigs{$str_Job}{har_Config}{$_}{source}} ) } ARE_Generations )
							],

						# Allocate source groups and pathes
						$sql_InsertSourceAllocation, [
							map { my $str_Generation = $_; map { [ $har_JobsConfigs{$str_Job}{_har_LocationBlocks}{$str_Generation}, $_, $har_JobsConfigs{$str_Job}{_str_JobName} ] }
							@{$har_JobsConfigs{$str_Job}{har_Config}{$str_Generation}{source}} } keys(%{$har_JobsConfigs{$str_Job}{_har_LocationBlocks}})
							],

						# Add notations
						$sql_InsertNotation, [
							map { [ $_->{str_Notation} ] }
							grep { ! $har_DuplicateCheck{bol_Notations}{$_}++ }
							@har_ToSize
							],

						# Add backups
						$sql_InsertBackupSizing, \@are_Backups,

						# Allocate backups
						$sql_InsertMxdAllocation, \@are_Allocations,

						# Loop body
						) {
							if ( ! QueryDB($har_JobsConfigs{$str_Job}{_uri_DatabaseLocation}, $sql_Statement, $are_Data) ) {
								FATAL(qq{Database error happened.});
								TRACE(q{Disposing lock...});
								$har_JobsConfigs{$str_Job}{_obj_Lock}->MainUnlock();
								TRACE(q{Lock freed.});
								return(undef);
								}
							}

						}
					else {
						FATAL(qq{Unable to gather task time.});
						return(false);
						}
					} # lop_AskUser1
				}

			TRACE(q{Disposing lock...});
			$har_JobsConfigs{$str_Job}{_obj_Lock}->MainUnlock();
			TRACE(q{Lock freed.});
			}

		DEBUG(sprintf(q{Sizing %s.}, ( $bol_Succeeded
			? q{succeeded}
			: q{failed}
			)));

		return($bol_Succeeded);
		}

	sub _FastSequenceSteps {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;

		if ( $har_SubCommands{backup}{bol_Active} ) {
			PrepareJob($str_Job) or return(false);
			ServerPreRun($str_Job) or return(false);
			ClientPreRun($str_Job) or return(false);
			if ( Backup($str_Job) ) {
				ClientPostRun($str_Job) or return(false);
				ServerPostRun($str_Job);
				}
			}
		}

	sub _FastSequenceCleanup {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;

		if ( $har_SubCommands{backup}{bol_Active}
		&& $har_JobsConfigs{$str_Job}{_bol_Succeeded} ) {
			Cleanup($str_Job);
			}
		}

	sub FastSequence {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		if ( $har_SubCommands{backup}{bol_Active} ) {
			my %str_LockedJobs		= ();
			DEBUG(q{Starting fast backup sequence.});

			lop_Backup:
			foreach my $str_Job ( @str_ActiveJobs ) {
				TRACE(q{Acquiring lock...});
				$har_JobsConfigs{$str_Job}{_obj_Lock}->MainLock() or next(lop_Backup);
				TRACE(q{Got lock.});
				$str_LockedJobs{$str_Job}	= true;
				_FastSequenceSteps($str_Job);
				}

			TRACE(q{Starting cleanup sequence.});
			lop_Cleanup:
			foreach my $str_Job ( @str_ActiveJobs ) {
				if ( defined($str_LockedJobs{$str_Job}) ) {
					_FastSequenceCleanup($str_Job);
					TRACE(q{Disposing lock...});
					$har_JobsConfigs{$str_Job}{_obj_Lock}->MainUnlock();
					TRACE(q{Lock freed.});
					}
				}
			}

		if ( $har_SubCommands{size}{bol_Active} ) {
			DEBUG(q{Starting sizing sequence.});
			foreach my $str_Job ( @str_ActiveJobs ) {
				Sizing($str_Job);
				}
			}
		}

	sub ParallelFastSequence {
		DEBUG(q{Starting parallel fast backup sequence.});
		foreach my $str_Job ( @str_ActiveJobs ) {
			RunAsChild(sub {
				TRACE(q{Acquiring lock...});
				if ( ! $har_JobsConfigs{$str_Job}{_obj_Lock}->MainLock() ) {
					FATAL(qq{Unable to acquire lock for $str_Job.});
					return(false);
					}
				TRACE(q{Got lock.});
				_FastSequenceSteps($str_Job);
				_FastSequenceCleanup($str_Job);
				TRACE(q{Disposing lock...});
				$har_JobsConfigs{$str_Job}{_obj_Lock}->MainUnlock();
				TRACE(q{Lock freed.});

				Sizing($str_Job);
				});
			}
		}

	sub _NormalSequenceSteps {
		TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
		my $str_Job		= shift;

		if ( $har_SubCommands{backup}{bol_Active} ) {
			TRACE(qq{Acquiring lock for $str_Job...});
			if ( ! $har_JobsConfigs{$str_Job}{_obj_Lock}->MainLock() ) {
				FATAL(qq{Unable to acquire lock for $str_Job.});
				return(false);
				}
			TRACE(q{Got lock.});
			PrepareJob($str_Job) or return(false);
			if ( ! $har_JobsConfigs{$str_Job}{_bol_HardLinkProtect} ) {
				Cleanup($str_Job);
				}
			ServerPreRun($str_Job) or return(false);
			ClientPreRun($str_Job) or return(false);
			if ( Backup($str_Job) ) {
				ClientPostRun($str_Job) or return(false);
				ServerPostRun($str_Job);
				}
			if ( $har_JobsConfigs{$str_Job}{_bol_HardLinkProtect} ) {
				Cleanup($str_Job);
				}
			TRACE(q{Disposing lock...});
			$har_JobsConfigs{$str_Job}{_obj_Lock}->MainUnlock();
			TRACE(q{Lock freed.});
			}

		Sizing($str_Job);
		}

	sub NormalSequence {
		DEBUG(q{Starting normal backup sequence.});
		foreach my $str_Job ( @str_ActiveJobs ) {
			TRACE(qq{...for job "$har_JobsConfigs{$str_Job}{_str_JobName}".});
			if ( _NormalSequenceSteps($str_Job) ) {
				TRACE(q{Done.});
				}
			else {
				ERROR(qq{Backup and/or sizing of $har_JobsConfigs{$str_Job}{_str_JobName} failed.});
				}
			}
		}

	sub ParallelNormalSequence {
		DEBUG(q{Starting parallel normal backup sequence.});
		foreach my $str_Job ( @str_ActiveJobs ) {
			RunAsChild(sub {
				_NormalSequenceSteps($str_Job) or ERROR(qq{Backup and/or sizing of $har_JobsConfigs{$str_Job}{_str_JobName} failed.});
				});
			}
		}

	foreach my $str_Job ( @str_ActiveJobs ) {
		my $str_FoldCasedJob			= fc($str_Job);

		if ( defined($har_JobsConfigs{$str_FoldCasedJob}) ) {
			$str_Job			= $str_FoldCasedJob;

			if ( $str_Job
			&& -e $str_Job
			&& -T realpath($str_Job) ) {
				local $|	= true;
				my $tsp_Wait	= time + 60;
				local $SIG{INT}	= sub {
					TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
					print qq{\n};
					exit(120);
					};

				LOGWARN(sprintf(qq{There are two files with the same name: "./$str_Job"
and a job file at the default job path:
"$har_JobsConfigs{$str_Job}{uri_File}".
The one from default job path will be ran. If it is want to run
the local file use the realtive path syntax. Interrupt now by
pressing [Ctrl]+[c] if you want to change. (Waiting for %d
seconds.)}, $tsp_Wait - time));

				print qq{\n};

				while ( time <= $tsp_Wait ) {
					printf(qq{% 2s seconds left.\r}, $tsp_Wait - time);

					sleep(1);
					}
				print qq{\n};
				}
			}
		elsif ( -e $str_Job			# Is a path
		&& -T realpath($str_Job) ) {
			TRACE(q{Job file found.});

			$har_JobsConfigs{$str_Job}	= ReadConfigurationFile($str_Job);
			}
		else {
			WARN(qq{Unknown job "$str_Job". Will be omitted.});
			$str_Job			= undef;
			}
		}
	@str_ActiveJobs					= grep { defined($_) } @str_ActiveJobs;

	DEBUG(sub { return(q{Active jobs, which will be run: } . Dumper({ str_ActiveJobs => \@str_ActiveJobs })); });

	if ( $bol_Parallel
	&& $bol_Wait ) {		# 1 1
		TRACE(q{Running in parallel mode in foreground.});
		# Start all jobs together but don't exit to the background but wait for all forks to finish => blocking
		GlobalPreRun() or return(false);
		if ( $bol_Fast ) {
			ParallelFastSequence();
			}
		else {
			ParallelNormalSequence();
			}

		WaitForChildren(0);
		GlobalPostRun();
		}
	elsif ( $bol_Parallel
	&& ! $bol_Wait ) {	# 1 0
		TRACE(q{Running in parallel mode in background.});
		# Start all jobs together and exit the main application => non-blocking
		GlobalPreRun() or return(false);
		if ( $bol_Fast ) {
			ParallelFastSequence();
			}
		else {
			ParallelNormalSequence();
			}

		RunAsChild(sub {
			DEBUG(qq{Management agent started on PID C$$.});
			WaitForChildren(0);
			TRACE(qq{All children died.});
			GlobalPostRun();
			TRACE(qq{GlobalPostRun finished.});
			});
		}
	elsif ( ! $bol_Parallel
	&& $bol_Wait ) {	# 0 1
		TRACE(q{Running sequencially in foreground.});
		# Start jobs sequentially and wait until finished => blocking
		GlobalPreRun() or return(false);
		if ( $bol_Fast ) {
			FastSequence();
			}
		else {
			NormalSequence();
			}
		GlobalPostRun();
		}
	else {						# 0 0
		TRACE(q{Running sequencially in background.});
		# Start jobs sequentially but exit the main application => non-blocking
		RunAsChild(sub {
			TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
			GlobalPreRun() or return(false);
			if ( $bol_Fast ) {
				FastSequence();
				}
			else {
				NormalSequence();
				}
			GlobalPostRun();
			});
		}
	}

sub ListSizes {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my @str_ActiveJobs		= ExpandARGV();
	my $are_Result			= undef;
	my %are_SourceGroups		= (
		# <STR sgroup_name> => [ ARE <URI spath>, <URI spathN...> ],
		);
	my @str_Sequence		= qw(
		backup_notation
		backup_elments
		backup_size
		delta
		backup_mtime
		);
	my %str_Header			= (
		backup_notation		=> q{DIRECTORY},
		backup_elments		=> q{ELEMENTS},
		backup_size		=> q{FULL SIZE},
		delta			=> q{DIFFERENCE},
		backup_mtime		=> q{MODIFICATION TIME},

		# CSV only
		job_name		=> q{JOB},
		pathes			=> q{PATHES (ARRAY)},
		sgroups_name		=> q{PATH GROUP NAME},
		delta_notation		=> q{DELTA DIRECTORY},
		);
	my @str_CSVheaderSequence	= sort { $a cmp $b } keys(%str_Header);	# Make sure sequence stays the same way all time
	# Length inside each column, including spaces
	my %int_Lengthes		= ();
	#				  spaces before and after	borders inbetween	+2 Borders at start and ending
	my $int_FullWidth		= 0;	# Adding maximum lengthes later
	my $int_InnerWidth		= 0;
	my $str_TableSyntax		= STR_BorderVertical . join(STR_BorderVertical, map { q{ %s } } @str_Sequence) . STR_BorderVertical;
	my $str_TableStartSyntax	= '';
	my $str_HeaderRow		= '';
	my $str_FooterSyntax		= '';
	my @har_OutputData		= (
		# { <HAR str_Name => <STR job name> . <STR path group>, are_Lines => <ARE of HAR containing select's rows> }
		);
	my sub PrettyLocalTime;

	sub PrettyLocalTime {
		my $obj_LocalTime = localtime(shift);

		if ( $bol_BatchMode ) {
			return($obj_LocalTime->strftime(q{%Y-%m-%dT%H:%M:%S%z}));
			}
		else {
			return($obj_LocalTime->strftime(q{%a %d. %b %H:%M:%S %Z %Y}));
			}
		}

	if ( $har_SubCommands{list}{bol_Active} ) {
		TRACE(qq{Listing is activated.});
		}
	else {
		DEBUG(qq{Listing is not activated.});
		return(true);
		}

	if ( scalar(@str_ActiveJobs) == 0 ) {
		FATAL(qq{To few arguments! Requires job name(s).});
		return(false);
		}

	GlobalPreRun() or return(false);

	foreach my $str_Key ( @str_Sequence ) {
		$int_Lengthes{$str_Key}	= length($str_Header{$str_Key});
		}

	if ( $bol_SelectList ) {
		TRACE(q{Manual selection was requested.});

		my $int_TaskID	= undef;
		my %har_Tasks	= (
			# <INT id> => <STR Time string>,
			);
		my $str_Select	= qq{  %7s  %8s};
		my $are_Jobs	= undef;

		if ( scalar(@str_ActiveJobs) != 1 ) {
			FATAL(q{Must be one argument only to use --ask/--select!});
			GlobalPostRun();
			return(false);
			}

		$are_Jobs	= QueryDB($har_JobsConfigs{$str_ActiveJobs[0]}{_uri_DatabaseLocation}, $sql_SelectTasksByJob, [ $har_JobsConfigs{$str_ActiveJobs[0]}{_str_JobName} ]) or return(false);

		if ( ! @{$are_Jobs} ) {
			FATAL(qq{No sizing data for $str_ActiveJobs[0].});
			return(false);
			}

		%har_Tasks	= map { $_->{id} => scalar(localtime($_->{time})) } @{$are_Jobs};

		DEBUG(sub { return(Dumper({ har_Tasks => \%har_Tasks })); });

		lop_UserRequest:
		while ( true ) {
			print qq{Select a sizing by ID.\n\n} .
				sprintf(qq{$str_Select\n}, q{ID }, q{SIZED AT})
					.  join(qq{\n},
						map { sprintf($str_Select, qq{[$_]}, $har_Tasks{$_}) }
						sort { $a <=> $b }
						keys(%har_Tasks)
						)
					. qq{\n\nID of date you want to see: };

			chomp($int_TaskID	= <STDIN>);

			if ( exists($har_Tasks{$int_TaskID}) ) {
				DEBUG(qq{User decided for task with id '$int_TaskID'.});
				last(lop_UserRequest);
				}
			else {
				print STDERR qq{ID '$int_TaskID' is unknown or invalid.\n\n};
				}
			}

		$are_Result	= QueryDB($har_JobsConfigs{$str_ActiveJobs[0]}{_uri_DatabaseLocation}, $sql_SelectSizingByJobAndTaskId, [ $har_JobsConfigs{$str_ActiveJobs[0]}{_str_JobName}, $int_TaskID ]);

		if ( ! defined($are_Result) ) {
			TRACE(q{Got no result.});
			GlobalPostRun();
			return(false);
			}
		}
	else {
		TRACE(q{Regular output.});

		foreach my $str_Job ( @str_ActiveJobs ) {
			my $are_PartialResult	= QueryDB($har_JobsConfigs{$str_Job}{_uri_DatabaseLocation}, $sql_SelectLastSizingByJob, [ $har_JobsConfigs{$str_Job}{_str_JobName} ]);
			my $are_PartialSGroups	= QueryDB($har_JobsConfigs{$str_Job}{_uri_DatabaseLocation}, $sql_SelectSourcePathesAndGroups);

			if ( defined($are_PartialResult)
			&& defined($are_PartialSGroups) ) {
				TRACE(q{Got requested data.});

				foreach my $har_Source ( @{$are_PartialSGroups} ) {

					if ( ! defined($are_SourceGroups{$har_Source->{sgroup_name}}) ) {
						$are_SourceGroups{$har_Source->{sgroup_name}}	= [];
						}

					push(@{$are_SourceGroups{$har_Source->{sgroup_name}}}, $har_Source->{spath});
					}

				push(@{$are_Result}, @{$are_PartialResult});
				}
			else {
				DEBUG(q{Got no source pathes.});
				GlobalPostRun();
				return(false);
				}
			}
		}

	foreach my $str_Key ( keys(%are_SourceGroups) ) {
		@{$are_SourceGroups{$str_Key}}			= MakeListUnique(@{$are_SourceGroups{$str_Key}});
		}

	DEBUG(sub { return(q{Results got: } . Dumper({ are_Result => $are_Result, are_SourceGroups => \%are_SourceGroups })); });

	foreach my $har_DataToPrepare ( @{$are_Result} ) {
		$har_DataToPrepare->{backup_elments}		= HumanReadableInteger($har_DataToPrepare->{backup_elments});
		$har_DataToPrepare->{backup_size}		= HumanReadableSize($har_DataToPrepare->{backup_size});
		$har_DataToPrepare->{backup_mtime}		= PrettyLocalTime($har_DataToPrepare->{backup_mtime});
		$har_DataToPrepare->{delta_size}		= defined($har_DataToPrepare->{delta_size})		? HumanReadableSize($har_DataToPrepare->{delta_size}) : undef;
		$har_DataToPrepare->{delta}			= defined($har_DataToPrepare->{delta})			? HumanReadableSize($har_DataToPrepare->{delta}) : undef;
		$har_DataToPrepare->{delta_mtime}		= defined($har_DataToPrepare->{delta_mtime})		? PrettyLocalTime($har_DataToPrepare->{delta_mtime}) : undef;
		$har_DataToPrepare->{task_time}			= defined($har_DataToPrepare->{task_time})		? PrettyLocalTime($har_DataToPrepare->{task_time}) : undef;
		}

	DEBUG(sub { return(q{Results adapted to: } . Dumper({ are_Result => $are_Result })); });

	if ( $bol_BatchMode ) {
		TRACE(q{Batch mode active - building CSV.});

		require Text::CSV;
		Text::CSV->import(qw( :DEFAULT ));

		my $obj_TextCSV					= Text::CSV->new({
			binary		=> 1,
			strict		=> 1,
			always_quote	=> 1,
			skip_empty_rows	=> q{skip},
			blank_is_undef	=> 1,
			quote_empty	=> 1,
			});

		if ( $obj_TextCSV ) {
			TRACE(q{CSV writing module loaded.});
			}
		else {
			FATAL(q{Couldn't load CSV writing module.});
			return(false);
			}

		unshift(@{$are_Result}, dclone(\%str_Header));

		foreach my $har_Line ( @{$are_Result} ) {

			# Do not change the header
			if ( ! defined($har_Line->{pathes}) ) {
				TRACE(q{Creating key 'pathes'.});

				$har_Line->{pathes}		= sprintf(q{[%s]}, join(q{,},
					map { qq{"$_"} }
					sort { $a cmp $b }
					grep { defined($_) }
					@{$are_SourceGroups{$har_Line->{sgroups_name}}}
					));
				}

			if ( ! $obj_TextCSV->combine(map { $har_Line->{$_} } @str_CSVheaderSequence) ) {
				FATAL(q{CSV line building is not possible});
				return(false);
				}

			$har_Line->{str_Output}			= $obj_TextCSV->string();
			}
		}
	else {
		TRACE(q{Normal mode. Building list output with ASCII art.});

		foreach my $har_DataToPrepare ( @{$are_Result} ) {
			foreach my $str_Header ( @str_Sequence ) {
				if ( defined($har_DataToPrepare->{$str_Header})
				&& length($har_DataToPrepare->{$str_Header}) > $int_Lengthes{$str_Header} ) {

					# Spaces before and after apply as well
					$int_Lengthes{$str_Header}	= length($har_DataToPrepare->{$str_Header});
					}
				}
			}

		# Full width
		map { $int_FullWidth					+= ($int_Lengthes{$_} + 2) } @str_Sequence;	# Including white spaces
		$int_FullWidth						+= scalar(@str_Sequence) + 1;

		# Width without borders on start and end
		$int_InnerWidth						= $int_FullWidth - 4;
		TRACE(qq{FullWidth:=$int_FullWidth characters, Inner width:=$int_InnerWidth});

		$int_Lengthes{backup_notation}				*= -1;	# Left aligning through negative value
		$str_TableSyntax					= sprintf($str_TableSyntax, map { qq{%$int_Lengthes{$_}s} } @str_Sequence);
		DEBUG(qq{Syntax for sprintf(): str_TableSyntax:='$str_TableSyntax'.});

		# Prepare table separators
		#							├────────────────┬─────────────────────────┬─────────────┬─────────────┬───────────────────┬────────┤
		$str_TableStartSyntax					= STR_BorderCrossFL
			. join(STR_BorderCrossFT,
				map { STR_BorderHorizontal x (( $int_Lengthes{$_} < 0 ? $int_Lengthes{$_} * -1 : $int_Lengthes{$_} ) + 2) }
				@str_Sequence)
			. STR_BorderCrossFR;
		#							├────────────────┬─────────────────────────┬─────────────┬─────────────┬───────────────────┬────────┤
		$str_HeaderRow						= sprintf($str_TableSyntax, map { $str_Header{$_} } @str_Sequence)
			. qq{\n}
			.  STR_BorderCrossFL
			. join(STR_BorderCross4,
				map { STR_BorderHorizontal x (( $int_Lengthes{$_} < 0 ? $int_Lengthes{$_} * -1 : $int_Lengthes{$_} ) + 2) }
				@str_Sequence)
			. STR_BorderCrossFR;
		#							├────────────────┼─────────────────────────┼─────────────┼─────────────┼───────────────────┼────────┤
		#							└────────────────┴─────────────────────────┴─────────────┴─────────────┴───────────────────┴────────┘
		$str_FooterSyntax					= STR_BorderCornerBL
			. join(STR_BorderCrossFB,
				map { STR_BorderHorizontal x (( $int_Lengthes{$_} < 0 ? $int_Lengthes{$_} * -1 : $int_Lengthes{$_} ) + 2) }
				@str_Sequence)
			. STR_BorderCornerBR;

		lop_PrepareOutput:
		for ( my $int_Index = 0 ; $int_Index < scalar(@{$are_Result}) ; $int_Index++ ) {
			my $str_Header				= '';
			my $str_Footer				= '';

			# If we're at the beginning
			if ( $int_Index == 0

			# If it's a different job as before
			|| $are_Result->[$int_Index - 1]{job_name} ne $are_Result->[$int_Index]{job_name} 

			# If it's a different path group as before
			|| $are_Result->[$int_Index - 1]{sgroups_name} ne $are_Result->[$int_Index]{sgroups_name} ) {

			# Build header
				my @str_Pathes			= ();
				my $str_Joiner			= q{, };
				my @str_Helper			= map { ShellQuote($_) } sort { $a cmp $b } grep { defined($_) && $_ ne '' } @{$are_SourceGroups{$are_Result->[$int_Index]{sgroups_name}}};

				lop_BuildPathesBlock:
				foreach my $str_Path ( @str_Helper ) {
					TRACE(qq{Iterating over $str_Path});

					TRACE(sub { return(q{Elements: } . Dumper({ str_Pathes => \@str_Pathes })); });

					# Add Joiner
					if ( scalar(@str_Pathes) > 0
					&& $str_Pathes[-1] ne '' ) { # if last element holds data
						TRACE(q{Adding joiner.});

						# Joiner still fits
						if ( length($str_Pathes[-1] . $str_Joiner) < $int_InnerWidth ) {
							$str_Pathes[-1]		.= $str_Joiner;
							}

						# First character fits
						elsif ( (length($str_Pathes[-1]) + 1) < $int_InnerWidth ) {

							# Append Joiner's first char only
							$str_Pathes[-1]		.= substr($str_Joiner, 0, 1);

							# And create a new line for the current element
							push(@str_Pathes, '');
							}

						# Nothing fits anymore
						else {
							# Joiner on new line
							push(@str_Pathes, $str_Joiner);
							}
						}
					# ELSE: nothing needed to do if line is empty

					# First element
					if ( ! @str_Pathes ) {
						push(@str_Pathes, q{PATHES : });
						}

					# Current path itself is already longer than one or more lines -> just append and warp it
					if ( length($str_Path) > $int_InnerWidth ) {

						# Warp over lines unless it's short enough
						while ( length($str_Pathes[-1] . $str_Path) > $int_InnerWidth ) {

							# Append to pathes and substract taken from current element
							$str_Pathes[-1]	.= substr($str_Path, 0, ($int_InnerWidth - length($str_Pathes[-1])), '');

							# Create next line
							push(@str_Pathes, '');
							}

						# Also append the left overs
						$str_Pathes[-1]		.= $str_Path;
						}

					# If line gets to long
					elsif ( length($str_Pathes[-1] . $str_Path) > $int_InnerWidth ) {

						# Put onto new line
						push(@str_Pathes, $str_Path);
						}

					else {	# Just append it to last line
						$str_Pathes[-1]		.= $str_Path;
						}
					}
				DEBUG(sub { return(qq{Pathes block: } . Dumper({ str_Pathes => \@str_Pathes })); });

				$str_Header			.= qq{\n};

				#				┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
				$str_Header			.= STR_BorderCornerTL
					. (STR_BorderHorizontal x ($int_FullWidth - 2))
					. STR_BorderCornerTR
					. qq{\n};

				#				│ JOB: Jobname (path group name)                                                                    │
				$str_Header			.= sprintf(qq{%s %} . (-1 * $int_InnerWidth) . qq{s %s\n},	# Left aligned
					STR_BorderVertical,
					qq{JOB    : $are_Result->[$int_Index]{job_name} ($are_Result->[$int_Index]{sgroups_name})},
					STR_BorderVertical
					);

				##				├───────────────────────────────────────────────────────────────────────────────────────────────────┤
				#$str_Header			.= STR_BorderCrossFL . (STR_BorderHorizontal x ($int_FullWidth - 2)) . STR_BorderCrossFR . qq{\n};

				#				│ PATHES: "/path", "/", "..."                                                                       │
				$str_Header			.= join('', map { sprintf(qq{%s %} . (-1 * $int_InnerWidth) . qq{s %s\n}, STR_BorderVertical, $_, STR_BorderVertical) } @str_Pathes);

				#				├────────────────┬─────────────────────────┬─────────────┬─────────────┬───────────────────┬────────┤
				$str_Header			.= qq{$str_TableStartSyntax\n$str_HeaderRow\n};
				}

			# If we're at the last element
			if ( $int_Index == $#{$are_Result}

			# If it's a different job as next
			|| $are_Result->[$int_Index + 1]{job_name} ne $are_Result->[$int_Index]{job_name} 

			# If it's a different path group as next
			|| $are_Result->[$int_Index + 1]{sgroups_name} ne $are_Result->[$int_Index]{sgroups_name} ) {

				#				└────────────────┴─────────────────────────┴─────────────┴─────────────┴───────────────────┴────────┘
				$str_Footer			.= qq{\n$str_FooterSyntax\n}; # qq{\n} . STR_BorderCornerBL . (WORK: splitted blocks over colums via STR_BorderCrossFB) . STR_BorderCornerBR . qq{\n};
				}

			# Combine blocks
			$are_Result->[$int_Index]{str_Output}	= $str_Header
				. sprintf($str_TableSyntax, map { defined($are_Result->[$int_Index]{$_}) ? $are_Result->[$int_Index]{$_} : q{N/A} } @str_Sequence)
				. $str_Footer;
			}
		}

	DEBUG(sub { return(q{Result: } . Dumper({ are_Result => $are_Result })); });

	# Real output
	print join('', map { qq{$_->{str_Output}\n} } @{$are_Result});

	GlobalPostRun();
	return(true);
	}

sub MakeListUnique {
	my $mxd_List		= \@_;
	my %bol_Seen		= ();

	return(grep { ! $bol_Seen{$_}++ } @{$mxd_List});
	}

sub HumanReadableSize {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $int_Bytes		= shift;

	TRACE(qq{Checking '$int_Bytes'.});

	if ( defined($int_Bytes)
	&& $int_Bytes =~ m{$rxp_Integer} ) {
		TRACE(q{Looks like an integer.});

		my $str_PrettySize	= undef;
		my $str_PrettyUnit	= q{Byte};
		my $int_CalculationBy	= 1_024;
		my $str_Addition	= q{iB};
		my $str_Unit		= $str_Unit;

		if ( ! defined($str_Unit) ) {	# Calculate if not set by user
			TRACE(q{No unit was set, calculating automatically.});

			if ( $int_Bytes >= $int_CalculationBy ** 8 ) {
				$str_Unit	= q{y};
				}
			elsif ( $int_Bytes >= $int_CalculationBy ** 7 ) {
				$str_Unit	= q{z};
				}
			elsif ( $int_Bytes >= $int_CalculationBy ** 6 ) {
				$str_Unit	= q{e};
				}
			elsif ( $int_Bytes >= $int_CalculationBy ** 5 ) {
				$str_Unit	= q{p};
				}
			elsif ( $int_Bytes >= $int_CalculationBy ** 4 ) {
				$str_Unit	= q{t};
				}
			elsif ( $int_Bytes >= $int_CalculationBy ** 3 ) {
				$str_Unit	= q{g};
				}
			elsif ( $int_Bytes >= $int_CalculationBy ** 2 ) {
				$str_Unit	= q{m};
				}
			elsif ( $int_Bytes >= $int_CalculationBy ** 1 ) {
				$str_Unit	= q{k};
				}
			else {
				$str_Unit	= q{b};
				}

			DEBUG(qq{Calculated size: '$str_Unit'.});
			}

		if ( $str_Unit =~ m{^[A-Z]$} ) {	# All upper case
			TRACE(q{Calculation by 1,000 is set.});

			$int_CalculationBy	= 1_000;
			$str_Addition		= q{B};
			}

		if ( $str_Unit eq q{b} ) {
			$int_CalculationBy	= 1;
			}
		elsif ( fc($str_Unit) eq fc(q{k}) ) {
			$int_CalculationBy	**= 1;
			$str_PrettyUnit		= qq{K$str_Addition};
			}
		elsif ( fc($str_Unit) eq fc(q{m}) ) {
			$int_CalculationBy	**= 2;
			$str_PrettyUnit		= qq{M$str_Addition};
			}		
		elsif ( fc($str_Unit) eq fc(q{g}) ) {
			$int_CalculationBy	**= 3;
			$str_PrettyUnit		= qq{G$str_Addition};
			}		
		elsif ( fc($str_Unit) eq fc(q{t}) ) {
			$int_CalculationBy	**= 4;
			$str_PrettyUnit		= qq{T$str_Addition};
			}		
		elsif ( fc($str_Unit) eq fc(q{p}) ) {
			$int_CalculationBy	**= 5;
			$str_PrettyUnit		= qq{P$str_Addition};
			}		
		elsif ( fc($str_Unit) eq fc(q{e}) ) {
			$int_CalculationBy	**= 6;
			$str_PrettyUnit		= qq{E$str_Addition};
			}		
		elsif ( fc($str_Unit) eq fc(q{z}) ) {
			$int_CalculationBy	**= 7;
			$str_PrettyUnit		= qq{Z$str_Addition};
			}		
		elsif ( fc($str_Unit) eq fc(q{y}) ) {
			$int_CalculationBy	**= 8;
			$str_PrettyUnit		= qq{Y$str_Addition};
			}		

		$str_PrettySize			= HumanReadableFloat(sprintf(q{%.2f}, $int_Bytes / $int_CalculationBy));

		DEBUG(qq{Calculated '$int_Bytes' bytes to '$str_PrettySize $str_PrettyUnit'.});

		return(qq{$str_PrettySize $str_PrettyUnit});
		}
	else {
		WARN(qq{Not recognized as number: '$int_Bytes'.});
		return($int_Bytes);
		}
	}

sub HumanReadableTimeSpan {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $int_Seconds		= shift;
	my @str_Times		= ();

	foreach my $har_TimeSpawn ( (
	{ pretty => q{week},	span	=> INT_OneWeek,		},
	{ pretty => q{day},	span	=> INT_OneDay,		},
	{ pretty => q{hour},	span	=> INT_OneHour,		},
	{ pretty => q{minute},	span	=> INT_OneMinute,	},
	{ pretty => q{second},	span	=> INT_OneSecond,	},
	) ) {
		if ( $int_Seconds >= $har_TimeSpawn->{span} ) {
			TRACE(qq{Calculating for $har_TimeSpawn->{pretty}.});
			my $int_Time	= floor($int_Seconds / $har_TimeSpawn->{span});
			$int_Seconds	-= $int_Time * $har_TimeSpawn->{span};

			push(@str_Times, sprintf(q{%d %s}, $int_Time,
				( $int_Time == 1 ? $har_TimeSpawn->{pretty} : qq{$har_TimeSpawn->{pretty}s} )));
			}
		}

	if ( $int_Seconds ) {
		WARN(qq{Something went wrong. Calculeated to $int_Seconds seconds, while it should be 0 seconds.});
		}
	else {
		DEBUG(qq{Returning "@str_Times".});
		}

	return(qq{@str_Times});
	}

sub HumanReadableFloat {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $flt_Number		= shift;
	my $str_PrettyNumber	= undef;

	if ( defined($flt_Number)
	&& $flt_Number =~ m{$rxp_Floating} ) {
		my $int_Integer		= $1;
		my $int_Decimal		= $2;

		$str_PrettyNumber	= HumanReadableInteger( $flt_Number < 0 ? $int_Integer * -1 : $int_Integer) .
			q{.} . ( defined($int_Decimal) ? join(q{ }, unpack(q{(A2)*}, $int_Decimal)) : q{00} );

		DEBUG(qq{Got number '$flt_Number' and translated it to '$str_PrettyNumber'.});

		return($str_PrettyNumber);
		}
	else {
		DEBUG(qq{Not recognized as number: '$flt_Number'.});

		return($flt_Number);
		}
	}

sub HumanReadableInteger {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $int_Number		= shift;
	my $str_PrettyNumber	= undef;

	if ( defined($int_Number)
	&& $int_Number =~ m{$rxp_Integer} ) {
		$str_PrettyNumber	= reverse(join(q{,}, unpack(q{(A3)*}, reverse($int_Number))));

		DEBUG(qq{Got number '$int_Number' and translated it to '$str_PrettyNumber'.});

		return($str_PrettyNumber);
		}
	else {
		DEBUG(qq{Not recognized as number: '$int_Number'.});

		return($int_Number);
		}
	}

sub CreateConfigurationFile {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $bol_Failed		= false;
	my $uri_File		= undef;
	my @str_JobTemplate	= split(/\n/, $str_Data{job_template}, -1);	# Create copy
	my $str_Iterator	= undef;
	my %har_Fitting		= (
		destination	=> { rxp => qr{\Q%DESTINATION%\E},	str_Value => undef, str_Pref => q{#}, str_Default => undef,		},
		loglevel	=> { rxp => qr{\Q%LOGLEVEL%\E},		str_Value => undef, str_Pref => q{#}, str_Default => $har_NeededConfigKeys{loglevel}{_}{str_default},		},
		hostname	=> { rxp => qr{\Q%HOSTNAME%\E},		str_Value => undef, str_Pref => q{#}, str_Default => undef,		},
		ipv46		=> { rxp => qr{\Q%IPV46%\E},		str_Value => undef, str_Pref => q{#}, str_Default => undef,		},
		source		=> { rxp => qr{\Q%SOURCE%\E},		str_Value => undef, str_Pref => q{#}, str_Default => undef,		},
		binrsync	=> { rxp => qr{\Q%BINRSYNC%\E},		str_Value => undef, str_Pref => q{#}, str_Default => $har_NeededConfigKeys{binrsync}{_}{str_default},		},
		#binnice	=> { rxp => qr{\Q%BINNICE%\E},		str_Value => undef, str_Pref => q{#}, str_Default => $har_NeededConfigKeys{binnice}{_}{str_default},		},
		#binionice	=> { rxp => qr{\Q%BINIONICE%\E},	str_Value => undef, str_Pref => q{#}, str_Default => $har_NeededConfigKeys{binionice}{_}{str_default},		},
		#bindu		=> { rxp => qr{\Q%BINDU%\E},		str_Value => undef, str_Pref => q{#}, str_Default => $har_NeededConfigKeys{bindu}{_}{str_default},		},
		#binfind	=> { rxp => qr{\Q%BINFIND%\E},		str_Value => undef, str_Pref => q{#}, str_Default => $har_NeededConfigKeys{binfind}{_}{str_default},		},
		#binwc		=> { rxp => qr{\Q%BINWC%\E},		str_Value => undef, str_Pref => q{#}, str_Default => $har_NeededConfigKeys{binwc}{_}{str_default},		},
		);	# Checks will be applied later
	my @str_FittingKeys		= keys(%har_Fitting);
	my @har_Binaries		= (
		{ key => q{binrsync},	pretty => q{rsync},		var => $uri_BinRsync },
		#{ key => q{binnice},	pretty => q{Nice},		var => $uri_BinNice },
		#{ key => q{binionice},	pretty => q{IONice},		var => $uri_BinIONice },
		#{ key => q{bindu},	pretty => q{Disk Usage},	var => $uri_BinDu },
		#{ key => q{binfind},	pretty => q{Find},		var => $uri_BinFind },
		#{ key => q{binwc},	pretty => q{Word Count},	var => $uri_BinWc },
		);

	foreach my $str_Key ( keys(%har_Fitting) ) {
		$har_Fitting{$str_Key}{ref_Check}	= $har_NeededConfigKeys{$str_Key}{_}{ref_check};
		}

	if ( $har_SubCommands{create}{bol_Active} ) {
		$uri_File	= shift(@ARGV);
		TRACE(sprintf(q{Preparing for configuration %s.}, defined($uri_File) ? qq{"$uri_File"} : q{NULL}));
		}
	else { # "create" is inactive
		DEBUG(qq{Creating is not activated.});

		return(true);
		}

	if ( scalar(@ARGV) > 0 ) {
		DEBUG(sub { return(Dumper({ ARGV => \@ARGV })); });
		FATAL(qq{To many arguments! Only one required.});

		return(false);
		}
	elsif ( scalar(@ARGV) != 0
	|| ! defined($uri_File) ) {
		FATAL(qq{To few arguments! Name for the new job is missing.});

		return(false);
		}

	if ( $uri_File !~ m{$rxp_Slashes} ) {
		$uri_File		= qq{$uri_JobsDir/$uri_File.conf};
		}
	elsif ( -d $uri_File ) {
		FATAL(qq{"$uri_File" is a directory.});

		$bol_Failed		= true;
		}

	DEBUG(qq{Entering configuration creation module for "$uri_File"});

	TRACE(q{Checking for log level.});
	if ( defined($int_LogLevel) ) {
		$har_Fitting{loglevel}{str_Value}	= $int_LogLevel;
		TRACE(q{Loaded from command line.});
		}
	elsif ( defined($har_JobsConfigs{MAIN}{har_Config}{_}{loglevel}[0]) ) {
		$har_Fitting{loglevel}{str_Default}	= $har_JobsConfigs{MAIN}{har_Config}{_}{loglevel}[0];
		TRACE(qq{Loaded from main config file "$uri_MainConfig".});
		}
	else {
		$har_Fitting{loglevel}{str_Default}	= $har_NeededConfigKeys{loglevel}{_}{str_default};
		TRACE(q{Loaded from defaults.});
		}
	TRACE(qq{Done.});
	INFO(q{Log level is set to } . ( defined($har_Fitting{loglevel}{str_Value}) ? qq{"$har_Fitting{loglevel}{str_Value}"} : q{NULL} ) . q{.});

	TRACE(q{Checking destination.});
	if ( defined($uri_Destination) ) {
		$har_Fitting{destination}{str_Value}	= $uri_Destination =~ s{$rxp_EndingSlashes} {}gr;
		TRACE(q{Loaded from command line.});
		}
	elsif ( defined($har_JobsConfigs{MAIN}{har_Config}{_}{destination}[0]) ) {
		$har_Fitting{destination}{str_Default}	= $har_JobsConfigs{MAIN}{har_Config}{_}{destination}[0];
		TRACE(qq{Loaded from main config file "$uri_MainConfig".});
		}
	else {
		$har_Fitting{destination}{str_Default}	= $har_NeededConfigKeys{destination}{_}{str_default};

		if ( defined($har_Fitting{destination}{str_Default}) ) {
			TRACE(q{Loaded from defaults.});
			}
		}
	TRACE(q{Done.});
	INFO(q{Destination is set to } . ( defined($har_Fitting{destination}{str_Value}) ? qq{"$har_Fitting{destination}{str_Value}"} : q{NULL} ) . q{.});

	TRACE(q{Checking hostname.});
	if ( defined($str_Host) ) {
		$har_Fitting{hostname}{str_Value}	= $str_Host;
		}
	TRACE(q{Done.});
	INFO(q{Hostname is set to } . ( defined($har_Fitting{hostname}{str_Value}) ? qq{"$har_Fitting{hostname}{str_Value}"} : q{NULL} ) . q{.});

	TRACE(q{Checking IP address.});
	if ( defined($str_IPv46) ) {
		$har_Fitting{ipv46}{str_Value}		= $str_IPv46;
		}
	TRACE(q{Done.});
	INFO(q{IP is set to } . ( defined($har_Fitting{ipv46}{str_Value}) ? qq{"$har_Fitting{ipv46}{str_Value}"} : q{NULL} ) . q{.});

	TRACE(q{Checking source.});
	if ( $uri_RsyncSourceLocation ) {
		$har_Fitting{source}{str_Value}		= NormalizePath($uri_RsyncSourceLocation);

		TRACE(q{Loaded from command line.});
		}
	else {
		$bol_Failed				= true;

		FATAL(qq{Got no source location.});
		}
	TRACE(q{Done.});
	INFO(q{Source is set to } . ( defined($har_Fitting{source}{str_Value}) ? qq{"$har_Fitting{source}{str_Value}"} : q{NULL} ) . q{.});

	foreach my $har_Binary ( @har_Binaries ) {
		TRACE(qq{Checking $har_Binary->{pretty}.});
		if ( defined($har_Binary->{var}) ) {
			$har_Fitting{$har_Binary->{key}}{str_Value}	= $har_Binary->{var};
			TRACE(qq{Loaded $har_Binary->{pretty} from command line.});
			}
		TRACE(q{Done.});
		INFO(qq{$har_Binary->{pretty} is set to } . ( defined($har_Fitting{$har_Binary->{key}}{str_Value}) ? qq{"$har_Fitting{$har_Binary->{key}}{str_Value}"} : q{NULL} ) . q{.});
		}

	foreach my $str_Key ( keys(%har_Fitting) ) {
		if ( defined($har_Fitting{$str_Key}{str_Value}) 
		&& defined($har_Fitting{$str_Key}{ref_Check}) ) {
			TRACE(qq{Checking value '$har_Fitting{$str_Key}{str_Value}' for $str_Key.});

			if ( ref($har_Fitting{$str_Key}{ref_Check}) eq q{CODE}
			&& ! $har_Fitting{$str_Key}{ref_Check}($har_Fitting{$str_Key}{str_Value}) ) {
				# Functions do their own output

				$bol_Failed	= true;
				}
			elsif ( ref($har_Fitting{$str_Key}{ref_Check}) eq q{Regexp}
			&& $har_Fitting{$str_Key}{str_Value} !~ $har_Fitting{$str_Key}{ref_Check} ) {
				FATAL(qq{Got invalid value for $str_Key.});

				$bol_Failed	= true;
				}
			}
		else {
			TRACE(q{No value or no routine to check.});
			}

		TRACE(q{Done.});
		}

	TRACE(q{Preparing keys.});
	foreach my $str_Key ( keys(%har_Fitting) ) {
		if ( defined($har_Fitting{$str_Key}{str_Value}) ) {
			$har_Fitting{$str_Key}{str_Pref}	= '';
			$har_Fitting{$str_Key}{str_Value}	= qq{"$har_Fitting{$str_Key}{str_Value}"};
			}
		else {
			$har_Fitting{$str_Key}{str_Value}	= ( defined($har_Fitting{$str_Key}{str_Default}) ) ?
				qq{"$har_Fitting{$str_Key}{str_Default}"} : q{""};
			}
		}
	TRACE(q{Keys prepared.});

	if ( $bol_Failed ) {
		FATAL(qq{No file written.});

		return(false);
		}

	TRACE(q{Preparing lines.});
	@str_FittingKeys		= keys(%har_Fitting);	# Update list again
	foreach my $str_Line ( @str_JobTemplate ) {
		chomp($str_Line);

		TRACE(qq{Working on line> $str_Line});

		($str_Iterator)		= grep { $str_Line =~ m{$har_Fitting{$_}{rxp}} } @str_FittingKeys;

		# Debug
		#TRACE(sub { return(Dumper({ har_Fitting => \%har_Fitting })); });
		#($str_Iterator)		= grep { TRACE(qq{rxp:='$har_Fitting{$_}{rxp}'}); $str_Line =~ m{$har_Fitting{$_}{rxp}} } @str_FittingKeys;

		if ( defined($str_Iterator) ) {
			TRACE(qq{Iterator:="$str_Iterator"});

			local $har_Fitting{$str_Iterator}{str_Value}	=
				defined($har_Fitting{$str_Iterator}{str_Value})
					? $har_Fitting{$str_Iterator}{str_Value}
					: '';

			$str_Line	= $har_Fitting{$str_Iterator}{str_Pref} .
				( $str_Line =~ s{$har_Fitting{$str_Iterator}{rxp}} {$har_Fitting{$str_Iterator}{str_Value}}rg );
			}
		elsif ( $str_Line =~ m{$rxp_AllTemplates}
		|| ( $str_Line !~ m{$rxp_Section}
		&& $str_Line !~ m{$rxp_Comment}
		&& $str_Line !~ m{$rxp_EmptyLine} ) ) {
			TRACE(qq{Iterator:=NULL});

			$str_Line	= q{#} . ( $str_Line =~ s{$rxp_AllTemplates} {""}rg );
			}
		}
	TRACE(q{Lines prepared.});

	if ( $bol_Failed ) {
		FATAL(qq{No file written.});

		return(false);
		}

	TRACE(qq{Writing file "$uri_File".});
	if ( -e $uri_File ) {
		$bol_Failed		= true;

		FATAL(qq{File "$uri_File" exists. Will not overwrite.});
		}
	elsif ( open(my $dsc_JobFile, '>', $uri_File) ) {

		print $dsc_JobFile join(qq{\n}, @str_JobTemplate);

		close($dsc_JobFile);

		TRACE(qq{File written.});
		}
	else {
		$bol_Failed		= true;

		FATAL(qq{Can not write "$uri_File".});
		}

	DEBUG(sub { return(sprintf(q{Overall process to create new config file "%s" %s.},
		$uri_File,
		( $bol_Failed ? q{was successful} : q{had errors} ),
		))}); 

	if ( $bol_Failed ) {
		FATAL(qq{No file written.});

		return(false);
		}

	return( $bol_Failed ? false : true);
	}

sub IsValidRsyncSource {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $uri_Source		= shift;
	my $bol_IsRsyncModule	= IsRsyncModule($uri_Source);

	if ( defined($bol_IsRsyncModule) ) {
		DEBUG(qq{"$uri_Source" is a valid target for rsync.});

		return(true);
		}
	else {
		FATAL(qq{Source "$uri_Source" is invalid. It must be an rsync module (one leading colon) or a absolute path (one leading slash).});

		return(false);
		}
	}

sub IsRsyncModule {
	TRACE(do { my $are_Args = \@_ ; sub { return(q{Start: } . Dumper({ are_Args => $are_Args })); } });
	my $uri_Source		= shift;
	
	if ( ! $uri_Source ) {
		FATAL(q{Got no value to check!});

		return(undef);
		}
	elsif ( $uri_Source =~ m{$rxp_Colon}
	&& $uri_Source !~ m{$rxp_Slashes} ) {
		DEBUG(qq{"$uri_Source" is a rsync daemon module.});

		return(true);
		}
	else {
		DEBUG(qq{"$uri_Source" is a file system target.});

		return(false);
		}
	}


##### P R O G R A M #####
if ( grep { m{$rxp_DebugOption} } @ARGV ) {
	Log::Log4perl->easy_init($TRACE);	# Dummy until the full system is initialized
	require Data::Dumper;
	Data::Dumper->import();
	}
else {
	Log::Log4perl->easy_init($WARN);	# Dummy until the full system is initialized
	}

ReadDataBlock() or LOGDIE(qq{Invalid data block.});

GetOptions(

	# Output
	q{h|help|?}					=> \$bol_Help,
	q{usage}					=> \$bol_Help,
	q{V|version}					=> \$bol_Version,
	q{manpage}					=> \$bol_ManPage,
	q{v|verbose|verbosity-level|verbositylevel+}	=> \$int_Verbose,

	# Aktivates extended output for easy Log4perl
	q{l|loglevel|log-level|level+}			=> \$int_LogLevel, # 0 = don't log, 1 = log errors, 2 = log errors and warnings, 3 = log everything
	#q{dryrun|dry-run}				=> \$bol_DryRun,

	# Behaviour
	q{p|parallel}					=> \$bol_Parallel,
	q{w|wait}					=> \$bol_Wait,
	q{f|fast|hurry}					=> \$bol_Fast,

	# Overrides
	q{n|nice-client!}				=> \$bol_NiceClient,
	q{N|nice-server!}				=> \$bol_NiceServer,
	q{hardlinks|protector|hardlinkprotector!}	=> \$bol_ProtectHardLinks,	# only needed for --noprotector and similar
	q{ping-client|ping-check|pong-client!}		=> \$bol_PingCheck,

	# Listing of sizing
	q{select|ask}					=> \$bol_SelectList,
	q{u|units=s}					=> \$str_Unit, # K M G T k m g t b ; K = KB, k = KiB ... , b = bytes
	q{b|batch}					=> \$bol_BatchMode,

	# Create configuration
	q{destination=s}				=> \$uri_Destination,
	q{hostname|dnsname=s}				=> \$str_Host,
	q{ipv4|ipv6|ip6|ip4=s}				=> \$str_IPv46,
	q{S|source|src=s}				=> \$uri_RsyncSourceLocation,
	q{rsync=s}					=> \$uri_BinRsync,
	#q{nice=s}					=> \$uri_BinNice,
	#q{ionice=s}					=> \$uri_BinIONice,
	#q{du=s}					=> \$uri_BinDu,
	#q{find=s}					=> \$uri_BinFind,
	#q{wc=s}					=> \$uri_BinWc,

	) or Usage(1);

## Information
if ( $bol_Help ) {
	if ( $bol_Version ) {
		ShowVersion();
		}
	Usage(0);
	}
elsif ( $bol_Version ) {
	ShowVersion();
	exit(0);
	}
elsif ( $bol_ManPage ) {
	ShowManpage();
	}

if ( defined($str_Unit)
&& $str_Unit !~ m{$rxp_ValidUnits} ) {
	print STDERR qq{Unknown unit '$str_Unit'.\n};
	Usage(9);
	}

if ( $bol_SelectList ) {
	INFO(q{--ask pulls --wait});

	$bol_Wait			= true;
	}

# Required settings
if ( $int_Verbose ) {
	$bol_Wait			= true;
	}

## Preparation
CheckEnvironment() or die q{Environment checks failed.};
SetupLoggers(
	# Nothing loaded yet
	( $int_LogLevel // $int_DefaultLogLevel ),
	( $int_Verbose // $int_DefaultVerbose ),
	) or die qq{Logger setup failed.\n}; # FROM NOW ON WE CAN USE LOG AND VERBOSE AS CONFIGURED
DEBUG(sub { return(q{GetOptions got: } . Dumper({

	# Output
	q{h|help|?}					=> $bol_Help,
	q{usage}					=> $bol_Help,
	q{V|version}					=> $bol_Version,
	q{manpage}					=> $bol_ManPage,
	q{v|verbose|verbosity-level|verbositylevel+}	=> $int_Verbose,

	# Aktivates extended output for easy Log4perl
	q{l|loglevel|log-level|level+}			=> $int_LogLevel, # 0 = don't log, 1 = log errors, 2 = log errors and warnings, 3 = log everything
	#q{dryrun|dry-run}				=> $bol_DryRun,

	# Behaviour
	q{p|parallel}					=> $bol_Parallel,
	q{w|wait}					=> $bol_Wait,
	q{f|fast|hurry}					=> $bol_Fast,
	q{n|nice-client}				=> $bol_NiceClient,
	q{N|nice-server}				=> $bol_NiceServer,
	q{hardlinks|protector|hardlinkprotector!}	=> $bol_ProtectHardLinks,	# only needed for --noprotector and similar
	q{ping-client|pong-client!}			=> $bol_PingCheck,

	# Listing of sizing
	q{select|ask}					=> $bol_SelectList,
	q{u|units=s}					=> $str_Unit, # K M G T k m g t b ; K = KB, k = KiB ... , b = bytes
	q{b|batch}					=> $bol_BatchMode,

	# Create configuration
	q{destination=s}				=> $uri_Destination,
	q{hostname|dnsname=s}				=> $str_Host,
	q{ipv4|ipv6|ip6|ip4=s}				=> $str_IPv46,
	q{S|source|src=s}				=> $uri_RsyncSourceLocation,
	q{rsync=s}					=> $uri_BinRsync,
	q{nice=s}					=> $uri_BinNice,
	q{ionice=s}					=> $uri_BinIONice,
	q{du=s}						=> $uri_BinDu,
	q{find=s}					=> $uri_BinFind,
	q{wc=s}						=> $uri_BinWc,
	})); });

# Set overrides
foreach my ( $bol_Switch, $str_Key ) (
$bol_NiceServer,		q{niceserver},
$bol_NiceClient,		q{niceclient},
$bol_ProtectHardLinks,		q{protecthardlinks},
$bol_PingCheck,			q{pingcheck}
) {
	TRACE(qq{Checking key '$str_Key'.});

	if ( defined($bol_Switch) ) {
		TRACE(sprintf(q{Is set with value '%s'.}, $bol_Switch ? q{true} : q{false}));

		$har_NeededConfigKeys{$str_Key}{_}{str_override}	= $bol_Switch
			? true
			: false;
		}
	}
CheckForSystemApplications() or LOGDIE(qq{Missing dependencies.});

# Prepare input
PrepareSubCommands() or LOGDIE(qq{Inappropriate sub-command(s).});
LoadDefaultConfiguration() or LOGDIE(qq{Unable to load config files.});

ShowConfiguration();
CreateConfigurationFile();
BackupAndSize();		# Also re-run SetupLoggers() again for every target and fall back to MAIN after finishing
ListSizes();

exit(0);


__DATA__
This block (data descreptor DATA) is not available for compiled Perl applications. Check constant STR_DATA for the content.
