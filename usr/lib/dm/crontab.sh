#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() { cat << EOF

usage: $script [OPTIONS]

This script permits editing and updating the crontab.
    -e  Edit crontab.
    -r  Reload (update) crontab.

    -h  Print this help message.

    * All other options are passed to /usr/bin/crontab

NOTES:
    The script is intended to be used in place of the crontab command

    If the -e option is provided, the \$HOME/.crontab file is edited and
    the crontab is reloaded.

    If the -r option is provided, the crontab is reloaded. Reloading the
    crontab implies combining the \$HOME/.crontab file and the
    \$DM_USERS/holds/* files into one, and replacing the existing
    crontab with that file.

    If reloading with either the -e or -r options, the effective userid's
    crontab is updated.

    If either -e or -r options are provided all other options are
    ignored with one exception. If the -u option is provided as well,
    since the script doesn't honour the -u option, the effective
    userid's crontab is updated, it exits with an error.

    If neither the -e nor -r options are provided, all options and cli
    parameterss are passed on to /usr/bin/crontab.
EOF
}

HOLD_HEADER='
#
# DM system hold crontabs
#
'

_options() {
    # set defaults
    args=()
    unset editing
    unset reloading
    unset user

    while [[ $1 ]]; do
        case "$1" in
            -e) editing=1 reloading=1 ;;
            -r) reloading=1     ;;
            -u) user=1          ;;
            -h) _u; exit 0      ;;
#            -*) _u; exit 0      ;; Options like -l are passed on to the /usr/bin/crontab command.
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done
}

_options "$@"

if [[ $user && -n $editing ]] || [[ $user && -n $reloading ]]; then
    __me "crontab.sh does not handle -u option.
        Login as user to update their cron."
fi

if [[ $editing ]]; then
    /usr/bin/vim -c 'set ft=crontab' "$HOME/.crontab"
fi

if [[ $reloading ]]; then
    tmpfile=$(__tmp_file)
    cp "$HOME/.crontab" "$tmpfile"
    echo "$HOLD_HEADER" >> "$tmpfile"
    grep -h -v '^#' "$DM_USERS"/holds/* | sort -n -k 4 -k 3 -k 2 -k 1  >> "$tmpfile"
    /usr/bin/crontab "$tmpfile"
fi

if [[ ! $editing && ! $reloading ]]; then
    echo "/usr/bin/crontab $args"
    /usr/bin/crontab "$args"
fi
