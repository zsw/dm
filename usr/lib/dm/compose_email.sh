#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 [mod_id]

This script initiates an email compose with mutt, tagging the email with
a mod id.

OPTIONS:

   -h      Print this help message.

EXAMPLE:

    $0 12345

NOTES:

    If a mod id is not provided the current one is used, ie. the one
    indicated in $DM_USERS/current_mod

EOF
}


function header {

cat << EOT
To:
Subject:
EOT
}

while getopts "h" options; do
  case $options in

    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

# Get the id of the mod.
mod_id=

if [ $# -gt 1 ]; then
    _u
    exit 1
fi

if [ $# -eq 1 ]; then
    mod_id=$1;
else
    mod_id=$(< $DM_USERS/current_mod);
fi

if [ ! $mod_id ]; then

    echo 'ERROR: Unable to determine current mod id.' >&2
    exit 1
fi

file=$(tmp_file)

header > $file
echo "X-DM-Mod-Id: $mod_id" >> $file

mutt -H $file
