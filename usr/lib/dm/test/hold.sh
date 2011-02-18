#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/hold.sh functions.
#

source $DM_ROOT/test/test.sh
_loaded_hold 2>/dev/null || source $DM_ROOT/lib/hold.sh


#
# tst_hold_add_usage_comment
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on hold_add_usage_comment function
#
function tst_hold_add_usage_comment {

    # Handles no mod gracefully
    hold_add_usage_comment ''
    tst "$?" "1" 'no mod provided returns false'

    local mod=11111
    local mod_dir="$DM_MODS/$mod"
    mkdir -p $mod_dir
    local hold_file="$mod_dir/hold"

    rm $hold_file 2> /dev/null

    # No existing hold file
    hold_has_usage_comment $mod
    tst "$?" "1" 'no hold file has no comment'
    hold_add_usage_comment $mod
    hold_has_usage_comment $mod
    tst "$?" "0" 'no hold file, add, now has comment'

    # Hold file, no comment
    echo '#whatever' > $hold_file
    hold_has_usage_comment $mod
    tst "$?" "1" 'hold file has no comment'
    hold_add_usage_comment $mod
    hold_has_usage_comment $mod
    tst "$?" "0" 'hold file, add, now has comment'

    return
}


#
# tst_hold_as_crontab
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on hold_as_crontab function
#
function tst_hold_as_crontab {

    local crontab=$(hold_as_crontab '2010-10-31 12:34:56')
    local expect="34 12 31 10 *"
    tst "$crontab" "$expect" 'returns expected crontab'

    crontab=$(hold_as_crontab '2010-01-02 03:04:05')
    expect="04 03 02 01 *"
    tst "$crontab" "$expect" 'crontab is zero padded'
    return
}


#
# tst_hold_as_yyyy_mm_dd_hh_mm_ss
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on hold_as_yyyy_mm_dd_hh_mm_ss function
#
function tst_hold_as_yyyy_mm_dd_hh_mm_ss {

    local cron_exp="59 23 31 12"
    local timestamp=$(hold_as_yyyy_mm_dd_hh_mm_ss "$cron_exp" 2>/dev/null)
    local expect=""
    tst "$timestamp" "$expect" 'invalid cron_exp returns nothing'

    cron_exp="XX 00 01 01 *  $HOME/dm/bin/take_off_hold.sh 10786 # Move to Guelph. @2010"
    timestamp=$(hold_as_yyyy_mm_dd_hh_mm_ss "$cron_exp" 2>/dev/null)
    expect=""
    tst "$timestamp" "$expect" 'letters in cron_exp returns nothing'

    # With year.
    cron_exp="01 01 01 01 * some command 12345 # desc @2999"
    timestamp=$(hold_as_yyyy_mm_dd_hh_mm_ss "$cron_exp")
    expect="2999-01-01 01:01:00"
    tst "$timestamp" "$expect" 'with year returns expected'

    # With year, not zero padded
    cron_exp="0 1 1 1 * some command 12345 # desc @2999"
    timestamp=$(hold_as_yyyy_mm_dd_hh_mm_ss "$cron_exp")
    expect="2999-01-01 01:00:00"
    tst "$timestamp" "$expect" 'with year, not padded returns expected'

    # Caution: Without a year, the results of
    # hold_as_yyyy_mm_dd_hh_mm_ss depend on today's date which of course
    # changes every time the script is run.

    # Without year.
    # Test with the first minute of the year. No matter when this test is
    # run, if today's year is used, it should always be in the past. To
    # be in the future, add 1 to the year.
    cron_exp="01 01 01 01 *"
    timestamp=$(hold_as_yyyy_mm_dd_hh_mm_ss "$cron_exp")
    local year=$(date "+%Y" --date="+1 year")
    expect="$year-01-01 01:01:00"
    tst "$timestamp" "$expect" 'returns expected (next year)'

    # Without year.
    # Test with the last minute of the year. No matter when this test is
    # run, if today's year is used, it should always be in the future.
    cron_exp="59 23 31 12 *"
    timestamp=$(hold_as_yyyy_mm_dd_hh_mm_ss "$cron_exp")
    year=$(date "+%Y")
    expect="$year-12-31 23:59:00"
    tst "$timestamp" "$expect" 'returns expected (current year)'


    # Test octal number printf "%02d" "08" will fail with "invalid octal
    # number" message.
    cron_exp="00 08 31 12 *"
    timestamp=$(hold_as_yyyy_mm_dd_hh_mm_ss "$cron_exp")
    year=$(date "+%Y")
    expect="$year-12-31 08:00:00"
    tst "$timestamp" "$expect" 'octal number handled'
    return
}


#
# tst_hold_crontab
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on hold_crontab function
#
function tst_hold_crontab {

    # FIXME
    # [ ] Test invalid mod_id
    # [ ] Test invalid timestamp

    # Create mod for testing
    local mod_id="11111"
    local mod_dir="$DM_MODS/$mod_id"
    mkdir -p $mod_dir
    local description="Test mod."
    echo "$description" > $mod_dir/description

    local timestamp="2010-12-31 12:34:56"
    local crontab=$(hold_crontab "$mod_id" "$timestamp")
    local expect='34 12 31 12 *  $HOME/dm/bin/take_off_hold.sh 11111 # Test mod. @2010'
    tst "$crontab" "$expect" 'returns expected crontab'

    return
}


#
# tst_hold_has_usage_comment
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on hold_has_usage_comment function
#
function tst_hold_has_usage_comment {

    hold_has_usage_comment ''
    tst "$?" "1" 'no mod provided returns false'

    local mod=11111
    local mod_dir="$DM_MODS/$mod"
    mkdir -p $mod_dir
    local hold_file="$mod_dir/hold"

    rm $hold_file 2>/dev/null

    # No hold file
    hold_has_usage_comment $mod
    tst "$?" "1" 'no hold file returns false'

    # Hold file, no comment
    local mod_dir="$DM_MODS/$mod"
    mkdir -p $mod_dir
    echo '#whatever' > $mod_dir/hold
    hold_has_usage_comment $mod
    tst "$?" "1" 'no comment in hold file returns false'

    # Hold file, with comment
    hold_usage_comment $mod >> $mod_dir/hold
    hold_has_usage_comment $mod
    tst "$?" "0" 'has comment returns true'
    return
}


#
# tst_hold_timestamp
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on hold_timestamp function.
#
function tst_hold_timestamp {

    local ht=$(hold_timestamp '')
    tst "$ht" '' 'no mod provided returns nothing'

    local mod=11111

    ht=$(hold_timestamp $mod)
    tst "$ht" '' 'no mod directory returns nothing'

    local mod_dir="$DM_MODS/$mod"
    mkdir -p $mod_dir

    ht=$(hold_timestamp $mod)
    tst "$ht" '' 'no hold file returns nothing'


    echo '#whatever' > $mod_dir/hold
    ht=$(hold_timestamp $mod)
    tst "$ht" '' 'no crontab in hold file returns nothing'


    local crontab='59 23 31 12 *  $HOME/dm/bin/take_off_hold.sh 11111 # Test mod.'
    echo "$crontab" > $mod_dir/hold
    local year=$(date "+%Y")
    local expect="$year-12-31 23:59:00"

    ht=$(hold_timestamp $mod)
    tst "$ht" "$expect" 'crontab in hold file returns timestamp'

    echo '#22 22 22 12 *  $HOME/dm/bin/take_off_hold.sh 22222 # Another test mod.' > $mod_dir/hold
    echo '#33 23 31 12 *  $HOME/dm/bin/take_off_hold.sh 33333 # Another mod.'     >> $mod_dir/hold
    ht=$(hold_timestamp $mod)
    tst "$ht" '' 'Only commented crontabs returns nothing'

    echo "$crontab" >> $mod_dir/hold
    ht=$(hold_timestamp $mod)
    tst "$ht" "$expect" 'commented crontabs ignored, returns timestamp'
}


#
# tst_hold_timestamp_status
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on hold_timestamp_status function.
#
function tst_hold_timestamp_status {

    status=$(hold_timestamp_status)
    tst "$status" "off_hold" 'no timestamp returns off hold'


    timestamp=$(date "+%Y-%m-%d %H:%M:%S" --date="+1 hour")

    status=$(hold_timestamp_status "$timestamp")
    tst "$status" "on_hold" 'timestamp in future returns on hold'

    timestamp=$(date "+%Y-%m-%d %H:%M:%S" --date="-1 hour")

    status=$(hold_timestamp_status "$timestamp")
    tst "$status" "expired" 'timestamp in past returns expired'
}

#
# tst_hold_usage_comment
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on hold_usage_comment function
#
function tst_hold_usage_comment {

    local comment=$(hold_usage_comment '')
    tst "$comment" '' 'no mod provided returns nothing'

    local mod=11111

    local comment=$(hold_usage_comment $mod)
    local expect="# <minute> <hour> <day> <month> <dow> \$HOME/dm/bin/take_off_hold.sh $mod # <descr> @<year>"
    tst "$comment" "$expect" 'mod, returns expected'

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
