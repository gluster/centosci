#!/bin/bash

# Verify everything works with the following:
docker run hello-world

# if selinux is enabled
selinuxenabled
if [ $? -ne 0 ]
then
    sudo yum install libselinux-python

/bin/bash centosci/scripts/gluster-ansible-infra/tests/run-centos-ci.sh
