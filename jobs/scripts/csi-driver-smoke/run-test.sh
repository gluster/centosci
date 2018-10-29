#!/bin/bash

# if anything fails, we'll abort
set -e

# TODO: disable debugging
set -x

# we get the code from git and configure VMs with Ansible
yum -y install git ansible

mkdir -p go/{src,pkg,bin}
pushd go

export GOPATH="$PWD"
export PATH="$GOPATH/bin:$PATH"

export GIT=https://github.com/gluster/gluster-csi-driver.git
export SRC="$GOPATH/src/github.com/gluster/gluster-csi-driver"

mkdir -p "$SRC"
git clone "$GIT" "$SRC"
pushd "$SRC"

# by default we clone the master branch, but maybe this was triggered through a PR?
if [ -n "${ghprbPullId}" ]
then
	git fetch origin "pull/${ghprbPullId}/head:pr_${ghprbPullId}"
	git checkout "pr_${ghprbPullId}"

	# Now rebase on top of master
	git rebase master
	if [ $? -ne 0 ] ; then
	    echo "Unable to automatically merge master. Please rebase your patch"
	    exit 1
	fi
fi

# run the centos-ci.sh script, which installs any requirements and runs the test
./extras/centos-ci.sh
