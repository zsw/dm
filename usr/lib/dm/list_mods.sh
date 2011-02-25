#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 options

This script lists mods.

OPTIONS:

    -h  Print this help message.

EOF

    key_bindings
}

key_bindings() {

    cat << EOF
KEYBINDINGS
? - help
h - toggle hold status: all, on hold, off hold
m - toggle mod type: all, only mods, only archive
q - quit
r - reverse sort order
t - toggle trees: all, main, reminders, tools, now, personal)
v - vim - open list in vim
w - toggle who: all, only yourself
<, > - Sort by column on the right, left
EOF
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

ALL=0
ONLY=1
NONE=2

list_file="/tmp/list.txt"
if [[ ! -e $list_file ]]; then
    stale=1
else
    stale=$(find /tmp/list.txt -mtime +0)       # Stale if file is 24 hours old.
fi
[[ $stale ]] && find $DM_MODS $DM_ARCHIVE | $DM_BIN/filter_mod.pl | $DM_BIN/format_mod.sh | sort > "$list_file"
work_file1=$(__tmp_file)
work_file2=$(__tmp_file)


declare -a mod_options=('all' 'mods' 'archive')
declare -a hold_options=('all' 'off hold' 'on hold')
declare -a who_options=('all' $DM_PERSON_INITIALS)
declare -a reverse_options=('' 'r')
declare -a tree_options     # The tree options vary based on filterd data


mod=$ONLY
hold=$ALL
tree=$ALL
who=$ONLY

cmd=
print_help=
reverse=0
sort_key=1
sort_cols=7
default_sort='2'

#       10514  JK ---------- --:--:--  personal mods Access dtjimk from Listowel
header="id    who hold date   time         tree type description"


while : ; do
    cp $list_file $work_file1
    match=
    [[ $mod == "$ONLY" ]] && match='mods'
    [[ $mod == "$NONE" ]] && match='arch'

    if [[ $match ]]; then
        cat $work_file1 | awk -v m=$match '$6 ~ m' > $work_file2
        cp $work_file2 $work_file1
    fi

    if [[ $who != "$ALL" ]]; then
        cat $work_file1 | awk -v i=$DM_PERSON_INITIALS '$2 ~ i' > $work_file2
        cp $work_file2 $work_file1
    fi

    match=
    [[ $hold == "$ONLY" ]] && match='[0-9]'
    [[ $hold == "$NONE" ]] && match='-----'

    if [[ $match ]]; then
        cat $work_file1 | awk -v m=$match '$3 ~ m' > $work_file2
        cp $work_file2 $work_file1
    fi

    # Set up an array of tree names found in work_file1.
    # Determine the tree options prior to filtering by the tree option.
    tree_options=($(echo 'all' && cat $work_file1 | awk '{print $5}' | sort | uniq))

    if [[ $tree != "$ALL" ]]; then
        cat $work_file1 | awk -v t=${tree_options[$tree]} '$5 ~ t' > $work_file2
        cp $work_file2 $work_file1
    fi


    if [[ $sort_key -gt $sort_cols ]]; then
        sort_key=1
    fi
    if [[ $sort_key -lt 1 ]]; then
        sort_key=$sort_cols
    fi

    echo "$header"

    r=${reverse_options[$reverse]}
    # It isn't necessary to capture results of next command, but the "case" in
    # the command seems to fark with vim syntax highlighting otherwise.
    x=$(cat $work_file1 | sort --ignore-case --key="${sort_key}${r}")
    echo "$x"

    if [[ $print_help ]]; then
        _u
        print_help=
    fi

    if [[ $cmd ]]; then
        eval $cmd
        cmd=
    fi

    printf "mods: %s  hold: %s  who: %s  tree: %s sort %s reverse %s\n"\
        "${mod_options[$mod]}" \
        "${hold_options[$hold]}" \
        "${who_options[$who]}" \
        "${tree_options[$tree]}" \
        "${sort_key}" \
        "${reverse_options[$reverse]}" \

    read -n 1 -p "Select h/m/q/r/t/v/w/</>/?: " code

    case $code in
        \<) sort_key=$(echo "($sort_key - 1)" | bc);;
        \>) sort_key=$(echo "($sort_key + 1)" | bc);;
        \?) print_help=1;;
         h) hold=$(echo "($hold + 1) % ${#hold_options[@]}" | bc);;
         m) mod=$(echo "($mod + 1) % ${#mod_options[@]}" | bc);;
         q) echo "" && break;;
         r) reverse=$(echo "($reverse + 1) % ${#reverse_options[@]}" | bc);;
         t) tree=$(echo "($tree + 1) % ${#tree_options[@]}" | bc);;
         v) cmd="vim $work_file1";;
         w) who=$(echo "($who + 1) % ${#who_options[@]}" | bc);;
         *) ;;
    esac
done
