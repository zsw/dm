#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_files 2>/dev/null || source $DM_ROOT/lib/files.sh
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##/}
_u() { cat << EOF
usage: $script file mod_id

This script dissembles a file  and writes the content to mod directory
files.

   -h      Print this help message.

EXAMPLE:
    $0 /tmp/file.txt 12345

NOTES:
    Intended to be used on files created by assemble_mod.sh.

    The assemble script adds some space lines to make the content
    easier to work with. This script removes those space lines.

    If an attribute file already exists, it will be overwritten.
    If attribute file does not exist it will be created.
EOF
}

#
# _filename_from_section
#
# Sent: mod          - eg 12345
#       section name - eg 'who', 'files/attachment.txt'
# Return: filename - eg '/root/dm/mods/12345/who' '/root/dm/mods/12345/files/attachment.txt'
# Purpose:
#
#   Return the full file name the section should be associated with.
#
_filename_from_section() {

    local mod mod_dir section
    mod=$1
    section=$2

    [[ ! $mod ]] && return
    [[ ! $section ]] && return

    mod_dir=$(mod_dir "$mod")

    echo "$mod_dir/$section"
}

#
# _section_name
#
# Sent: section name
# Return: section name
# Purpose:
#
#   Return a properly formatted section name.
#
_section_name() {

    local attachment attr section
    section=$1

    [[ ! $section ]] && return

    attachment=$(grep -o "^files/" <<< "$section")

    attr=$(grep -v "/" <<< "$section")

    # If the section is not a attribute or attachment then it's foo
    # We're going to assume it's an attachment and configure it as so.
    # Prepend the section with files.
    [[ ! $attachment && ! $attr ]] && section="files/$section"

    echo "$section"
}

_options() {
    # set defaults
    args=()

    while [[ $1 ]]; do
        case "$1" in
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} != 2 )) && { _u; exit 1; }
    assemble_file=${args[0]}
    mod_id=${args[1]}
}

_options "$@"


# Remove existing mod attributes and attachment symlinks so files
# associated with sections removed from mod file will be removed in mod
# directory. The test on mod_dir is a precaution since the next command
# does a rm -r.

mod_dir=$(mod_dir "$mod_id")
[[ ! $mod_dir ]] && __me "mod_dir not defined. Aborting."
[[ $mod_dir =~ /(mods|archive)/ ]] && rm -r "$mod_dir" &>/dev/null
mkdir -p "$mod_dir"

tmpdir=$(tmp_dir)
split_dir=$tmpdir/dissemble/csplit
mkdir -p "$split_dir"
rm -f "$split_dir"/*

cd "$split_dir"

csplit -s "$assemble_file" '/^--------------------------------------------- .* ---$/' {*}

for file in *; do
    # csplit may create empty files. Ignore them.
    [[ ! -s $file ]] && continue

    name=$(awk '/^--------------------------------------------- .* ---$/ {print $2}' "$file")

    # If we can't determine the section name, we're screwed.
    [[ ! $name ]] && { __mi "No section name found in $split_dir/$file"; continue; }
    section=$(_section_name "$name")
    new_file=$(_filename_from_section "$mod_id" "$name")

    # Line 1: Delete the section line
    # Line 2: Delete all leading blank lines at top of file
    # Line 3: Delete all trailing blank lines at end of file
    sed -i -e '/^--------------------------------------------- .* ---$/d' \
           -e '/./,$!d' \
           -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$file"

    if ! grep -qE '^files/' <<< "$section"; then
        # Mod attributes are saved as is
        mv "$file" "$new_file"

    else
        # Attachments are saved in DM_FILES and symlinked to the mods
        # directory.
        "$DM_BIN/attach.sh" -m "$mod_id" "$DM_ROOT/$section"

        # For non-text files, leave it up to the user to cp the file to
        # DM_FILES. For text files, cp the content of the section.

        # Copy the attachment file to the attachment directory. Use caution. If
        # after removing the divider, blank lines, etc, the section file is now
        # empty, the user could be linking to an existing file created in
        # another mod, say. Best not to overwrite it. Only copy if the size is
        # non-zero.
        [[ -s $file ]] && __is_text "$file" && mv "$file" "$DM_ROOT/$section"

        # Warn the user if the symlink points to an non-existent file.
        # This will remind them to cp the attachment to the correct
        # directory.
        [[ ! -f $DM_ROOT/$section ]] && __mi "WARNING: Linking to non existent file $DM_ROOT/$section"
    fi
done
