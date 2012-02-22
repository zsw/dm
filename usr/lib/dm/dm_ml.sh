#!/bin/bash
script="${0##*/}"
_u() { cat << EOF
usage: $script -d /path/to/dm_maildir -s /path/to/search_maildir -t /path/to/tree_file
Creates mailing list thread for each ID in a tree
    -d  path to dm maildir
    -s  path to search maildir used by mairix
    -t  path to tree file

    -h  Print this help message

EXAMPLE:
    $script -d $HOME/.mail/dm -t $DM_ROOT/trees/main
    $script -d $HOME/.mail/dm -s $HOME/.mail/search -t $DM_ROOT/trees/main

long_description
EOF
}


## Using comm, compare all ids in a tree file with ids in subject header of a maildir
_ids() {
    readarray -t missing_email < <(comm -2 -3 <(printf "%s\n" "${tree_ids[@]}" | sort -u) <(printf "%s\n" "${ml_ids[@]}" | sort -u))

    ##  Create an email for each missing ml_id
    [[ ! ${missing_email[@]} ]] && return
    for i in "${missing_email[@]}"; do
        description=$(< "$DM_MODS/$i/description")
        divider='--------------------------------------------- specs ---'
        { echo "$divider"; cat "$DM_MODS/$i/"spec* 2>/dev/null; } | mail -r "$from_email" -s "[$i] $description" "$to_email"
    sleep 5
    done
    exit 0
}

## compare descriptions
_cd() {
    command -v mairix &>/dev/null || __me "mairix not installed"
    readarray -t missing_description < <(comm -2 -3 <(printf "%s\n" "${tree_list[@]}" | sort -u) <(printf "%s\n" "${ml_list[@]}" | sort -u))

    while IFS=$'\r' read -r o n; do
        mairix s:"$mod_id"
        msg_id=$(grep -hP '^Message-Id:' "$maildir_search/$(ls -rt1 "$maildir_search/" | head -1)")
        printf "%s\n"   "To: devmod ML" \
                        "Subject: $n (was: $o)" \
                        "In-Reply-To: <$msg_id>" \
                        "" \
                        "Changed: Description" | sendmail -f "$from_email" -- "$to_email"
    done < <(printf "%s\r%s\n" "${missing_description[@]}")
}

_options() {
    args=()
    unset maildir_dm maildir_search tree

    while [[ $1 ]]; do
        case "$1" in
            -d) shift; maildir_dm=$1   ;;
            -s) shift; maildir_search=$1    ;;
            -t) shift; tree=$1  ;;
            -h) _u; exit 0      ;;
            --) shift; [[ $* ]] && args+=( "$@" ); break;;
            -*) _u; exit 0      ;;
             *) args+=( "$1" )  ;;
        esac
        shift
    done

     (( ${#args[@]} == 2 )) && { _u; exit 1; }
     (( ${#args[@]} == 3 )) && { _u; exit 1; }
     mod=${args[0]}
}

_options "$@"

#to_email=dm@zsw.ca
to_email=devmod@googlegroups.com
from_email=dm_bot@zsw.ca

ml_list=()
ml_ids=()
tree_list=()
tree_ids=()
missing_email=()
missing_description=()

readarray -t tree_list < <(prioritize.sh "$tree" | format_mod.sh "%i %d")
tree_ids=( "${tree_list[@]%% *}" )

readarray -t ml_list < <(grep -hP '^Subject: \[[[:digit:]]{5}\] ' "$maildir_dm"/{cur,new}/ | sed -r 's/^Subject: .*([[:digit:]]{5})](.*)/\1\2/' | sed 's/(was: .*//')
ml_ids=( "${ml_list[@]%% *}" )

## Run functions
_ids
#_cd
