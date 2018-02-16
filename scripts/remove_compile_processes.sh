#!/bin/bash
display_seperator()
{
echo ""   >> ${RESULT_FILE}
echo "========================================================"  >> ${RESULT_FILE}
echo ""   >> ${RESULT_FILE}
}


kill_process()
{
	process_name=$1
	echo "`date '+%H:%M:%S'` Remove $process_name processes" >> ${RESULT_FILE}
	ps -ef | grep $process_name | grep -v grep | awk '{print $2}'|xargs kill -9

}

display_seperator
kill_process "make"
kill_process "Nightly-Build"
kill_process "cvs"
kill_process "ccfe"
kill_process $branch
display_seperator
exit 0
