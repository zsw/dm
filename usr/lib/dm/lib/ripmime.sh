#!/bin/bash

#
# ripmime.sh
#
# Library of functions related to ripmime and extracting content and
# attachments from MIME encoded files (email).
#

_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

#
# ripmime_attachments
#
# Sent: mime file to get attachments from
# Return: name of attachment files
# Purpose:
#
#   Return the names of files attached in a mime file.
#
function ripmime_attachments {

    local file=$1

    local ripmime_cmd=$(ripmime_command)
    if [[ ! "$ripmime_cmd" ]]; then
        echo "ripmime: command not found. Unable to parse $file"
        return
    fi

    ripmime_dir=$(ripmime_run "$file")
    find $ripmime_dir -maxdepth 1 -mindepth 1 -type f | grep -v __rip__
}


#
# ripmime_command
#
# Sent: nothing
# Return: full path ripmime command, nothin if not found
# Purpose:
#
#   Determine the full path ripmime command in the enviroment.
#
# Usage:
#   ripmime_cmd=$(ripmime_command)
#   if [[ ! ripmime_cmd ]]; then
#       echo 'Ripmime not found'
#   fi
#
function ripmime_command {

    local cmd=$(which ripmime 2>/dev/null)

    if [[ "$?" != "0" ]]; then
        echo ""
        return
    fi

    echo $cmd
}


#
# ripmime_files_cat
#
# Sent: mime file to rip
# Return: concatenated ripmime files
# Purpose:
#
#   Return the ripmime files concatenated.
#
function ripmime_files_cat {

    local file=$1

    local ripmime_cmd=$(ripmime_command)
    if [[ ! "$ripmime_cmd" ]]; then
        echo "ripmime: command not found. Unable to parse $file"
        return
    fi

    ripmime_dir=$(ripmime_run "$file")

    # Default to plain text files. If none, cat others.
    file_list=$(find $ripmime_dir -name '__rip__text-plain*')
    if [[ ! "$file_list" ]]; then
        file_list=$(find $ripmime_dir -name '__rip__*')
    fi

    for i in $file_list; do
        cat $i
    done
}


#
# ripmime_run
#
# Sent: file - name of mime file to rip, full path
# Return: path to directory of ripped files
# Purpose:
#
#   Rip a mime file and return a path.
#
function ripmime_run {

    local file=$1

    local base=$(basename $file);
    local working_dir=$(ripmime_tmpdir)
    local tmpdir="$working_dir/$base"
    mkdir -p $tmpdir

    # ripmime will extract the mail body and attachments from an email
    # The body will be stored in file(s) name by -p option, eg __rip__0, __rip__1
    # The attachments will be stored in files the same name as the attachment.
    ripmime -i $file -d $tmpdir --name-by-type --mailbox -p __rip__ --overwrite

    echo $tmpdir
}


#
# ripmime_tmpdir
#
# Sent: nothing
# Return: path to directory mime files are ripped into
# Purpose:
#
#   Return a the temporary directory mime files are ripped in.
#
function ripmime_tmpdir {

    tmpdir=$(tmp_dir)
    echo "$tmpdir/ripmime"
}


# This function indicates this file has been sourced.
function _loaded_ripmime {
    return 0
}

# Export all functions to any script sourcing this library file.
for function in $(awk '/^function / { print $2}' $DM_ROOT/lib/ripmime.sh); do
    export -f $function
done
