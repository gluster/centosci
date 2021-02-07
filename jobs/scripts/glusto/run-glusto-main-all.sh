#!/bin/bash
# Run ansible script to setup everything
# Get master IP
host=$(grep ansible_host hosts | head -n 1 | awk '{split($2, a, "="); print a[2]}')


set -x
 
GLUSTO_WORKSPACE="$WORKSPACE"
pwd
if [ -d "glusto" ]; then
  mv hosts centosci/hosts
  pushd centosci
  GLUSTO_WORKSPACE="$WORKSPACE"/centosci
fi
export GLUSTO_WORKSPACE
pwd
ls
# Retry Ansible runs thrice
MAX=3
RETRY=0
while [ $RETRY -lt $MAX ];
do
    ANSIBLE_HOST_KEY_CHECKING=False "$HOME/env/bin/ansible-playbook" -i hosts jobs/scripts/glusto/setup-glusto.yml
    RETURN_CODE=$?
    if [ $RETURN_CODE -eq 0 ]; then
        break
    fi
    RETRY=$((RETRY+1))
done

# run bvt and cvt tests
GLUSTO_MODULE="bvt"
EXIT_ON_FAIL="False" 
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no jobs/scripts/glusto/run-glusto.sh "root@${host}:run-glusto.sh"
ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "root@$host" EXIT_ON_FAIL="$EXIT_ON_FAIL" ./run-glusto.sh -m "$GLUSTO_MODULE"
JENKINS_STATUS=$?
if [ $JENKINS_STATUS -eq 0 ]; then
    GLUSTO_MODULE="cvt"
    ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "root@$host" EXIT_ON_FAIL="$EXIT_ON_FAIL" ./run-glusto.sh -m "$GLUSTO_MODULE"
fi
source $GLUSTO_WORKSPACE/jobs/scripts/glusto/get-glusto-logs.sh
exit $JENKINS_STATUS
