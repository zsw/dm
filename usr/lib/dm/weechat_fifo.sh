#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_weechat 2>/dev/null || source $DM_ROOT/lib/weechat.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 "message to send to weechat fifo"

This script copies all positional parameters to weechat fifo's. Useful
for sending jabber messages from within scripts or testing from the cli.

OPTIONS:

   -u      Username to send message to.
   -h      Print this help message.

EXAMPLES:

    $0 "Test message."
    $0 "Test multiline message.\nThis is the second line."


NOTES:

    Requires weechat and weechat fifo channel: $HOME/.weechat/weechat_fifo_xxxxx

    Reference: http://weechat.flashtux.org/doc/en/weechat.en.html#secFIFOpipe

    If the -u option is not provided, the value of DM_PERSON_USERNAME,
    which gets its value from the USERNAME enviroment variable, is assumed.
    In other words these are equivalent.

    $0
    $0 -u \$DM_PERSON_USERNAME
    $0 -u \$USERNAME
EOF
}


#
# loggable_msg
#
# Sent: msg (string)
# Return: msg to log (string)
# Purpose:
#
#   Return a message suitable for logging.
#
# Notes:
#
#   Some messages are filtered in which case an empty string is returned.
#
function loggable_msg {

    msg=$1

    text=${msg##*|}

    # Filter messages from tests
    if [[ "$text" == '###### TEST ######' ]]; then
        return
    fi

    if [[ "$text" == '## test_body ##' ]]; then
        return
    fi

    if [[ "$text" == '## test_subject ##' ]]; then
        return
    fi

    if [[ "$text" == '** This message is from the test server ** Do not respond **' ]]; then
        return
    fi

    echo "$msg"
    return
}


username=$DM_PERSON_USERNAME

while getopts "hu:" options; do
  case $options in

    h ) _u
        exit 0 ;;
    u ) username=$OPTARG;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

if [[ ! $1 ]]; then
    _u
    exit 1
fi


set -f      # Disable parameter expansion, prevents * in message from expanding
message=$(echo -e "$*")              # Echo interprets escaped characters

if [[ ! $username ]]; then
    echo "ERROR: Unable to determine username." >&2
    exit 1
fi


pipe=$($DM_BIN/weechat_fifo_pipe.sh)

[[ ! "$pipe" ]] && exit 1      # exit without messages
                                # weechat_fifo_pipe.sh provides error messages


events_file=$(__weechat_events_file)


IFS=$'\n'

for line in $message; do

    # First append the message to the weechat events file so it triggers an
    # event action (eg display message with osd, or update count in dwm
    # status bar).

    if [[ $username == $DM_PERSON_USERNAME ]]; then


        msg=$(printf "%s|%s|%s|%s" \
                "$(date)" \
                'highlight' \
                "$username" \
                "$line" \
        )

        loggable_msg=$(loggable_msg "$msg")

        if [[ "$loggable_msg" ]]; then
            echo "$loggable_msg" >> "$events_file"
        fi
        echo "python.jabber.server.gtalk *$username: $line" > $pipe
    fi

    # Second, pass the message to the weechat fifo pipe so it is displayed
    # in the general weechat buffer.
    echo "python.jabber.server.gtalk */jmsg $username $line" > $pipe
done
set +f
