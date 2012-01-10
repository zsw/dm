#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Test script for lib/log.sh functions.
#
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

source $DM_ROOT/test/test.sh
__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

msg='This is a message'
tmpdir=$(__tmp_dir)
mkdir -p "$tmpdir"
tmp_file=$tmpdir/test/to_file
SYSLOG_FACILITY=local7
SYSLOG_FILE=/var/log/local7.log

#
# clear_logger_settings
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Clear logging settings
#
clear_logger_settings() {

    LOG_FORMAT_DATE=
    LOG_FORMAT_FILE=
    LOG_FORMAT_LEVEL=
    LOG_FORMAT_MESSAGE=

    DM_LOG=
    LOG_TO_STDERR=
    LOG_TO_STDOUT=

    OVERRIDE_DATE=
}


#
# date
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Provides a method of overriding the bash date command.
#   If the $OVERRIDE_DATE variable is set, a date command returns its
#   instead of the output of the 'date' command.
#
date() {

    [[ $OVERRIDE_DATE ]] && echo "$OVERRIDE_DATE" || command date "$*"
}


#
# tst_logger_level
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __logger_level function.
#
tst_logger_level() {

    LOG_LEVEL_DEBUG=1
    LOG_LEVEL_INFO=2
    LOG_LEVEL_WARN=3
    LOG_LEVEL_ERROR=4
    LOG_LEVEL_FATAL=5
    LOG_LEVEL_OFF=6

    while read -r level expect comment; do

        level=${level%,}        ## remove comma
        expect=${expect%,}      ## remove comma

        LOG_LEVEL=$level

        ll=$(__logger_level)
        LOG_LEVEL=INFO              # So reporting works
        tst "$ll" "$expect" "$comment, returns correct level"

    done <<EOT
    DEBUG, 1, uppercase debug
    INFO,  2, uppercase info
    WARN,  3, uppercase warn
    ERROR, 4, uppercase error
    FATAL, 5, uppercase fatal
    OFF,   6, uppercase off
    debug, 1, lowercase debug
    info,  2, lowercase info
    warn,  3, lowercase warn
    error, 4, lowercase error
    fatal, 5, lowercase fatal
    off,   6, lowercase off
EOT
}


#
# tst_logger_log
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run tests on __logger_log function.
#
tst_logger_log() {
    local save_DM_LOG level value expect ll

    # The code in tst uses __logger_log to report test results.
    # Restore logger settings using source test.sh before calling tst.
    save_DM_LOG=$DM_LOG
    DM_LOG=

    # Test formats
    level=DEBUG

    clear_logger_settings

    LOG_FORMAT_DATE=1
    LOG_TO_STDOUT=1
    OVERRIDE_DATE='2009-01-31 12:34:56'     # see function date()

    value=$(__logger_log "$level" "$msg")
    expect=$OVERRIDE_DATE

    source "$DM_ROOT/test/test.sh"
    OVERRIDE_DATE=
    tst "$value" "$expect" "format date logs date"


    clear_logger_settings

    LOG_FORMAT_FILE=1
    LOG_TO_STDOUT=1

    value=$(__logger_log "$level" "$msg")

    source "$DM_ROOT/test/test.sh"
    tst "$value" ", $0" "format file logs file"


    clear_logger_settings

    LOG_FORMAT_LEVEL=1
    LOG_TO_STDOUT=1

    value=$(__logger_log "$level" "$msg")

    source "$DM_ROOT/test/test.sh"
    tst "$value" "[${level}]" "format level logs level"


    clear_logger_settings

    LOG_FORMAT_MESSAGE=1
    LOG_TO_STDOUT=1


    value=$(__logger_log "$level" "$msg")

    source "$DM_ROOT/test/test.sh"
    tst "$value" "$msg" "format message logs message"


    clear_logger_settings

    LOG_FORMAT_DATE=1
    LOG_FORMAT_LEVEL=1
    LOG_FORMAT_FILE=1
    LOG_FORMAT_MESSAGE=1

    LOG_TO_STDOUT=1

    OVERRIDE_DATE='2009-01-31 12:34:56'

    value=$(__logger_log "$level" "$msg")

    expect="$OVERRIDE_DATE [$level] $msg, $0"

    source "$DM_ROOT/test/test.sh"
    OVERRIDE_DATE=
    tst "$value" "$expect" "format all logs proper message"


    # Test log "to" options

    # Log to file
    clear_logger_settings

    LOG_FORMAT_MESSAGE=1
    DM_LOG=$tmp_file

    [[ -e $tmp_file ]] && rm "$tmp_file"

    ll=$(__logger_log "$level" "$msg")
    value=$(< "$tmp_file")

    source "$DM_ROOT/test/test.sh"
    tst "$value" "$msg" "log to file logs message"


    # syslog
    # syslog test only works if the syslog file is readable
    if [[ -r $SYSLOG_FILE ]]; then
        clear_logger_settings

        LOG_FORMAT_MESSAGE=1
        DM_LOG=syslog:$SYSLOG_FACILITY

        uniq_msg="_the date is_ $(date) _log.sh test_"
        ll=$(__logger_log "$level" "$uniq_msg")
        value=$(grep -o "$uniq_msg" "$SYSLOG_FILE")

        source "$DM_ROOT/test/test.sh"
        tst "$value" "$uniq_msg" "log to syslog logs message"
    fi

    # stderr
    clear_logger_settings

    LOG_FORMAT_MESSAGE=1
    LOG_TO_STDERR=1

    ll=$(__logger_log "$level" "$msg" 2>"$tmp_file")
    value=$(< "$tmp_file")

    source "$DM_ROOT/test/test.sh"
    tst "$value" "$msg" "log to stderr logs message"

    DM_LOG=$save_DM_LOG
}


#
# tst_logger_debug
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on __logger_debug function.
#
tst_logger_debug() {
    local save_DM_LOG level

    save_DM_LOG=$DM_LOG
    DM_LOG=

    level=DEBUG

    while IFS=',' read -r log_level message name comment; do
        clear_logger_settings
        cp /dev/null "$tmp_file"

        LOG_FORMAT_MESSAGE=1
        DM_LOG=$tmp_file

        LOG_LEVEL=$log_level

        ll=$(__logger_debug "$msg")
        value=$(< "$tmp_file")

        source "$DM_ROOT/test/test.sh"
        tst "$value" "$message" "LOG_LEVEL $name, returns $comment"
    done < <(sed -e 's/^\s\+//g; s/,\s\+/,/g' <<EOT
    ,       ,     not set,            nothing
    info,   ,     higher than $level, nothing
    debug,  $msg, equal to $level,    message
EOT
)

    DM_LOG=$save_DM_LOG
}


#
# tst_logger_info
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on __logger_info function.
#
tst_logger_info() {
    local save_DM_LOG level

    save_DM_LOG=$DM_LOG
    DM_LOG=

    level=INFO

    while IFS=',' read -r log_level message name comment; do
        clear_logger_settings
        cp /dev/null "$tmp_file"

        LOG_FORMAT_MESSAGE=1
        DM_LOG=$tmp_file

        LOG_LEVEL=$log_level

        ll=$(__logger_info "$msg")
        value=$(< "$tmp_file")

        source "$DM_ROOT/test/test.sh"
        tst "$value" "$message" "LOG_LEVEL $name, returns $comment"
    done < <(sed -e 's/^\s\+//g; s/,\s\+/,/g' <<EOT
    ,      ,     not set,            nothing
    warn,  ,     higher than $level, nothing
    info,  $msg, equal to $level,    message
    debug, $msg, less than $level,   message
EOT
)

    DM_LOG=$save_DM_LOG
}


#
# tst_logger_warn
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on __logger_warn function.
#
tst_logger_warn() {
    local save_DM_LOG level

    save_DM_LOG=$DM_LOG
    DM_LOG=

    level=WARN

    while IFS=',' read -r log_level message name comment; do
        clear_logger_settings
        cp /dev/null "$tmp_file"

        LOG_FORMAT_MESSAGE=1
        DM_LOG=$tmp_file

        LOG_LEVEL=$log_level

        ll=$(__logger_warn "$msg")
        value=$(< "$tmp_file")

        source "$DM_ROOT/test/test.sh"
        tst "$value" "$message" "LOG_LEVEL $name, returns $comment"
    done < <(sed -e 's/^\s\+//g; s/,\s\+/,/g' <<EOT
    ,      ,     not set,            nothing
    error, ,     higher than $level, nothing
    warn,  $msg, equal to $level,    message
    info,  $msg, less than $level,   message
EOT
)

    DM_LOG=$save_DM_LOG
}


#
# tst_logger_error
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on __logger_error function.
#
tst_logger_error() {
    local save_DM_LOG level

    save_DM_LOG=$DM_LOG
    DM_LOG=

    level=ERROR

    while IFS=',' read -r log_level message name comment; do
        clear_logger_settings
        cp /dev/null "$tmp_file"

        LOG_FORMAT_MESSAGE=1
        DM_LOG=$tmp_file

        LOG_LEVEL=$log_level

        ll=$(__logger_error "$msg")
        value=$(< "$tmp_file")

        source "$DM_ROOT/test/test.sh"
        tst "$value" "$message" "LOG_LEVEL $name, returns $comment"
    done < <(sed -e 's/^\s\+//g; s/,\s\+/,/g' <<EOT
    ,      ,     not set,            nothing
    fatal, ,     higher than $level, nothing
    error, $msg, equal to $level,    message
    warn,  $msg, less than $level,   message
EOT
)

    DM_LOG=$save_DM_LOG
}


#
# tst_logger_fatal
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on __logger_fatal function.
#
tst_logger_fatal() {
    local save_DM_LOG level

    save_DM_LOG=$DM_LOG
    DM_LOG=

    level=FATAL

    while IFS=',' read -r log_level message name comment; do
        clear_logger_settings
        cp /dev/null "$tmp_file"

        LOG_FORMAT_MESSAGE=1
        DM_LOG=$tmp_file

        LOG_LEVEL=$log_level

        ll=$(__logger_fatal "$msg")
        value=$(< "$tmp_file")

        source "$DM_ROOT/test/test.sh"
        tst "$value" "$message" "LOG_LEVEL $name, returns $comment"
    done < <(sed -e 's/^\s\+//g; s/,\s\+/,/g' <<EOT
    ,      ,     not set,            nothing
    off,   ,     higher than $level, nothing
    fatal, $msg, equal to $level,    message
    error, $msg, less than $level,   message
EOT
)

    DM_LOG=$save_DM_LOG
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
