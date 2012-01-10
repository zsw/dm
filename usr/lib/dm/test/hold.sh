#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/hold.sh functions.
#

source $DM_ROOT/test/test.sh
__loaded_hold 2>/dev/null || source $DM_ROOT/lib/hold.sh


#
# tst_hold_add_usage_comment
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __hold_add_usage_comment function
#
tst_hold_add_usage_comment() {
    local mod mod_dir hold_file

    # Handles no mod gracefully
    __hold_add_usage_comment ''
    tst "$?" "1" 'no mod provided returns false'

    mod=11111
    mod_dir=$DM_MODS/$mod
    mkdir -p "$mod_dir"
    hold_file=$mod_dir/hold

    rm "$hold_file" 2> /dev/null

    # No existing hold file
    __hold_has_usage_comment "$mod"
    tst "$?" "1" 'no hold file has no comment'
    __hold_add_usage_comment "$mod"
    __hold_has_usage_comment "$mod"
    tst "$?" "0" 'no hold file, add, now has comment'

    # Hold file, no comment
    echo '#whatever' > "$hold_file"
    __hold_has_usage_comment "$mod"
    tst "$?" "1" 'hold file has no comment'

    __hold_add_usage_comment "$mod"
    __hold_has_usage_comment "$mod"
    tst "$?" "0" 'hold file, add, now has comment'
}


#
# tst_hold_as_crontab
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __hold_as_crontab function
#
tst_hold_as_crontab() {
    local crontab expect

    crontab=$(__hold_as_crontab '2010-10-31 12:34:56')
    expect="34 12 31 10 *"
    tst "$crontab" "$expect" 'returns expected crontab'

    crontab=$(__hold_as_crontab '2010-01-02 03:04:05')
    expect="04 03 02 01 *"
    tst "$crontab" "$expect" 'crontab is zero padded'
}


#
# tst_hold_as_yyyy_mm_dd_hh_mm_ss
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __hold_as_yyyy_mm_dd_hh_mm_ss function
#
tst_hold_as_yyyy_mm_dd_hh_mm_ss() {
    local cron_exp timestamp expect year

    cron_exp="59 23 31 12"
    timestamp=$(__hold_as_yyyy_mm_dd_hh_mm_ss "$cron_exp" 2>/dev/null)
    expect=""
    tst "$timestamp" "$expect" 'invalid cron_exp returns nothing'

    cron_exp="XX 00 01 01 *  $HOME/dm/bin/take_off_hold.sh 10786 # Move to Guelph. @2010"
    timestamp=$(__hold_as_yyyy_mm_dd_hh_mm_ss "$cron_exp" 2>/dev/null)
    expect=""
    tst "$timestamp" "$expect" 'letters in cron_exp returns nothing'

    # With year.
    cron_exp="01 01 01 01 * some command 12345 # desc @2999"
    timestamp=$(__hold_as_yyyy_mm_dd_hh_mm_ss "$cron_exp")
    expect="2999-01-01 01:01:00"
    tst "$timestamp" "$expect" 'with year returns expected'

    # With year, not zero padded
    cron_exp="0 1 1 1 * some command 12345 # desc @2999"
    timestamp=$(__hold_as_yyyy_mm_dd_hh_mm_ss "$cron_exp")
    expect="2999-01-01 01:00:00"
    tst "$timestamp" "$expect" 'with year, not padded returns expected'

    # Caution: Without a year, the results of
    # __hold_as_yyyy_mm_dd_hh_mm_ss depend on today's date which of course
    # changes every time the script is run.

    # Without year.
    # Test with the first minute of the year. No matter when this test is
    # run, if today's year is used, it should always be in the past. To
    # be in the future, add 1 to the year.
    cron_exp="01 01 01 01 *"
    timestamp=$(__hold_as_yyyy_mm_dd_hh_mm_ss "$cron_exp")
    year=$(date "+%Y" --date="+1 year")
    expect="$year-01-01 01:01:00"
    tst "$timestamp" "$expect" 'returns expected (next year)'

    # Without year.
    # Test with the last minute of the year. No matter when this test is
    # run, if today's year is used, it should always be in the future.
    cron_exp="59 23 31 12 *"
    timestamp=$(__hold_as_yyyy_mm_dd_hh_mm_ss "$cron_exp")
    year=$(date "+%Y")
    expect="$year-12-31 23:59:00"
    tst "$timestamp" "$expect" 'returns expected (current year)'


    # Test octal number printf "%02d" "08" will fail with "invalid octal
    # number" message.
    cron_exp="00 08 31 12 *"
    timestamp=$(__hold_as_yyyy_mm_dd_hh_mm_ss "$cron_exp")
    year=$(date "+%Y")
    expect="$year-12-31 08:00:00"
    tst "$timestamp" "$expect" 'octal number handled'
}


#
# tst_hold_crontab
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __hold_crontab function
#
tst_hold_crontab() {
    local mod_id mod_dir description timestamp crontab expect

    # FIXME
    # [ ] Test invalid mod_id
    # [ ] Test invalid timestamp

    # Create mod for testing
    mod_id=11111
    mod_dir=$DM_MODS/$mod_id

    mkdir -p "$mod_dir"
    description="Test mod."
    echo "$description" > "$mod_dir/description"

    timestamp="2010-12-31 12:34:56"
    crontab=$(__hold_crontab "$mod_id" "$timestamp")
    expect='34 12 31 12 *  $HOME/dm/bin/take_off_hold.sh 11111 # Test mod. @2010'
    tst "$crontab" "$expect" 'returns expected crontab'
}


#
# tst_hold_has_usage_comment
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __hold_has_usage_comment function
#
tst_hold_has_usage_comment() {
    local mod mod_dir hold_file

    __hold_has_usage_comment ''
    tst "$?" "1" 'no mod provided returns false'

    mod=11111
    mod_dir=$DM_MODS/$mod
    mkdir -p "$mod_dir"
    hold_file=$mod_dir/hold

    rm "$hold_file" 2>/dev/null

    # No hold file
    __hold_has_usage_comment "$mod"
    tst "$?" "1" 'no hold file returns false'

    # Hold file, no comment
    mod_dir=$DM_MODS/$mod
    mkdir -p "$mod_dir"
    echo '#whatever' > "$mod_dir/hold"
    __hold_has_usage_comment "$mod"
    tst "$?" "1" 'no comment in hold file returns false'

    # Hold file, with comment
    __hold_usage_comment "$mod" >> "$mod_dir/hold"
    __hold_has_usage_comment "$mod"
    tst "$?" "0" 'has comment returns true'
}


#
# tst_hold_timestamp
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __hold_timestamp function.
#
tst_hold_timestamp() {
    local ht mod mod_dir crontab year expect

    ht=$(__hold_timestamp '')
    tst "$ht" '' 'no mod provided returns nothing'

    mod=11111

    ht=$(__hold_timestamp "$mod")
    tst "$ht" '' 'no mod directory returns nothing'

    mod_dir=$DM_MODS/$mod
    mkdir -p "$mod_dir"

    ht=$(__hold_timestamp "$mod")
    tst "$ht" '' 'no hold file returns nothing'


    echo '#whatever' > "$mod_dir/hold"
    ht=$(__hold_timestamp "$mod")
    tst "$ht" '' 'no crontab in hold file returns nothing'


    crontab='59 23 31 12 *  $HOME/dm/bin/take_off_hold.sh 11111 # Test mod.'
    echo "$crontab" > "$mod_dir/hold"
    year=$(date "+%Y")
    expect="$year-12-31 23:59:00"

    ht=$(__hold_timestamp "$mod")
    tst "$ht" "$expect" 'crontab in hold file returns timestamp'

    echo '#22 22 22 12 *  $HOME/dm/bin/take_off_hold.sh 22222 # Another test mod.' > "$mod_dir/hold"
    echo '#33 23 31 12 *  $HOME/dm/bin/take_off_hold.sh 33333 # Another mod.'     >> "$mod_dir/hold"
    ht=$(__hold_timestamp "$mod")
    tst "$ht" '' 'Only commented crontabs returns nothing'

    echo "$crontab" >> "$mod_dir/hold"
    ht=$(__hold_timestamp "$mod")
    tst "$ht" "$expect" 'commented crontabs ignored, returns timestamp'
}


#
# tst_hold_timestamp_status
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __hold_timestamp_status function.
#
tst_hold_timestamp_status() {
    local status timestamp

    status=$(__hold_timestamp_status)
    tst "$status" "off_hold" 'no timestamp returns off hold'

    timestamp=$(date "+%Y-%m-%d %H:%M:%S" --date="+1 hour")
    status=$(__hold_timestamp_status "$timestamp")
    tst "$status" "on_hold" 'timestamp in future returns on hold'

    timestamp=$(date "+%Y-%m-%d %H:%M:%S" --date="-1 hour")
    status=$(__hold_timestamp_status "$timestamp")
    tst "$status" "expired" 'timestamp in past returns expired'
}

#
# tst_hold_usage_comment
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __hold_usage_comment function
#
tst_hold_usage_comment() {
    local comment mod expect

    comment=$(__hold_usage_comment '')
    tst "$comment" '' 'no mod provided returns nothing'

    mod=11111
    comment=$(__hold_usage_comment "$mod")
    expect="# <minute> <hour> <day> <month> <dow> \$HOME/dm/bin/take_off_hold.sh $mod # <descr> @<year>"
    tst "$comment" "$expect" 'mod, returns expected'
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
