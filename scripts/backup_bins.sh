#!/bin/bash
export BINARY_LIST=${CONFIG_DIR}/nightly_binary_list.txt
export DestDir=${BINARIES_BASE}/${PATCH_RELEASE}/
timestamp="`date '+%Y%m%d_%H%M%S'`"
. $BUILD_ENV
cd $CHARGING_HOME/bin
missing_bins=0
expected=0

echo ""  >> ${RESULT_FILE}
echo "========================================================"  >> ${RESULT_FILE}
echo ""  >> ${RESULT_FILE}
echo "Nightly Build For Regression"  >> ${RESULT_FILE}
echo ""  >> ${RESULT_FILE}

for binary in `cat ${BINARY_LIST}`
do
	if ! ls $binary > /dev/null 2>&1
	then
		echo "Binary - $binary not found"  >> ${RESULT_FILE}
		missing_bins=$[$missing_bins +1]
	else
		if [ -d "$DestDir" ]
		then
			echo "Dir exists"
		else
	        mkdir -p $DestDir
		fi

		cp -f $binary $DestDir$binary
		cp -f $binary $DestDir$binary.$timestamp
		echo "Copied Binary to "$DestDir$binary"" >> ${RESULT_FILE}
		echo "Copied Binary to "$DestDir$binary.$timestamp"" >> ${RESULT_FILE}
	fi
	expected=$[$expected +1]
done

echo ""  >> ${RESULT_FILE}

if [ "$missing_bins" == "0" ]
then
	echo "`date '+%H:%M:%S'` All Binaries copied "  >> ${RESULT_FILE}
	echo ""  >> ${RESULT_FILE}
	echo "========================================================"  >> ${RESULT_FILE}
else
	echo "`date '+%H:%M:%S'` Expected "$expected", There were "$missing_bins" binaries not copied"  >> ${RESULT_FILE}
	echo ""  >> ${RESULT_FILE}
	echo "========================================================"  >> ${RESULT_FILE}
fi
