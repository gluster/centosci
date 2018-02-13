#!/bin/bash

function print_help {
    echo "./run-glusto.sh -m <module-name>"
    echo "<module-name matches the folder names in tests/functional folder"
    echo "bvt is a special module name"
}

while getopts m:h option
do
    case "${option}" in
    m)
        MODULE=${OPTARG}
        ;;
    h)
        print_help
        exit 0
        ;;
    ?)
        echo "Invalid parameter"
        print_help
        exit 1
        ;;
    esac
done

cd glusto-tests/tests
if [ "$MODULE" == "bvt" ]
    then
        glusto -c ../../gluster_tests_config.yml --pytest='-v functional/bvt/test_basic.py --junitxml=/tmp/bvt-junit.xml'
        glusto -c ../../gluster_tests_config.yml --pytest='-v functional/bvt/test_vvt.py --junitxml=/tmp/vvt-junit.xml'
        glusto -c ../../gluster_tests_config.yml --pytest='-v functional/bvt/test_cvt.py  --junitxml=/tmp/cvt-junit.xml'
    else
        glusto -c ../../gluster_tests_config.yml --pytest='-v functional/$MODULE --junitxml=/tmp/$MODULE-junit.xml'
fi
