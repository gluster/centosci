#!/bin/bash

source env
# if anything fails, we'll abort
set -e

set -x

# Strangely, userspace-rcu-devel comes from EPEL. We might as well install pip
# from EPEL.
yum -y install epel-release yum-utils
yum-config-manager --add-repo=http://artifacts.ci.centos.org/gluster/nightly/master.repo
yum -y install glusterfs-server glusterfs-cli glusterfs-api
systemctl start glusterd

# create bricks
for i in {1..4}
do
    truncate --size=2G /srv/test.brick${i}.img;
    mkfs -t xfs /srv/test.brick${i}.img;
    mkdir -p /bricks/b${i};
    mount -o loop /srv/test.brick${i}.img /bricks/b${i};
    mkdir /bricks/b${i}/data;
done

# create a volume ("test" is the default name in test/test.conf)
gluster --mode=script volume create test replica 2 ${HOSTNAME}:/bricks/b{1..4}/data force
gluster --mode=script volume start test

# basic dependencies for the tests
yum -y install git python-pip python36
pip install --upgrade pip tox

git clone git://review.gluster.org/libgfapi-python
cd libgfapi-python/

# run tests
tox -e pep8,py27,py36,functest27,functest36
