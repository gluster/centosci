#!/bin/bash
set +e
ANSIBLE_HOST_KEY_CHECKING=False $HOME/env/bin/ansible-playbook -i hosts scripts/glusto/get-gluster-logs.yml
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host:/root/gluster-logs.gz .
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host:/tmp/glustomain.log .
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host:/tmp/*junit.xml .
