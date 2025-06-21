#!/usr/bin/env bash

if [ -z "$1" ] ; then
	echo "Which manpage do you want to see?" 1>&2
	echo "Usage: $0 <Number of page>" 1>&2
	exit 1
elif [ ! -e "man$1.pod" ] ; then
	echo "man$1.pod: cannot open 'man$1.pod' (No such file or directory)" 1>&2
	exit 2
	fi

while true ; do ( pod2man -q none man$1.pod | man -l - ) ; sleep 1 ; done 
