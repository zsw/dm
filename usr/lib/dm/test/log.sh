#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

#
# Test script for lib/log.sh functions.
#
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

source $DM_ROOT/test/test.sh
_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

msg='This is a message'
tmpdir=$(tmp_dir)
mkdir -p $tmpdir
tmp_file="${tmpdir}/test/to_file"
SYSLOG_FACILITY='local7'
SYSLOG_FILE='/var/log/local7.log'

#
# clear_logger_settings
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Clear logging settings
#
function clear_logger_settings {

    LOG_FORMAT_DATE=
    LOG_FORMAT_FILE=
    LOG_FORMAT_LEVEL=
    LOG_FORMAT_MESSAGE=

    DM_LOG=
    LOG_TO_STDERR=
    LOG_TO_STDOUT=

    override_date=

    return
}


#
# date
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Provides a method of overriding the bash date command.
#   If the $override_date variable is set, a date command returns its
#   instead of the output of the 'date' command.
#
function date {

    if [[ $override_date ]]; then
        echo $override_date
        return
    fi

    command date "$*"

    return
}


#
# tst_logger_level
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on logger_level function.
#
function tst_logger_level {

    LOG_LEVEL_DEBUG=1
    LOG_LEVEL_INFO=2
    LOG_LEVEL_WARN=3
    LOG_LEVEL_ERROR=4
    LOG_LEVEL_FATAL=5
    LOG_LEVEL_OFF=6

    while read line
    do
        line=$(echo $line | sed -e "s/\,\s\+/\,/g")

        saveIFS=$IFS
        IFS=","
        set -- $line
        arr=( $line )
        IFS=$saveIFS

        LOG_LEVEL=${arr[0]}

        ll=$(logger_level)
        LOG_LEVEL=INFO              # So reporting works
        tst "$ll" "${arr[1]}" "${arr[2]}, returns correct level"

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

    return
}


#
# tst_logger_log
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on logger_log function.
#
function tst_logger_log {

    # The code in tst uses logger_log to report test results.
    # Restore logger settings using source test.sh before calling tst.

    saveDM_LOG=$DM_LOG
    DM_LOG=

    # Test formats
    level='DEBUG'

    clear_logger_settings

    LOG_FORMAT_DATE=1
    LOG_TO_STDOUT=1
    override_date='2009-01-31 12:34:56'     # see function date()

    value=$(logger_log $level $msg)
    expect="$override_date"

    source $DM_ROOT/test/test.sh
    override_date=
    tst "$value" "$expect" "format date logs date"


    clear_logger_settings

    LOG_FORMAT_FILE=1
    LOG_TO_STDOUT=1

    value=$(logger_log $level $msg)

    source $DM_ROOT/test/test.sh
    tst "$value" ", $0" "format file logs file"


    clear_logger_settings

    LOG_FORMAT_LEVEL=1
    LOG_TO_STDOUT=1

    value=$(logger_log $level $msg)

    source $DM_ROOT/test/test.sh
    tst "$value" "[$level]" "format level logs level"


    clear_logger_settings

    LOG_FORMAT_MESSAGE=1
    LOG_TO_STDOUT=1


    value=$(logger_log $level $msg)

    source $DM_ROOT/test/test.sh
    tst "$value" "$msg" "format message logs message"


    clear_logger_settings

    LOG_FORMAT_DATE=1
    LOG_FORMAT_LEVEL=1
    LOG_FORMAT_FILE=1
    LOG_FORMAT_MESSAGE=1

    LOG_TO_STDOUT=1

    override_date='2009-01-31 12:34:56'

    value=$(logger_log $level $msg)

    expect="$override_date [$level] $msg, $0"

    source $DM_ROOT/test/test.sh
    override_date=
    tst "$value" "$expect" "format all logs proper message"


    # Test log "to" options

    # Log to file
    clear_logger_settings

    LOG_FORMAT_MESSAGE=1
    DM_LOG=$tmp_file

    [[ -e $tmp_file ]] && rm $tmp_file

    ll=$(logger_log $level $msg)
    value=$(cat $tmp_file)

    source $DM_ROOT/test/test.sh
    tst "$value" "$msg" "log to file logs message"


    # syslog
    # syslog test only works if the syslog file is readable
    if [[ -r $SYSLOG_FILE ]]; then
        clear_logger_settings

        LOG_FORMAT_MESSAGE=1
        DM_LOG="syslog:$SYSLOG_FACILITY"

        ll=$(logger_log $level $msg)
        value=$(tail $SYSLOG_FILE | grep -o "$msg" | tail -1)

        source $DM_ROOT/test/test.sh
        tst "$value" "$msg" "log to syslog logs message"
    fi

    # stderr
    clear_logger_settings

    LOG_FORMAT_MESSAGE=1
    LOG_TO_STDERR=1

    ll=$(logger_log $level $msg 2>$tmp_file)
    value=$(cat $tmp_file)

    source $DM_ROOT/test/test.sh
    tst "$value" "$msg" "log to stderr logs message"

    DM_LOG=$saveDM_LOG
    return
}


#
# tst_logger_debug
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on logger_debug function.
#
function tst_logger_debug {

    saveDM_LOG=$DM_LOG
    DM_LOG=

    level=DEBUG

    while read line
    do
        line=$(echo $line | sed -e "s/\,\s\+/\,/g")

        saveIFS=$IFS
        IFS=","
        set -- $line
        arr=( $line )
        IFS=$saveIFS

        clear_logger_settings
        cp /dev/null $tmp_file

        LOG_FORMAT_MESSAGE=1
        DM_LOG=$tmp_file

        LOG_LEVEL=${arr[0]}

        ll=$(logger_debug $msg)
        value=$(cat $tmp_file 2>/dev/null)

        source $DM_ROOT/test/test.sh
        tst "$value" "${arr[1]}" "LOG_LEVEL ${arr[2]}, returns ${arr[3]}"

    done <<EOT
    ,       ,     not set,            nothing
    info,   ,     higher than $level, nothing
    debug,  $msg, equal to $level,    message
EOT

    DM_LOG=$saveDM_LOG
    return
}


#
# tst_logger_info
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on logger_info function.
#
function tst_logger_info {

    saveDM_LOG=$DM_LOG
    DM_LOG=

    level=INFO

    while read line
    do
        line=$(echo $line | sed -e "s/\,\s\+/\,/g")

        saveIFS=$IFS
        IFS=","
        set -- $line
        arr=( $line )
        IFS=$saveIFS

        clear_logger_settings
        cp /dev/null $tmp_file

        LOG_FORMAT_MESSAGE=1
        DM_LOG=$tmp_file

        LOG_LEVEL=${arr[0]}

        ll=$(logger_info $msg)
        value=$(cat $tmp_file 2>/dev/null)

        source $DM_ROOT/test/test.sh
        tst "$value" "${arr[1]}" "LOG_LEVEL ${arr[2]}, returns ${arr[3]}"

    done <<EOT
    ,      ,     not set,            nothing
    warn,  ,     higher than $level, nothing
    info,  $msg, equal to $level,    message
    debug, $msg, less than $level,   message
EOT

    DM_LOG=$saveDM_LOG
    return
}


#
# tst_logger_warn
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on logger_warn function.
#
function tst_logger_warn {

    saveDM_LOG=$DM_LOG
    DM_LOG=

    level=WARN

    while read line
    do
        line=$(echo $line | sed -e "s/\,\s\+/\,/g")

        saveIFS=$IFS
        IFS=","
        set -- $line
        arr=( $line )
        IFS=$saveIFS

        clear_logger_settings
        cp /dev/null $tmp_file

        LOG_FORMAT_MESSAGE=1
        DM_LOG=$tmp_file

        LOG_LEVEL=${arr[0]}

        ll=$(logger_warn $msg)
        value=$(cat $tmp_file 2>/dev/null)

        source $DM_ROOT/test/test.sh
        tst "$value" "${arr[1]}" "LOG_LEVEL ${arr[2]}, returns ${arr[3]}"

    done <<EOT
    ,      ,     not set,            nothing
    error, ,     higher than $level, nothing
    warn,  $msg, equal to $level,    message
    info,  $msg, less than $level,   message
EOT

    DM_LOG=$saveDM_LOG
    return
}


#
# tst_logger_error
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on logger_error function.
#
function tst_logger_error {

    saveDM_LOG=$DM_LOG
    DM_LOG=

    level=ERROR

    while read line
    do
        line=$(echo $line | sed -e "s/\,\s\+/\,/g")

        saveIFS=$IFS
        IFS=","
        set -- $line
        arr=( $line )
        IFS=$saveIFS

        clear_logger_settings
        cp /dev/null $tmp_file

        LOG_FORMAT_MESSAGE=1
        DM_LOG=$tmp_file

        LOG_LEVEL=${arr[0]}

        ll=$(logger_error $msg)
        value=$(cat $tmp_file 2>/dev/null)

        source $DM_ROOT/test/test.sh
        tst "$value" "${arr[1]}" "LOG_LEVEL ${arr[2]}, returns ${arr[3]}"

    done <<EOT
    ,      ,     not set,            nothing
    fatal, ,     higher than $level, nothing
    error, $msg, equal to $level,    message
    warn,  $msg, less than $level,   message
EOT

    DM_LOG=$saveDM_LOG
    return
}


#
# tst_logger_fatal
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on logger_fatal function.
#
function tst_logger_fatal {

    saveDM_LOG=$DM_LOG
    DM_LOG=

    level=FATAL

    while read line
    do
        line=$(echo $line | sed -e "s/\,\s\+/\,/g")

        saveIFS=$IFS
        IFS=","
        set -- $line
        arr=( $line )
        IFS=$saveIFS

        clear_logger_settings
        cp /dev/null $tmp_file

        LOG_FORMAT_MESSAGE=1
        DM_LOG=$tmp_file

        LOG_LEVEL=${arr[0]}

        ll=$(logger_fatal $msg)
        value=$(cat $tmp_file 2>/dev/null)

        source $DM_ROOT/test/test.sh
        tst "$value" "${arr[1]}" "LOG_LEVEL ${arr[2]}, returns ${arr[3]}"

    done <<EOT
    ,      ,     not set,            nothing
    off,   ,     higher than $level, nothing
    fatal, $msg, equal to $level,    message
    error, $msg, less than $level,   message
EOT

    DM_LOG=$saveDM_LOG
    return
}


functions=$(cat $0 | grep '^function tst_' | awk '{ print $2}')

[[ -n "$1" ]] && functions="$*"

for function in  $functions; do
    if [[ ! $(declare -f $function) ]]; then
        echo "Function not found: $function"
        continue
    fi

    $function
done
