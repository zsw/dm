#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_files 2>/dev/null || source $DM_ROOT/lib/files.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

usage() {

    cat << EOF

    usage: $0 file mod_id

This script dissembles a file  and writes the content to mod directory files.

OPTIONS:

   -h      Print this help message.

EXAMPLE:

    $0 /tmp/fil.txt 12345

NOTES:

    Intended to be used on files created by assemble_mod.sh.

    The assemble script adds some space lines to make the content
    easier to work with. This script removes those space lines.

    If an attribute file already exists, it will be overwritten.
    If attribute file does not exist it will be created.
EOF
}


while getopts "h" options; do
  case $options in

    h ) usage
        exit 0;;
    \?) usage
        exit 1;;
    * ) usage
        exit 1;;

  esac
done

shift $(($OPTIND - 1))


if [ $# -ne 2 ]; then

    echo "Usage: $0 dev_id" >&2
    exit 1;
fi

if [[ -z "$DM_MODS" ]]; then
    echo "DM_MODS not defined. Aborting." >&2
    exit 1;
fi

assemble_file=$1
mod_id=$2
mod_dir=$(mod_dir $mod_id)

mkdir -p $mod_dir

# Remove existing mod attributes and attachment symlinks so files
# associated with sections removed from mod file will be removed in mod
# directory. The test on mod_dir is a precaution since the next command
# does a rm -rf.

if [[ -z "$mod_dir" ]]; then
    echo "mod_dir not defined. Aborting." >&2
    exit 1;
fi

rm -rf $mod_dir
mkdir -p $mod_dir

tmpdir=$(tmp_dir)
split_dir="$tmpdir/dissemble/csplit"
mkdir -p $split_dir
rm -f $split_dir/*

cd $split_dir

csplit -s $assemble_file '/^--------------------------------------------- .* ---$/' {*}

for file in *; do

    # csplit may create empty files. Remove them.

    size=$(du $file | awk '{ print $1}')
    if [[ $size -eq 0 ]]; then
        rm $file
        continue
    fi

    name=$(grep  '^--------------------------------------------- .* ---$' $file | awk '{print $2}')

    # If we can't determine the section name, we're screwed.

    if [[ -z $name ]]; then
        echo "No section name found in $split_dir/$file" >&2
        continue
    fi


    # Delete the section line
    sed -i -e '/^--------------------------------------------- .* ---$/d' $file

    ## Delete the # }}} fold indicator on last line of file
    grep -qE '# }}}' <(tail -1 "$file") && sed -i '$d' "$file"

    # Delete all leading blank lines at top of file
    sed -i '/./,$!d' $file

    # Delete all trailing blank lines at end of file
    sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' $file

    section=$(section_name $name)

    new_file=$(filename_from_section $mod_id $name)


    echo $section | grep -q "^files/"

    if [[ "$?" -ne "0" ]]; then

        # Mod attributes are saved as is
        mv $file "$new_file"

    else
        # Attachments are saved in DM_FILES and symlinked to the mods
        # directory.

        $DM_BIN/attach.sh -m "$mod_id"  "$DM_ROOT/$section"

        # For non-text files, leave it up to the user to cp the file to
        # DM_FILES. For text files, cp the content of the section.

        text=$(is_text $file)

        logger_debug "Section: $section, text: $text, path: $path"

        if [[ -n "$text" ]]; then

            # If the section file is empty, the user could be linking to
            # an existing file created in another mod, say. Best not to
            # overwrite an existing file.

            size=$(du $file | awk '{ print $1}')
            if [[ $size -gt 0 ]]; then
                mv $file "$DM_ROOT/$section"
            fi
        fi

        # Warn the user if the symlink points to an non-existent file.
        # This will remind them to cp the attachment to the correct
        # directory.

        ! test -f $DM_ROOT/$section && echo "WARNING: Linking to non existent file $DM_ROOT/$section" >&2
    fi

done
