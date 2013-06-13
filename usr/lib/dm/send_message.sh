#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

script=${0##*/}
_u() { cat << EOF
usage: $script [options] email_address /path/to/mod

This script sends a message to the email address for a mod.
    -j  Send a jabber message instead of an email.
    -f  Wrote mod id to a file

    -h  Print this help message.

EXAMPLES:
    $script username@domain.com $HOME/dm/12345

NOTES:
    If the -j option is provided then the script attempts to use a weechat pipe
    to send message.
EOF
}


#
# by_email
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Send message by email
#
_by_email() {
    local subject

    subject=$(< "$mod_dir/description")
    subject=${subject//\"/\\\"}

    cat "$mod_dir"/spec{,s} 2>/dev/null | mail -s "$subject" "$account" >/dev/null
}

#
# by_file
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Write mod id to a file
#
_by_file() {
    local mod_id

    mod_id=${mod_dir##*/}
    [[ ! $mod_id ]] && __me "No mod_id found for directory: $mod_dir"
    echo "$mod_id" >> "$DM_NOTIFY_FILE"
}

#
# by_weechat
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Send message by weechat
#
_by_weechat() {
    local pid fifo msg

    pid=$(pidof weechat-curses)
    [[ ! $pid ]] && __me "Reminder for mod $mod_dir aborted. Unable to get pid of weechat"

    fifo=$HOME/.weechat/weechat_fifo_$pid
    [[ ! -p $fifo ]] && __me "Reminder for mod $mod_dir aborted. Not a named pipe: $fifo"

    msg=$(< $mod_dir/description)
    echo "python.jabber.server.$account */jabber_echo_message $account dm $msg" > "$fifo"
}


_options() {
    args=()
    unset jabber

    while [[ $1 ]]; do
        case "$1" in
            -f) file=1          ;;
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

if [[ $jabber ]]; then
    _by_weechat
elif [[ $file ]]; then
    _by_file
else
    _by_email
fi
