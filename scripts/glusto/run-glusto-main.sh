#!/bin/bash
# Run ansible script to setup everything

# Get master IP
host=$(cat hosts | grep ansible_host | head -n 1 | awk '{split($2, a, "="); print a[2]}')

# Build gluster packages
#scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no scripts/glusto/build-rpms.sh root@${host}:build-rpms.sh
#ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host BRANCH=$BRANCH ./build-rpms.sh

# Retry Ansible runs thrice
MAX=3
RETRY=0
while [ $RETRY -lt $MAX ];
do
    ANSIBLE_HOST_KEY_CHECKING=False $HOME/env/bin/ansible-playbook -i hosts scripts/glusto/setup-glusto.yml
    RETURN_CODE=$?
    if [ $RETURN_CODE -eq 0 ]; then
        break
    fi
    RETRY=$((RETRY+1))
done

# run the test command from master
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no scripts/glusto/run-glusto.sh root@${host}:run-glusto.sh
ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host ./run-glusto.sh -m $GLUSTO_MODULE
JENKINS_STATUS=$?
exit $JENKINS_STATUS
