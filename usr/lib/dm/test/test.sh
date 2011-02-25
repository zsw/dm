#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Functions and setup for test scripts.
#


__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh
source $DM_ROOT/lib/log.sh                          # Re-source this every time or log.sh tests won't work

LOG_LEVEL=info
LOG_TO_STDOUT=              # Prevent logger calls in functions from affecting tests

tmpdir=$(__tmp_dir)
test_dir=$tmpdir/test

[[ $test_dir =~ ^/tmp ]] && rm -r "$test_dir" 2>/dev/null
mkdir -p "$test_dir"

export DM_ARCHIVE=$test_dir/archive
export DM_IDS=$test_dir/users/ids
export DM_MODS=$test_dir/mods
export DM_PEOPLE=$test_dir/users/people
export DM_TREES=$test_dir/trees
export DM_USERS=$test_dir/users/$USERNAME

tst() {
    local value expect label saveOut

    value=$1
    expect=$2
    label=$3

    # Logging to stdout was turned off above. Restore so the user sees
    # output.

    saveOut=$LOG_TO_STDOUT
    LOG_TO_STDOUT=1

    if [[ $value == $expect ]]; then
        logger_info "$function - $label"
    else
        logger_error "$function - $label"
        echo "Expected: $expect"
        echo "Got     : $value"
    fi

    LOG_TO_STDOUT=$saveOut
}


tst_is_not_empty() {
    local var label saveOut

    var=$1
    label=$2

    saveOut=$LOG_TO_STDOUT
    LOG_TO_STDOUT=1

    if [[ ! ${!var} && ${!var-_} ]]; then
        logger_error "$function - $label"
    elif [[ ! ${!var} ]]; then
        logger_error "$function - $label"
    else
        logger_info "$function - $label"
    fi

    LOG_TO_STDOUT=$saveOut
}

tst_is_set() {
    local var label saveOut

    var=$1
    label=$2

    saveOut=$LOG_TO_STDOUT
    LOG_TO_STDOUT=1

    if [[ ! ${!var} && ${!var-_} ]]; then
        logger_error "$function - $label"
    else
        logger_info "$function - $label"
    fi

    LOG_TO_STDOUT=$saveOut
}
