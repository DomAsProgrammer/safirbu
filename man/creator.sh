#!/usr/bin/env bash
#set -x

cnt_Fails=0
str_ProgName=$(echo "$(basename "$(dirname "$(dirname "$(echo "$(pwd)/man-creator.sh")")")")" | sed -E 's/-[0-9.]+$//g')
ver_ProgVer=$(grep -iE 'my \$ver_AppVersion' ../bin/${str_ProgName}.pl | perl -pe 's/^.+?([.0-9]+).+$/\1/')
declare -A str_NameSuffix=([5]="-CONFIG")

declare -A str_ShortDesc=([5]="File Formats Manual" [8]="System Administrator's Manual")

for handbook in {1..9} ; do

	uri_PodFile="./man${handbook}.pod"
	uri_ManFile="./${str_ProgName}.${handbook}.xz" #"../BUILDROOT/usr/share/man/manN/${str_ProgName}.N.gz"

	if [ -e "$uri_PodFile" ] ; then
		( set -x ; pod2man -r "$str_ProgName v$ver_ProgVer" -c "${str_ShortDesc[$handbook]}" -n "$(echo "$str_ProgName" | tr '[a-z]' '[A-Z]')${str_NameSuffix[$handbook]}" -s ${handbook} -v -u "$uri_PodFile" | xz -9e > "$uri_ManFile" )

		if [ $? -eq 0 ] ; then
			echo "Created \"$uri_ManFile\""
		else
			echo "Failed to create manpage for $handbook." 1>&2
			cnt_Fails=$(echo "$cnt_Fails + 1" | bc)
			fi

		fi

	done

exit $cnt_Fails
