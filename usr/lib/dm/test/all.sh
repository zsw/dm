#!/bin/bash

# Do not load environment here or else individual scripts will see the
# _loaded_env value and not set their own environments.
# The script cannot assume any dm env variables.
# _loaded_env 2>/dev/null || { . $HOME/.dm/dmrc && . $DM_ROOT/lib/env.sh || exit 1 ; }

#
# Run all tests.
#

test_dir=$(dirname $0)

for script in $test_dir/*.sh; do

    [[ $(basename $script) == 'all.sh' ]]  && continue
    [[ $(basename $script) == 'test.sh' ]]  && continue

    echo "Running: $script"
    $script
done
