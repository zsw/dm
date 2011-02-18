#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh
_loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh

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

#    pid=$(pidof weechat-curses)
    pid=31024
#    [[ ! $pid ]] && __me "Reminder for mod $mod_dir aborted. Unable to get pid of weechat"

    fifo=$HOME/.weechat/weechat_fifo_$pid
#    [[ ! -p $fifo ]] && __me "Reminder for mod $mod_dir aborted. Not a named pipe: $fifo"

    msg=$(< $mod_dir/description)

    echo "$account */jmsg $DM_PERSON_USERNAME $msg" > "$fifo"
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

    subject=$(cat $mod_dir/description | sed -e "s/\"/\\\\\"/" )
    notes=$(cat $mod_dir/notes | sed -e "s/\"/\\\\\"/" )

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

[[ $jabber ]] && _by_weechat || _by_email
