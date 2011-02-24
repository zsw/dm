#!/bin/bash

# FIXME
# The run_tests function was originally in ~/dm/bin/create_mods.sh. This needs
# formatting/testing.

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
_run_tests() {
    label=()
    test=()
    expect=()
    local i=0

    mod_id=$("$DM_BIN/next_mod_id.sh" -d)
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

