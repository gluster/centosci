#!/bin/bash

BUILD_GIT_REPO="https://github.com/gluster/samba-integration"
BUILD_GIT_BRANCH="samba-build"
SAMBA_BRANCH='master'
CENTOS_VERSION='7'
CENTOS_ARCH='x86_64'
RESULT_BASE="/tmp/samba-build/rpms"
RESULT_DIR="${RESULT_BASE}/${SAMBA_BRANCH}/${CENTOS_VERSION}/${CENTOS_ARCH}"
REPO_NAME="samba-nightly-${SAMBA_BRANCH}"
REPO_FILE="${RESULT_BASE}/${REPO_NAME}.repo"

artifact()
{
    [ -e ~/rsync.passwd ] || return 0
    rsync -av --password-file ~/rsync.passwd ${@} gluster@artifacts.ci.centos.org::gluster/nightly-samba/
}

# if anything fails, we'll abort
set -e

# Install basic dependencies for building the tarball and srpm.
# epel is needed to get more up-to-date versions of mock and ansible.
yum -y install epel-release
yum -y install git make rpm-build mock ansible createrepo_c

git clone --depth=1 --branch="${BUILD_GIT_BRANCH}" "${BUILD_GIT_REPO}" "${BUILD_GIT_BRANCH}"
cd "${BUILD_GIT_BRANCH}"

# By default, we clone the branch ${BUILD_GIT_BRANCH},
# but maybe this was triggered through a PR?
if [ -n "${ghprbPullId}" ]
then
	git fetch origin "pull/${ghprbPullId}/head:pr_${ghprbPullId}"
	git checkout "pr_${ghprbPullId}"

	git rebase "origin/${ghprbTargetBranch}"
	if [ $? -ne 0 ] ; then
		echo "Unable to automatically rebase to branch '${ghprbTargetBranch}'. Please rebase your PR!"
		exit 1
	fi
fi

make "rpms.centos${CENTOS_VERSION}"

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
name=Samba Nightly Builds (${SAMBA_BRANCH} branch)
baseurl=http://artifacts.ci.centos.org/gluster/nightly-samba/${SAMBA_BRANCH}/\$releasever/\$basearch
enabled=1
gpgcheck=0"

pushd "${RESULT_BASE}"
artifact "${REPO_NAME}.repo"
artifact "${SAMBA_BRANCH}"
popd
