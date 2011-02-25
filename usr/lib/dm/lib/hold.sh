#!/bin/bash

#
# hold.sh
#
# Library of functions related to putting mods on hold.
#

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh


#
# hold_add_usage_comment
#
# Sent: mod_id - id of mod
# Return: nothing
# Purpose:
#
#   Add a hold usage comment to the hold file of the mod with the
#   provided id.
#
# Note:
#   This routine doesn't check if the hold file already has a usage
#   comment. Suggested usage:
#
#       hold_has_usage_comment $mod || hold_add_usage_comment $mod
#
__hold_add_usage_comment() {

    local mod=$1
    [[ ! $mod ]] && return 1

    hold_file="$DM_MODS/$mod/hold"
    hold_usage_comment $mod >> $hold_file

    return
}


#
# hold_as_crontab TIMESTAMP
#
# Sent: timestamp
# Return: echo cron expression to stdout
# Purpose:
#
#   Convert a timestamp to a cron expression.
#
#   The cron expression is of the format
#    "<minute> <hour> <day> <month> *"
#
#   The year and the seconds of the timestamp are ignored.
#
__hold_as_crontab() {

    date --date="$1" "+%M %H %d %m *"
    return
}


#
# hold_as_yyyy_mm_dd_hh_mm_ss CRON_EXPRESSION
#
# Sent: crontab - string, see notes
# Return: echo timestamp in yyyy-mm-dd hh:mm:ss format
# Purpose:
#
#   Convert a cron expression to a timestamp, format yyyy-mm-dd
#   hh:mm:ss.
#
# Notes:
#
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

    local cron_exp=$1
    local fields=$(echo "$cron_exp" | awk '{print NF}')
    if [[ $fields -lt 5 ]]; then
        echo "Invalid crontab expression: $cron_exp" >&2
        return
    fi

    # Break off cron expression fields from left side
    local c="$cron_exp"
    local minute=$(echo "${c%% *}" | grep -P "^[0-9]{1,2}$")
    c="${c#* }"
    local hour=$(echo "${c%% *}" | grep -P "^[0-9]{1,2}$")
    c="${c#* }"
    local day=$(echo "${c%% *}" | grep -P "^[0-9]{1,2}$")
    c="${c#* }"
    local month=$(echo "${c%% *}" | grep -P "^[0-9]{1,2}$")
    c="${c#* }"
    local year=$(echo "${c##*@}" | grep -P "^[0-9]{1,4}$")

    # With the exception of "year", all fields must return a valid
    # amount or we have an invalid crontab entry.
    if [[ ! $minute ]] || \
        [[ ! $hour ]]  || \
        [[ ! $day ]]   || \
        [[ ! $month ]]; then
        echo "Unable to parse crontab expression: $cron_exp" >&2
        return
    fi

    local second=0

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
        year=$(date "+%Y")
        local today_as_seconds=$(date "+%s")
        local ymdhms_as_seconds=$(date "+%s" \
            --date="$(printf "%04d-%02d-%02d %02d:%02d:%02d" \
            $year $month $day $hour $minute $second \
            )" \
            )
        if [[ $today_as_seconds > $ymdhms_as_seconds ]]; then
            year=$((year + 1))
        fi
    fi

    printf "%04d-%02d-%02d %02d:%02d:%02d\n" $year $month $day $hour $minute $second
    return
}


#
# hold_crontab MOD_ID TIMESTAMP
#
# Sent: mod id - id of the mod the crontab entry is for
#       timestamp - hold time, format: yyyy-mm-ss hh:mm:ss
# Return: echo string representing hold crontab entry
# Purpose:
#
#   Return a crontab entry that will put the mod on hold until the given
#   timestamp.
#
__hold_crontab() {

    local mod_id=$1
    local timestamp=$2
    local cron_exp=$(hold_as_crontab "$timestamp")
    if [[ ! "$cron_exp" ]]; then
        return
    fi
    year=$(date --date="$timestamp" "+%Y")
    echo "$mod_id" | $DM_BIN/format_mod.sh "$cron_exp  \$HOME/dm/bin/take_off_hold.sh %i # %d @$year"
    return
}


#
# hold_has_usage_comment
#
# Sent: mod_id - id of mod
# Return: nothing
# Purpose:
#
#   Determine if the hold file of the mod with the provided id has a
#   usage comment in it.
#
__hold_has_usage_comment() {

    local mod=$1
    [[ ! $mod ]] && return 1

    hold_file="$DM_MODS/$mod/hold"

    [[ ! -e "$hold_file" ]] && return 1

    comment=$(hold_usage_comment $mod)
    [[ ! "$comment" ]] && return 1

    found=$(grep "$comment" $hold_file)
    if [[ ! $found ]]; then
        return 1
    fi

    return 0
}


#
# __hold_status
#
# Sent: mod
# Return: nothing
# Purpose:
#
#   Process hold_status for a mod.
#
__hold_status() {
    local hold_file mod status timestamp who who_file

    mod=$1

    hold_file=$(attr_file "$mod" 'hold')

    # Ignore files with git conflict markers. Processing them may cause
    # foo. Eg, the user may be editing the file fixing the conflict or
    # the hold time may get commented out.

    has_conflict_markers "$hold_file" && return

    timestamp=$(hold_timestamp "$mod")

    status=$(hold_timestamp_status "$timestamp")

    [[ ! $timestamp ]] && timestamp='---------- --:--:--'
    [[ ! $status ]]    && status='off_hold'

    who_file=$(attr_file "$mod" 'who')
    who=$(tr -d -c 'A-Z' < "$who_file")

    echo "$mod $who $timestamp $status"
}


#
# hold_timestamp
#
# Sent: mod id ( eg 12345)
# Return: nothing (echo's timestamp to stdout)
# Purpose:
#
#   Determine the hold timestamp for a mod.
#
# Usage:
#
#   mod=12345
#   time=$(hold_timestamp $mod)
#
# Notes:
#
#   If a hold file does not exist or it does not have a hold timestamp,
#   nothing is printed.
#
__hold_timestamp() {

    local mod=$1

    [[ ! $mod ]] && return

    local hold_file=$(attr_file $mod 'hold')

    [[ ! $hold_file ]] && return

    local crontab=$(tail -1 $hold_file | grep -v '^#')

    [[ ! "$crontab" ]] && return

    local timestamp=$(hold_as_yyyy_mm_dd_hh_mm_ss "$crontab")

    echo $timestamp
}


#
# hold_timestamp_status
#
# Sent: timestamp ( "yyyy-mm-dd hh:mm:ss" )
# Return: nothing (echo's status to stdout)
# Purpose:
#
#   Determine the status of a hold timestamp.
#
# Usage:
#
#   mod=12345
#   timestamp=$(hold_timestamp $mod)
#   status=$(hold_timestamp_status "$timestamp")
#
# Notes:
#
#   Statuses:
#
#   on_hold         - Mod is on hold
#   off_hold        - Mod is not on hold
#   expired         - Mod has a hold time but it is past
#
#   A null timestamp is assumed 'off_hold'.
#
__hold_timestamp_status() {

    local timestamp=$1

    local status='off_hold'

    if [[ $timestamp ]]; then

        local time=$(date +%s -d "$timestamp")
        local  now=$(date +%s)                # present in seconds-since-epoch form

        if [[ "$time" -lt "$now" ]]; then
            status='expired'
        else
            status='on_hold'
        fi
    fi

    echo "$status"
    return;
}


#
# hold_usage_comment
#
# Sent: mod_id - id of mod
# Return: string - usage comment
# Purpose:
#
#   Return a usage comment for the mod with the provided id.
#
__hold_usage_comment() {

    local mod=$1
    [[ ! $mod ]] && return

    echo "# <minute> <hour> <day> <month> <dow> \$HOME/dm/bin/take_off_hold.sh $mod # <descr> @<year>"
    return
}


# This function indicates this file has been sourced.
__loaded_hold() {
    return 0
}

# Export all functions to any script sourcing this library file.
while read -r function; do
    export -f "${function%%(*}"         # strip '()'
done < <(awk '/^__*()/ {print $1}' "$DM_ROOT"/lib/hold.sh)

