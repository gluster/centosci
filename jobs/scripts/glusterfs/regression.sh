#!/bin/bash

MY_ENV=$(env | sort)
BURL=${BUILD_URL}consoleFull

# Display all environment variables in the debugging log
echo "Start time $(date)"
echo
echo "Display all environment variables"
echo "*********************************"
echo
echo "$MY_ENV"
echo

# Pull required tests into /opt/qa
mkdir -p /opt/
git clone --depth 1 https://github.com/gluster/glusterfs-patch-acceptance-tests /opt/qa

# Remove any gluster daemon leftovers from aborted runs
sudo -E bash /opt/qa/cleanup.sh

# Clean up the git repo
sudo rm -rf $WORKSPACE/.gitignore $WORKSPACE/*
sudo chown -R jenkins:jenkins $WORKSPACE
cd $WORKSPACE || exit 1
git reset --hard HEAD

# Clean up other Gluster dirs
sudo rm -rf /var/lib/glusterd/* /build/install /build/scratch >/dev/null 2>&1

# Remove the many left over socket files in /var/run
sudo rm -f /var/run/????????????????????????????????.socket >/dev/null 2>&1

# Remove GlusterFS log files from previous runs
sudo rm -rf /var/log/glusterfs/* /var/log/glusterfs/.cmd_log_history >/dev/null 2>&1

JDIRS="/var/log/glusterfs /var/lib/glusterd /var/run/gluster /d /d/archived_builds /d/backends /d/build /d/logs /home/jenkins/root"
sudo mkdir -p $JDIRS
sudo chown jenkins:jenkins $JDIRS
chmod 755 $JDIRS

# Skip tests for certain folders
SKIP=true
for file in $(git diff-tree --no-commit-id --name-only -r HEAD); do
    /opt/qa/is-ignored-file.py $file
    matched=$?
    if [ $matched -eq 1 ]; then
        SKIP=false
        break
    fi
done
if [[ "$SKIP" == true ]]; then
    echo "Patch only modifies ignored files. Skipping further tests"
    RET=0
    VERDICT="Skipped tests for change that only modifies ignored files"
    V="+1"
    echo $VERDICT ":" $V
    exit $RET
fi

# Build Gluster
echo "Start time $(date)"
echo
echo "Build GlusterFS"
echo "***************"
echo
/opt/qa/build.sh
RET=$?
if [ $RET != 0 ]; then
    # Build failed, so abort early
    VERDICT="FAILED"
    V="-1"
    echo $VERDICT ":" $V
    exit $RET
fi
echo

TEST_ONLY=true
declare -a TEST_FILES
TEST_COUNT=0
for file in $(git diff-tree --no-commit-id --name-only -r HEAD); do
    if [[ $file =~ tests/.*\.t$ ]] ;then
        TEST_FILES[$TEST_COUNT]="$file"
        TEST_COUNT=$(( $TEST_COUNT + 1 ))
    else
        TEST_ONLY=false
    fi
done

# Run the regression test
echo "Start time $(date)"
echo
echo "Run the regression test"
echo "***********************"
echo
if [[ "$TEST_ONLY" == true ]]; then
    echo "This review only changes tests, running only the changed tests"
    sudo -E bash /opt/qa/regression.sh ${TEST_FILES[*]}
else
    sudo -E bash /opt/qa/regression.sh
fi

RET=$?
if [ $RET = 0 ]; then
    V="+1"
    VERDICT="SUCCESS"
else
    V="-1"
    VERDICT="FAILED"
fi
# Update Gerrit with the success/failure status
sudo mv /tmp/gluster_regression.txt $WORKSPACE || true
sudo chown jenkins:jenkins gluster_regression.txt || true
echo $VERDICT ":" $V
exit $RET
