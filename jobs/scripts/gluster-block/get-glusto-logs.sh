#!/bin/bash
set -x
set +e

host=$(cat hosts | grep ansible_host | head -n 1 | awk '{split($2, a, "="); print a[2]}')
ANSIBLE_HOST_KEY_CHECKING=False $HOME/env/bin/ansible-playbook -i hosts scripts/gluster-block/get-logs.yml || true
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host:/root/gluster-logs.gz $WORKSPACE/ || true
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host:/tmp/glustomain.log $WORKSPACE/ || true
