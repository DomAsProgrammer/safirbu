#!/usr/bin/env bash
#set -x

# General
uri_WorkDir="$(dirname "$(dirname "$(realpath "$0")")")/work"
uri_Configuration="$(dirname "$(dirname "$(realpath "$0")")")/configuration.conf"
str_OutputLevel='-x'
bol_Failed=0

# OS specific
OS="$(uname -s)"
cmd_Downloader=''
cmd_Shell=''

# Perlbrew environment
uri_Perl="$(which perl)"
ver_PerlVersion='5.42.0'
cmd_PerlbrewWithPerlVersion="perlbrew exec --with perl-${ver_PerlVersion}"
uri_PerlbrewLink='https://install.perlbrew.pl'
#export PERLBREW_ROOT="${uri_WorkDir}/perlbrew"
export PERLBREW_ROOT="$(bash -c ". '$uri_Configuration' && echo \$PERLBREW_ROOT")"
export PERL_CPANM_HOME="$uri_WorkDir/cpanm"
source_file="${PERLBREW_ROOT}/etc/bashrc"

# Public libs
str_PerlLibs='Term::ANSIColor utf8 Time::Piece File::Basename POSIX Cwd Data::Dumper Getopt::Long File::Path DBI DBD::SQLite Encode Time::Local Log::Log4perl String::CRC32 Text::CSV Text::CSV_XS PAR::Packer Net::Ping Net::OpenSSH'
# Lib::Name@flt_Version
declare -A ver_PerlLibs=()
#declare -A ver_PerlLibs=(["Net::OpenSSH"]="0.84" ["DBI"]="1.647" ["DBD::SQLite"]="1.76" ["Log::Log4perl"]="1.57" ["Text::CSV"]="2.06" ["Text::CSV_XS"]="1.60" ["PAR::Packer"]="1.063")
str_MissingPerlLibs=''

# Custom Libs
str_CustomLibs='IPC::LockTicket'
declare -A ver_CustomLibs=(["IPC::LockTicket"]="2.13")
str_MissingCustLibs=''

# IPC::LockTicket
str_LockTicketTarball="IPC-LockTicket-${ver_CustomLibs["IPC::LockTicket"]}.tar.xz"
uri_LockTicketLink='https://github.com/DomAsProgrammer/perl-IPC-LockTicket/raw/refs/heads/main/'$str_LockTicketTarball
uri_LockTicketDir="${uri_WorkDir}/$(basename $str_LockTicketTarball .tar.xz)"

function CleanUp {
	if [ -e "$source_file" ] ; then
		. "$source_file"
		perlbrew clean
		return 0
	else
		echo 'FATAL: CleanUp() executed before anything is there to clean up!' 1>&2
		exit 124
		fi
	}

if [ -z "$uri_Configuration" ] || [ ! -e "$uri_Configuration" ] ; then
	echo 'Run configuration first!' 1>&2
	echo 'Use `./configure` in package root.' 1>&2
	bol_Failed=1
	fi

if [ -z "$PERLBREW_ROOT" ] ; then
	echo 'PERLBREW_ROOT is not set.' 1>&2
	bol_Failed=1
	fi

if [ -z "$uri_Perl" ] ; then
	echo 'Basic Perl is not installed. Simply install it from the package manager.' 1>&2
	bol_Failed=1
	fi

if [ -z "$(which tar 2> /dev/null)" ] ; then
	echo 'Can'"'"'t find tar for packing tarballs in $PATH: '$PATH 1>&2
	bol_Failed=1
	fi

if [ "$OS" == "Linux" ] ; then
	cmd_Downloader='curl -L'
	cmd_Shell='bash'

	if [ -z "$(which curl 2> /dev/null)" ] ; then
		cmd_Downloader='wget -O -'
		fi
elif [ "$OS" == "FreeBSD" ] ; then
	cmd_Downloader='fetch -o-'
	cmd_Shell='sh'
else
	echo 'System "'$OS'" is not implemented. Check this script for further details.' 1>&2
	bol_Failed=1
	fi

#if [ "$(whoami)" == "root" ] ; then
#	echo 'Should not be run as administrator!' 1>&2
#	
#	read -p 'Do you really want to proceed? [y|N] ' str_Answer
#	if [ -z "$(echo "$str_Answer" | grep -Ei '^y(es)?$')" ] ; then
#		exit 1
#		fi
#	fi

if [ $bol_Failed -ne 0 ] ; then
	exit 2
else
	mkdir -pv "$uri_WorkDir"
	fi

# Install Perlbrew if not found
if [ ! -e "$PERLBREW_ROOT/bin/perlbrew" ] || [ ! -e "$source_file" ] ; then
	( set $str_OutputLevel ; $cmd_Downloader "$uri_PerlbrewLink" | $cmd_Shell ) > /dev/null 2>&1 || exit 4

	fi

# Load perlbrew
if [ -e "$source_file" ] ; then
	. "$source_file" || exit 5
	fi

# Install required Perl
if [ -z "$(perlbrew list | grep -F "perl-$ver_PerlVersion")" ] ; then

	( set $str_OutputLevel ; perlbrew -v install "perl-$ver_PerlVersion" ) || exit 6

	CleanUp

	if [ $? -ne 0 ] ; then
		echo 'Automatic installation failed.' 1>&2
		#echo 'Please make sure '$ver_PerlVersion' is installed, before running '$0' again.' 1>&2
		exit 7
		fi

	# Good practice
	yes | perlbrew install-patchperl

	# Install package manager
	yes | perlbrew install-cpanm

	fi

# Set up library
#if [ -z "$(perlbrew list | grep -F "$cmd_PerlbrewWithPerlVersion")" ] ; then
	#( set $str_OutputLevel ; perlbrew lib create "$cmd_PerlbrewWithPerlVersion" )
	#fi

for str_Lib in $str_PerlLibs ; do
	int_Return=''

	if [ -n "${ver_PerlLibs["$str_Lib"]}" ] ; then
		$cmd_PerlbrewWithPerlVersion perl -e "use $str_Lib ${ver_PerlLibs["$str_Lib"]};" 2> /dev/null 1>&2
		int_Return=$?
	else
		$cmd_PerlbrewWithPerlVersion perl -e "use $str_Lib;" 2> /dev/null 1>&2
		int_Return=$?
		fi

	if [ $int_Return -ne 0 ] ; then
		if [ -n "${ver_PerlLibs["$str_Lib"]}" ] ; then
			str_MissingPerlLibs="$str_MissingPerlLibs ${str_Lib}@${ver_PerlLibs["$str_Lib"]}"
		else
			str_MissingPerlLibs="$str_MissingPerlLibs $str_Lib"
			fi
		fi
	done
	unset int_Return

for str_Lib in $str_CustomLibs ; do
	int_Return=''
	if [ -n "${ver_CustomLibs["$str_Lib"]}" ] ; then
		$cmd_PerlbrewWithPerlVersion perl -e "use $str_Lib ${ver_CustomLibs["$str_Lib"]};" 2> /dev/null 1>&2
		int_Return=$?
	else
		$cmd_PerlbrewWithPerlVersion perl -e "use $str_Lib;" 2> /dev/null 1>&2
		int_Return=$?
		fi

	if [ $int_Return -ne 0 ] ; then
		str_MissingCustLibs="$str_MissingCustLibs $str_Lib"
		fi
	done
	unset int_Return

# Install libraries from MetaCpan
if [ -n "$str_MissingPerlLibs" ] ; then
	( set $str_OutputLevel ; $cmd_PerlbrewWithPerlVersion cpanm -v $str_MissingPerlLibs 2> /dev/null 1>&2 ) || exit 8

	CleanUp
	fi

## Install custom libraries
# IPC::LockTicket
if [ -n "$(echo "$str_MissingCustLibs" | grep -F 'IPC::LockTicket')" ] ; then

	# Create temp directory
	( set $str_OutputLevel ; mkdir -p "$uri_WorkDir" ) || exit 9

	# Download & extract
	( set $str_OutputLevel ; $cmd_Downloader $uri_LockTicketLink | xz -d | tar xf - -C "$uri_WorkDir" ) || exit 10

	# Build
	cd "$uri_LockTicketDir" || exit 11
	( set $str_OutputLevel ; $cmd_PerlbrewWithPerlVersion perl Makefile.PL ) || exit 12
	( set $str_OutputLevel ; $cmd_PerlbrewWithPerlVersion make ) || exit 13
	( set $str_OutputLevel ; $cmd_PerlbrewWithPerlVersion make install ) || exit 14
	cd - 1> /dev/null
	fi

exit 0
