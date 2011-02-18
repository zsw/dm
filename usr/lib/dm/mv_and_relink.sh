#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh

script=${0##*/}
_u() {

    cat << EOF
usage: $0 [OPTION] SOURCE DESTINATION

This script moves a file or directory SOURCE to a DESTINATION and
changes any symbolic links pointing to SOURCE to point to DESTINATION.

OPTIONS:

   -i      Interactive. Prompt before overwrite.
   -v      Verbose.

   -h      Print this help message.

EXAMPLES:

    $0 file.txt /path/to/files
    $0 file.txt /path/to/files/newname.txt
    $0 ~/tmp/diff* /path/to/files

    mkdir ~/work_dir
    $0 ~/work_dir /path/to/directories
    $0 ~/work_dir /path/to/directories/newname_dir

NOTES:

    SOURCE can be a file or directory.
    If DESTINATION exists and is a directory, SOURCE will be moved to the DESTINATION directory.
    If DESTINATION exists and is a file, SOURCE must be a file and will be renamed to DESTINATION clobbering existing DESTINATION.
    If DESTINATION does not exist, SOURCE will be renamed to DESTINATION.

    Wildcards are not permitted in the SOURCE or DESTINATION.

    Only symbolic links within \$DM_ROOT subdirectories are updated.
EOF
}

interactive=false
verbose=false
while getopts "hiv" options; do
  case $options in

    i ) interactive=true;;
    v ) verbose=true;;
    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    *)  _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

if [[ "$#" -ne "2" ]]; then
    _u
    exit 1
fi

source=$(readlink -f $1)
destination=$(readlink -f $2)

i=
$interactive && i='-i'

v=
$verbose && v='-v'

$DM_BIN/mv_link_back.sh  $i $v $source $destination

current_file=$(basename $source);

for file in $(find $DM_ROOT/ -lname "*$current_file"); do
    [[ "$destination" == "$file" ]] && continue

    rl=$(readlink -f $file)
    [[ "$rl" != "$destination" ]] && continue

    ln -snf $i $v $destination $file
done

test -f $source && rm $source
test -h $source && rm $source
