#!/bin/bash

__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh
__loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh

source $DM_ROOT/test/test.sh

tmpdir=$(__tmp_dir)
test_dir="${tmpdir}/test"


#
# run_tests
#
# Sent: nothing
# Return: nothing
#
# Purpose:
#   Run some tests.
#
# Notes:
#
#   The tests ensure the script outputs the expected tree structure.
#   Testing the created mods is limited.
#
tst_run_tests() {
    label=()
    test=()
    expect=()
    local i=0


    rm "$DM_IDS" 2>/dev/null

    mkdir -p "${DM_IDS%/*}"

    cat <<EOT >> "$DM_IDS"
start_mod_id,end_mod_id,person_id
00001,00040,x1
00040,09999,3
10000,29999,1
30000,49999,2
50000,99949,0
99950,99999,4
EOT

    mkdir -p "$DM_USERS"
    echo "30000" > "$DM_USERS/mod_counter"

    mod_id=$("$DM_BIN/next_mod_id.sh")
    mod_id_2=$((mod_id + 1))
    mod_id_3=$((mod_id + 2))

    label[++i]="Single mod"
    test[$i]=$(cat <<EOT
[s] Test 001.
EOT
)

    expect[$i]=$(cat <<EOT
[ ] $mod_id Test 001.
EOT
)

    label[++i]="Multiple mods"
    test[$i]=$(cat <<EOT
[j] Test 001.
[m] Test 002.
[s] Test 003.
EOT
)

    expect[$i]=$(cat <<EOT
[ ] $mod_id Test 001.
[ ] $mod_id_2 Test 002.
[ ] $mod_id_3 Test 003.
EOT
)

    label[++i]="Mod dependency"
    test[$i]=$(cat <<EOT
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
        echo "30000" > "$DM_USERS/mod_counter"
        echo "${test[$i]}" > "$test_dir/create_mods.txt"
        got=$("$DM_BIN/create_mods.sh" "$test_dir/create_mods.txt" 2>/dev/null)
        if [[ $got == "${expect[$i]}" ]]; then
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
}

functions=$(awk '/^tst_/ {print $1}' $0)

[[ $1 ]] && functions="$*"

for function in  $functions; do
    function=${function%%(*}        # strip '()'
    if ! declare -f "$function" &>/dev/null; then
        __mi "Function not found: $function" >&2
        continue
    fi

    "$function"
done
