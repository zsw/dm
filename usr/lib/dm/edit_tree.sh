#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() { cat << EOF
usage: $script tree_name

This script allows a user to edit a tree and create mods directly within
the tree.
    -v      Verbose.

    -h      Print this help message.

EXAMPLE:
    $script main                 # Edit the main tree.
    $script reminders            # Edit your personal reminders tree.
EOF
}

_options() {
    # set defaults
    args=()
    unset verbose

    while [[ $1 ]]; do
        case "$1" in
            -v) verbose=true    ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} != 1 )) && { _u; exit 1; }
    tree_name=${args[0]}
}

_options "$@"

tree=$("$DM_BIN/tree.sh" "$tree_name")
[[ ! $tree ]] && exit 1

__mi "Editing tree: $tree"

# The tmpfile is use to store new mod specs
tmpfile=$(__tmp_file)

# Create temporary tree files within a directory structure similar to
# that used in the dm system. Replace the base $DM_ROOT directory with
# the tmpdir.
tmpdir=$(__tmp_dir)
file=${tree/$DM_ROOT/$tmpdir}
file_dir=${file%/*}
mkdir -p "$file_dir"
cp "$tree" "$file"

# Back up tree file so the original can be diff'd against.
file_bak=${file}.bak
cp -p "$file" "$file_bak"
__mi "Tree backup: $file_bak"

# Edit the tree file
vim "$file"

# Test if file was changed, if so save is required.
diff -q "$file" "${file}.bak" >/dev/null && __me "Quit without saving."

# The string '---' is used as a delimiter later in the script. If the
# user happened to add that string to the tree file, it will cause foo,
# interpreting it as an delimiter where it wasn't intended. Append
# another hypen on the string so the foo doesn't happen.

sed -i -e 's/^---$/----/' "$file"

replace_dir=$file_dir/replace
[[ $replace_dir =~ ^/tmp ]] && rm -r "$replace_dir" &>/dev/null
mkdir -p "$replace_dir"

split_dir=$file_dir/csplit
[[ $split_dir =~ ^/tmp ]] && rm -r "$split_dir" &>/dev/null
mkdir -p "$split_dir"

cd "$split_dir"

# Strategy: Phase I - Update existing mods
# In this phase, if the description of a existing mod is changed, update the
# mod description file.

# A breakdown of the awk in the next command.
#   --re-interval: Required to use {5} syntax
#   /^> /        : Ignore any line not starting with '>'
#   /[ ]...{5}/  : Get only output associated with existing mods. Eg [x] 12345
while read -r line; do
    # Example line='12345 This is the mod description'
    mod_id=${line%% *}
    description=${line#* }
    mod_dir=$(__mod_dir "$mod_id")
    descr_file=$mod_dir/description
    [[ ! -w $descr_file ]] && continue
    __mi "Updating mod description: $mod_id $description"
    echo "$description" > "$descr_file"
done < <(diff "$file_bak" "$file" | \
        awk --re-interval '
            /^> / &&
            /[ ]*\[( |x)\] [0-9]{5}/ {
                sub(/>[ \t]+\[[x ]\][ \t]+/, ""); print
            }')

# Strategy: Phase II - Create new mods
# A diff of the edited tree file and it's backup will reveal the
# changes the user made. The changes are scrubbed and than split into
# sections delimited by '---', the same delimiter diff uses. The mod
# specs contained in the section files are then piped through
# create_mods.sh one by one to create mods from the text inserted into
# the tree file. The mod spec in the tree file is then replaced by the
# tree structured create_mods.sh produces using block_substitute.py.

# A breakdown of the awk in the next command.
#   --re-interval: Required to use {5} syntax
#  /> ---/       : Replace '> ---' with '----' so incidental dividers in the
#  !/> /         : Any line *not* starting with '> ' is ignored. This includes
#                  diff overhead, eg line numbers, and diff text from the
#                  original file.
#   /[ ]...{5}/  : Any diff output related to existing mods can be ignored.
#   {sub...}     : Remove the leading '> '
diff "$file_bak" "$file" | \
    awk --re-interval '
         /> ---/                  {print "----";next}
        !/> /                     {print "---";next}
         /[ ]*\[( |x)\] [0-9]{5}/ {print "---";next}
                                  {sub(/^>[ \t]/, "")};{print}' | \
    csplit -z -s - '/^---$/' {*}

__mi "New entries split out here: $split_dir"

file_new=${file}.new
cp -p "$file" "$file_new"
tmp=$(__tmp_file)
cd "$split_dir"
for base_file in *; do
    file=$split_dir/$base_file
    __mi "Processing section: $file"
    # Remove the '---' delimiter on the first line.
    awk '/^---$/ && NR==1 {next;} {print}' "$file" > "$tmp" && mv "$tmp" "$file"
    [[ ! -s $file ]] && continue
    replace_file=$replace_dir/$base_file
    __mi "Creating mods."
    "$DM_BIN/create_mods.sh" "$file" > "$replace_file"
    __mi "Replacing mod spec with checkbox in tree."
    __mi "$DM_BIN/block_substitute.py $file_new $file $replace_file"
    "$DM_BIN/block_substitute.py" "$file_new" "$file" "$replace_file" > "$tmp" && mv "$tmp" "$file_new"
done

__mi "Copy of updated tree: $file_new"

cp "$file_new" "$tree"

# Validate schema in tree
__mi "Validating schema in tree."
if ! { cat "$tree" | "$DM_BIN/dependency_schema.pl" "$DM_ROOT"; }; then
    __me "The schema in the tree is not valid: $tree\n===> ERROR: Use this command to repeat schema validation check\n===> ERROR: cat $tree | $DM_BIN/dependency_schema.pl $DM_ROOT"
fi
