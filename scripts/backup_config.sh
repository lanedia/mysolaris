#!/bin/bash
export CONFIG_LIST=${CONFIG_DIR}/nightly_config_list.txt
export DestDir=${BINARIES_BASE}/${PATCH_RELEASE}/
timestamp="`date '+%Y%m%d_%H%M%S'`"
. $BUILD_ENV
cd $CHARGING_HOME/source/config
missing_config=0
expected=0

echo ""  >> ${RESULT_FILE}
echo "========================================================"  >> ${RESULT_FILE}
echo ""  >> ${RESULT_FILE}
echo "Nightly Build For Regression"  >> ${RESULT_FILE}
echo ""  >> ${RESULT_FILE}

for config in `cat ${CONFIG_LIST}`
do
	if ! ls $config > /dev/null 2>&1
	then
		echo "config - $config not found"  >> ${RESULT_FILE}
		missing_config=$[$missing_config +1]
	else
		if [ -d "$DestDir" ]
		then
			echo "Dir exists"
		else
	        mkdir -p $DestDir
		fi

		cp -f $config $DestDir$config
		cp -f $config $DestDir$config.$timestamp
		echo "Copied Config file to "$DestDir$config"" >> ${RESULT_FILE}
		echo "Copied Config file to "$DestDir$config.$timestamp"" >> ${RESULT_FILE}
	fi
	expected=$[$expected +1]
done

echo ""  >> ${RESULT_FILE}

if [ "$missing_config== "0" ]
then
	echo "`date '+%H:%M:%S'` All Config files copied "  >> ${RESULT_FILE}
	echo ""  >> ${RESULT_FILE}
	echo "========================================================"  >> ${RESULT_FILE}
	exit 0
else
	echo "`date '+%H:%M:%S'` Expected $expected There were $missing_config Config files not copied"  >> ${RESULT_FILE}
	echo ""  >> ${RESULT_FILE}
	echo "========================================================"  >> ${RESULT_FILE}
	exit 1
fi
