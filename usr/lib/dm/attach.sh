#!/bin/bash
_loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

_loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

source $DM_ROOT/lib/attributes.sh

usage() {

    cat << EOF

usage: $0 [options] FILES...

This script attaches files to a mod.

OPTIONS:

    -m ID   Id of mod to attach file to.
    -v      Verbose.

    -h      Print this help message.

EXAMPLE:

    $0 $DM_ROOT/files/advanced_bash.pdf        # Attach advanced_bash.pdf to the current mod
    $0 $DM_ROOT/files/payroll/t4200.pdf        # Attach payroll/t4200.pdf to the current mod
    $0 -m 12345 $DM_ROOT/files/xpdfrc.txt      # Attach xpdfrc.txt to mod 12345

NOTES:

    If the -m mod option is not provided the file is attached to the
    current mod, ie. the one indicated in $HOME/.dm/mod

    Attachment file names must begin with the $DM_ROOT/files directory
    tree. If not, the attachment of that file will fail with an error
    message.

    The attached file does not need to exist.
EOF
}


mod=$(cat $HOME/.dm/mod);
verbose=

while getopts "hm:v" options; do
  case $options in

    m ) mod=$OPTARG;;
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

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

[[ -n $verbose ]] && LOG_LEVEL=debug
[[ -n $verbose ]] && LOG_TO_STDERR=1

dir=$(mod_dir $mod)

if [[ -z $dir ]]; then
    echo "ERROR: Unable to locate mod $mod in mods or archive directories." >&2
    exit 1
fi

canonical_dm_root=$(readlink -f $DM_ROOT)
if [[ -z $canonical_dm_root ]]; then
    echo "ERROR: Unable to determine canonical DM_ROOT. Aborting." >&2
    exit 1
fi
logger_debug "Canonical DM_ROOT: $canonical_dm_root"

dm_root=$(readlink -f $DM_ROOT)
exit_status=0

logger_debug "Attaching to mod: $mod"
while :; do

    [[ -z "$1" ]] && break

    logger_debug "Attaching file: $1"

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
    file=$(readlink -f $1)

    # Determine the name of the file relative to DM_ROOT, ie, strip the
    # dm_root path from the file.
    rel_file=${file#${dm_root}/files/}
    if [[ "$rel_file" == "$file" ]]; then
        echo "ERROR: Attachment file must be in a subdirectory of DM_ROOT/files: $file" >&2
        exit_status=1
        shift
        continue
    fi

    # The path of attachment files should be the same within the mod.
    # Example
    #   file:              $DM_ROOT/files/path/to/attach.txt
    #   in mod: $DM_ROOT/mods/12345/files/path/to/attach.txt

    to_file="$dir/files/$rel_file"
    to_dir=${to_file%/*}            # Remove the file name
    [[ ! -d $to_dir ]] && mkdir -p $to_dir

    # Relative symlinks can be made only in the destination directory,
    # so cd to it.
    cd $to_dir

    # Create the ../ relative path.
    found=
    r=
    while : ; do
        r="../$r"
        rl=$(readlink -f $r)
        if [[ "$rl" == "/" ]]; then
            # Can't go any further
            break
        fi
        if [[ "$rl" == "$dm_root" ]]; then
            found=1
            break
        fi
    done
    if [[ -z $found ]]; then
        echo "ERROR: Destination does not appear to be a subdirectory of DM_ROOT. Link failed." >&2
        exit_status=1
        shift
        continue
    fi

    from_file="${r}files/${rel_file}"
    # Intentionally not testing the existance of from_file, it doesn't
    # have to exist.

    # And finally make the link.
    ln -snf "$from_file" .

    if [[ "$?" != "0" ]]; then
        exit_status=1
        shift
    fi

    shift
done
exit $exit_status
