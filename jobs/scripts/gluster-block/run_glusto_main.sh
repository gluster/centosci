#!/bin/bash
# Run ansible script to setup everything
# Get master IP
host=$(grep ansible_host hosts | head -n 1 | awk '{split($2, a, "="); print a[2]}')

set -x

GLUSTO_WORKSPACE="$WORKSPACE"
export GLUSTO_WORKSPACE
# Retry Ansible runs thrice
MAX=3
RETRY=0
while [ $RETRY -lt $MAX ];
do
    ANSIBLE_HOST_KEY_CHECKING=False "$HOME/env/bin/ansible-playbook" -i hosts scripts/gluster-block/setup-gluster-block-glusto.yml
    #ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts "$WORKSPACE/setup_glusto-on-nodes-local.yml"
    RETURN_CODE=$?
    if [ $RETURN_CODE -eq 0 ]; then
        break
    fi
    RETRY=$((RETRY+1))
done

scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no scripts/gluster-block/run_glusto_on_host.sh "root@${host}:run_glusto_on_host.sh"
ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "root@$host" EXIT_ON_FAIL="$EXIT_ON_FAIL" ./run_glusto_on_host.sh
JENKINS_STATUS=$?

source $GLUSTO_WORKSPACE/scripts/glusto/get-glusto-logs.sh
exit $JENKINS_STATUS
