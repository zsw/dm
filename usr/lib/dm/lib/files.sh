#!/bin/bash

#
# files.sh
#
# Library of functions related to attachment files.
#

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh

#
# __is_text
#
# Sent: file
# Return: echo file type if file is text
# Purpose:
#
#   Ruturn 0 if file is text file.
#
__is_text() {

    file=$1
    [[ ! -r $file ]] && return

    # Any file with a 'c' in the first column followed by a space or tab
    # in the first 100 lines file interprets as fortran, prints 'FORTRAN
    # program'.
    # The command file does not determine if a symlink is a text file.
    file -b "$(readlink -f "$file")" | grep -qE 'FORTRAN|text'
}


# This function indicates this file has been sourced.
__loaded_files() {
    return 0
}

# Export all functions to any script sourcing this library file.
for function in $(awk '/^function / { print $2}' $DM_ROOT/lib/files.sh); do
    export -f $function
done
