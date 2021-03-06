#!/bin/bash

#
# lock.sh
#
# Library of functions related to dm system locks.
#

__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

#
# __is_locked
#
# Sent: file - lock file name, absolute path, optional
# Return: string simulating boolean, "true" or "false"
# Purpose:
#
#   Determine if the dm system is locked.
#
__is_locked() {
    local file=$1

    [[ ! $file ]] && file=$(__lock_file)
    [[ -r $file ]] && return 0 || return 1
}


#
# __lock_alert
#
# Sent: to - email address to send alert to
#       file - lock file name, absolute path, optional
# Return: string simulating boolean, "true" or "false"
# Purpose:
#
#   Send alert message.
#
__lock_alert() {
    local to file script subject body

    to=$1
    file=$2

    [[ ! $to ]] && return 1
    [[ ! $file ]] && file=$(__lock_file)
    [[ ! -r $file ]] && return 1

    script=$(__lock_file_key_value script "$file")
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
    echo -e "To: $to\nSubject: $subject\n\n$body" | sendmail -v -- "$to" &>/dev/null
}


#
# __lock_create
#
# Sent: file - lock file name, absolute path, optional
# Return: true = lock obtained, false = lock failed
#
# Purpose:
#   Create a lock file.
#
__lock_create() {
    local file path success tries range min t script_file created_on i

    file=$1

    [[ ! $file ]] && file=$(__lock_file)

    # Make sure the directory exists
    path=${file%/*}
    [[ $path ]] && mkdir -p "$path"

    tries=30
    while true; do
        # "set -o noclobber" tests for an existing lock and creates a lock file
        # at the exact same time. Any time between those two steps could create
        # race conditions whereby process A could create a lock file after
        # process B tests for it finding none, but before process B creates
        # one.
        (set -o noclobber; > "$file") 2>/dev/null && break

        (( --tries == 0 )) && return 1
        sleep 1
    done

    script_file=$0
    [[ ${0:0:1} != '/' ]] && script_file=$(readlink -f "$0")

    cat > "$file" << EOF
PID: $$
script: $script_file
created_on: $(date "+%F %T")
EOF

    trap '__lock_remove; exit $?' INT TERM EXIT
}


#
# lock_file
#
# Sent: nothing
# Return: full name of lock file
#
# Purpose:
#   Return the full name of the lock file.
#
__lock_file() {
    local tmpdir=$(__tmp_dir)

    echo "$tmpdir/LOCK"
}


#
# __lock_file_key_value
#
# Sent: key
#       file - lock file name, absolute path, optional
# Return: value

# Purpose:
#   Return the value of the attribute indicated by the key in the lock file.
#
# Notes:
#   If there are more than one line in the lock file matching the indicated
#   attribute key, the value of the last is returned.
#
# Example:
#   $ cat /tmp/tst_lock_sh.txt
#   script: /path/to/script.sh
#   created_on: 2009-01-01 01:01:01
#   created_on: 2009-01-01 11:11:11
#
#   __lock_file_key_value script /tmp/tst_lock_sh.txt
#   # returns: /path/to/script.sh
#
#   __lock_file_key_value created_on /tmp/tst_lock_sh.txt
#   # returns: 2009-01-01 11:11:11
#
__lock_file_key_value() {
    local key file value_line value

    key=$1
    file=$2

    [[ ! $key ]] && return
    [[ ! $file ]] && file=$(__lock_file)
    [[ ! -r $file ]] && return

    value_line=$(grep "^$key:" "$file" | tail -1)
    value=${value_line#$key: }
    echo "$value"
}


#
# __lock_is_alertable
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
__lock_is_alertable() {
    local age file created_on now_seconds created_on_limit

    age=$1
    file=$2

    [[ ! $age ]] && age="0 minutes"
    [[ ! $file ]] && file=$(__lock_file)
    [[ ! -r $file ]] && return 1

    created_on=$(__lock_file_key_value created_on "$file")
    [[ ! $created_on ]] && return 1

    now_seconds=$(date "+%s")

    # NOTE: Addition in date commands reverts times to UTC. Include the
    # relative timezone time (eg -0500 for EST) to correct this.
    tz=$(date +%z)

    created_on_limit=$(date "+%s" --date="$created_on $tz + $age")

    (( "$now_seconds" >= "$created_on_limit" )) && return 0 || return 1
}


#
# __lock_remove
#
# Sent: file - lock file name, absolute path, optional
# Return: nothing
# Purpose:
#
#   Remove the lock file.
#
__lock_remove() {
    local file=$1

    [[ ! $file ]] && file=$(__lock_file)
    [[ ! -e $file ]] && return

    rm "$file"
}

# This function indicates this file has been sourced.
__loaded_lock() {
    return 0
}

# Export all functions to any script sourcing this library file.
while read -r function; do
    export -f "${function%%(*}"         # strip '()'
done < <(awk '/^__*()/ {print $1}' "$DM_ROOT/lib/lock.sh")
