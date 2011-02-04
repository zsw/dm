#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

# osd_daemon.sh

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

usage() {

cat << EOF

usage: $0 [options]


This script will monitor an osd pipe, $osd_pipe, and display any messages using OSD.


OPTIONS:
-f      Fork process (detach).

-h      Print this help message.

NOTES:

The script runs as a daemon with the -f option.

OSD MESSAGES:

To display a message using OSD simply print the message to the osd pipe.

    Example: echo "This is a message" > $osd_pipe

To remove the message use the STOP control. See below.

OSD CONTROLS:

The OSD message queue can be controlled by passing commands to the osd pipe.

   Usage:   echo command  > $osd_pipe
   Example: echo __STOP__ > $osd_pipe

Command         Action
__HIDE__        Hide current OSD message but leave at top of message queue.
__FORK__        Fork process (essentially a restart, similar to sending a SIGHUP).
__SHOW__        Show OSD message if previously hidden.
__STOP__        Stop displaying current OSD message and move on to next in queue.
__KILL__        Exit this program.
EOF
}


#
# fork
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Fork (detach) the script.
#
# Notes:
#
#   A fork simply retarts this script in the background
#   using setsid with all arguments except the fork option
#   and then exits.
#
function fork {

    cmd=$( echo "$0 $args" | sed -e "s/ -f//" )         # Remove fork option.

    logger_debug "Forking... $cmd"

    /usr/bin/setsid $cmd <&- >&- &                      # Close stdin/stdout and run in background.

    exit 0
}

function push {
    if [ -z "$1" ]; then
        return
    fi

    let "SP += 1"     # Bump stack pointer.
    stack[$SP]=$1

    return
}

function pop {
    message=                    # Empty out data item.

    if [ "$SP" -eq "0" ];then   # Stack empty?
        return
    fi                       #  This also keeps SP from going below 0
                             #+ i.e., prevents a runaway stack.

    let "top = 1"
    message=${stack[$top]}      # Get top item of stack

                             # Shuffle items in stack up one
    for ((i=$top;i<$SP;i+=1)); do

        let "next = $i + 1"
        stack[$i]=${stack[$next]}
    done

    let "SP -= 1"            # Bump down stack pointer.
    return
}


function kill_osd_cat() {

    logger_debug "kill_osd_cat"

    pid=$(/usr/bin/pgrep -P $$ osd_cat);
    if [[ -z "$pid" ]]; then
        return;
    fi

    logger_debug "osd_cat pid: $pid"

    res=$(/usr/bin/pkill -P $$ osd_cat > /dev/null)
}

function show_msg() {

    logger_debug "show_msg"

    export DISPLAY=:0
    echo "$1" | /usr/bin/osd_cat $options 2>/dev/nill &
}


trap kill_osd_cat SIGHUP SIGTERM SIGKILL SIGQUIT

# Create the OSD named pipe if it doesn't exist
tmpdir=$(tmp_dir)
pipe_dir="${tmpdir}/pipes"
osd_pipe="$pipe_dir/osd"

mkdir -p $pipe_dir
test -p $osd_pipe || mkfifo $osd_pipe

fork=0

args="$*"

while getopts "hf" options; do
  case $options in

    f ) fork=1;;
    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))


if [[ "$fork" -eq "1" ]]; then
    fork
fi

# Remove duplicate processes.
# pgrep only matches on first 15 characters without -f option
for pid in $(pgrep -f osd_daemon.sh); do
    # $$ is the current process id. Don't kill it!
    if [ "$pid" -eq "$$" ]; then
        continue;
    fi
    kill -9 $pid
done


LOG_TO_STDOUT=                          # Prevent logging to stdout

FONT="-adobe-helvetica-bold-r-*-*-24-*-*-*-*-*-*-*"
COLOUR='yellow'
POS='top'
OFFSET=100
DELAY=0
INDENT=10
OUTLINE=9
OUTLINECOLOUR='black'
SHADOW=0
SHADOWCOLOUR='black'

options=$(printf "%s  %s  %s  %s  %s  %s  %s  %s  %s  %s" "-f $FONT" "-c $COLOUR" "-p $POS" "-o $OFFSET" "-i $INDENT" "-d $DELAY" "-O $OUTLINE" "-u $OUTLINECOLOUR" "-S $SHADOW" "-s $SHADOWCOLOUR");


# Use a stack to store messages
declare -a stack

SP=0            #  Stack Pointer.
message=           #  Contents of stack location.

status='show'

while true; do

    event=$(cat $osd_pipe)

    case "$event" in

        __HIDE__)
                logger_debug "Hide event processed"
                kill_osd_cat
                status='hide'
                ;;

        __SHOW__)
                logger_debug "Show event processed"
                kill_osd_cat
                status='show'
                ;;

        __FORK__)
                logger_debug "Fork event processed"
                kill_osd_cat
                fork
                ;;

        __STOP__)
                logger_debug "Stop event processed"
                kill_osd_cat
                status='show'
                pop
                ;;

        __KILL__)
                logger_debug "Kill event processed"
                kill_osd_cat
                exit 0
                ;;

        *)
                # Assume a message for display, push on stack
                push "$event"
                ;;

    esac

    if [[ -z $message ]]; then
        pop
    fi

    if [[ "$status" == "show" ]]; then
        show_msg "$message"
    fi

done

exit;
