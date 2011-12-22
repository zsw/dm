#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

script=${0##*/}
_u() { cat << EOF
usage: $script [options] FILES...

This script attaches files to a mod.
    -m ID   Id of mod to attach file to.

    -h      Print this help message.

EXAMPLE:
    $script $DM_ROOT/files/advanced_bash.pdf        # Attach advanced_bash.pdf to the current mod
    $script $DM_ROOT/files/payroll/t4200.pdf        # Attach payroll/t4200.pdf to the current mod
    $script -m 12345 $DM_ROOT/files/xpdfrc.txt      # Attach xpdfrc.txt to mod 12345

NOTES:
    If the -m mod option is not provided the file is attached to the
    current mod, ie. the one indicated in $DM_USERS/current_mod

    Attachment file names must begin with the $DM_ROOT/files directory
    tree. If not, the attachment of that file will fail with an error
    message.

    The attached file does not need to exist.
EOF
}

_options() {
    # set defaults
    args=()
    mod=$(< "$DM_USERS/current_mod")

    while [[ $1 ]]; do
        case "$1" in
            -m) shift; mod=$1   ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} < 1 )) && { _u; exit 1; }
}

_options "$@"

dir=$(__mod_dir "$mod")
[[ ! $dir ]] && __me 'Unable to locate mod $mod in mods or archive directories.'

canonical_dm_root=$(readlink -f "$DM_ROOT")
[[ ! $canonical_dm_root ]] && __me 'Unable to determine canonical DM_ROOT. Aborting.'

dm_root=$(readlink -f "$DM_ROOT")
exit_status=0

for i in "${args[@]}"; do
    #
    # Strategy by example
    #
    #   file    = /var/git/dm/files/steve/.bash_dm
    #   to_dir  = /var/git/dm/mods/30226/files/steve/
    #
    #   Create the symlink as follow:
    #
    #   $ mkdir /var/git/dm/mods/30226/files/steve
    #   $ cd /var/git/dm/mods/30226/files/steve
    #   $ ln -snf ../../../../files/steve/.bash_dm .
    #

    # Translate symlinks.
    file=$(readlink -f "$i")

    # Determine the name of the file relative to DM_ROOT, ie, strip the
    # dm_root path from the file.
    rel_file=${file#${dm_root}/files/}
    if [[ $rel_file == $file ]]; then
        __mi "Attachment file must be in a subdirectory of DM_ROOT/files: $file" >&2
        exit_status=1
        continue
    fi

    # The path of attachment files should be the same within the mod.
    # Example
    #   file:              $DM_ROOT/files/path/to/attach.txt
    #   in mod: $DM_ROOT/mods/12345/files/path/to/attach.txt
    to_file="$dir/files/$rel_file"
    to_dir=${to_file%/*}            # Remove the file name
    [[ ! -d $to_dir ]] && mkdir -p "$to_dir"

    # Relative symlinks can be made only in the destination directory,
    # so cd to it.
    cd "$to_dir"

    # Create the ../ relative path.
    found=
    r=
    while true; do
        r="../$r"
        rl=$(readlink -f "$r")
        [[ $rl == / ]] && break     # Can't go any further
        [[ $rl == $dm_root ]] && { found=1; break; }
    done

    if [[ ! $found ]]; then
        __mi 'Destination does not appear to be a subdirectory of DM_ROOT. Link failed.' >&2
        exit_status=1
        continue
    fi

    from_file="${r}files/${rel_file}"
    # Intentionally not testing the existance of from_file, it doesn't
    # have to exist.

    # And finally make the link.
    ln -snf "$from_file" .

    (( $? != 0 )) && exit_status=1
done
exit $exit_status
