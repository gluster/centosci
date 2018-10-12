#!/bin/bash

# basic dependencies for the tests
yum -y install git
git clone https://github.com/gluster/gluster-ansible-infra.git

# Verify everything works with the following:
docker run hello-world

# if selinux is enabled
selinuxenabled
if [ $? -ne 0 ]
then
    sudo yum install libselinux-python
fi

./gluster-ansible-infra/tests/run-centos-ci.sh
