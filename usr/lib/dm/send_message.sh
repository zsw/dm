#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh
__loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh

script=${0##*/}
_u() { cat << EOF
usage: $script [options] email_address /path/to/mod

This script sends a message to the email address for a mod.
    -j  Send a jabber message instead of an email.

    -h  Print this help message.

EXAMPLES:
    $script username@gmail.com $HOME/dm/12345

NOTES:
    If the -j option is provided then the script attempts to use a weechat pipe
    to send message.
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
_by_weechat() {
    pid=$(pidof weechat-curses)
    [[ ! $pid ]] && __me "Reminder for mod $mod_dir aborted. Unable to get pid of weechat"

    fifo=$HOME/.weechat/weechat_fifo_$pid
    [[ ! -p $fifo ]] && __me "Reminder for mod $mod_dir aborted. Not a named pipe: $fifo"

    msg=$(< $mod_dir/description)

    echo "python.jabber.server.$account */jabber_echo_message $account dm $msg" > "$fifo"
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
_by_email() {
    subject=$(sed -e "s/\"/\\\\\"/" "$mod_dir/description")
    notes=$(sed -e "s/\"/\\\\\"/" "$mod_dir/notes")
    res=$(echo -e "To: $account\nSubject: $subject\n\n$notes" | sendmail -v -- "$account")
}

_options() {
    # set defaults
    args=()
    unset jabber

    while [[ $1 ]]; do
        case "$1" in
            -j) jabber=1        ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} != 2 )) && { _u; exit 1; }
    account=${args[0]}
    mod_dir=${args[1]}
}

_options "$@"

[[ ! -d $mod_dir ]] && __me "No such file or directory: $mod_dir"

[[ $jabber ]] && _by_weechat || _by_email
