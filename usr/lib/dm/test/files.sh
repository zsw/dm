#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/files.sh functions.
#

source $DM_ROOT/test/test.sh
__loaded_files 2>/dev/null || source $DM_ROOT/lib/files.sh


#
# tst_is_text
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __is_text function.
#
tst_is_text() {

    __is_text >/dev/null
    tst "$?" "1" 'no file - returns nothing'

    __is_text '' >/dev/null
    tst "$?" "1" 'blank file - returns nothing'

    __is_text '/fake/file/dot.txt' >/dev/null
    tst "$?" "1" 'non-existent file - returns nothing'

    __is_text $0 >/dev/null
    tst "$?" "0" 'this script - returns text'

    __is_text '/bin/true' >/dev/null
    tst "$?" "1" '/bin/true - returns non-text'
}


functions=$(awk '/^tst_/ {print $1}' "$0")

[[ $1 ]] && functions="$*"

for function in  $functions; do
    function=${function%%(*}        # strip '()'
    if ! declare -f "$function" &>/dev/null; then
        __mi "Function not found: $function" >&2
        continue
    fi

    "$function"
done
