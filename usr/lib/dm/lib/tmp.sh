#!/bin/bash

#
# tmp.sh
#
# Library of functions related to temporary files.
#

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

#
# tmp_dir
#
# Sent: username (optional)
# Return: directory - string, eg '/tmp/dm_username'
# Purpose:
#
#   Return the directory where tmp files are stored.
#
# Notes:
#
#   The directory is the format /tmp/dm_${username}.
#
#   The username is determined by the first non-blank string returned by the
#   following.
#
#   1. provided username
#   2. $USERNAME
#   3. mktemp -d -u XXXXXXXXXXXX
#
function tmp_dir {

    if [[ $DM_TMP ]]; then
	    echo "$DM_TMP"
    else
	    username=$1
	    [[ -z $username ]] && username=$USERNAME
	    [[ -z $username ]] && username=$(mktemp -d -u XXXXXXXXXXXX)
	    echo "/tmp/dm_${username}"
    fi
    return
}


#
# tmp_file
#
# Sent: tmpdir - directory to store temp file (optional)
# Return: tmp_file - string, eg /tmp/dm_username/tmp.AFslDe235s
# Purpose:
#
#   Return the name of a temp file.
#
# Notes:
#
#   The tmp_file is the format returned by mktemp.
#
#   The directory of the temp file is determined by the first non-blank string
#   returned by the following.
#
#   1. provided directory
#   2. that provided by tmp_dir with no username passed.
#   3. /tmp
#
function tmp_file {

    tmpdir=$1
    [[ -z $tmpdir ]] && tmpdir=$(tmp_dir)
    [[ -z $tmpdir ]] && tmpdir='/tmp'

    mkdir -p $tmpdir

    filename=${0##*/}
    template="tmp.XXXXXXXXXX.${filename}"

    tmp_file=$(mktemp --tmpdir="$tmpdir" $template)

    echo "$tmp_file"
    return
}


# This function indicates this file has been sourced.
function _loaded_tmp {
    return 0
}

# Export all functions to any script sourcing this library file.
for function in $(awk '/^function / { print $2}' $DM_ROOT/lib/tmp.sh); do
    export -f $function
done
