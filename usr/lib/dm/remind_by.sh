#!/bin/bash
_loaded_env 2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

_loaded_log 2>/dev/null || source $DM_ROOT/lib/log.sh
_loaded_tmp 2>/dev/null || source $DM_ROOT/lib/tmp.sh

script=${0##*/}
_u() { cat << EOF

usage: $script [ -m mod_id ] <remind_by options> <email addresses>

This script sets the methods (email, jabber, pager) for which alerts will be sent for a mod.

OPTIONS:
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
    $0 -m 12345 jabber pager

    # Remind mod 12345 by email as well
    $0 -m 12345 +email

    # Remove the option for reminding mod 12345 by pager
    $0 -m 12345 -pager

    # Remind the default mod by pager
    $0 pager

    # Use short forms to set mod 22222 to remind by email, jabber and pager
    $0 -m 22222 e j p

NOTES:

    If the -m options is not provided, the mod postponed is the current one,
    ie. one indicated in $DM_USERS/current_mod

    For each remind_by method only one of the absolute option or the + relative
    or the - relative are permitted.

    The email, jabber, and pager addresses are determined from the
    $DM_ROOT/users/people file. The lib/dm.sh script sets
    environmental variables that identify the local user.

    Alternatives for remind_by options can be created from the cli.

    echo username@gmail.com > $DM_ROOT/mods/12345/remind
    echo 5195552121@pcs.rogers.com > $DM_ROOT/mods/12345/remind

EOF
}

function clean_remind {

    # Remove dupes and sort remind file

    file=$1
    tmpfile=$(tmp_file)

    res=$(cat $file | sort | uniq > $tmpfile)
    res=$(cp $tmpfile $file)
}

mod=$(< $DM_USERS/current_mod);

email=
email_add=
email_minus=
email_opts=0
jabber=
jabber_add=
jabber_minus=
jabber_opts=0
pager=
pager_add=
pager_minus=
pager_opts=0
empty=

while [ "$1" != "" ]; do
    case $1 in

        -m ) shift
             mod=$1
             ;;

         e*) email=1
             let "email_opts++"
             empty=1
             ;;
        +e*) email_plus=1
             let "email_opts++"
             ;;
        -e*) email_minus=1
             let "email_opts++"
             ;;

         j*) jabber=1
             let "jabber_opts++"
             empty=1
             ;;
        +j*) jabber_plus=1
             let "jabber_opts++"
             ;;
        -j*) jabber_minus=1
             let "jabber_opts++"
             ;;

         p*) pager=1
             let "pager_opts++"
             empty=1
             ;;
        +p*) pager_plus=1
             let "pager_opts++"
             ;;
        -p*) pager_minus=1
             let "pager_opts++"
             ;;

        -h ) _u
             exit 0;;
         * ) _u
             exit 1;;

    esac
    shift
done


if [ ! $mod ]; then

    echo 'ERROR: Unable to determine mod id.' >&2
    exit 1
fi

if [[ "$email_opts" -gt "1" ]]; then
    _u
    exit 1
fi

if [[ "$jabber_opts" -gt "1" ]]; then
    _u
    exit 1
fi

if [[ "$pager_opts" -gt "1" ]]; then
    _u
    exit 1
fi


remind=$DM_MODS/$mod/remind
remind_by=$DM_MODS/$mod/remind_by

if [[ $empty ]]; then
    logger_debug "Clearing $remind"
    echo -n '' > $remind
    echo -n '' > $remind_by
fi

if [[ $email || -n $email_plus ]]; then
    logger_debug "Adding email $DM_PERSON_EMAIL to remind_by options for mod $mod"
    echo $DM_PERSON_EMAIL >> $remind
    echo 'email' >> $remind_by
fi

if [[ $email_minus ]]; then
    logger_debug "Removing email $DM_PERSON_EMAIL from remind_by options for mod $mod"
    sed -i "/$DM_PERSON_EMAIL/d" $remind
    sed -i "/email/d" $remind_by
fi


if [[ $jabber || -n $jabber_plus ]]; then
    logger_debug "Adding jabber $DM_PERSON_JABBER to remind_by options for mod $mod"
    echo $DM_PERSON_JABBER >> $remind
    echo 'jabber' >> $remind_by
fi

if [[ $jabber_minus ]]; then
    logger_debug "Removing jabber $DM_PERSON_JABBER from remind_by options for mod $mod"
    sed -i "/$DM_PERSON_JABBER/d" $remind
    sed -i "/jabber/d" $remind_by
fi


if [[ $pager || -n $pager_plus ]]; then
    logger_debug "Adding pager $DM_PERSON_PAGER to remind_by options for mod $mod"
    echo $DM_PERSON_PAGER >> $remind
    echo 'pager' >> $remind_by
fi

if [[ $pager_minus ]]; then
    logger_debug "Removing pager $DM_PERSON_PAGER from remind_by options for mod $mod"
    sed -i "/$DM_PERSON_PAGER/d" $remind
    sed -i "/pager/d" $remind_by
fi

clean_remind $remind
clean_remind $remind_by

logger_debug "cat $remind"
logger_debug $(cat $remind)
