#!/bin/bash

BUILD_GIT_REPO="https://github.com/gluster/samba-integration"
BUILD_GIT_BRANCH="samba-build"
SAMBA_BRANCH="${SAMBA_BRANCH:-master}"
SAMBA_MAJOR_VERS=$([ "${SAMBA_BRANCH}" != "master" ] && ( (tmp="${SAMBA_BRANCH//[a-zA-Z]}" && echo "${tmp//-/.}") | sed 's/.$//' ) || echo "${SAMBA_BRANCH}" )
CENTOS_VERSION="${CENTOS_VERSION:-7}"
CENTOS_ARCH='x86_64'
RESULT_BASE="/tmp/samba-build/rpms"
RESULT_DIR="${RESULT_BASE}/${SAMBA_MAJOR_VERS}/${CENTOS_VERSION}/${CENTOS_ARCH}"
REPO_NAME="samba-nightly-${SAMBA_MAJOR_VERS}"
REPO_FILE="${RESULT_BASE}/${REPO_NAME}.repo"

artifact()
{
    [ -e ~/rsync.passwd ] || return 0
    rsync -av --password-file ~/rsync.passwd "${@}" gluster@artifacts.ci.centos.org::gluster/nightly-samba/
}

# if anything fails, we'll abort
set -e

# log the commands
set -x

# Install basic dependencies for building the tarball and srpm.
# epel is needed to get more up-to-date versions of mock and ansible.
yum -y install epel-release
yum -y install git make rpm-build mock ansible createrepo_c


# Install vagrant/vagrant-libvirt and prerequisites to run the rpm install test.

yum -y install \
	qemu-kvm \
	qemu-kvm-tools \
	qemu-img \
	make \
	ansible \
	libvirt \
	libvirt-devel

# "Development Tools" and libvirt-devel are needed to run
# "vagrant plugin install"
yum -y group install "Development Tools"


# We install vagrant directly from upstream hashicorp since
# the centos/scl vagrant packages are deprecated / broken.

# yum install fails if the package is already installed at the desired
# version, so we check whether vagrant is already installed at that
# version. This is important to check when the script is invoked a
# couple of times in a row to prevent it from failing. As a positive
# side effect, it also avoids duplicate downloads of the RPM.
#
VAGRANT_VERSION="2.2.14"
if ! rpm -q "vagrant-${VAGRANT_VERSION}"
then
	yum -y install "https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_x86_64.rpm"
fi

vagrant plugin install vagrant-libvirt

# Vagrant needs libvirtd running
systemctl start libvirtd

# Log the virsh capabilites so that we know the
# environment in case something goes wrong.
virsh capabilities


git clone --depth=1 --branch="${BUILD_GIT_BRANCH}" "${BUILD_GIT_REPO}" "${BUILD_GIT_BRANCH}"
cd "${BUILD_GIT_BRANCH}"

# By default, we clone the branch ${BUILD_GIT_BRANCH},
# but maybe this was triggered through a PR?
if [ -n "${ghprbPullId}" ]
then
	# We have to fetch the whole target branch to be able to rebase.
	git fetch --unshallow  origin

	git fetch origin "pull/${ghprbPullId}/head:pr_${ghprbPullId}"
	git checkout "pr_${ghprbPullId}"

	git rebase "origin/${ghprbTargetBranch}"
	if [ $? -ne 0 ] ; then
		echo "Unable to automatically rebase to branch '${ghprbTargetBranch}'. Please rebase your PR!"
		exit 1
	fi

	proceed=0

	read -r -d '' -a FILES_CHANGED < <(git diff --name-only origin/"${ghprbTargetBranch}")

	for i in "${FILES_CHANGED[@]}"
	do
		if [[ $i =~ "spec" ]] && [[ $i =~ ${SAMBA_MAJOR_VERS} ]]
		then
			proceed=1
			break
		fi
	done

	if [ $proceed -eq 0 ]; then
		echo "RPM spec file unchanged for version ${SAMBA_MAJOR_VERS}, skipping..."
		exit 0
	fi

fi

make "rpms.centos${CENTOS_VERSION}" "refspec=${SAMBA_BRANCH}"
make "test.rpms.centos${CENTOS_VERSION}" "refspec=${SAMBA_BRANCH}"

# Don't upload the artifacts if running on a PR.
if [ -n "${ghprbPullId}" ]
then
	exit 0
fi

pushd "${RESULT_DIR}"
createrepo_c .
popd

# create a new .repo file (for new branches, and it prevents cleanup)
cat > "${REPO_FILE}" <<< "[${REPO_NAME}]
name=Samba Nightly Builds (${SAMBA_MAJOR_VERS} branch)
baseurl=http://artifacts.ci.centos.org/gluster/nightly-samba/${SAMBA_MAJOR_VERS}/\$releasever/\$basearch
enabled=1
gpgcheck=0"

pushd "${RESULT_BASE}"
artifact "${REPO_NAME}.repo"
artifact "${SAMBA_MAJOR_VERS}"
popd
