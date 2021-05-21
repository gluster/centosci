# Inspired by cico-node-get-to-ansible.sh
# A script that provisions nodes and writes them to a file
set +x
NODE_COUNT=${NODE_COUNT:-1}
ANSIBLE_HOSTS=${ANSIBLE_HOSTS:-$WORKSPACE/hosts}
SSID_FILE=${SSID_FILE:-$WORKSPACE/cico-ssid}

# Delete the host file if it exists
rm -rf $ANSIBLE_HOSTS

# Get nodes
nodes=$(cico -q node get --count ${NODE_COUNT} --column hostname --release ${CENTOS_VERSION} --column ip_address --column comment -f value)
cico_ret=$?

# Fail in case cico returned an error, or no nodes at all
if [ ${cico_ret} -ne 0 ]
then
    echo "cico returned an error (${cico_ret})"
    exit 2
elif [ -z "${nodes}" ]
then
    echo "cico failed to return any systems"
    exit 2
fi

# Write nodes to inventory file and persist the SSID separately for simplicity
touch ${SSID_FILE}
IFS=$'\n'
for node in ${nodes}
do
    host=$(echo "${node}" |cut -f1 -d " ")
    address=$(echo "${node}" |cut -f2 -d " ")
    ssid=$(echo "${node}" |cut -f3 -d " ")

    line="${address}"
    echo "${line}" >> ${ANSIBLE_HOSTS}

    # Write unique SSIDs to the SSID file
    if ! grep -q ${ssid} ${SSID_FILE}; then
        echo ${ssid} >> ${SSID_FILE}
    fi
done
