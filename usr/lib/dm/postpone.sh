#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_hold 2>/dev/null || source $DM_ROOT/lib/hold.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 [ -m mod_id ] <date option>

This script postpones a mod.

OPTIONS:
   -f      Force postpone. Ignore checks.
   -m      Id of mod
   -h      Print this help message.

EXAMPLES:

    $0 -m 12345 tomorrow
    $0 -m 23456 2008-09-12 11:30
    $0 next thursday
    $0 2 days

NOTES:

   If the -m options is not provided, the mod postponed is the current one,
   ie. one indicated in $DM_USERS/current_mod

   All arguments are passed along to the date command --date option
   and so must follow the appropriate syntax. See man date.

   Unless the force, -f, option is provided, the script exits with error
   message if the postpone date is in the past.
EOF
}

mod=$(< $DM_USERS/current_mod);
force=

while getopts "fhm:" options; do
  case $options in
    f ) force=1;;
    m ) mod=$OPTARG;;
    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;
  esac
done

shift $(($OPTIND - 1))

if [[ ! "$*" ]]; then
    _u
    exit 1
fi

if [ ! $mod ]; then
    echo 'ERROR: Unable to determine mod id.' >&2
    exit 1
fi

date=$(date "+%Y-%m-%d %H:%M:%S" --date="$*")
if [[ ! $date ]]; then
    exit 1
fi

if [[ ! $force ]]; then
    date_as_sec=$(date "+%s" --date="$*")
    now_as_sec=$(date "+%s")
    if [[ $date_as_sec -lt $now_as_sec ]]; then
        echo 'ERROR: Refusing to postpone mod to time in the past.' >&2
        exit 1
    fi
fi

# Take the mod off hold if it currently is on hold
$DM_BIN/take_off_hold.sh -f $mod

# Add a FIXME:Usage comment to hold file if not already done
__hold_has_usage_comment $mod || __hold_add_usage_comment $mod

__hold_crontab "$mod" "$date" >> $DM_MODS/$mod/hold

holds_dir="$DM_USERS/holds"
mkdir -p $holds_dir
cd $holds_dir
ln -f -s ../../../mods/$mod/hold  ./$mod
$DM_BIN/crontab.sh -r
echo "Mod $mod on hold until $date."
