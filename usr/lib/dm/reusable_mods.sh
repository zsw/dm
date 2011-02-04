#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh

usage() {

    cat << EOF

usage: $0 [options]

This script outputs the ids reusable mods.

OPTIONS:
    -u  Limit mods to those assigned to this user.

    -h  Print this help message.

EXAMPLE:

    $0                  # Get all reusable mods.
    $0 -u jimk          # Get all reusable mods assigned to jimk.

NOTES:

    If the -u option is provided, then only mods assigned the person
    associated with the username are considered.

    If no reusable mod is available, the script prints nothing.

    A reusable mod has a description with the single case-sensitive
    word: REUSE
EOF
}

username=
while getopts "hu:" options; do
  case $options in
    u ) username=$OPTARG;;
    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

logger_debug "username: $username"

for mod in $(find $DM_ARCHIVE/ -name description -exec grep -l '^REUSE$' '{}' \; | xargs --replace dirname {} | $DM_BIN/format_mod.sh "%i" | sort);
do
    logger_debug "mod: $mod"
    if [[ -n $username ]]; then

        who=$(person_attribute username initials `attribute $mod 'who'`)
        logger_debug "who: $who"

        [[ "$who" != "$username" ]] && continue
    fi

    echo $mod
done
