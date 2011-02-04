#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

usage() {

    cat << EOF

usage: $0 tree_name

This script allows a user to edit a tree and create mods directly within
the tree.

OPTIONS:

    -d      Dry run. No changes are made to dm system data.
    -v      Verbose.

    -h      Print this help message.

EXAMPLE:

    $0 main                 # Edit the main tree.
    $0 reminders            # Edit your personal reminders tree.

EOF
}


dry_run=
verbose=

while getopts "dhv" options; do
  case $options in

    d ) dry_run=1;;
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

if [ $# -ne 1 ]; then
    usage
    exit 1
fi

tree=$($DM_BIN/tree.sh $1)
if [[ "$?" != "0" ]]; then
    # tree.sh will provide an error message
    exit 1
fi

[[ -n $verbose ]] && echo "Editing tree: $tree"

# The tmpfile is use to store new mod specs
tmpfile=$(tmp_file)

# Create temporary tree files within a directory structure similar to
# that used in the dm system. Replace the base $DM_ROOT directory with
# the tmpdir.
tmpdir=$(tmp_dir)
file=$(echo $tree | sed -e "s@^$DM_ROOT@$tmpdir@")
file_dir=$(dirname $file)
mkdir -p "$file_dir"
cp $tree $file

# Back up tree file so the original can be diff'd against.
file_bak=${file}.bak
cp -p $file $file_bak
[[ -n $verbose ]] && echo "Tree backup: $file_bak"

# Edit the tree file
/usr/bin/vim -c 'set ft=our_doc' $file

# Test if file was changed, if so save is required.
diff -q $file $file_bak > /dev/null
if [[ "$?" == "0" ]]; then
    echo "Quit without saving."
    exit 0
fi

# The string '---' is used as a delimiter later in the script. If the
# user happened to add that string to the tree file, it will cause foo,
# interpreting it as an delimiter where it wasn't intended. Append
# another hypen on the string so the foo doesn't happen.

sed -i -e 's/^---$/----/' $file

replace_dir="$file_dir/replace"
mkdir -p $replace_dir
split_dir="$file_dir/csplit"
mkdir -p $split_dir
cd $split_dir
rm $split_dir/*   2>&1 | grep -v 'No such file or directory'
rm $replace_dir/* 2>&1 | grep -v 'No such file or directory'

# Strategy: Phase I - Update existing mods
# In this phase, if the description of a existing mod is changed, update the
# mod description file.

# A breakdown of the next command.
# line 1: diff the edited file and the backup.
# line 2: Ignore any line not starting with '>'
# line 3: Get only output associated with existing mods.
# line 4: Strip leading space and box.
# lines 5-6: Extract the mod_id and description.
# lines 7-8: Determine the mod description file name.
# lines 9-16: Write the description to the descriptiion file.
diff $file_bak $file | \
    awk '{ if (/^> /) {print} }' | \
    awk --re-interval '{if (/[ ]*\[( |x)\] [0-9]{5}/) {print}}' | \
    sed 's/^>\s*\[[ x]\]\s*//g' | while read line; do
        mod_id=${line%% *}
        description=${line#* }
        mod_dir=$(mod_dir $mod_id)
        descr_file="${mod_dir}/description"
        if [[ -w "$descr_file" ]]; then
            [[ -n $verbose ]] && echo "Updating mod description: $mod_id $description"
            if [[ -z "$dry_run" ]]; then
                echo "$description" > $descr_file
            else
                echo "Dry run: mod not updated."
            fi
        fi
done

# Strategy: Phase II - Create new mods
# A diff of the edited tree file and it's backup will reveal the
# changes the user made. The changes are scrubbed and than split into
# sections delimited by '---', the same delimiter diff uses. The mod
# specs contained in the section files are then piped through
# create_mods.sh one by one to create mods from the text inserted into
# the tree file. The mod spec in the tree file is then replaced by the
# tree structured create_mods.sh produces using block_substitute.py.

# A breakdown of the next command.
# line 1: diff the edited file and the backup.
# line 2: Replace '> ---' with '> ----' so incidental dividers in the
#         mod text are not interpreted as a delimiter.
# line 3: Any line *not* starting with '> ' is ignored. This includes diff
#         overhead, eg line numbers, and diff text from the original
#         file.
# line 4: Any diff output related to existing mods can be ignored.
# line 5: Remove the '> ' from the text.
# line 6: Split into section files delimited on '---'

diff $file_bak $file | \
    awk '{ if ( /^> ---$/) {print "> ----"} else {print}}' | \
    awk '{ if (! /^> /) {print "---"} else {print} }' | \
    awk --re-interval '{if (/[ ]*\[( |x)\] [0-9]{5}/) {print "---" } else {print}}' | \
    sed -e 's/^> //' | \
    csplit -z -s - '/^---$/' {*}

[[ -n $verbose ]] && echo "New entries split out here: $split_dir"

d_flag=''
[[ -n "$dry_run" ]] && d_flag='-d'

file_new=${file}.new
cp -p $file $file_new
tmp=$(tmp_file)
for x in $(find ${split_dir} -maxdepth 1 -mindepth 1 -type f -name "xx*"); do
    base_x=$(basename "$x")
    [[ -n $verbose ]] && echo "Processing section: $x"
    # Remove the '---' delimiter on the first line.
    awk '{if(!/^---$/ || NR>1) {print} }' "$x" > $tmp && mv $tmp "$x"
    replace_file="$replace_dir/$base_x"
    [[ -n $verbose ]] && echo "Creating mods."
    cat "$x" | $DM_BIN/create_mods.sh $d_flag > $replace_file
    [[ -n $verbose ]] && echo "Replacing mod spec with checkbox in tree."
    [[ -n $verbose ]] && echo "$DM_BIN/block_substitute.py $file_new $x $replace_file"
    $DM_BIN/block_substitute.py $file_new $x $replace_file > $tmp && mv $tmp $file_new
done

[[ -n $verbose ]] && echo "Copy of updated tree: $file_new"

if [[ -z "$dry_run" ]]; then
    cp $file_new $tree
fi

# Validate schema in tree
[[ -n $verbose ]] && echo "Validating schema in tree."
val_tree=$tree
[[ -n "$dry_run" ]] && val_tree=$file_new
cat $val_tree | $DM_BIN/dependency_schema.pl $DM_ROOT
if [[ "$?" != "0" ]]; then
    echo "ERROR: The schema in the tree is not valid: $val_tree" >&2
    echo "Use this command to repeat schema validation check." >&2
    echo "cat $val_tree | $DM_BIN/dependency_schema.pl $DM_ROOT" >&2
    exit 1
fi

exit 0
