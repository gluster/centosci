#!/bin/bash


cd /root/gluster-block/tests
SETX=""
if [ $EXIT_ON_FAIL == True ]
    then
    SETX="-x"
fi

glusto -c ../../gluster_tests_config.yml --pytest="-v $SETX glusto/* "

