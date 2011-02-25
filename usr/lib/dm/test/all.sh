#!/bin/bash

# Do not load environment here or else individual scripts will see the
# _loaded_env value and not set their own environments.
# The script cannot assume any dm env variables.
# _loaded_env2>/dev/null || { source $HOME/.dm/dmrc && source $DM_ROOT/lib/env.sh; } || exit 1

#
# Run all tests.
#

test_dir=${0%/*}           # Strip all.sh

for script in "$test_dir"/*.sh; do

    [[ ${script##*/} == all.sh ]]  && continue
    [[ ${script##*/} == test.sh ]]  && continue

    echo "Running: $script"
    "$script"
done
