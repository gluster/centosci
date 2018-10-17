#!/bin/bash

function print_help {
    echo "./run-glusto.sh -p path/to/test.py"
}

while getopts p:h option
do
    case "${option}" in
    p)
        GLUSTO_PATH=${OPTARG}
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
SETX=""
if [ $EXIT_ON_FAIL == True ]
    then
    SETX="-x"
fi
glusto -c ../../gluster_tests_config.yml --pytest="-v $SETX $GLUSTO_PATH"
