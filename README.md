# centosci

This repository contains Jenkins job builder files for the Gluster project.
These jobs are run on ci.centos.org using [Jenkins Job Builder][jjb].

[jjb]: http://docs.openstack.org/infra/jenkins-job-builder/


## Guidelines for jobs
* Make sure job names are prefixed with `gluster_`.
* Do not prefix the yml file with `gluster_` as it will make it more difficult
  for human readability and autocompletion.
* Make a folder inside scripts folder for all scripts related to your code.
* Anything in scripts/common is expected to be re-used by multiple jobs.
* Do not curl or wget a script from github and execute it in your job.
