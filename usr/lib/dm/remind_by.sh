#!/bin/bash
__loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

__loaded_attributes 2>/dev/null || source $DM_ROOT/lib/attributes.sh
__loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
__loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() { cat << EOF
usage: $script [-m mod_id] <remind_by options>

This script sets the methods (email, jabber, pager) for which alerts will be sent for a mod.
    -m      Id of mod

    -h      Print this help message.

REMIND_BY OPTIONS
    These are the remind_by options, ie how the alerts for the mod are reminded by.

    e(mail)
    j(abber)
    p(ager)

    Only the first letter of the option will be consider. For example the
    options p, page, pager, pageme, pepper all represent pager.

    Absolute options

    If a remind_by option is given without a + or - prefix, the option is
    considered absolute. If an absolute option is given, it is assumed as a
    replacement for any existing remindby options. Ie. the remind file for the
    mod is first cleared.

    Relative options

    If a remind_by option is given with a + or - prefix, the option is
    considered relative. A + prefix means, add the remind_by option to existing
    options in the mod's remind file. A - prefix means remove the remind_by
    option from the mod's remind file, leaving any other entries in the remind
    file untouched.

EXAMPLES:
    # Remind mod 12345 by jabber and pager
    $script -m 12345 jabber pager

    # Remind mod 12345 by email as well
    $script -m 12345 +email

    # Remove the option for reminding mod 12345 by pager
    $script -m 12345 -pager

    # Remind the default mod by pager
    $script pager

    # Use short forms to set mod 22222 to remind by email, jabber and pager
    $script -m 22222 e j p

NOTES:
    If the -m options is not provided, the mod postponed is the current one,
    ie. one indicated in $DM_USERS/current_mod

    For each remind_by method only one of the absolute option or the + relative
    or the - relative are permitted.

    The email, jabber, and pager addresses are determined from the
    $DM_ROOT/users/people file. The lib/dm.sh script sets
    environmental variables that identify the local user.

    Alternatives for remind_by options can be created from the cli.

    echo email > $DM_ROOT/mods/12345/remind_by
    echo pager > $DM_ROOT/mods/12345/remind_by

EOF
}

_options() { # set defaults
    args=()
    mod_id=$(< "$DM_USERS/current_mod")
    unset empty
    unset email
    unset email_add
    unset email_minus
    unset jabber
    unset jabber_add
    unset jabber_minus
    unset pager
    unset pager_add
    unset pager_minus
    email_opts=0
    jabber_opts=0
    pager_opts=0

    while [[ $1 ]]; do
        case "$1" in
             -m) shift; mod_id=$1 ;;
             e*) email=1;        ((email_opts++));  empty=1 ;;
            +e*) email_plus=1;   ((email_opts++)) ;;
            -e*) email_minus=1;  ((email_opts++)) ;;
             j*) jabber=1;       ((jabber_opts++)); empty=1 ;;
            +j*) jabber_plus=1;  ((jabber_opts++)) ;;
            -j*) jabber_minus=1; ((jabber_opts++)) ;;
             p*) pager=1;        ((pager_opts++));  empty=1 ;;
            +p*) pager_plus=1;   ((pager_opts++)) ;;
            -p*) pager_minus=1;  ((pager_opts++)) ;;
             -h) _u; exit 0      ;;
             --) shift; [[ $* ]] && args+=( "$@" ); break;;
             -*) _u; exit 0      ;;
              *) args+=( "$1" )  ;;
        esac
        shift
    done

    (( ${#args[@]} != 0 )) && { _u; exit 1; }
    (( $email_opts  > 1 )) && { _u; exit 1; }
    (( $jabber_opts > 1 )) && { _u; exit 1; }
    (( $pager_opts  > 1 )) && { _u; exit 1; }
    (( $email_opts + $jabber_opts + $pager_opts == 0 )) && { _u; exit 1; }
}


_options "$@"


[[ ! $mod_id ]] && __me 'Unable to determine mod id.'

mod_dir=$(__mod_dir "$mod_id")
remind_by=$mod_dir/remind_by

[[ $empty ]]                    && echo -n '' > $remind_by
[[ $email  || $email_plus ]]    && echo 'email'  >> $remind_by
[[ $jabber || $jabber_plus ]]   && echo 'jabber' >> $remind_by
[[ $pager  || $pager_plus ]]    && echo 'pager'  >> $remind_by
[[ $email_minus ]]              && sed -i "/email/d"  $remind_by
[[ $jabber_minus ]]             && sed -i "/jabber/d" $remind_by
[[ $pager_minus ]]              && sed -i "/pager/d"  $remind_by

# Sort and remove duplicates
sort -u -o "$remind_by" "$remind_by"
