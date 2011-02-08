#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

usage() {

    cat << EOF

usage: cat specs | $0 [options]

This script will create file and directory-based mods within DM_ROOT for the
specs received through STDIN.

OPTIONS:

    -d      Debug mode. Dm system not affected.
    -t      Run tests.
    -v      Verbose.

    -h      Print this help message.

EXAMPLE:

    cat ~/tmp/spec.txt | $0         # Create mods from spec file
    echo "[JK] Blank mod" | $0      # Create a blank mod.


NOTES:

    If the -d debug option is provided, mods are created in a /tmp subdirectory,
    not in the dm system. The option is useful for testing.

    Specs should be of the form:

        <offset>[<initials>] <description>
        <notes>
        <offset>[<initials>] <description>
        <notes>
        <offset>[<initials>] <description>
        <notes>
        etc.

    After creating directories and files, the script will output this same schema
    with the ids that were used for the mods.  The output should follow the format
    of a depedency tree.

        <offset>[ ] <id> <description>
        <offset>[ ] <id> <description>
        <offset>[ ] <id> <description>
        etc.

    Any text in specs not following the above mod format is printed as
    is to stdout. This can include group start and end tags or comments.

    The script attempts to handle group start and end tags in a "least
    surprise" method, printing them as part of the dependency tree and
    assuming they are not part of a mod description. In some cases the
    text could be misinterpreted.

    Spec with project groups followed by the dependency tree outputted.

        group 001
        # Project: fix dm system
        <offset>[<initials>] <description>
        <notes>
        end

        group 001
        # Project: fix dm system
        <offset>[ ] <id> <description>
        end
EOF
}


#
# run_tests
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run some tests.
#
# Notes:
#
#   The tests ensure the script outputs the expected tree structure.
#   Testing the created mods is limited.
#
function run_tests {

    declare -a label
    declare -a test
    declare -a expect
    local i=0

    mod_id=$($DM_BIN/next_mod_id.sh -d)
    let mod_id_2="mod_id + 1"
    let mod_id_3="mod_id + 2"


    label[++i]="Single mod"
    test[$i]=$( cat <<EOT
[s] Test 001.
EOT
)

    expect[$i]=$( cat <<EOT
[ ] $mod_id Test 001.
EOT
)

    label[++i]="Multiple mods"
    test[$i]=$( cat <<EOT
[j] Test 001.
[m] Test 002.
[s] Test 003.
EOT
)

    expect[$i]=$( cat <<EOT
[ ] $mod_id Test 001.
[ ] $mod_id_2 Test 002.
[ ] $mod_id_3 Test 003.
EOT
)

    label[++i]="Mod dependency"
    test[$i]=$( cat <<EOT
[j] Test 001.
    [m] Test 002.
[s] Test 003.
EOT
)

    expect[$i]=$( cat <<EOT
[ ] $mod_id Test 001.
    [ ] $mod_id_2 Test 002.
[ ] $mod_id_3 Test 003.
EOT
)

    label[++i]="Mod with complex description"
    test[$i]=$( cat <<"EOT"
[s] Test 001.
This mod has a multiline description including non-alpha characters.
This is the second line.
[ ] bullet line no 1
[ ] bullet line no 2
/usr/include
P@$$W0RD$?
"I didn't", said Jane O'Brien and O'nickel.
`ls -l`
~!@#$%^&*()_+-=:''}{[]/.,``""\|
EOT
)

    expect[$i]=$( cat <<EOT
[ ] $mod_id Test 001.
EOT
)

    label[++i]="Spec without initials"
    test[$i]=$( cat <<EOT
[ ] Test 001.
This is a description.
EOT
)

    # Should leave mod unchanged.
    expect[$i]=$( cat <<EOT
[ ] Test 001.
This is a description.
EOT
)

    label[++i]="Single group"
    test[$i]=$( cat <<EOT
group 001
# Project description
[s] Test 002.
Description 002.
end
EOT
)

    expect[$i]=$( cat <<EOT
group 001
# Project description
[ ] $mod_id Test 002.
end
EOT
)

    label[++i]="Group within group"
    test[$i]=$( cat <<EOT
group 001
# Project description
[s] Test 001.
Description 001.
    group 002
    # Project 2 description
    [j] Test 002.
    Description 002
    end
end
EOT
)

    expect[$i]=$( cat <<EOT
group 001
# Project description
[ ] $mod_id Test 001.
    group 002
    # Project 2 description
    [ ] $mod_id_2 Test 002.
    end
end
EOT
)

    for i in ${!label[@]}; do
        echo -n "Test $i: ${label[$i]} ... "
        got=$(echo "${test[$i]}" | $DM_BIN/create_mods.sh -d 2>/dev/null)
        if [[ "$got" == "${expect[$i]}" ]]; then
            echo "ok"
        else
            echo "FAIL"
            echo "Expected: ------------------"
            echo "${expect[$i]}"
            echo "Got: -----------------------"
            echo "$got"
            echo ""
        fi
    done

    return
}


#
# scrub_who
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Return a scrubbed "who".
#
# Notes:
#
# Scrubbing includes:
#
#   * Replacing alias with initials
#   * Changing to uppercase.
#   * Validating initials in people file
#
function scrub_who {

    who=$1
    if [[ -z "$who" ]]; then
        [[ -n $verbose ]] && echo "scrub_who: no who provided."
        return
    fi

    aliases="$DM_ROOT/users/initial_aliases"
    from_alias=$(grep  "^${who}=" $aliases | head -1 | awk -F'=' '{print $2}')
    [[ -n "$from_alias" ]] && who=$from_alias

    who=$(echo "$who" | tr "[:lower:]" "[:upper:]")

    # Check if a user exists with those initials
    username=$(person_attribute username initials "$who")
    if [[ -z "$username" ]]; then
        return
    fi

    echo "$who"
    return
}


debug=
verbose=

while getopts "dhtv" options; do
  case $options in

    d ) debug=1;;
    t ) run_tests
        exit 0;;
    v ) verbose=1;;

    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

d_flag=
dm_root=$DM_ROOT
tmpdir=$(tmp_dir)
if [[ -n "$debug" ]]; then
    d_flag='-d'
    dm_root="${tmpdir}/create_mods"
    [[ ! -d $dm_root ]] && mkdir -p $dm_root
    echo "** Debug mode **" >&2
    echo "Dev system is not affected." >&2
    echo "Mods are created in $dm_root directory" >&2
fi

tree_file="${tmpdir}/create_mods_tree"
cp /dev/null $tree_file

if [[ ! -d $dm_root ]]; then
    echo "ERROR: DM root directory, $dm_root, does not exist. Refusing to create." >&2
    exit 1
fi

mod_dir=
re="^[ ]*\[([A-Za-z]+)\][ ]*(.+)[ ]*$"
saveIFS=$IFS
IFS=$'\n'
count=0
prev_notes=
while read line; do
    if [[ ! $line =~ $re ]]; then
        # Check for group start or end tag
        found=$(echo "$line" | awk '/^[ ]*(group [0-9]+|end$)/')
        if [[ -n "$found"  ]]; then
            echo $line >> $tree_file
            # A group tag signals the mod notes are done as well.
            mod_dir=
            continue
        fi
        if [[ -n "$mod_dir" ]]; then
            # If we have a mod_dir, we're processing a mod, we can
            # assume the text is from the mod notes
            echo "$line" >> ${mod_dir}/notes
        else
            # Print non-mod text to stdout as is.
            echo $line >> $tree_file
        fi
        continue
    fi

    if [[ -n "$prev_notes" ]]; then
        $DM_BIN/unindent.sh -i $prev_notes
    fi

    # Mod line: [JK] the description
    mod_id=$($DM_BIN/next_mod_id.sh $d_flag)
    if [[ "$?" != '0' || -z "$mod_id" ]]; then
        echo "ERROR: Unable to get mod id." >&2
        continue
    fi
    if [[ -n "$debug" ]]; then
        # In debug mod the mod_id won't increment. Simulate it.
        let mod_id="mod_id + count"
        let count++
    fi
    [[ -n $verbose ]] && echo "next_mod_id.sh returns: $mod_id"
    mod=$(printf %05d $mod_id)
    mod_dir="${dm_root}/mods/${mod}"
    [[ -d "$mod_dir" ]] && rm -r "$mod_dir"
    mkdir -p $mod_dir
    # Initialize notes file
    cp /dev/null ${mod_dir}/notes
    prev_notes="${mod_dir}/notes"
    who=${BASH_REMATCH[1]}
    description=${BASH_REMATCH[2]}
    scrubbed_who=$(scrub_who "$who")
    if [[ -z "$scrubbed_who" ]]; then
        scrubbed_who=$DM_PERSON_INITIALS
        echo -e "\nASSIGN TO $who\n" >> ${mod_dir}/notes
    fi
    echo "$scrubbed_who" > ${mod_dir}/who
    echo "$description" > ${mod_dir}/description
    [[ -n $verbose ]] && echo "Mod created: $mod_dir"
    [[ -n $verbose ]] && echo "Mod id: $mod, who: $scrubbed_who, description: $description"

    indent=${line%%[^ ]*}
    len=${#indent}
    if [[ $len -gt 0 ]]; then
        printf "%${len}s" " " >> $tree_file
    fi
    printf "[ ] %05d %s\n" "$mod" "$description" >> $tree_file
done
IFS=$saveIFS
if [[ -n "$prev_notes" ]]; then
    $DM_BIN/unindent.sh -i $prev_notes
fi
cat $tree_file

