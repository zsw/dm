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
    scripts exits with error.

    This script puts a lock on the dm system while processing. If it
    cannot obtain a lock, it exits with message.
EOF
}

_options() {
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

git fetch -q --all || __me "git fetch --all $server"
git branch -f "$server" "$server/master" >/dev/null || __me "git branch -f $server $server/master"
__lock_create || __me "${script}: Lock file found. cat $(__lock_file)"
git merge -q "$server" || __me "git merge $server"

pull_dir=$DM_USERS/pulls
mkdir -p "$pull_dir"
date "+%s" > "$pull_dir/$server"
