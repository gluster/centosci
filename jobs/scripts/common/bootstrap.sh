#!/bin/bash

set -e
set -x
EXEC_BIN="$(basename $1)"
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$1" "root@$(cat $WORKSPACE/hosts):$EXEC_BIN"
if [ -z $2 ];
then
    ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "root@$(cat $WORKSPACE/hosts)" "./$EXEC_BIN"
else
    ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "root@$(cat $WORKSPACE/hosts)" "$2" "./$EXEC_BIN"
fi
