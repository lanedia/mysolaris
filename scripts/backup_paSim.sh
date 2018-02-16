#!/bin/bash
export PaSim_LIST=${CONFIG_DIR}/pa-sim.txt
export DestDir=${BINARIES_BASE}/PaSim/${PATCH_RELEASE}/
timestamp="`date '+%Y%m%d_%H%M%S'`"
. $BUILD_ENV
cd $CHARGING_HOME/source/libs/PaymentAgentDispatcher/PaymentAgentSim
missing_files=0
expected=0

echo ""  >> ${RESULT_FILE}
echo "========================================================"  >> ${RESULT_FILE}
echo ""  >> ${RESULT_FILE}
echo "Nightly Build For Regression"  >> ${RESULT_FILE}
echo ""  >> ${RESULT_FILE}

for paSim in `cat ${PaSim_LIST}`
do
	if ! ls $paSim > /dev/null 2>&1
	then
		echo "PaSim - $paSim not found"  >> ${RESULT_FILE}
		missing_files=$[$missing_files +1]
	else
		if [ -d "$DestDir" ]
		then
			echo "Dir exists"
		else
	        mkdir -p $DestDir
		fi

		cp -f $paSim $DestDir$paSim
		cp -f $paSim $DestDir$paSim.$timestamp
		echo "Copied $paSim to "$DestDir$paSim"" >> ${RESULT_FILE}
		echo "Copied $paSim to "$DestDir$paSim.$timestamp"" >> ${RESULT_FILE}
	fi
	expected=$[$expected +1]
done

echo ""  >> ${RESULT_FILE}

if [ "$missing_files" == "0" ]
then
	echo "`date '+%H:%M:%S'` All PaSim files copied "  >> ${RESULT_FILE}
	echo ""  >> ${RESULT_FILE}
	echo "========================================================"  >> ${RESULT_FILE}
else
	echo "`date '+%H:%M:%S'` Expected "$expected", There were "$missing_files" PaSim files not copied"  >> ${RESULT_FILE}
	echo ""  >> ${RESULT_FILE}
	echo "========================================================"  >> ${RESULT_FILE}
fi
