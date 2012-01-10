#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/env.sh functions.
#

source "$DM_ROOT/test/test.sh"


#
# tst_env
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on environment.
#
tst_env() {

    tst_is_not_empty USERNAME "USERNAME is not empty"
    tst_is_set USERNAME "USERNAME is set"
    tst_is_not_empty DM_ROOT "DM_ROOT is not empty"
    tst_is_set DM_ROOT "DM_ROOT is set"
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
