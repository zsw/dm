#!/bin/bash

#
# lock.sh
#
# Library of functions related to dm system locks.
#

_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

#
# is_locked
#
# Sent: file - lock file name, absolute path, optional
# Return: string simulating boolean, "true" or "false"
# Purpose:
#
#   Determine if the dm system is locked.
#
function is_locked {

    file=$1
    if [[ -z $file ]]; then
        file=$(lock_file)
    fi

    if [[ -r "$file" ]]; then
        echo "true"
    else
        echo "false"
    fi
}


#
# lock_alert
#
# Sent: to - email address to send alert to
#       file - lock file name, absolute path, optional
# Return: string simulating boolean, "true" or "false"
# Purpose:
#
#   Send alert message.
#
function lock_alert {

    to=$1
    file=$2

    if [[ -z $to ]]; then
        echo "false"
        return
    fi

    if [[ -z $file ]]; then
        file=$(lock_file)
    fi

    if [[ ! -r $file ]]; then
        echo "false"
        return
    fi

    script=$(lock_file_key_value script $file)
    subject="dm system is locked"
    body="Script: $script

This dm script is unable to complete because the system is
locked. This may be a result of normal working operations.
However, if the system is locked for a lengthy period of time,
foo can ensue. Hence it might be worth looking into.

Lock file: $file

Check for the existence of the above lock file. If it no longer
exists, the system has been unlocked and all is good. Cat the
file for details on the script locking the system.
"
    # send email
    res=$(echo -e "To: $to\nSubject: $subject\n\n$body" | sendmail -v -- $to)
    if [[ "$?" != "0" ]]; then
        echo "false"
        return
    fi

    echo "true"

    return
}


#
# lock_create
#
# Sent: file - lock file name, absolute path, optional
# Return: true = lock obtained, false = lock failed
# Purpose:
#
#   Create a lock file.
#
function lock_create {

    file=$1

    if [[ -z $file ]]; then
        file=$(lock_file)
    fi

    # Make sure the directory exists
    path=${file%/*}
    if [[ -n $path ]]; then
        mkdir -p $path
    fi

    success=

    tries=5
    range=10
    min=5
    for ((i=$tries; i>0; i--)); do
        # "set -o noclobber" tests for an existing lock and creates a lock file
        # at the exact same time. Any time between those two steps could create
        # race conditions whereby process A could create a lock file after
        # process B tests for it finding none, but before process B creates
        # one.
        if ( set -o noclobber; echo "PID: $$" > "$file") 2> /dev/null; then
            success=1
            break
        fi
        # Sleep for x seconds.  min <= x <= min + range
        t=$(echo "scale=0; $RANDOM % $range + $min" | bc)
        sleep $t
    done

    if [[ -n $success ]]; then
        echo "true"
    else
        echo "false"
        return
    fi

    script_file=$0
    [[ ${0:0:1} != '/' ]] && script_file="$PWD/${0#./}"

    echo "script: $script_file" >> $file

    created_on=$(date "+%F %T")
    echo "created_on: $created_on" >> $file
    return
}


#
# lock_file
#
# Sent: nothing
# Return: full name of lock file
# Purpose:
#
#   Return the full name of the lock file.
#
function lock_file {

    tmpdir=$(tmp_dir)
    echo "$tmpdir/LOCK"
}


#
# lock_file_key_value
#
# Sent: key
#       file - lock file name, absolute path, optional
# Return: value
# Purpose:
#
#   Return the value of the attribute indicated by the key in the lock file.
#
# Notes:
#
#   If there are more than one line in the lock file matching the indicated
#   attribute key, the value of the last is returned.
#
# Example:
#
#   $ cat /tmp/tst_lock_sh.txt
#   script: /path/to/script.sh
#   created_on: 2009-01-01 01:01:01
#   created_on: 2009-01-01 11:11:11
#
#   lock_file_key_value script /tmp/tst_lock_sh.txt
#   # returns: /path/to/script.sh
#
#   lock_file_key_value created_on /tmp/tst_lock_sh.txt
#   # returns: 2009-01-01 11:11:11
#
function lock_file_key_value {

    key=$1
    file=$2

    if [[ -z $key ]]; then
        return
    fi

    if [[ -z $file ]]; then
        file=$(lock_file)
    fi

    if [[ ! -r $file ]]; then
        return
    fi

    value_line=$(grep "^$key:" $file | tail -1)

    value=${value_line#$key: }
    echo $value

    return
}


#
# lock_is_alertable
#
# Sent: age - required age
#       file - lock file name, absolute path, optional
# Return: string simulating boolean, "true" or "false"
# Purpose:
#
#   Determine if a lock is alertable.
#
# Notes:
#
#   A lock is alertable if the following is true:
#
#   1) the lock file exists
#   2) the current time is greater than or equal
#      lock file created_on + required age
#
#   If no age is provided, the age defaults to "0 minutes"
#   If no age is provided, and the lock file exists, the function will return
#   true.
#
function lock_is_alertable {

    age=$1
    file=$2

    if [[ -z $age ]]; then
        age="0 minutes"
    fi

    if [[ -z $file ]]; then
        file=$(lock_file)
    fi

    if [[ ! -r $file ]]; then
        echo 'false'
        return
    fi

    created_on=$(lock_file_key_value created_on $file)
    if [[ -z $created_on ]]; then
        echo 'false'
        return
    fi

    now_seconds=$(date "+%s")

    # NOTE: Addition in date commands reverts times to UTC. Include the
    # relative timezone time (eg -0500 for EST) to correct this.
    tz=$(date +%z)

    created_on_limit=$(date "+%s" --date="$created_on $tz + $age")

    if [[ "$now_seconds" -lt "$created_on_limit" ]]; then
        echo 'false'
        return
    fi

    echo 'true'

    return
}


#
# lock_remove
#
# Sent: file - lock file name, absolute path, optional
# Return: nothing
# Purpose:
#
#   Remove the lock file.
#
function lock_remove {

    file=$1
    if [[ -z $file ]]; then
        file=$(lock_file)
    fi

    if [[ ! -e $file ]]; then
        return
    fi

    rm $file

    return
}
# This function indicates this file has been sourced.
function _loaded_lock {
    return 0
}

# Export all functions to any script sourcing this library file.
for function in $(awk '/^function / { print $2}' $DM_ROOT/lib/lock.sh); do
    export -f $function
done
