#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
_loaded_hold 2>/dev/null || source $DM_ROOT/lib/hold.sh

script=${0##*/}
_u() {

    cat << EOF

usage: echo mod_id | $0  [format]
or     echo /path/to/mod/directory | $0 [format]

This script formats attributes of a mod suitable for printing.

OPTIONS:

    -t  Tree format. full=complete path,      eg /root/dm/trees/jimk/reminders
                     sub=include subdirectory,eg jimk/reminders
                     name=tree name only,     eg reminders (default)

    -h  Print this help message.

EXAMPLES:

    echo 12345 | $0
    echo \$DM_ROOT/mods/12345 | $0
    find \$DM_ROOT/ | filter_mods.pl | sort | $0

    # Example output

    12345  JK ---------- --:--:-- main  Do the thing whereby the problem is fixed.

NOTES:

    The format string controls the output.  Interpreted sequences are:

    %%   A literal %.
    %b   Box, [ ] if mod is live, [x] if mod is done
    %d   Contents of /description
    %h   Contents of /hold, or "---------- --:--:--" nothing in hold/.
    %i   The mod's id (scraped from the subdirectory name)
    %l   Location: mods or archive.
    %t   The dependency tree the mod belongs to.
    %w   Contents of /who (three initials, left-padded, empty if unassigned).

    The format will default to "%i %w %h %t %l %d" if unspecified.


    The -t tree format option can take the following values.

    Option  Description             Example

    name    Tree name only          reminders
    sub     Include subdirectory    jimk/reminders
    full    Complete path           /root/dm/trees/jimk/reminders

    If the option is not provided, the "name" format is used.

    When the "-t name" options is used, trees in the $DM_ROOT/trees/archive
    directory are prefixed with x_ to distinguish them from trees with the same
    name in the $DM_ROOT/trees directory. For example:

    tree                            name
    $DM_ROOT/trees/main             main
    $DM_ROOT/trees/archive/main     x_main
EOF
}

#
# tree_name
#
# Sent: tree file name
# Return: tree name
# Purpose:
#
#   Return the name of the tree for the given tree file name.
#
function tree_name {

    file=$1
    name=${file##*/}
    sub_name=${tree#$DM_TREES/}
    subdir=${sub_name%%/*}

    ## Add a prefix to distinguish trees in the archive directory
    if [[ "$subdir" == "archive" ]]; then
        name="x_$name"
    fi

    echo $name
}

tree_format='name'

while getopts "ht:" options; do
  case $options in

    t ) tree_format=$OPTARG;;

    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

if [[ "$#" -gt "1" ]]; then
    _u
    exit 1
fi

# Prevent this script from creating noise from logging. Check the log
# file LOG_TO_FILE for logs.
LOG_TO_STDOUT=
LOG_TO_STDERR=

format="%i %w %h %t %l %d"

[[ $1 ]] && format=$1

logger_debug "Format: $format"

oldIFS=$IFS
IFS=""  # Preserve spacing in printf output

while read mod
do
    if [[ ${mod:0:1} == '/' ]]; then
        mod_dir=$mod
    else
        mod_dir=$(mod_dir $mod)
    fi

    if [[ ! "$mod_dir" ]]; then
        echo "Unable to locate directory for mod $mod" >&2
        continue
    fi

    id=$(basename $mod)

    line=$format

    esc=$(echo -e "\e")         # Insignicant except that it's uncommon
    line=${line//\%\%/$esc}     # Hide %% so it's not interpreted

    line=${line//\%i/$id}

    if [[ $format == *%b* ]]; then
        box="[ ]"
        [[ "$mod_dir" == "$DM_ARCHIVE/$id" ]] && box="[x]"
        line=${line//\%b/$box}
    fi

    if [[ $format == *%d* ]]; then
        line=${line//\%d/$(cat $mod_dir/description)}
    fi

    if [[ $format == *%h* ]]; then
        hold='---------- --:--:--'
        if [[ -e "$mod_dir/hold" ]]; then
            hold=$(hold_timestamp $id)
            [[ ! $hold ]] && hold='---------- --:--:--'
        fi
        line=${line//\%h/$hold}
    fi

    if [[ $format == *%l* ]]; then
        location='????'
        [[ "$mod_dir" == "$DM_MODS/$id" ]]    && location='mods'
        [[ "$mod_dir" == "$DM_ARCHIVE/$id" ]] && location='arch'
        line=${line//\%l/$location}
    fi

    if [[ $format == *%t* ]]; then
        tree=$(grep -lsr "\[.\] $id" $DM_TREES/* | head -1 ) ;

        case $tree_format in

            full) size=30
                  ;;

            name) tree=$(tree_name "$tree")
                  size=9
                  ;;

            sub)  tree=${tree#$DM_TREES/}
                  size=20
                  ;;

            * ) echo "Invalid tree format." >&2
                _u
                exit 1;;
        esac

        line=${line//\%t/$(printf "%${size}.${size}s" $tree)}
    fi

    if [[ $format == *%w* ]]; then
        who=$(cat $mod_dir/who)
        line=${line//\%w/$(printf "%3s" $who)}
    fi

    line=${line//$esc/%}       # Show literal %

    echo $line

done

IFS=$oldIFS
