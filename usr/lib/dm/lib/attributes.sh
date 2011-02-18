#!/bin/bash

#
# attributes.sh
#
# Library of functions related to mod attributes and attribute files.
#
# Attributes include description, hold, notes and who.
#

#
# attr_file_name
#
# Sent: mod id ( eg 12345)
#       attr   ( eg 'description', 'who', 'hold' )
# Return: nothing (echo's attribute file name including path to stdout)
# Purpose:
#
#   Determine the attribute file name from the mod id.
#
# Usage:
#
#   mod=12345
#   file_name=$(attr_file $mod 'hold')
#
# Note:
#
#   The routine does not attempt to determine if the file exists or not.
#   Use attr_file for that.
#
function attr_file_name {

    mod=$1
    attr=$2

    dir=$(mod_dir $mod)

    [[ ! $dir ]] && return

    echo $dir/$attr

    return
}


#
# attr_file
#
# Sent: mod id ( eg 12345)
#       attr   ( eg 'description', 'who', 'hold' )
# Return: nothing (echo's attribute file name including path to stdout)
# Purpose:
#
#   Determine the attribute file from the mod id. If the file exists the
#   name of the file is printed to stdout. If the file does not exist,
#   nothing is printed.
#
# Usage:
#
#   mod=12345
#   file_name=$(attr_file $mod 'hold')
#
function attr_file {

    mod=$1
    attr=$2

    file_name=$(attr_file_name "$mod" "$attr")

    [[ ! $file_name ]] && return

    [[ ! -e $file_name ]] && return

    echo $file_name

    return
}


#
# attribute
#
# Sent: mod id ( eg 12345)
#       attr   ( attribute name eg 'description', 'who', 'hold' )
# Return: nothing (echo's attribute value to stdout)
# Purpose:
#
#   Determine the attribute from the mod id. The attribute is the
#   contents of the attribute file.
#
# Usage:
#
#   mod=12345
#   who=$(attribute $mod 'who')
#
# Notes:
#
#   Nothing is echo'd if the attribute file does not exist.
#
function attribute {

    mod=$1
    attr=$2

    file=$(attr_file "$mod" "$attr")

    [[ ! $file ]] && return

    cat $file

    return
}


#
# has_conflict_markers
#
# Sent: file_name (Eg /path/to/file)
# Return: 0 = has, 1 = does not have, conflict markers
# Purpose:
#
#   Determine if the file has conflict markers.
#
function has_conflict_markers {

    file=$1

    [[ ! $file ]] && return 1

    [[ ! -e $file ]] && return 1

    marker=$(cat $file | grep -E '^(<<<<<<<|=======|>>>>>>>)$')

    [[ $marker ]] && return 0

    return 1
}


#
# mod_dir
#
# Sent: mod id ( eg 12345)
# Return: nothing (echo's directory path to stdout)
# Purpose:
#
#   Determine the directory of the mod from the mod id.
#
# Usage:
#
#   mod=12345
#   dir=$(mod_dir $mod)
#
function mod_dir {

    mod=$1

    [[ ! $mod ]] && return

    find $DM_MODS/$mod -maxdepth 0 -type d > /dev/null 2>&1
    if [[ "$?" == "0" ]]; then
        echo "$DM_MODS/$mod"
        return
    fi

    find $DM_ARCHIVE/$mod -maxdepth 0 -type d > /dev/null 2>&1
    if [[ "$?" == "0" ]]; then
        echo "$DM_ARCHIVE/$mod"
        return
    fi
}

# This function indicates this file has been sourced.
function _loaded_attributes {
    return 0
}

# Export all functions to any script sourcing this library file.
for function in $(awk '/^function / { print $2}' $DM_ROOT/lib/attributes.sh); do
    export -f $function
done
