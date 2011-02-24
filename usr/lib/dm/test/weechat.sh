#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/weechat.sh functions.
#

source $DM_ROOT/test/test.sh
__loaded_weechat 2>/dev/null || source $DM_ROOT/lib/weechat.sh


#
# tst_weechat_log_path
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on weechat_log_path function.
#
function tst_weechat_log_path {

    # In some environments, weechat may not be available. Without weechat
    # most tests will fail. Do only mininal testing in that case.
    log_path="$HOME/.weechat/logs/"
    if [[ ! -d $log_path ]]; then
        value=$(weechat_log_path 2>/dev/null)
        expect=""
        tst "$value" "$expect" "default log path"
        return
    fi

    value=$(weechat_log_path)
    expect="/var/log/weechat"
    tst "$value" "$expect" "default log path"

    value=$(weechat_log_path 'aaaa' )
    expect=""
    tst "$value" "$expect" "Invalid weechat version."

    value=$(weechat_log_path '0.2.6' )
    expect="/var/log/weechat"
    tst "$value" "$expect" "Handles version 0.2.6"

    value=$(weechat_log_path '0.2.7' )
    expect="/var/log/weechat"
    tst "$value" "$expect" "Handles version 0.2.7"

    value=$(weechat_log_path '0.3.0' )
    expect="/var/log/weechat"
    tst "$value" "$expect" "Handles version 0.3.0"

    value=$(weechat_log_path '0.3.1' )
    expect="/var/log/weechat"
    tst "$value" "$expect" "Handles version 0.3.1"

    value=$(weechat_log_path '' '%h/logs' )
    expect="$HOME/.weechat/logs"
    tst "$value" "$expect" "Handles %h placeholder"

    value=$(weechat_log_path '' '/path/to/logs/' )
    expect="/path/to/logs"
    tst "$value" "$expect" "Handles trailing slash"

    return
}


#
# tst_weechat_events_file
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on weechat_events_file function.
#
function tst_weechat_events_file {

    # In some environments, weechat may not be available. Without weechat
    # most tests will fail. Do only mininal testing in that case.
    log_path="$HOME/.weechat/logs/"
    if [[ ! -d $log_path ]]; then
        value=$(weechat_events_file 2>/dev/null)
        expect=""
        tst "$value" "$expect" "default events file"
        return
    fi

    value=$(weechat_events_file)
    expect="/var/log/weechat/events"
    tst "$value" "$expect" "default events file"

    return
}



functions=$(cat $0 | grep '^function tst_' | awk '{ print $2}')

[[ "$1" ]] && functions="$*"

for function in  $functions; do
    if [[ ! $(declare -f $function) ]]; then
        echo "Function not found: $function"
        continue
    fi

    $function
done
