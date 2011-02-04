#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

usage() {

    cat << EOF

usage: $0 [OPTIONS]

This script permits editing and updating the crontab.

OPTIONS:

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
    \$HOME/dm/var/holds/* files into one, and replacing the existing
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

HOLD_HEADER="
#
# DM system hold crontabs
#
"

# Save cli arguments, they may be passed on to /usr/bin/crontab
args=$@

editing=
reloading=
user=

while [[ -n "$1" ]]; do

    case "$1" in
      -e) editing=1
          reloading=1;;
      -r) reloading=1;;
      -u) user=1;;
      -h) usage
          exit 0;;
    esac
    shift
done

if [[ -n $user && -n $editing ]] || [[ -n $user && -n $reloading ]]; then
    echo "ERROR: crontab.sh does not handle -u option." >&2
    echo "Login as user to update their cron." >&2
    exit 1
fi

if [[ -n $editing ]]; then
    /usr/bin/vim -c 'set ft=crontab' $HOME/.crontab
fi

if [[ -n $reloading ]]; then
    tmpfile=$(tmp_file)
    cp $HOME/.crontab $tmpfile
    echo "$HOLD_HEADER" >> $tmpfile
    grep -h -v '^#' $DM_ROOT/var/holds/* | sort -n -k 4 -k 3 -k 2 -k 1  >> $tmpfile
    /usr/bin/crontab $tmpfile
fi

if [[ -z $editing && -z $reloading ]]; then
    echo "/usr/bin/crontab $args"
    /usr/bin/crontab "$args"
fi
