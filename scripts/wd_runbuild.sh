#!/bin/bash
set -x
script='/export/home/tecnomen/Nightly-Build/scripts/run_build.sh -a'
all_ok=0
while getopts r opt
do
	case ${opt} in
		r)
			script='/export/home/tecnomen/Nightly-Build/scripts/run_build.sh -R -f /export/home/tecnomen/Nightly_Config/regression_branch_list.txt'
			;;
	esac
done
#check that the process is running. Ignore grep and all vi/vim/gvim sessions
ps -eo args |grep -v grep|grep run_build|grep -v vi> /dev/null 2>&1
process_running=$?
echo "process running ${process_running}"
if [ ${process_running} -eq 0 ]
then
    echo "$script already running"
else
    echo "$script not running, starting it"
    ${script} &
    if [ $? -ne 0 ]
    then
        echo "Failed to start ${script}!"
    fi
fi
exit 0

