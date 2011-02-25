#!/bin/bash

#
# attributes.sh
#
# Library of functions related to mod attributes and attribute files.
#
# Attributes include description, hold, notes and who.
#

#
# __attr_file_name
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
#   file_name=$(__attr_file $mod 'hold')
#
# Note:
#
#   The routine does not attempt to determine if the file exists or not.
#   Use __attr_file for that.
#
__attr_file_name() {

    mod=$1
    attr=$2

    dir=$(__mod_dir $mod)

    [[ ! $dir ]] && return

    echo $dir/$attr

    return
}


#
# __attr_file
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
#   file_name=$(__attr_file $mod 'hold')
#
__attr_file() {

    mod=$1
    attr=$2

    file_name=$(__attr_file_name "$mod" "$attr")

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
#   who=$(__attribute $mod 'who')
#
# Notes:
#
#   Nothing is echo'd if the attribute file does not exist.
#
__attribute() {

    mod=$1
    attr=$2

    file=$(__attr_file "$mod" "$attr")

    [[ ! $file ]] && return

    cat $file

    return
}


#
# __has_conflict_markers
#
# Sent: file_name (Eg /path/to/file)
# Return: 0 = has, 1 = does not have, conflict markers
# Purpose:
#
#   Determine if the file has conflict markers.
#
__has_conflict_markers() {

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
#   dir=$(__mod_dir $mod)
#
__mod_dir() {

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
__loaded_attributes() {
    return 0
}

# Export all functions to any script sourcing this library file.
while read -r function; do
    export -f "${function%%(*}"         # strip '()'
done < <(awk '/^__*()/ {print $1}' "$DM_ROOT"/lib/attributes.sh)
