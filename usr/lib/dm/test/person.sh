#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

#
# Test script for lib/person.sh functions.
#
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

source $DM_ROOT/test/test.sh
_loaded_person 2>/dev/null || source $DM_ROOT/lib/person.sh

tmpdir=$(tmp_dir)
test_dir="${tmpdir}/test"

#
# tst_person_attribute
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on person_attribute function.
#
function tst_person_attribute {

    DM_PEOPLE="${test_dir}/people"

    rm $DM_PEOPLE 2>/dev/null

    value=$(person_attribute)
    tst "$value" '' 'no people file returns nothing'

    mkdir -p `dirname $DM_PEOPLE`

    cat <<EOT >> $DM_PEOPLE
id,initials,username, name
1, ABC, aabbcc, Aaa Cccccc
2,  DE, ddee,   Dddd Eeeeeeee
3, FGH, ffgghh, Fffff Gggggggggg
EOT

    value=$(person_attribute)
    tst "$value" '' '[ ] attribute [ ] key [ ] value returns nothing'

    value=$(person_attribute initials)
    tst "$value" '' '[x] attribute [ ] key [ ] value returns nothing'

    value=$(person_attribute initials id)
    tst "$value" '' '[x] attribute [x] key [ ] value returns nothing'

    value=$(person_attribute initials id 1)
    tst "$value" 'ABC' '[x] attribute [x] key [x] value returns value 1'

    value=$(person_attribute initials id 2)
    tst "$value" 'DE' '[x] attribute [x] key [x] value returns value 2'

    value=$(person_attribute initials id 3)
    tst "$value" 'FGH' '[x] attribute [x] key [x] value returns value 3'

    value=$(person_attribute xxx id 3)
    tst "$value" '' 'invalid attribute returns nothing'

    value=$(person_attribute initials xxx 3)
    tst "$value" '' 'invalid key returns nothing'

    value=$(person_attribute initials id 999)
    tst "$value" '' 'non-existent key value returns nothing'

    value=$(person_attribute id id 2)
    tst "$value" '2' 'key id, returns correct id'

    value=$(person_attribute username id 2)
    tst "$value" 'ddee' 'key id, returns correct username'

    value=$(person_attribute name id 2)
    tst "$value" 'Dddd Eeeeeeee' 'key id, returns correct name'

    value=$(person_attribute id initials DE)
    tst "$value" '2' 'key initials, returns correct id'

    value=$(person_attribute initials initials DE)
    tst "$value" 'DE' 'key initials, returns correct initials'

    value=$(person_attribute username initials DE)
    tst "$value" 'ddee' 'key initials, returns correct username'

    value=$(person_attribute name initials DE)
    tst "$value" 'Dddd Eeeeeeee' 'key initials, returns correct name'

    value=$(person_attribute id name "Dddd Eeeeeeee")
    tst "$value" '2' 'key name, returns correct id'
}


#
# tst_person_translate_who
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Run tests on person_translate_who function.
#
function tst_person_translate_who {

    DM_PEOPLE="${test_dir}/people"

    rm $DM_PEOPLE 2>/dev/null

    value=$(person_attribute)
    tst "$value" '' 'no people file returns nothing'

    mkdir -p `dirname $DM_PEOPLE`

    cat <<EOT >> $DM_PEOPLE
id,initials,username, name
1, ABC, aabbcc, Aaa Cccccc
2,  DE, ddee,   Dddd Eeeeeeee
3, FGH, ffgghh, Fffff Gggggggggg
4, IJK, iijjkk, Iiiii Kkkkkkkkkk
EOT

    value=$(person_translate_who)
    tst "$value" '' 'no who returns nothing'

    value=$(person_translate_who FGH)
    tst "$value" 'FGH' 'initials returns correct initials'

    value=$(person_translate_who ddee)
    tst "$value" 'DE' 'username returns correct initials'

    value=$(person_translate_who 4)
    tst "$value" 'IJK' 'id returns correct initials'

    value=$(person_translate_who fake_user)
    tst "$value" '' 'non-existent user returns nothing'
}


functions=$(cat $0 | grep '^function ' | awk '{ print $2}')

[[ -n "$1" ]] && functions="$*"

for function in  $functions; do
    if [[ ! $(declare -f $function) ]]; then
        echo "Function not found: $function"
        continue
    fi

    $function
done
