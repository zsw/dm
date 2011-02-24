#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Functions and setup for test scripts.
#


__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh
source $DM_ROOT/lib/log.sh                          # Re-source this every time or log.sh tests won't work

LOG_LEVEL=info
LOG_TO_STDOUT=              # Prevent logger calls in functions from affecting tests

tmpdir=$(tmp_dir)
test_dir="${tmpdir}/test"

rm -r $test_dir 2>/dev/null
mkdir -p $test_dir

export DM_ARCHIVE=$test_dir/archive
export DM_IDS=$test_dir/users/ids
export DM_MODS=$test_dir/mods
export DM_PEOPLE=$test_dir/users/people
export DM_TREES=$test_dir/trees
export DM_USERS=$test_dir/users/$USERNAME

function tst {

    local value="$1"
    local expect="$2"
    local label="$3"

    #echo "Value: $value, expect: $expect, label: $label"

    # Logging to stdout was turned off above. Restore so the user sees
    # output.

    local saveOut=$LOG_TO_STDOUT
    LOG_TO_STDOUT=1

    if [[ "$value" == "$expect" ]]; then
        logger_info "$function - $label"
    else
        logger_error "$function - $label"
        echo "Expected: $expect"
        echo "Got     : $value"
    fi

    LOG_TO_STDOUT=$saveOut
}


function tst_is_not_empty {

    local var="$1"
    local label="$2"

    local saveOut=$LOG_TO_STDOUT
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

function tst_is_set {

    local var="$1"
    local label="$2"

    local saveOut=$LOG_TO_STDOUT
    LOG_TO_STDOUT=1

    if [[ ! ${!var} && ${!var-_} ]]; then
        logger_error "$function - $label"
    else
        logger_info "$function - $label"
    fi

    LOG_TO_STDOUT=$saveOut
}

mkdir -p $test_dir

