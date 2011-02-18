#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/env.sh functions.
#

source $DM_ROOT/test/test.sh


#
# tst_env
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on environment.
#
function tst_env {

    tst_is_not_empty USERNAME "USERNAME is not empty"
    tst_is_set USERNAME "USERNAME is set"
    tst_is_not_empty DM_ROOT "DM_ROOT is not empty"
    tst_is_set DM_ROOT "DM_ROOT is set"

    return
}


functions=$(cat $0 | grep '^function ' | awk '{ print $2}')

[[ "$1" ]] && functions="$*"

for function in  $functions; do
    if [[ ! $(declare -f $function) ]]; then
        echo "Function not found: $function"
        continue
    fi

    $function
done
