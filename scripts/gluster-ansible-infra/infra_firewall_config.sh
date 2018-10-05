#!/bin/bash

virtualenv --system-site-packaes env
source env

# install dependency packages
yum install libselinux-python
yum install gcc python-virtualenv
pip install ansible molecule docker-py

# start and enable Docker service
systemctl start docker
systemctl enable docker

# Ensure that your user is in the docker group.
sudo groupadd docker
sudo usermod -aG docker $USER

# Verify everything works with the following:
docker run hello-world

# if selinux is enabled
selinuxenabled
if [ $? -ne 0 ]
then
    sudo yum install libselinux-python

# basic dependencies for the tests
yum -y install git
git clone https://github.com/gluster/gluster-ansible-infra.git
cd gluster-ansible-infra/roles/firewall_config/

# run tests
molecule init
molecule test
