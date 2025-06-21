#!/bin/sh

strUserAnswer=
uriLeftFiles=
uriMainPath='%SINGLEPATH%'

uriListFilesToDel='%TODEL%'
uriMyself="$0"
uriSafirbu='%SAFIRBUURI%'
shaOrigSafirbu='%SAFIRBUSHA%'	# sha512sum return value
uriLogrotate='%LOGROTATEURI%'
shaOrigLogrotate='%LOGROTATESHA%'
uriTmpfiles='%TMPFILESURI%'
shaOrigTmpfiles='%TMPFILESSHA%'

# Deletions happen only if this is empty
if [ -n "$uriMainPath" ] ; then
	echo "Just delete '$uriMainPath' to uninstall Safirbu." 1>&2
	exit 1
	fi

# Delete only if unchanged
if [ -n "$uriSafirbu" ] && [ -e "$uriSafirbu" ] && [ "$shaOrigSafirbu" == "$(sha512sum "$uriSafirbu" | awk '{print $1}')" ] ; then
	uriListFilesToDel="$uriListFilesToDel
$uriSafirbu"
elif [ -n "$uriSafirbu" ] ; then
	uriLeftFiles="$uriLeftFiles
$uriSafirbu"
	fi

if [ -n "$uriLogrotate" ] && [ -e "$uriLogrotate" ] && [ "$shaOrigLogrotate" == "$(sha512sum "$uriLogrotate" | awk '{print $1}')" ] ; then
	uriListFilesToDel="$uriListFilesToDel
$uriLogrotate"
elif [ -n "$uriLogrotate" ] ; then
	uriLeftFiles="$uriLeftFiles
$uriLogrotate"
	fi

if [ -n "$uriTmpfiles" ] && [ -e "$uriTmpfiles" ] && [ "$shaOrigTmpfiles" == "$(sha512sum "$uriTmpfiles" | awk '{print $1}')" ] ; then
	uriListFilesToDel="$uriListFilesToDel
$uriTmpfiles"
elif [ -n "$uriTmpfiles" ] ; then
	uriLeftFiles="$uriLeftFiles
$uriTmpfiles"
	fi

uriListFilesToDel=$(echo "$uriListFilesToDel" | grep -E '[^\s]+')

# Question
echo
echo "$uriListFilesToDel" | sort
dirname "$(realpath "$0")"
realpath "$0"
echo
read -p 'To delete the shown files write "yes" in capital letters and press [RETURN].
Your answer: ' strUserAnswer

if [ "$strUserAnswer" == "YES" ] ; then
	echo 'Uninstalling...'
else
	echo 'Stop.'
	exit 2
	fi

# Deletion
IFS=$'\n'
for uriElement in $(echo "$uriListFilesToDel" | sort -r) ; do
	if [ -d "$uriElement" ] ; then
		rmdir "$uriElement"

		if [ $? -eq 0 ] ; then
			echo "Removed empty directory '$uriElement'."
		else
			uriLeftFiles="$uriLeftFiles
$uriElement"
			fi
	elif [ -e "$uriElement" ] ; then
		rm -f "$uriElement"

		if [ $? -eq 0 ] ; then
			echo "Unlinked '$uriElement'."
		else
			uriLeftFiles="$uriLeftFiles
$uriElement"
			fi
	else
		echo "'$uriElement': No such file or directory" 1>&2
		uriLeftFiles="$uriLeftFiles
$uriElement (not found)"
		fi
	done
unset IFS

echo "Unlinked '$(realpath "$0")'."
echo "Unlinked '$(dirname "$(realpath "$0")")'."

# Report
uriLeftFiles=$(echo "$uriLeftFiles" | grep -E '[^\s]+')
if [ -n "$uriLeftFiles" ] ; then
	echo
	echo
	echo -e 'Some elements were not deleted:' 1>&2

	echo "$uriLeftFiles" | sort

	echo
	fi

sh -c "sleep 0.25 ; rm -f '$0' ; rmdir '$(dirname "$(realpath "$0")")'" &

echo 'Done.'

exit 0
