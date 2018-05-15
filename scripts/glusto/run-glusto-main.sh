#!/bin/bash
# Run ansible script to setup everything
# Get master IP
host=$(grep ansible_host hosts | head -n 1 | awk '{split($2, a, "="); print a[2]}')

# Build gluster packages
#scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no scripts/glusto/build-rpms.sh root@${host}:build-rpms.sh
#ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host BRANCH=$BRANCH ./build-rpms.sh

set -x
# Check if this is a patch run
GLUSTO_WORKSPACE="$WORKSPACE"
if [ -d "glusto" ]
then
  pushd glusto
  GLUSTO_PATCH=$(git diff-tree --no-commit-id --name-only -r HEAD --diff-filter=AMR -- 'tests/*.py' | sed 's#tests/##g' )
  popd
  mv hosts centosci/hosts
  pushd centosci
  GLUSTO_WORKSPACE="$WORKSPACE"/centosci
fi
export GLUSTO_WORKSPACE
# Retry Ansible runs thrice
MAX=3
RETRY=0
while [ $RETRY -lt $MAX ];
do
    ANSIBLE_HOST_KEY_CHECKING=False "$HOME/env/bin/ansible-playbook" -i hosts scripts/glusto/setup-glusto.yml
    RETURN_CODE=$?
    if [ $RETURN_CODE -eq 0 ]; then
        break
    fi
    RETRY=$((RETRY+1))
done

# run the test command from master
if [ -z "$GLUSTO_PATCH" ]; then
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no scripts/glusto/run-glusto.sh "root@${host}:run-glusto.sh"
    ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "root@$host" EXIT_ON_FAIL="$EXIT_ON_FAIL" ./run-glusto.sh -m "$GLUSTO_MODULE"
    JENKINS_STATUS=$?
    exit $JENKINS_STATUS
  else
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no scripts/glusto/run-glusto-patch.sh "root@${host}:run-glusto-patch.sh"
    ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "root@$host" ./run-glusto-patch.sh -p "$GLUSTO_PATCH"
    JENKINS_STATUS=$?
    exit $JENKINS_STATUS
fi
