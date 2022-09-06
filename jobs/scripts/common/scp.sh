set +x
scp -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no /duffy-ssh-key/ssh-privatekey root@$(cat $WORKSPACE/hosts):gluster-ssh-privatekey
ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$(cat $WORKSPACE/hosts) "chmod 0600 ~/gluster-ssh-privatekey"
