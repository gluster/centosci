#!/bin/bash

# basic dependencies for the tests
yum -y install git
git clone https://github.com/gluster/gluster-ansible-infra.git

./gluster-ansible-infra/tests/run-centos-ci.sh
