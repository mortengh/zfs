#!/bin/bash

export ZFS_DEV=/dev/zfs
export ZED_PROG_NAME=zed
export ZED_PATH=/usr/local/sbin/zed
export ERRNO_PATH=/usr/include/sys/errno.h
export ZPOOL=/usr/local/sbin/zpool

syslog_echo()
{
	/usr/bin/syslog -s -l notice "$1"
}

errno_exit()
{
	str_error=$1
	numeric_val=$(awk -v pat=$str_error '$0 ~ pat{print $3}' "$ERRNO_PATH")
	perror "$numeric_val"
	exit "$numeric_val"
}

if [ ! -c "$ZFS_DEV" -o x"$(pgrep "$ZED_PROG_NAME")" = x ] ; then
	sleep 2
	if [ ! -c "$ZFS_DEV" ] ; then
		if [ -d /Library/Extensions/spl.kext\
		    -a -d /Library/Extensions/zfs.kext ] ; then
			/sbin/kextload /Library/Extensions/spl.kext
			/sbin/kextload -d /Library/Extensions/spl.kext\
			    /Library/Extensions/zfs.kext
		elif [ -d /System/Library/Extensions/spl.kext\
		    -a -d /System/Library/Extensions/zfs.kext ] ; then
			/sbin/kextload /System/Library/Extensions/spl.kext
			/sbin/kextload -d /System/Library/Extensions/spl.kext\
			    /System/Library/Extensions/zfs.kext
		fi
		sleep 2
		if [ ! -c "$ZFS_DEV" ] ; then
			syslog_echo "/dev/zfs does not exist"
			errno_exit ENOENT
		fi
	fi
	if [ x"$(pgrep "$ZED_PROG_NAME")" = x ] ; then
		sleep 2
		if [ x"$(pgrep "$ZED_PROG_NAME")" = x ] ; then
			"$ZED_PATH"
		fi
		if [ x"$(pgrep "$ZED_PROG_NAME")" = x ] ; then
			syslog_echo "zed not started yet"
			errno_exit ESRCH
		fi
	fi
fi

"$ZPOOL" list -H | awk -v faulted=FAULTED '$7 == faulted{print $1;}' |\
while read p ; do
	reimport_msg=$(printf "Trying to reimport %s\n" "$p")
	syslog_echo "$reimport_msg"
	"$ZPOOL" export "$p" && "$ZPOOL" import -N "$p"
done

zfs mount -a
