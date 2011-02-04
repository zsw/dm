#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh
_loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh

usage() {

    cat << EOF

usage: $0 [options] /path/to/file

This script sends a message stored in a file.

OPTIONS:

    -t  To username. Defaults to \$DM_PERSON_USERNAME
    -v  Verbose

    -h  Print this help message.

EXAMPLES:

    $0 /tmp/message.txt         # Send message contained in file.

NOTES:

    The script attempts to use a weechat pipe to send message. If that is not
    possible the message is sent by email.
EOF
}


#
# by_weechat
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Send message by weechat
#
function by_weechat {

    [[ -z $file ]] && return
    [[ -z $to ]] && return

    logger_debug "Sending by weechat"

    saveIFS=$IFS
    IFS=$'\n'
    for line in $(cat $file); do
        $DM_ROOT/bin/weechat_fifo.sh -u $to "$line"
    done
    IFS=$saveIFS
    return
}


#
# by_email
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Send message by email
#
function by_email {

    logger_debug "Sending email"

    note="------------------\nNote: Weechat is not available."
    body=$(cat $file && echo "" && echo -e $note && echo "" && cat $tmpfile)
    # Please update your dev system
    # 123456789012345678901234567890
    subject=$(head -1 $file | cut -c1-30)
    to_email=$(person_attribute email username $to)
    logger_debug "Subject: $subject"
    logger_debug "To: $to_email"
    res=$(echo -e "To: $to_email\nSubject: $subject\n\n$body" | sendmail -v -- $to_email)
    logger_debug "$res"

    return
}

verbose=
to=$DM_PERSON_USERNAME

while getopts "ht:v" options; do
  case $options in

    t ) to=$OPTARG;;
    v ) verbose=1;;
    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

[[ -n $verbose ]] && LOG_LEVEL=debug
[[ -n $verbose ]] && LOG_TO_STDERR=1

if [ $# -lt 1 ]; then
    echo "ERROR: Please provide the name of the file containing the message."
    usage
    exit 1
fi

if [ -z "$to" ]; then
    echo "ERROR: Please provide username to send to with -t option."
    usage
    exit 1
fi

file=$1;

if [[ ! -r "$file" ]]; then
    echo "ERROR: Unable to read file $file" >&2
    exit 1
fi

tmpfile=$(tmp_file)
pipe=$($DM_BIN/weechat_fifo_pipe.sh 2> $tmpfile)
exit_status=$?
logger_debug "weechat_fifo_pipe.sh exit status: $exit_status"
logger_debug "weechat pipe: $pipe"

if [[ "$exit_status" == '0' && -n "$pipe" ]]; then
    by_weechat
else
    by_email
fi
