#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_lock 2>/dev/null || source $DM_ROOT/lib/lock.sh

script=${0##*/}
_u() { cat << EOF
usage: $script [options] server

This script runs a git pull from another server.
    -g  Path to git repository.
    -h  Print this help message.

EXAMPLES:
    cd $DM_ROOT
    $script donkey

NOTES:
    If the git repository path option, -g, is not provided, the current
    working directory is assumed. If a git repo configuration file,
    .git/config, does not exist in the current working directory, the
    user is prompted to select from available git repos on the local
    computer.

    This script puts a lock on the dm system while processing. If it
    cannot obtain a lock, it exits with message.
EOF
}

_options() {
    # set defaults
    args=()
    unset git_dir

    while [[ $1 ]]; do
        case "$1" in
            -g) shift; git_dir=$1   ;;
            -h) _u; exit 0          ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0          ;;
             *) args+=( "$1" )      ;;
        esac
        shift
    done

     (( ${#args[@]} != 1 )) && { _u; exit 1; }
     server=${args[0]}
}

_options "$@"

[[ ! $git_dir ]] && git_dir=$(pwd)
[[ ! -d $git_dir || ! -f $git_dir/.git/config ]] && __me "Pull aborted. Present directory is not a git repo."


if ! __lock_create; then
    __me "Unable to run $script. The dm system is locked at the moment.
        Run this command to see which script has the file locked: cat $(__lock_file)"
fi

trap '__lock_remove; exit $?' INT TERM EXIT

git checkout "$server" || exit 1

if ! git pull &>/dev/null ; then
    __mi "*************************
        WARNING: git pull failed
        To troubleshoot, run pull commands below and review messages
        \$ git checkout $server
        \$ git pull
        \$ git checkout master
        *************************" >&2
    git checkout master || exit 1
    __lock_remove
    exit 1
fi

git checkout master || exit 1

git diff --stat "$server" master || exit 1

diff=$(git diff "$server" master)
[[ ! $diff ]] && __me "Remote branch $server and local branch master are identical."

git merge "$server" || exit 1

pull_dir=$DM_USERS/pulls
mkdir -p "$pull_dir"
date "+%s" > "$pull_dir/$server"

__lock_remove
trap - INT TERM EXIT
