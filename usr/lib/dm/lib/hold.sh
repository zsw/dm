#!/bin/bash

#
# hold.sh
#
# Library of functions related to putting mods on hold.
#

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh


#
# __hold_add_usage_comment
#
# Sent: mod_id - id of mod
# Return: nothing
#
# Purpose:
#   Add a hold usage comment to the hold file of the mod with the
#   provided id.
#
# Note:
#   This routine doesn't check if the hold file already has a usage
#   comment. Suggested usage:
#
#       __hold_has_usage_comment $mod || __hold_add_usage_comment $mod
#
__hold_add_usage_comment() {
    local mod=$1
    [[ ! $mod ]] && return 1

    __hold_usage_comment "$mod" >> "$DM_MODS/$mod/hold"
}


#
# __hold_as_crontab TIMESTAMP
#
# Sent: timestamp
# Return: echo cron expression to stdout
#
# Purpose:
#   Convert a timestamp to a cron expression.
#
#   The cron expression is of the format
#    "<minute> <hour> <day> <month> *"
#
#   The year and the seconds of the timestamp are ignored.
#
__hold_as_crontab() {

    date --date="$1" "+%M %H %d %m *"
}


#
# __hold_as_yyyy_mm_dd_hh_mm_ss CRON_EXPRESSION
#
# Sent: crontab - string, see notes
# Return: echo timestamp in yyyy-mm-dd hh:mm:ss format
#
# Purpose:
#   Convert a cron expression to a timestamp, format yyyy-mm-dd
#   hh:mm:ss.
#
# Notes:
#   The crontab line is parsed as follows:
#   <minute> <hour> <day> <month> * .* @<year>
#
#   The first asterisk is the actual asterisk symbol. The period and the second
#   asterisk is the regexp symbol representing any characters or none.
#
#   Example:
#   "00 06 31 12 * /command 12345 # My mod. @2010"
#
#   The seconds of the timestamp are set to 0.
#
#   If the year is not available, the earliest year such that the
#   timestamp is in the future is used.
#
__hold_as_yyyy_mm_dd_hh_mm_ss() {
    local c cron_exp fields minute hour day month year second
    local today_as_seconds ymdhms_as_seconds

    cron_exp=$1
    fields=$(awk '{print NF}' <<< "$cron_exp")
    if (( $fields < 5 )); then
        __mi "Invalid crontab expression: $cron_exp" >&2
        return
    fi

#   "00 06 31 12 * /command 12345 # My mod. @2010"

    # Break off cron expression fields from left side
    read minute hour day month _ <<< "$cron_exp"

    grep -q '@' <<< "$cron_exp" && year=${cron_exp##*@}
    (( $year )) || year=

    # With the exception of "year", all fields must return a valid
    # amount or we have an invalid crontab entry.
    for i in $minute $hour $day $month; do
        if ! [[ $i =~ ^[0-9]+$ ]]; then
            __mi "Unable to parse crontab expression: $cron_exp" >&2
            return
        fi
    done

    second=0

    # If a value has a leading zero it may be interpreted as an octal
    # number by printf. Convert to decimal using $(( 10#$x ))
    minute=$(( 10#$minute ))
    hour=$(( 10#$hour ))
    day=$(( 10#$day ))
    month=$(( 10#$month ))

    # If the year value is not available then guess it. Take the
    # earliest year that makes the date in the future, ie this year if
    # it's not past, else next year.
    if [[ ! $year ]]; then
        printf -v year "%(%Y)T"  -1             ## creates a variable 'year' for current year
        printf -v today_as_seconds "%(%s)T"  -1 ## creates a variable 'today_as_seconds' for epoch seconds from now
        printf -v ymdhms "%04d-%02d-%02d %02d:%02d:%02d" "$year" "$month" "$day" "$hour" "$minute" "$second"
        ymdhms_as_seconds=$(date "+%s" --date="$ymdhms")
        (( $today_as_seconds > $ymdhms_as_seconds )) && year=$(( $year + 1 ))
    fi

    printf "%04d-%02d-%02d %02d:%02d:%02d\n" "$year" "$month" "$day" "$hour" "$minute" "$second"
}


#
# __hold_crontab MOD_ID TIMESTAMP
#
# Sent: mod id - id of the mod the crontab entry is for
#       timestamp - hold time, format: yyyy-mm-ss hh:mm:ss
# Return: echo string representing hold crontab entry
#
# Purpose:
#   Return a crontab entry that will put the mod on hold until the given
#   timestamp.
#
__hold_crontab() {
    local mod_id timestamp cron_exp year

    mod_id=$1
    timestamp=$2
    cron_exp=$(__hold_as_crontab "$timestamp")
    [[ ! $cron_exp ]] && return
    year=$(date --date="$timestamp" "+%Y")
    "$DM_BIN/format_mod.sh" "$cron_exp  \$HOME/dm/bin/take_off_hold.sh %i # %d @$year" <<< "$mod_id"
}


#
# __hold_has_usage_comment
#
# Sent: mod_id - id of mod
# Return: nothing
#
# Purpose:
#   Determine if the hold file of the mod with the provided id has a
#   usage comment in it.
#
__hold_has_usage_comment() {
    local mod hold_file comment found

    mod=$1
    [[ ! $mod ]] && return 1

    hold_file=$DM_MODS/$mod/hold
    [[ ! -e $hold_file ]] && return 1

    comment=$(__hold_usage_comment "$mod")
    [[ ! $comment ]] && return 1

    grep -q "$comment" "$hold_file" || return 1
}


#
# __hold_status
#
# Sent: mod
# Return: nothing
#
# Purpose:
#   Process __hold_status for a mod.
#
__hold_status() {
    local hold_file mod status timestamp who who_file

    mod=$1

    hold_file=$(__attr_file "$mod" 'hold')

    # Ignore files with git conflict markers. Processing them may cause
    # foo. Eg, the user may be editing the file fixing the conflict or
    # the hold time may get commented out.

    __has_conflict_markers "$hold_file" && return

    timestamp=$(__hold_timestamp "$mod")

    status=$(__hold_timestamp_status "$timestamp")

    [[ ! $timestamp ]] && timestamp='---------- --:--:--'
    [[ ! $status ]]    && status=off_hold

    who_file=$(__attr_file "$mod" 'who')
    [[ $who_file ]] && who=$(tr -d -c 'A-Z' < "$who_file") || who="--"

    echo "$mod $who $timestamp $status"
}


#
# __hold_timestamp
#
# Sent: mod id ( eg 12345)
# Return: nothing (echo's timestamp to stdout)
#
# Purpose:
#   Determine the hold timestamp for a mod.
#
# Usage:
#   mod=12345
#   time=$(__hold_timestamp $mod)
#
# Notes:
#   If a hold file does not exist or it does not have a hold timestamp,
#   nothing is printed.
#
__hold_timestamp() {
    local mod hold_file crontab timestamp

    mod=$1
    [[ ! $mod ]] && return

    hold_file=$(__attr_file "$mod" 'hold')
    [[ ! $hold_file ]] && return

    crontab=$(tail -1 $hold_file | grep -v '^#')
    [[ ! $crontab ]] && return

    timestamp=$(__hold_as_yyyy_mm_dd_hh_mm_ss "$crontab")
    [[ ! $timestamp ]] && echo "Unable to get hold timestamp from crontab for mod $mod" >&2

    echo "$timestamp"
}


#
# __hold_timestamp_status
#
# Sent: timestamp ( "yyyy-mm-dd hh:mm:ss" )
# Return: nothing (echo's status to stdout)
#
# Purpose
#   Determine the status of a hold timestamp.
#
# Usage:
#   mod=12345
#   timestamp=$(__hold_timestamp $mod)
#   status=$(__hold_timestamp_status "$timestamp")
#
# Notes:
#   Statuses:
#
#   on_hold         - Mod is on hold
#   off_hold        - Mod is not on hold
#   expired         - Mod has a hold time but it is past
#
#   A null timestamp is assumed 'off_hold'.
#
__hold_timestamp_status() {
    local timestamp status time now

    timestamp=$1
    status=off_hold

    if [[ $timestamp ]]; then
        time=$(date +%s -d "$timestamp")
        now=$(date +%s)                # present in seconds-since-epoch form

        (( $time < $now )) && status=expired || status=on_hold
    fi

    echo "$status"
}


#
# __hold_usage_comment
#
# Sent: mod_id - id of mod
# Return: string - usage comment
#
# Purpose:
#   Return a usage comment for the mod with the provided id.
#
__hold_usage_comment() {
    local mod=$1
    [[ ! $mod ]] && return

    echo "# <minute> <hour> <day> <month> <dow> \$HOME/dm/bin/take_off_hold.sh $mod # <descr> @<year>"
}


# This function indicates this file has been sourced.
__loaded_hold() {
    return 0
}

# Export all functions to any script sourcing this library file.
while read -r function; do
    export -f "${function%%(*}"         # strip '()'
done < <(awk '/^__*()/ {print $1}' "$DM_ROOT/lib/hold.sh")
