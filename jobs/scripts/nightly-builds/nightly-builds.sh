#!/bin/bash

artifact()
{
    [ -e ~/rsync.passwd ] || return 0
    rsync -av --password-file ~/rsync.passwd ${@} gluster@artifacts.ci.centos.org::gluster/nightly/
}

# if anything fails, we'll abort
set -e

BUILDREQUIRES="libaio-devel librdmacm-devel libattr-devel libxml2-devel readline-devel openssl-devel libibverbs-devel fuse-devel glib2-devel userspace-rcu-devel libacl-devel sqlite-devel libuuid-devel"

if [ "${CENTOS_VERSION}" -eq 8 ]
then
    ENABLE_REPOS="--enablerepo=PowerTools,Devel"
    BUILDREQUIRES="${BUILDREQUIRES} python3-devel rpcgen libtirpc-devel"
    yum -y epel-release
else
    BUILDREQUIRES="${BUILDREQUIRES} python-devel"
fi

# install basic dependencies for building the tarball and srpm
yum -y install git autoconf automake gcc libtool bison flex make rpm-build mock createrepo_c
# gluster repositories contain additional -devel packages
yum -y install centos-release-storage-common centos-release-gluster
yum -y ${ENABLE_REPOS} install ${BUILDREQUIRES}

# clone the repository, github is faster than our Gerrit
#git clone https://review.gluster.org/glusterfs
git clone --depth 1 --branch ${GITHUB_BRANCH} https://github.com/gluster/glusterfs
cd glusterfs/

# generate a version based on branch.last-commit-date.last-commit-hash
if [ ${GITHUB_BRANCH} = 'devel' ]; then
    GIT_VERSION=''
    GIT_HASH="$(git log -1 --format=%h)"
    GIT_DATE="$(git log -1 --format=format:%cd --date=short | sed 's/-//g')"
    VERSION="${GIT_DATE}.${GIT_HASH}"
else
    GIT_VERSION="$(sed 's/.*-//' <<< ${GITHUB_BRANCH})"
    GIT_HASH="$(git log -1 --format=%h)"
    GIT_DATE="$(git log -1 --format=format:%cd --date=short | sed 's/-//g')"
    VERSION="${GIT_VERSION}.${GIT_DATE}.${GIT_HASH}"
fi

# Because this is a shallow clone, there are no tags in the git repository. It
# is not possible to use ./build-aux/pkg-version to get a matching version of a
# release. Create a VERSION file so that ./build-aux/pkg-version will not
# return any errors.
echo "v${VERSION}" > VERSION

# unique tag to use in git
TAG="${VERSION}-$(date +%Y%m%d).${GIT_HASH}"

if grep -q -E '^AC_INIT\(.*\)$' configure.ac; then
    # replace the default version by our autobuild one
    sed -i "s/^AC_INIT(.*)$/AC_INIT([glusterfs],[${VERSION}],[gluster-devel@gluster.org])/" configure.ac

    # Add a note to the ChangeLog (generated with 'make dist')
    git commit -q -n --author='Autobuild <gluster-devel@gluster.org>' \
        -m "autobuild: set version to ${VERSION}" configure.ac
fi

# generate the tar.gz archive
./autogen.sh
./configure --enable-fusermount --enable-gnfs
rm -f *.tar.gz
make dist

# build the SRPM
rm -f *.src.rpm
SRPM=$(rpmbuild --define 'dist .autobuild' --define "_srcrpmdir ${PWD}" \
    --define '_source_payload w9.gzdio' \
    --define '_source_filedigest_algorithm 1' \
    -ts glusterfs-${VERSION}.tar.gz | cut -d' ' -f 2)

MOCK_RPM_OPTS=''
case "${CENTOS_VERSION}/${GIT_VERSION}" in
    6/4*|6/5*)
        # CentOS-6 does not support server builds from Gluster 4.0 onwards
	# TODO: once glusterfs-3.x is obsolete, always set this for CentOS-6
        MOCK_RPM_OPTS='--without=server'
        ;;
    *)
        # gnfs is not enabled by default, but our regression tests depend on it
        MOCK_RPM_OPTS='--with=gnfs'
        ;;
esac

# do the actual RPM build in mock
# TODO: use a CentOS Storage SIG buildroot
RESULTDIR=/srv/gluster/nightly/${GITHUB_BRANCH}/${CENTOS_VERSION}/${CENTOS_ARCH}
/usr/bin/mock \
    --root epel-${CENTOS_VERSION}-${CENTOS_ARCH} \
    ${MOCK_RPM_OPTS} \
    --resultdir ${RESULTDIR} \
    --rebuild ${SRPM}

pushd ${RESULTDIR}
createrepo_c .
popd

# create a new .repo file (for new branches, and it prevents cleanup)
if [ -z "${GIT_VERSION}" ]; then
    REPO_VERSION='master'
    REPO_NAME='master'
else
    REPO_VERSION=$(sed 's/\.//' <<< ${GIT_VERSION})
    REPO_NAME=${GITHUB_BRANCH}
fi

cat > /srv/gluster/nightly/${REPO_NAME}.repo <<< "[gluster-nightly-${REPO_VERSION}]
name=Gluster Nightly builds (${GITHUB_BRANCH} branch)
baseurl=http://artifacts.ci.centos.org/gluster/nightly/${GITHUB_BRANCH}/\$releasever/\$basearch
enabled=1
gpgcheck=0"

pushd /srv/gluster/nightly
artifact ${REPO_NAME}.repo
artifact ${GITHUB_BRANCH}
popd
