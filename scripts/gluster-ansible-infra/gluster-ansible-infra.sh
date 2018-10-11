#!/bin/bash

# Verify everything works with the following:
docker run hello-world

# if selinux is enabled
selinuxenabled
if [ $? -ne 0 ]
then
    sudo yum install libselinux-python

/bin/bash gluster-ansible-infra/tests 
