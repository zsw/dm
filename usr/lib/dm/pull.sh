#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
__loaded_lock 2>/dev/null || source $DM_ROOT/lib/lock.sh

script=${0##*/}
_u() {

    cat << EOF

usage: $0 [options] server

This script runs a git pull from another server.

OPTIONS:

    -d  Dry run. Actions not performed.
    -g  Path to git repository.
    -v  Verbose.

    -h  Print this help message.

EXAMPLES:

    cd $DM_ROOT
    $0 donkey

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


#
# pull_fail_message
#
# Sent: nothing
# Return: nothing
# Purpose:
#
#   Print a message related to a failed pull.
#
function pull_fail_message {

#    __mi "*************************
#        WARNING: git pull failed
#        To troubleshoot, run pull commands below and review messages
#        \$ git checkout $server
#        \$ git pull
#        \$ git checkout master
#        *************************" >&2
#    return

    echo "*************************" >&2
    echo "WARNING: git pull failed" >&2
    echo "To troubleshoot, run pull commands below and review messages" >&2
    echo "" >&2
    echo "git checkout $server" >&2
    echo "git pull" >&2
    echo "git checkout master" >&2
    echo "*************************" >&2
    return
}


dryrun=false
git_dir=
interactive=
verbose=

while getopts "dg:hv" options; do
  case $options in

    d ) dryrun=true;;
    g ) git_dir=$OPTARG;;
    v ) verbose=1;;
    h ) _u
        exit 0;;
    \?) _u
        exit 1;;
    * ) _u
        exit 1;;

  esac
done

shift $(($OPTIND - 1))

[[ $verbose ]] && LOG_LEVEL=debug
[[ $verbose ]] && LOG_TO_STDERR=1

server=$1
[[ ! $server ]] && { _u; exit 1; }

[[ ! $git_dir ]] && git_dir=$(pwd)
if [[ ! -d $git_dir || ! -f $git_dir/.git/config ]]; then
    echo "ERROR: Pull aborted. Present directory is not a git repo." >&2
    exit 1
fi

__logger_debug "Git repo path: $git_dir"

__logger_debug "Git server: $server"

$dryrun && echo "Dry run. Pull not executed"
$dryrun && exit 0

if ! __lock_create; then
    __me "Unable to run $script. The dm system is locked at the moment.
        Run this command to see which script has the file locked: cat $(__lock_file)"
fi

trap '__lock_remove; exit $?' INT TERM EXIT

__logger_debug "git checkout $server"
git checkout $server || exit 1

__logger_debug "git pull"
git_pull_failed=
git pull || git_pull_failed=1

if [[ $git_pull_failed ]]; then
    pull_fail_message
    __logger_debug "git checkout master"
    git checkout master || exit 1
    __lock_remove
    exit 1
fi

__logger_debug "git checkout master"
git checkout master || exit 1

__logger_debug "git diff --stat $server master"
git diff --stat $server master || exit 1

diff=$(git diff $server master)
if [[ ! "$diff" ]]; then
    echo "Remote branch $server and local branch master are identical."
    exit 1
fi

reply=
while :
do
    if [[ $interactive ]]; then
        read -p 'Merge changes? (Y/n): ' reply
    fi

    [[ ! "$reply" ]] && reply=y
    reply=$(echo $reply | tr "[:upper:]" "[:lower:]")

    [[ "$reply" == "y" ]] || [[ "$reply" == "n" ]] && break
done

[[ "$reply" == "n" ]] && exit 0

__logger_debug "git merge $server"
git merge $server || exit 1

__logger_debug "Log pull."
pull_dir="$DM_USERS/pulls"
mkdir -p "$pull_dir"
date "+%s" > "$pull_dir/$server"

__lock_remove
trap - INT TERM EXIT
