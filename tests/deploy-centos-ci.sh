#!/bin/bash
sed "s/JENKINS_API_KEY/$JENKINS_API_KEY/g" tests/jenkins.conf > jobs/jenkins.ini
jenkins-jobs --conf jobs/jenkins.ini update jobs
