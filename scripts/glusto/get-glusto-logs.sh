#!/bin/bash
set +e
host=$(cat hosts | grep ansible_host | head -n 1 | awk '{split($2, a, "="); print a[2]}')
ANSIBLE_HOST_KEY_CHECKING=False $HOME/env/bin/ansible-playbook -i hosts scripts/glusto/get-gluster-logs.yml || true
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host:/root/gluster-logs.gz . || true
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host:/tmp/glustomain.log . || true
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host:/tmp/*junit.xml . || true
