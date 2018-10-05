#!/bin/bash

# setting up virtual environment
yum -y install epel-release
virtualenv --system-site-packaes env
source env

# install dependency packages
yum install libselinux-python
yum install gcc python-virtualenv
pip install ansible molecule docker-py
yum install docker

# start and enable Docker service
systemctl start docker
systemctl enable docker

# basic dependencies for the tests
yum -y install git
git clone https://github.com/gluster/gluster-ansible-infra.git
cd gluster-ansible-infra/roles/firewall_config/

# run tests
molecule init
molecule test

