#!/usr/bin/env bash
#set -x

verperl=
binperl=`which perl 2> /dev/null`
reqperl="v5.40.2"

if [ -n "$binperl" ] ; then
	perl -e 'use strict; use warnings;
my $required = q{5.040002};
#print qq{required="$required"\ngiven="$]"\n};
if ( $] >= $required ) {
exit(0);
} else {
exit(1);
}'
	if [ $? -ne 0 ] ; then
		echo "Perl $reqperl or higher is required"'!' 1>&2
		echo "Got only $(perl -e 'print $^V') ." 1>&2
		exit 1
	else
		echo "Got $reqperl. OK"
		fi
else
	echo 'Perl 5 is missing!' 1>&2
	exit 2
	fi

exit 0

# OLD WAY
if [ -n "$binperl" ] ; then
	declare $(perl -V:version)
	verperl=$(echo $version | sed "s/'//g;s/;//")

	if [ $(echo $verperl | awk -F. '{print $1}') -eq 5 ] ; then
		if [ $(echo $verperl | awk -F. '{print $2}') -gt 40 ] ; then
			exit 0
		elif [ $(echo $verperl | awk -F. '{print $2}') -eq 40 ] ; then
			if [ -n "$(echo $verperl | awk -F. '{print $3}')" ] && [ $(echo $verperl | awk -F. '{print $3}') -ge 0 ] ; then
				exit 0
			else
				echo 'Perl v5.40.2 or higher is required!' 1>&2
				echo "Got only v$verperl ." 1>&2
				exit 1
				fi
		else
			echo 'Perl v5.40.2 or higher is required!' 1>&2
			echo "Got only v$verperl ." 1>&2
			exit 1
			fi
	else
		echo 'Perl5 is missing!' 1>&2
		exit 2
		fi
else
	echo 'Perl5 is missing!' 1>&2
	exit 2
	fi

exit 3
