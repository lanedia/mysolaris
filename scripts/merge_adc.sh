#!/bin/env bash
export DATE=`date '+%y%m%d_%H%M%S'`
GIT_DATE=`date '+%y-%m-%d - %H:%M:%S'`
export AUTOBUILDBASE=$HOME/autobuild/
export AUTOBUILDBASE=/net/jupiter/swdev/scripts/autobuild/
export RESULT_FILE=$HOME/nightlybuild_$DATE.txt
export SCRIPTS="$AUTOBUILDBASE/scripts/"
export CONFIG_DIR=$AUTOBUILDBASE/config
export BRANCH_LIST=$CONFIG_DIR/branchlist.txt
export CTP_NAME=`uname -n`
export RESULT_DIR=/net/kore/sem/CGW/NightlyBuildResults/$CTP_NAME/
export BINARIES_BASE=/net/kore/sem/CGW/NightlyBuildBinaries/
export ENV_DIR="$AUTOBUILDBASE/environment/"
export CVS="/net/den/usr/local/bin/cvs"
export TCCSDB="git@git.tecnotree.com:ocs-database/tccsdbase.git"
export VOICE_REPO="http://saturn/svnrepos/prepaid/"
export PPIN_GIT_REPO="git@git.tecnotree.com:ppin/"
export CCS_GIT_REPO="git@git.tecnotree.com:ccs/"
export ADC_GIT_REPO="git@170.51.249.51:git/"
export ADC_GIT_REPO="http://git:tecnomen@170.51.249.51/git/"
export SVN_CHECKOUT="svn checkout --username tecnomen --password tecnomen "
export SCM_GROUP="PPIN"

CMLIBRARY=~/releases/lib/
multiple_branches=true
automated=false
run_regression=false
checkout_code=false
compile_code=false
verify_code=false
update_config=true
create_patch=false
create_base_patch=false
jenkins_status=true
generate_tag=false
use_tag=false

EMAIL_SUBJECT=""
EMAIL_LIST="CCS-RBM-NIGHTLYBUILD@tecnotree.com"
EMAIL_LIST_FAIL="PPIN.Scrum.Team@tecnotree.com"
WARNINGS=""
known_warnings=0
SAVE_OUTPUT_BACKUP=0
compiled=true

compile_status=false
MERGE=false

DevGroup="rbm" # setting default to RBM group - initial nightly build..
#DevGroup="sma" # setting default to SMA group - initial nightly build..

export PATCH_NUM='1' # Setting default to 1.
export VERSION='4100200' # Setting default to 4100200.
export OUTPUT_DIR=${RESULT_DIR}${DATE}
#Diarmuid

function display_seperator()
{
LogAndEcho ""
LogAndEcho "=========================================================================="
LogAndEcho ""
}


# This is a wrapper function for svn checkout of the SVN_REPO repository base.
#
function checkout_svn()
{
`env > $HOME/$branch-env.txt`
	if [ `hostname` == "ctp-1-rbm-bld" ]; then
		export SVN_CHECKOUT="svn checkout --username ${LOGNAME} --password ${LOGNAME} "
	fi
	if [ $# -eq 1 ]; then
		SVN_REPO=$1
	else
		SVN_REPO=$VOICE_REPO
		if [ $use_tag == "true" ]; then
			SVN_REPO="$SVN_REPO/tags/"
		else
			SVN_REPO="$SVN_REPO/branches/"
		fi
	fi
	if [ ! -d $BASE_PROJ_DIR ]; then
		LogAndEcho "$SVN_CHECKOUT $SVN_REPO/$branch $BASE_PROJ_DIR "
		$SVN_CHECKOUT $SVN_REPO/$branch $BASE_PROJ_DIR 
	else
		LogAndEcho "svn update"
		cd $BASE_PROJ_DIR
		svn update
	fi

}

# This is a wrapper function for GIT checkout of the GIT_REPO repository base.
#
function checkout_git()
{
if [ "$SCM_GROUP" == "CCS" ]; then
    PPIN_GIT_REPO=$CCS_GIT_REPO
elif [ "$SCM_GROUP" == "ADC" ]; then
    PPIN_GIT_REPO=$ADC_GIT_REPO
else
    PPIN_GIT_REPO="git@git.tecnotree.com:ppin/"
fi
	if [ $# -eq 1 ]; then
		if [[ "$DevGroup" == "rbm" || "$DevGroup" == "data" ]]; then
			GIT_REPO="${PPIN_GIT_REPO}data.git"
		elif [ "$DevGroup" == "voice" ]; then
			GIT_REPO="${PPIN_GIT_REPO}voice.git"
		elif [ "$DevGroup" == "sma" ]; then
			GIT_REPO="${PPIN_GIT_REPO}sma.git"
		elif [ "$DevGroup" == "pom" ]; then
			GIT_REPO="${PPIN_GIT_REPO}pom.git"
		elif [[ "$DevGroup" == "smi" || "$SCM_GROUP" == "CCS" ]]; then
                	GIT_REPO="${PPIN_GIT_REPO}smi.git"
		elif [[ "$DevGroup" == "sss" || "$SCM_GROUP" == "CCS" ]]; then
			GIT_REPO="${PPIN_GIT_REPO}sss.git"
		fi
	else
		GIT_REPO=$TCCSDB
	fi
	if [ `hostname` == "ctp-1-rbm-bld" ]; then
		if [ -d $BASE_PROJ_DIR ]; then
			rm -rf $BASE_PROJ_DIR
		fi
		LogAndEcho "git clone $GIT_REPO $BASE_PROJ_DIR --single-branch --branch $branch"
		git clone $GIT_REPO $BASE_PROJ_DIR --single-branch --branch $branch --depth 1
		if [ "$DevGroup" == "sma" ]; then
			cd $BASE_PROJ_DIR
			git update-index --skip-worktree $BASE_PROJ_DIR/custcare/etc/env.sh $BASE_PROJ_DIR/custcare/src/apps/Payment/scripts/smReverseChargeRequest.sh
		fi
	else
		if [ ! -d $BASE_PROJ_DIR ]; then
			LogAndEcho "git clone $GIT_REPO $BASE_PROJ_DIR --branch $branch"
			#git clone $GIT_REPO $BASE_PROJ_DIR --branch $branch 
                        git clone $GIT_REPO $BASE_PROJ_DIR --single-branch --branch $branch --depth 1
			if [ "$DevGroup" == "sma" ]; then
				cd $BASE_PROJ_DIR
				git update-index --skip-worktree $BASE_PROJ_DIR/custcare/etc/env.sh $BASE_PROJ_DIR/custcare/src/apps/Payment/scripts/smReverseChargeRequest.sh
			fi
		else
			LogAndEcho "git pull"
			cd $BASE_PROJ_DIR
			git pull
		fi
	fi

}
# This is a wrapper function for GIT checkout of the GIT_REPO repository base.
#
function git_push()
{
if [ "$SCM_GROUP" == "CCS" ]; then
    PPIN_GIT_REPO=$CCS_GIT_REPO
elif [ "$SCM_GROUP" == "ADC" ]; then
    PPIN_GIT_REPO=$ADC_GIT_REPO
fi
if [ $# -eq 1 ]; then
    if [[ "$DevGroup" == "rbm" || "$DevGroup" == "data" ]]; then
        GIT_REPO="${PPIN_GIT_REPO}data.git"
    elif [ "$DevGroup" == "voice" ]; then
        GIT_REPO="${PPIN_GIT_REPO}voice.git"
    elif [ "$DevGroup" == "sma" ]; then
        GIT_REPO="${PPIN_GIT_REPO}sma.git"
    elif [ "$DevGroup" == "pom" ]; then
        GIT_REPO="${PPIN_GIT_REPO}pom.git"
    elif [[ "$DevGroup" == "smi" || "$SCM_GROUP" == "CCS" ]]; then
        GIT_REPO="${PPIN_GIT_REPO}smi.git"
    elif [[ "$DevGroup" == "sss" || "$SCM_GROUP" == "CCS" ]]; then
        GIT_REPO="${PPIN_GIT_REPO}sss.git"
    fi
else
    GIT_REPO=$TCCSDB
fi
if [ `hostname` == "ctp-1-rbm-bld" ]; then
    if [ -d $BASE_PROJ_DIR ]; then
        rm -rf $BASE_PROJ_DIR
    fi
    LogAndEcho "git clone $GIT_REPO $BASE_PROJ_DIR --single-branch --branch $branch"
    git clone $GIT_REPO $BASE_PROJ_DIR --single-branch --branch $branch --depth 1
    if [ "$DevGroup" == "sma" ]; then
        cd $BASE_PROJ_DIR
        git update-index --skip-worktree $BASE_PROJ_DIR/custcare/etc/env.sh $BASE_PROJ_DIR/custcare/src/apps/Payment/scripts/smReverseChargeRequest.sh
    fi
else
    if [ ! -d $BASE_PROJ_DIR ]; then
        LogAndEcho "git clone $GIT_REPO $BASE_PROJ_DIR --branch $branch"
        git clone $GIT_REPO $BASE_PROJ_DIR --branch $branch 
        if [ "$DevGroup" == "sma" ]; then
            cd $BASE_PROJ_DIR
            git update-index --skip-worktree $BASE_PROJ_DIR/custcare/etc/env.sh $BASE_PROJ_DIR/custcare/src/apps/Payment/scripts/smReverseChargeRequest.sh
        fi
    else
        LogAndEcho "git pull"
        cd $BASE_PROJ_DIR
        git pull
    fi
fi

}

# This is a wrapper function for CVS checkout of the CCS code base.
#
function checkout_pom_cvs()
{
	if [ `hostname` == "ctp-1-rbm-bld" ]; then
		local v_cvspass=":pserver:ccsbld:tecnomen@jupiter:2401/export/home/tocs/cvsroot"
	else
		local v_cvspass=":pserver:${LOGNAME}:tecnomen@jupiter:2401/export/home/tocs/cvsroot"
	fi
	local v_commoncvspass=$v_cvspass
	local CHECKOUT_BRANCH=""
	local BRANCH=trunk
	local v_cvspass=":pserver:mccorda:mcc0rda@jupiter:/export/home/ipduser/cvsroot"
	local dev_code="in"
	local test_code="intest"

	if [ $# -eq 1 ]; then
		BRANCH=$1
		CHECKOUT_BRANCH="-r $BRANCH"
		local DevBranch=`echo $1|tr '[:upper:]' '[:lower:]'`
		if [ "$BRANCH" == "trunk" ]; then
			CHECKOUT_BRANCH=""
		fi
	fi
	cd $HOME
	$CVS -d $v_cvspass login
	if [ "$ITERATIVE_BUILD" == "true" ] && [ -d "$PROJECT" ]; then
		LogAndEcho "Iterative Build  branch=$BRANCH, PROJECT=$PROJECT"
		local v_cvscommand="update -d"
	elif [ "$update_code" == "true" ] && [ -d "$PROJECT" ]; then
		LogAndEcho "Update Build  branch=$BRANCH, PROJECT=$PROJECT"
		local v_cvscommand="update -d"
	else
		local v_cvscommand="co $CHECKOUT_BRANCH $dev_code $dev_code"
		local v_cvstestcommand="co $CHECKOUT_BRANCH $test_code $test_code"
		LogAndEcho "Non iterative build, branch =$BRANCH, PROJECT=$PROJECT ...... mkdir $PROJECT"
		rm -rf $PROJECT/in
		rm -rf $PROJECT/intest
		mkdir -p $PROJECT
	fi
	cd $PROJECT/
	LogAndEcho ""
	LogAndEcho "$CVS -d $v_cvspass $v_cvscommand "
	$CVS -d $v_cvspass $v_cvscommand  >/dev/null
	LogAndEcho "$CVS -d $v_cvspass $v_cvstestcommand "
	$CVS -d $v_cvspass $v_cvstestcommand  >/dev/null

	display_seperator
}
# This is a wrapper function for CVS checkout of the CCS code base.
function checkout_ccs_cvs()
{
	if [ `hostname` == "ctp-1-rbm-bld" ]; then
		local v_cvspass=":pserver:ccsbld:tecnomen@jupiter:2401/export/home/tocs/cvsroot"
	else
		local v_cvspass=":pserver:${LOGNAME}:tecnomen@jupiter:2401/export/home/tocs/cvsroot"
	fi
	local v_commoncvspass=$v_cvspass
	local TOCS_HOME=""
	# overwrite v_cvspass for different groups.
	# v_commoncvspass is shared between RBM & SMA pre Phase 3, slice 2.3
	if [[ "$DevGroup" == "rbm" || "$DevGroup" == "data" ]]; then
		local l_group="tocs"
		local l_source="-dsource"
		TOCS_HOME="tocs"
	elif [ "$DevGroup" == "sma" ]; then
		local v_cvspass=":pserver:ccsbld:tecnomen@jupiter:/export/share/custcare/cvsroot"
		local l_group="custcare"
		local l_source=""
	fi

	local COMMON_BRANCH=CGW_branch
	local CHECKOUT_BRANCH=""
	local BRANCH=CGW_2.40.a
	if [ $# -eq 1 ]; then
		BRANCH=$1
		CHECKOUT_BRANCH="-r $BRANCH"
		COMMON_BRANCH="$BRANCH"
	fi
	cd $HOME
	$CVS -d $v_cvspass login
	if [ "$ITERATIVE_BUILD" == "true" ] && [ -d "$PROJECT" ]; then
		LogAndEcho "Iterative Build  branch=$BRANCH, PROJECT=$PROJECT"
		local v_cvscommand="update -d"
		local v_cvscommoncmd=$v_cvscommand
	elif [ "$update_code" == "true" ] && [ -d "$PROJECT" ]; then
		LogAndEcho "Update Build  branch=$BRANCH, PROJECT=$PROJECT"
		local v_cvscommand="update -d"
		local v_cvscommoncmd=$v_cvscommand
	else
		local v_cvscommand="co $CHECKOUT_BRANCH $l_source $l_group"
		local v_cvscommoncmd="co -r $COMMON_BRANCH common"
		LogAndEcho "Non iterative build, branch =$BRANCH, PROJECT=$PROJECT ...... mkdir $PROJECT"
		rm -rf $PROJECT/../tocs
		mkdir -p $PROJECT
	fi
	cd $PROJECT/../$TOCS_HOME
	LogAndEcho ""
	LogAndEcho "$CVS -d $v_cvspass $v_cvscommand "
	$CVS -d $v_cvspass $v_cvscommand  >/dev/null
	. $BUILD_ENV

	if [[ $PKG_RELEASE != *11.00* && ! "$DevGroup" == "sma" && ! "$DevGroup" == "pom" ]]
	then
		#mkdir -p $PROJECT/../common
		cd $PROJECT/../
		LogAndEcho "$CVS -d $v_commoncvspass $v_cvscommoncmd "
		$CVS -d $v_commoncvspass $v_cvscommoncmd  >/dev/null
	fi
	display_seperator
}
# This is a wrapper function for CVS checkout of the CCS code base.
#
function checkout_cvs()
{
	if [ `hostname` == "ctp-1-rbm-bld" ]; then
		local v_cvspass=":pserver:ccsbld:tecnomen@jupiter:2401/export/home/tocs/cvsroot"
	else
		local v_cvspass=":pserver:${LOGNAME}:tecnomen@jupiter:2401/export/home/tocs/cvsroot"
	fi
	local v_commoncvspass=$v_cvspass
	local TOCS_HOME=""
	# overwrite v_cvspass for different groups.
	# v_commoncvspass is shared between RBM & SMA pre Phase 3, slice 2.3
	if [ "$DevGroup" == "pom" ]; then
		local v_cvspass=":pserver:mccorda:mcc0rda@jupiter:/export/home/ipduser/cvsroot"
		local l_group="in"
		local l_source=""
	else
		LogAndEcho "$DevGroup code not in cvs "
		exit 1
	fi

	local CHECKOUT_BRANCH=""
	if [ $# -eq 1 ]; then
		BRANCH="$1"
		CHECKOUT_BRANCH="-r $BRANCH"
	else
		LogAndEcho "No branch specified"
		exit 1
	fi
	cd $HOME
	if [ "$ITERATIVE_BUILD" == "true" ] && [ -d "$PROJECT" ]; then
		LogAndEcho "Iterative Build  branch=$BRANCH, PROJECT=$PROJECT"
		local v_cvscommand="update -d"
		local v_cvscommoncmd=$v_cvscommand
	elif [ "$update_code" == "true" ] && [ -d "$PROJECT" ]; then
		LogAndEcho "Update Build  branch=$BRANCH, PROJECT=$PROJECT"
		local v_cvscommand="update -d"
		local v_cvscommoncmd=$v_cvscommand
	else
		local v_cvscommand="co $CHECKOUT_BRANCH $l_source $l_group"
		LogAndEcho "Non iterative build, branch =$BRANCH, PROJECT=$PROJECT ...... mkdir $PROJECT"
		rm -rf $PROJECT
		mkdir -p $PROJECT
	fi
	cd $PROJECT/
	LogAndEcho ""
	pwd
	ls -larth
	LogAndEcho "$CVS -d $v_cvspass $v_cvscommand "
	$CVS -d $v_cvspass $v_cvscommand  >/dev/null
	. $BUILD_ENV

	display_seperator
}

 function verify()
 {
	missing_files=0
	VERIFY_LIST=$1
	expected=0
	TEMP_VERIFY_LIST=$CONFIG_DIR/$MY_BRANCH-verify.txt

	if [ -f $TEMP_VERIFY_LIST ]
	then
		VERIFY_LIST=$TEMP_VERIFY_LIST
	fi
	LogAndEcho "Using $VERIFY_LIST to verify $1"
	LogAndEcho "Currently in `pwd`, PROJECT=$PROJECT"

	/net/jupiter/swdev/scripts/checker.sh $VERIFY_LIST
	missing_files=$?
	expected=`cat $VERIFY_LIST|wc -l`
	if [ "$missing_files" == "0" ]
	then
		compile_status=true
		compiled=true
		LogAndEcho "All ($expected) $1 Files created "
		LogAndEcho "Build OK on $1"
		EMAIL_SUBJECT="Compiled OK"
	else
		LogAndEcho "Expected $expected, There were $missing_files missing $1 files"
		LogAndEcho "Build Failed against $1" $RED
		EMAIL_SUBJECT="Failed to compile"
		EMAIL_LIST=$EMAIL_LIST_FAIL
		compile_status=false
		jenkins_status=false
		compiled=false
		SAVE_OUTPUT_BACKUP=1
	fi
}

# Compare the warnings in the code compilation.
# There are currently some warnings which are not being removed.
# We want to prevent new warnings being added
# If new warnings added, we change the EMAIL_LIST to include all CCS-RBM
function check_warnings()
{
	# Grab the number of warnings located in the code.
	# There are different amounts of acceptable #warnings in different groups.
	num_warnings=`grep "Warning(s)" $MAKE_OUTPUT//*std*.txt|wc -l`
	
	rbm_set_warnings

	if [ "${num_warnings}" == "${known_warnings}" ]
	then
   		LogAndEcho "No Extra Warning(s) added to code"
	elif [ "${num_warnings}" -lt "${known_warnings}" ]
	then
		WARNINGS=" - Number of warnings has been reduced"
   		LogAndEcho "$WARNINGS"
		LogAndEcho "Known/Legacy #warnings = ${known_warnings}"
		LogAndEcho "Current/New #warnings = ${num_warnings}"
		LogAndEcho ""  
	else	
		EMAIL_LIST=$EMAIL_LIST_FAIL
		SAVE_OUTPUT_BACKUP=1
		WARNINGS=" - There are Extra Warning(s) added to code"
   		LogAndEcho "$WARNINGS" $RED
		LogAndEcho "Known/Legacy #warnings = ${known_warnings}"
		LogAndEcho "Current/New #warnings = ${num_warnings}"
		LogAndEcho ""
	fi
}

# The CCS-RBM libraries are to be backed up to a shared location for further builds.
# CCS-SMA phase3 is compiled against these shared libraries.
# In future other groups will have a similar backup.
function backup_libraries()
{
	if [[ "$DevGroup" == "rbm" || "$DevGroup" == "data" ]]; then
		if [ "$branch" == "Cgw_TIP" ]; then
			if [ "$compiled" == "true" ]; then
				if [ "$COMPILER_TYPE" == "g++" ]; then
					CMLIBRARY=$CMLIBRARY/lib-g++
				else
					CMLIBRARY=$CMLIBRARY/lib-cc
				fi

				LogAndEcho "Backup $DevGroup libraries to $CMLIBRARY"
				mkdir -p $CMLIBRARY
				cp -fp $CHARGING_HOME/lib//* $CMLIBRARY/
			fi
		fi
	fi
}
# If run_regression is set, we are to backup the files.
# These are backed up to kore and details will be included in the email.
function backup_files()
{
	if [ "$compiled" = true ]; then
		if [[ $PKG_RELEASE == *10.00* || $PKG_RELEASE == *11.00* ]]; then
			if [ "${run_regression}" == "true" ]; then
				$SCRIPTS/backup_bins.sh
				$SCRIPTS/backup_config.sh
			fi
			$SCRIPTS/backup_paSim.sh
		fi
	fi
}


function verify_rbm()
{
	local simulator_status=0
	local jar_status=0
	local bin_status=0
	local libs_status=0
	
	# verify the jar files created
	if [ -f $PROJECT/source/etc/jars-list.txt ]; then
		verify "$PROJECT/source/etc/jars-list.txt"
	elif [ -f $CONFIG_DIR/$MY_BRANCH-jar-list.txt ]; then
		verify "$CONFIG_DIR/$MY_BRANCH-jar-list.txt"
	else
		verify "$CONFIG_DIR/jar-list.txt"
	fi
	jar_status=$missing_files
	# verify the bin files created
	# Verify the commercial binaries first, then verify the PA simulator.
	# If Either are missing, we fail.
	if [ -f $PROJECT/source/etc/bin-list.txt ]; then
		verify "$PROJECT/source/etc/bin-list.txt"
	elif [ -f $CONFIG_DIR/$MY_BRANCH-binary-list.txt ]; then
		verify "$CONFIG_DIR/$MY_BRANCH-binary-list.txt"
	else
		verify "$CONFIG_DIR/binary-list.txt"
	fi
	bin_status=$missing_files

	# verify the libs files created
	if [ -f $PROJECT/source/etc/lib-list.txt ]; then
		verify "$PROJECT/source/etc/lib-list.txt"
	elif [ -f $CONFIG_DIR/$MY_BRANCH-libs-list.txt ]; then
		verify "$CONFIG_DIR/$MY_BRANCH-libs-list.txt"
	else
		verify "$CONFIG_DIR/libs-list.txt"
	fi
	libs_status=$missing_files

	if [ "$bin_status" == "0" ] && [ "$jar_status" == "0" ] && [ "$libs_status" == "0" ]; then
		compile_status=true
		jenkins_status=true
	else
		EMAIL_SUBJECT="Failed to compile"
		EMAIL_LIST=$EMAIL_LIST_FAIL
		compile_status=false
		jenkins_status=false
		compiled=false
		SAVE_OUTPUT_BACKUP=1
	fi
	display_seperator

}

function verify_sma()
{
	local build_status=0
	
	if [ -f $PROJECT/etc/checklist.txt ]; then
		verify "$PROJECT/etc/checklist.txt"
	else
		verify "$CONFIG_DIR/sma_checklist.txt"
	fi
	# verify the files created
	build_status=$missing_files

	display_seperator

}

function verify_other()
{
	local build_status=0
	
	local checklist=$CONFIG_DIR/base_checklist.txt
	if [[ "$DevGroup" == "voice" || "$DevGroup" == "brt" ]]; then
		checklist=$CONFIG_DIR/voice_checklist.txt
	elif [ "$DevGroup" == "pom" ]; then
    	cd $PROJECT/
		if [ -d in ]; then
    		export PROJECT=$PROJECT/in/
		fi
		checklist=$CONFIG_DIR/pom_checklist.txt
	fi
	verify "$checklist"
	build_status=$missing_files

	display_seperator

}

function verify_build()
{
	LogAndEcho "verify_build "
	if [[ "$DevGroup" == "rbm" || "$DevGroup" == "data" ]]; then
		verify_rbm
	elif [ "$DevGroup" == "sma" ]; then
		verify_sma
	else
		verify_other
		#LogAndEcho "Invalid group"
	fi

	if [ "$compile_code" == "true" ]; then
	{
		backup_libraries

		organise_logs

		if [[ "$DevGroup" == "rbm" || "$DevGroup" == "data" ]]; then
			#Backup binary & config files for RBM Phase 1 releasing.
			backup_files
		fi
	}
	fi
}
function compile_ccs()
{
	# compile the code
	LogAndEcho "Compile $DevGroup"
	if [[ "$DevGroup" == "rbm" || "$DevGroup" == "data" ]]; then
		if [[ $PKG_RELEASE != *11.00* ]]
		then
			cd $PROJECT/../common
			LogAndEcho "Build `pwd`"
			make > $MAKE_OUTPUT/common_stdout.txt 2> $MAKE_OUTPUT/common_stderr.txt
		else	
			LogAndEcho "Common has been migrated to RBMCommon "
		fi
		cd $PROJECT/source
		LogAndEcho "Build `pwd`"
		make > $MAKE_OUTPUT/source_stdout.txt 2> $MAKE_OUTPUT/source_stderr.txt

	elif [[ "$DevGroup" == "voice" || "$DevGroup" == "brt" ]]; then
		cd $PROJECT/
		make clean > $MAKE_OUTPUT/source_stdout.txt 2> $MAKE_OUTPUT/source_stderr.txt
		make > $MAKE_OUTPUT/source_stdout.txt 2> $MAKE_OUTPUT/source_stderr.txt
	elif [ "$DevGroup" == "sma" ]; then
		sma_compile
		#sma_compile_fast
	elif [ "$DevGroup" == "pom" ]; then
		pom_compile
	fi

	if [[ "$DevGroup" == "rbm" || "$DevGroup" == "data" ]]; then
		if [[ $PKG_RELEASE == *10.00* ]]
		then
			LogAndEcho "Build PaymentAgentProxy"
			cd $PROJECT/source/apps/PaymentAgentProxy
			make  > $MAKE_OUTPUT/paproxy_stdout.txt 2> $MAKE_OUTPUT/paproxy_stderr.txt
			cd $PROJECT/source/java/PA/server/
			make  >> $MAKE_OUTPUT/paproxy_stdout.txt 2>> $MAKE_OUTPUT/paproxy_stderr.txt
		fi

		if [[ $PKG_RELEASE == *10.00* || $PKG_RELEASE == *11.00* ]]
		then
			LogAndEcho "Build PaymentAgentSimulator"
			cd $PROJECT/source/libs/PaymentAgentDispatcher/PaymentAgentSim
			make  > $MAKE_OUTPUT/pasim_stdout.txt 2> $MAKE_OUTPUT/pasim_stderr.txt
			LogAndEcho ""  
			PA_SIM=$CHARGING_HOME/source/libs/PaymentAgentDispatcher/PaymentAgentSim/PaymentAgentServerSimulator
			if ! ls $PA_SIM > /dev/null 2>&1
			then
				LogAndEcho "Simulator Binary - $PA_SIM not found" $RED
				LogAndEcho "Build Failed on PA Simulator Binary" $RED
				simulator_status=1
			fi
		fi
	fi
}

# SMA Compile - temp compile function :)
function sma_compile_fast()
{
	LogAndEcho "Start $VERSION SMA compilation `pwd`"
	LogAndEcho "$PROJECT"
	cd $PROJECT/etc/
	. $BUILD_ENV
	cd $SOURCE_ROOT
	LogAndEcho "make tidy $VERSION @ `pwd`"
	make tidy $VERSION > $MAKE_OUTPUT/maketidy_stdout.txt 2> $MAKE_OUTPUT/maketidy_stderr.txt

	. $BUILD_ENV
	cd $PROJECT/src/lib
	LogAndEcho "make headers @ `pwd`"
	make headers > $MAKE_OUTPUT/lib_headers_stdout.txt 2> $MAKE_OUTPUT/lib_headers_stderr.txt
	cd $PROJECT/src/idls
	LogAndEcho "make headers @ `pwd`"
	make headers > $MAKE_OUTPUT/idls_headers_stdout.txt 2> $MAKE_OUTPUT/idls_headers_stderr.txt

	for build_dir in `ls $PROJECT/src/idls` 
	do
#	LogAndEcho "DEBUG idls- $build_dir"
		if [[ ! $build_dir == "CVS" && ! $build_dir == "Makefile" ]]; then
			cd $PROJECT/src/idls/$build_dir
#	LogAndEcho "xxDEBUG idls- $build_dir"
			stdout=idls_${build_dir}_stdout.txt
			stderr=idls_${build_dir}_stderr.txt
			LogAndEcho "make @ `pwd`: $stderr $stdout"
			make > $MAKE_OUTPUT/$stdout 2> $MAKE_OUTPUT/$stderr&
		fi
	done
	wait

	for build_dir in `ls $PROJECT/src/lib` 
	do
#	LogAndEcho "DEBUG lib- $build_dir"
		if [[ ! $build_dir == "CVS" && ! $build_dir == "Makefile" ]]; then
			cd $PROJECT/src/lib/$build_dir
#	LogAndEcho "xxDEBUG lib- $build_dir"
			stdout=lib_${build_dir}_stdout.txt
			stderr=lib_${build_dir}_stderr.txt
			LogAndEcho "make @ `pwd`: $stderr $stdout"
			make > $MAKE_OUTPUT/$stdout 2> $MAKE_OUTPUT/$stderr&
		fi
	done
	cd $PROJECT/src/apps/Common
	LogAndEcho "make @ `pwd`"
	make > $MAKE_OUTPUT/apps_Common_stdout.txt 2> $MAKE_OUTPUT/apps_Common_stderr.txt&
	#make debug> $MAKE_OUTPUT/apps_Common_debug_stdout.txt 2> $MAKE_OUTPUT/apps_Common_debug_stderr.txt&
	#make nodebug> $MAKE_OUTPUT/apps_Common_nodebug_stdout.txt 2> $MAKE_OUTPUT/apps_Common_nodebug_stderr.txt&
	wait

	cd $PROJECT/src/apps
	for build_dir in `ls $PROJECT/src/apps` 
	do
#	LogAndEcho "DEBUG apps- $build_dir"
		if [[ ! $build_dir == "CVS" && ! $build_dir == "Common" ]]; then
		#if [[ ! $build_dir == "Common" && ! $build_dir == "CVS" && $build_dir == "Makefile" ]]; then
			cd $PROJECT/src/apps/$build_dir
#	LogAndEcho "xxDEBUG apps- $build_dir"
			stdout=apps_${build_dir}_stdout.txt
			stderr=apps_${build_dir}_stderr.txt
			LogAndEcho "make @ `pwd`"
			make > $MAKE_OUTPUT/$stdout 2> $MAKE_OUTPUT/$stderr&
		fi
	done
	cd ${SOURCE_ROOT}/src/java/
	LogAndEcho "make clean @ `pwd`"
	make clean > $MAKE_OUTPUT/java_stdout.txt 2> $MAKE_OUTPUT/java_stderr.txt
	LogAndEcho "make @ `pwd`"
	make > $MAKE_OUTPUT/java_stdout.txt 2> $MAKE_OUTPUT/java_stderr.txt
	LogAndEcho "make release @ `pwd`"
	make release > $MAKE_OUTPUT/java_stdout.txt 2> $MAKE_OUTPUT/java_stderr.txt
	wait
 	LogAndEcho "End SMA compilation"
}
function sma_compile()
{
	LogAndEcho "Start $VERSION SMA compilation `pwd`"
	LogAndEcho "$PROJECT"
	cd $PROJECT/etc/
	. $BUILD_ENV
	cd $SOURCE_ROOT
	LogAndEcho "make tidy $VERSION @ `pwd`"
	make tidy $VERSION > $MAKE_OUTPUT/maketidy_stdout.txt 2> $MAKE_OUTPUT/maketidy_stderr.txt
	cd $PROJECT/etc/
	. $BUILD_ENV

	# Make idls headers
	cd $COMMON/src/idls
	LogAndEcho "make headers @ `pwd`"
	make headers > $MAKE_OUTPUT/idls_headers_stdout.txt 2> $MAKE_OUTPUT/idls_headers_stderr.txt

	# Make lib headers
	cd $PROJECT/src/lib
	LogAndEcho "make headers @ `pwd`"
	make headers > $MAKE_OUTPUT/lib_headers_stdout.txt 2> $MAKE_OUTPUT/lib_headers_stderr.txt

	# Make idls
	cd $COMMON/src/idls
	LogAndEcho "make @ `pwd`"
	make > $MAKE_OUTPUT/idls_stdout.txt 2> $MAKE_OUTPUT/idls_stderr.txt

	# Make lib
	cd $PROJECT/src/lib
	LogAndEcho "make @ `pwd`"
	make > $MAKE_OUTPUT/lib_stdout.txt 2> $MAKE_OUTPUT/lib_stderr.txt

	# Make apps
	cd $PROJECT/src/apps
	LogAndEcho "make @ `pwd`"
	make > $MAKE_OUTPUT/apps_stdout.txt 2> $MAKE_OUTPUT/apps_stderr.txt

	# Make java
	cd ${SOURCE_ROOT}/src/java/
	LogAndEcho "make clean @ `pwd`"
	make clean > $MAKE_OUTPUT/java_stdout.txt 2> $MAKE_OUTPUT/java_stderr.txt
	LogAndEcho "make @ `pwd`"
	make > $MAKE_OUTPUT/java_stdout.txt 2> $MAKE_OUTPUT/java_stderr.txt
	LogAndEcho "make release @ `pwd`"
	make release > $MAKE_OUTPUT/java_stdout.txt 2> $MAKE_OUTPUT/java_stderr.txt
 	LogAndEcho "End SMA compilation"
}

# SSS Compile - temp compile function :)
function pom_compile()
{
	LogAndEcho "Start SSS compilation"
    cd $PROJECT/
	if [ -d in ]; then
		cd in
	fi
	LogAndEcho "Build `pwd`"
	make clean > $MAKE_OUTPUT/in_stdout.txt 2> $MAKE_OUTPUT/in_stderr.txt
	make > $MAKE_OUTPUT/in_stdout.txt 2> $MAKE_OUTPUT/in_stderr.txt
    cd $PROJECT/
	if [ -d intest ]; then
		cd intest
		LogAndEcho "Build `pwd`"
		make clean > $MAKE_OUTPUT/intest_stdout.txt 2> $MAKE_OUTPUT/intest_stderr.txt
		make > $MAKE_OUTPUT/intest_stdout.txt 2> $MAKE_OUTPUT/intest_stderr.txt
	fi
 	LogAndEcho "End SSS compilation"
}

function organise_logs()
{
	#If there are NO warnings or build failures, remove the temp output files.
	if [ "${SAVE_OUTPUT_BACKUP}" == "0" ]; then
		rm $MAKE_OUTPUT//*_stderr.txt
		rm $MAKE_OUTPUT//*_stdout.txt
	else
	#If there are warnings or build failures, save the output files and include them in the email.
		display_seperator
		LogAndEcho "Trace Output can be found @ http://kore.tecnomen.net/sem/TACC/NightlyBuildResults/${CTP_NAME}/${DATE}_${MY_BRANCH}/"

		if [ -d "${OUTPUT_BACKUP}" ]; then
			LogAndEcho "${OUTPUT_BACKUP} exists"
		else
			mkdir ${OUTPUT_BACKUP}
			LogAndEcho "mkdir ${OUTPUT_BACKUP} "
		fi
		mv $MAKE_OUTPUT//*_stderr.txt ${OUTPUT_BACKUP}
		mv $MAKE_OUTPUT//*_stdout.txt ${OUTPUT_BACKUP}
	fi
}
# Send the notification email and return success/fail to caling script.
function generate_email_alert()
{
		LogAndEcho "Checking whether to send email or not to $EMAIL_LIST"
	if [ `hostname` == "ctp-1-rbm-bld" ]; then
		if [ "$compiled" = false ]; then
			cat ${RESULT_FILE} | mailx -s "$DevGroup : ${MY_BRANCH} $EMAIL_SUBJECT" $EMAIL_LIST
		else
			cat ${RESULT_FILE} | mailx -s "$DevGroup : ${MY_BRANCH} $EMAIL_SUBJECT $WARNINGS" $EMAIL_LIST
		fi
	else
		LogAndEcho "Development environment, not generating email to everyone"
	fi
}

function setup_email_lists()
{
	if [[ "$SCM_GROUP" == "PPIN" || "$DevGroup" == "data" ]]; then
		EMAIL_LIST="CCS-RBM-NIGHTLYBUILD@tecnotree.com"
		EMAIL_LIST_FAIL="PPIN.Scrum.Team@tecnotree.com"
	elif [ "$DevGroup" == "CCS" ]; then
		EMAIL_LIST="diarmuid.lane@tecnotree.com himanshu.Malla@tecnotree.com"
		EMAIL_LIST_FAIL="PPIN.Scrum.Team@tecnotree.com"
	fi
	
	# Debug mode - set email alert to me only
	#EMAIL_LIST="diarmuid.lane@tecnotree.com"
	#EMAIL_LIST_FAIL="diarmuid.lane@tecnotree.com"
}

function rbm_set_warnings()
{
	if [[ $PKG_RELEASE != *11.00* ]]
	then
		known_warnings=6
	else
		known_warnings=4 # Updated for phase 3.
	fi
}

function build_packages()
{
	# Can only create a base or patch package, not both. Defaulting to base package if both are set.
	if [ "$create_base_patch" == "true" ] && [ "$create_patch" == "true" ] ; then
		LogAndEcho "Setting create_patch = false (base & patch are set true)"
		create_patch=false
	fi
	# If build failed to compile, do not create packages
	if [ "$create_base_patch" == "false" ] && [ "$create_patch" == "false" ] ; then
		LogAndEcho "$DevGroup, Not creating packages for $MY_BRANCH" 
	elif [ "$compile_status" == "false" ]; then
		LogAndEcho "$MY_BRANCH failed to compile. Do not create packages" 
		create_patch=false
		create_base_patch=false
		jenkins_status=false
	else
		if [ "$DevGroup" == "db" ]; then
			LogAndEcho "Building packages for $DevGroup"
			build_db_packages
		elif [[ "$DevGroup" == "rbm" || "$DevGroup" == "data" ]]; then
			build_cgw_packages
		elif [[ "$DevGroup" == "sma" || "$DevGroup" == "smi" ]]; then
			build_sma_packages
		elif [ "$DevGroup" == "voice" ]; then
			build_voice_packages
		elif [[ "$DevGroup" == "pom" || "$DevGroup" == "sss" ]]; then
                        build_pom_packages
		else
			LogAndEcho "Not currently building packages for $DevGroup"
		fi
	fi
}
function build_voice_packages()
{
	GenTag=""
	if [ "generate_tag" == "true" ]; then
		GenTag=" -t"
	fi
	binaryRelease=""
	if [ "BINARYRELEASE" == "true" ]; then
		binaryRelease=" -u"
	fi
    baseCmd=""
    #Here is where we do the packaging if required.
    BASEPKGNAME="IN_Services-Prepaid $NID_RELEASE $PKG_RELEASE_LETTER"
    LogAndEcho "BasePkgName= $DB_TOP"
    LogAndEcho "RELEASE_DIR= $RELEASE_DIR"
    LogAndEcho "BASE_PROJ_DIR = $BASE_PROJ_DIR "
    LogAndEcho "$MY_BRANCH Compiled Successfully"
    rm -rf $HOME/$BASEPKGNAME
    ln -s $BASE_PROJ_DIR $HOME/$DB_TOP
    if [ "$create_base_patch" == "true" ]; then
        LogAndEcho "Create Voice Base Patch"
        baseCmd=" -b"
    elif [ "${create_patch}" == "true" ]; then
        LogAndEcho "Create Patch Package from $BASEPKGNAME"
    else
        return 0
    fi
    LogAndEcho "$AUTOBUILDBASE/packaging/Voice/prepRelease -a -p $BASE_PROJ_DIR $baseCmd $GenTag $binaryRelease"
    $AUTOBUILDBASE/packaging/Voice/prepRelease -a -p $BASE_PROJ_DIR $baseCmd  $GenTag $binaryRelease| tee -a $RESULT_FILE

}

function build_db_packages()
{
	cd $BASE_PROJ_DIR/scripts/build

	#Here is where we do the packaging if required.
	BASEPKGNAME="TCCSD$PKG_RELEASE.$PKG_RELEASE_LETTER"
	LogAndEcho "BasePkgName= $DB_TOP"
	LogAndEcho "RELEASE_DIR= $RELEASE_DIR"
	LogAndEcho "BASE_PROJ_DIR = $BASE_PROJ_DIR " 
	LogAndEcho "$MY_BRANCH Compiled Successfully" 
	rm -rf $HOME/$BASEPKGNAME
	ln -s $BASE_PROJ_DIR $HOME/$DB_TOP
	if [ "$create_base_patch" == "true" ]; then
		LogAndEcho "Create Base Patch $BASEPKGNAME"
		LogAndEcho "$CHARGING_HOME/source/build/dorelease -a -v $DB_TOP"
		$BASE_PROJ_DIR/scripts/build/dorelease -a -v $DB_TOP | tee $RESULT_FILE
	fi

	if [ "${create_patch}" == "true" ]; then
		LogAndEcho "Create Patch Package from $BASEPKGNAME"
		LogAndEcho "$CHARGING_HOME/source/build/dorelease -a -v $BASEPKGNAME -p `/net/jupiter/swdev/ccs/scripts/jira_interface.py -p` -d `/net/jupiter/swdev/ccs/scripts/jira_interface.py -t`"
		#$CHARGING_HOME/source/build/dorelease -a -v $BASEPKGNAME -p `/net/jupiter/swdev/ccs/scripts/jira_interface.py -p` -d `/net/jupiter/swdev/ccs/scripts/jira_interface.py -t`
		$CHARGING_HOME/scripts/build/dorelease -a -v $BASEPKGNAME  | tee $RESULT_FILE
	fi
}


function build_cgw_packages()
{
	GenTag=""
	if [ "$generate_tag" == "true" ]; then
		GenTag=" -t"
	fi
	cd $CHARGING_HOME/source/build
	#Here is where we do the packaging if required.
	BASEPKGNAME="CGW_$PKG_RELEASE.$PKG_RELEASE_LETTER"
	LogAndEcho "BasePkgName= $BASEPKGNAME"
	LogAndEcho "$MY_BRANCH Compiled Successfully" 
	if [[ $PKG_RELEASE != *11.00* ]]
	then
		if [ "$create_base_patch" == "true" ]; then
			LogAndEcho "Create Base Patch $BASEPKGNAME" 
			rm $HOME/$BASEPKGNAME
			ln -s $TOP $HOME/$BASEPKGNAME
			$CHARGING_HOME/source/build/dorelease -a -v $BASEPKGNAME | tee $RESULT_FILE
		fi
		if [ "${create_patch}" == "true" ]; then
			export TOP=$BASEPKGNAME
			LogAndEcho "TOP=$TOP"
			LogAndEcho "COMMON_ROOT= $COMMON_ROOT"
			LogAndEcho "SOURCE_ROOT= $SOURCE_ROOT"
			LogAndEcho "HOME_ROOT= $HOME_ROOT"
			LogAndEcho "Create Patch TINScgwPP-$PATCH_RELEASE"
			LogAndEcho "$CHARGING_HOME/source/build/makePatch $GenTag -a -b TINScgwPP -p $PATCH_RELEASE "
			$CHARGING_HOME/source/build/makePatch $GenTag -a -b TINScgwPP -p $PATCH_RELEASE >> ${RESULT_FILE} 
			LogAndEcho "Create Patch TINScgwDB-$PATCH_RELEASE"
			LogAndEcho "$CHARGING_HOME/source/build/makePatch $GenTag -a -b TINScgwDB -p $PATCH_RELEASE "
			$CHARGING_HOME/source/build/makePatch $GenTag -a -b TINScgwDB -p $PATCH_RELEASE >> ${RESULT_FILE} 
			LogAndEcho "Create Patch TINScgwOTV-$PATCH_RELEASE"
			LogAndEcho "$CHARGING_HOME/source/build/makePatch $GenTag -a -b TINScgwOTV -p $PATCH_RELEASE "
			$CHARGING_HOME/source/build/makePatch $GenTag -a -b TINScgwOTV -p $PATCH_RELEASE >> ${RESULT_FILE} 
		fi
	else
		rm $HOME/$BASEPKGNAME
		ln -s $TOP $HOME/$BASEPKGNAME
		if [ "$create_base_patch" == "true" ]; then
			LogAndEcho "Create Base Patch $BASEPKGNAME"
			LogAndEcho "$CHARGING_HOME/source/build/dorelease -a -v $BASEPKGNAME"
			$CHARGING_HOME/source/build/dorelease -a -v $BASEPKGNAME | tee $RESULT_FILE
			LogAndEcho "$CHARGING_HOME/source/build/dorelease -o -a -v $BASEPKGNAME"
			$CHARGING_HOME/source/build/dorelease -o -a -v $BASEPKGNAME | tee $RESULT_FILE
		fi
			if [ "${create_patch}" == "true" ]; then
				LogAndEcho "Create Patch Package from $BASEPKGNAME"
				LogAndEcho "$CHARGING_HOME/source/build/dorelease -a -v $BASEPKGNAME -p `/net/jupiter/swdev/ccs/scripts/jira_interface.py -p` -d `/net/jupiter/swdev/ccs/scripts/jira_interface.py -t`"
				$CHARGING_HOME/source/build/dorelease -a -v $BASEPKGNAME -p `/net/jupiter/swdev/ccs/scripts/jira_interface.py -p` -d `/net/jupiter/swdev/ccs/scripts/jira_interface.py -t` | tee $RESULT_FILE
				LogAndEcho "$CHARGING_HOME/source/build/dorelease -a -o -v $BASEPKGNAME -p `/net/jupiter/swdev/ccs/scripts/jira_interface.py -p` -d `/net/jupiter/swdev/ccs/scripts/jira_interface.py -t`"
				$CHARGING_HOME/source/build/dorelease -a -o -v $BASEPKGNAME -p `/net/jupiter/swdev/ccs/scripts/jira_interface.py -p` -d `/net/jupiter/swdev/ccs/scripts/jira_interface.py -t` | tee $RESULT_FILE
			fi
	fi
}

function build_sma_packages()
{
    cd $SOURCE_ROOT/build
    #Here is where we do the packaging if required.
    LogAndEcho "$MY_BRANCH Compiled Successfully" 
    if [ "${create_patch}" == "true" ]; then
        export TOP=$BASEPKGNAME
        LogAndEcho "TOP=$TOP"
        LogAndEcho "COMMON_ROOT= $COMMON_ROOT"
        LogAndEcho "SOURCE_ROOT= $SOURCE_ROOT"
        LogAndEcho "HOME_ROOT= $HOME_ROOT"
        sma_pkg TINCcc $CC_PATCH_RELEASE
        sma_pkg TINCccc $CCC_PATCH_RELEASE
        sma_pkg TINCpsp $PSP_PATCH_RELEASE
        sma_pkg TINCsdp $SDP_PATCH_RELEASE
        sma_pkg TINCcfg $CFG_PATCH_RELEASE
        sma_pkg TINCccdb $CCDB_PATCH_RELEASE
        sma_pkg TINCsidb $SIDB_PATCH_RELEASE
        sma_pkg TINCvmdb $VMDB_PATCH_RELEASE
        if [ "generate_tag" == "true" ]; then
            sma_pkg TINCvrdb $VRDB_PATCH_RELEASE $generate_tag
        else
            sma_pkg TINCvrdb $VRDB_PATCH_RELEASE
        fi
    fi
}
function sma_pkg()
{
GenTag=""
if [ $# -eq 2 ]; then
    PKG_NAME=$1
    PATCH_NUM=$2
elif [ $# -eq 3 ]; then
    PKG_NAME=$1
    PATCH_NUM=$2
    GenTag=" -t"
fi
cd $SOURCE_ROOT/build
. $BUILD_ENV
LogAndEcho "Create Patch :: $SOURCE_ROOT/build/makePatch.$VERSION $PKG_NAME $PATCH_NUM"
$SOURCE_ROOT/build/makePatch.$VERSION $PKG_NAME $PATCH_NUM >> ${RESULT_FILE}
cd $PKG_NAME-$PATCH_NUM/$PKG_NAME/ 
LogAndEcho "Create Patch :: $SOURCE_ROOT/build/makePatch.pl -a"
$SOURCE_ROOT/build/makePatch.pl -a >> ${RESULT_FILE} 
cd $SOURCE_ROOT/build
rm -rf $PKG_NAME-$PATCH_NUM/
LogAndEcho "$AUTOBUILDBASE/packaging/Sma/prepVersion -a -n $PKG_NAME -p $SOURCE_ROOT $GenTag"
$AUTOBUILDBASE/packaging/Sma/prepVersion -a -n $PKG_NAME -p $SOURCE_ROOT $GenTag | tee -a $RESULT_FILE
}

function build_pom_packages()
{
    cd $BASE_PROJ_DIR/in/scripts/development
    #Here is where we do the packaging if required.
    LogAndEcho "$MY_BRANCH Compiled Successfully" 
    if [ "${create_patch}" == "true" ]; then
        export TOP=$BASEPKGNAME
        LogAndEcho "TOP=$TOP"
    LogAndEcho "Create TINPbase Patch $PATCH_NUM"
        $BASE_PROJ_DIR/in/scripts/development/dopatch.faster.PPIN -v $VERSION -p TINPbase -n $PATCH_NUM
    LogAndEcho "Create TINPtmplt Patch $PATCH_NUM"
        $BASE_PROJ_DIR/in/scripts/development/dopatch.faster.PPIN -v $VERSION -p TINPtmplt -n $PATCH_NUM
    fi
}


#Diarmuid

function display_help()
{
	display_seperator
	LogAndEcho "/net/jupiter/swdev/scripts/autobuild/scripts/run_build.sh can takes the following paramaters"
	LogAndEcho ""
	LogAndEcho "Basic options for development (and Pipeline) environment"
	LogAndEcho "--------------------------------------------------------"
    LogAndEcho "-G DevGroup\t--> Specifies which Development Groups source to code to compile."
    LogAndEcho "\t\t--> Currently supporting RBM, Voice, Data, SSS, SMA & DB."
    LogAndEcho "-b branch\t--> Provide the branch to checkout/compile"
    LogAndEcho "\t\t--> If not provided, it will use $BRANCH_LIST, unless you supply (-f) below"
    LogAndEcho "-V version\t--> Version to build."
    LogAndEcho "\t\t--> For SMA/SMI, Version is used for make tidy & package identification."
    LogAndEcho "\t\t--> For POM/SSS, Version is is the base id for package identification."
    LogAndEcho "-n patch_num\t--> Patch Num to build."
    LogAndEcho "\t\t--> For POM/SSS, patch_num is is the patch number to build."
    LogAndEcho "\t\t--> This is taken from environment settings for the other packages."
    LogAndEcho "-c\t\t--> checkout (each) branch"
    LogAndEcho "-m\t\t--> make/compile (each) branch, also enables verify below"
    LogAndEcho "-v\t\t--> Verify the code - compare binary, jar, library files...."
    LogAndEcho "\t\t--> For RBM/Data lists exist in tocs/source/etc/*list*.txt"
    LogAndEcho "\t\t--> For Voice/SSS lists exist in /net/jupiter/swdev/scripts/autobuild/config/"
    LogAndEcho ""
    LogAndEcho "Advanced options for development (and Pipeline) environment"
    LogAndEcho "--------------------------------------------------------"
    LogAndEcho "-B\t\t--> BINARY RELEASE - will ignore upgrade scripts for voice patch generation"
    LogAndEcho "-l or -L \t--> Provide access to the LEGACY CODE - cvs / svn)"
    LogAndEcho "-S SCM_GROUP\t--> SCM_GROUP - PPIN/CCS/ADC"
    LogAndEcho "\t\t--> Used to identify the product. This is due to different repositories being used"
    LogAndEcho "-f file_name\t--> Provide file with list of branches (list of branches for 1 group)"
    LogAndEcho "-i\t\t--> Iterative build - do an update rather than a full checkout - where applicable"
    LogAndEcho "-p\t\t--> This will create Package for the group."
    LogAndEcho "-u\t\t--> Update each branch - used for iterative cvs update (obsolete)"
    LogAndEcho ""
    LogAndEcho "Advanced options for Pipeline environment"
    LogAndEcho "-----------------------------------------"
    LogAndEcho "-a\t\t--> checks out and compiles all listed branches (depends on if you supply -b)"
    LogAndEcho "-R\t\t--> This will backup binaries and config files on kore for release."
    LogAndEcho "\t\t--> E.g. - Data/RBM --> TINScgwDB, TINScgwPP, ....."
    LogAndEcho ""
    LogAndEcho ""
    LogAndEcho "-h\t\t--> display this message"
	display_seperator
	exit 0
}

#Main Script from here.

source /net/jupiter/swdev/scripts/tools.sh
#source $AUTOBUILDBASE/build_functions.sh
touch $RESULT_FILE

if [ ! -f $HOME/.bash_profile ]; then
	#Copy env files
	if [ -f $ENV_DIR/.bash_profile ]; then
		LogAndEcho "Copy $ENV_DIR/.bash_profile to $HOME/.bash_profile"
		cp $ENV_DIR/.bash_profile $HOME/.bash_profile
	else
		LogAndEcho "$ENV_DIR/.bash_profile not exist"
		if [ ! -f $HOME/.bash_profile ]; then
			LogAndEcho "$HOME/.bash_profile not exist, exiting"
			exit 1
		fi
	fi
else
	LogAndEcho "Not overwriting your .bash_profile." $RED
	LogAndEcho "You can get the generic .bash_profile @ $ENV_DIR" $RED
fi

if [ ! -f $HOME/.bashrc ]; then
	#Copy env files
	if [ -f $ENV_DIR/.bashrc ]; then
		LogAndEcho "Copy $ENV_DIR/.bashrc to $HOME/.bashrc"
		cp $ENV_DIR/.bashrc $HOME/.bashrc
	else
		LogAndEcho "$ENV_DIR/.bashrc not exist"
		if [ ! -f $HOME/.bashrc ]; then
			LogAndEcho "$HOME/.bashrc not exist, exiting"
			exit 1
		fi
	fi
else
	LogAndEcho "Not overwriting your .bashrc." $RED
	LogAndEcho "You can get the generic .bashrc @ $ENV_DIR" $RED
fi

. $HOME/.bashrc

LogAndEcho "The following paramaters are supplied to run_build.sh"
#while getopts g:G:ab:cf:i:hmRup:tTvlLV:S:n: opt
while getopts ab:cG:g:hi:M:mn:S:V:v opt
# Remaining Available options
# dejkoqrswxyz
# ACDEFHINOPUWXYZ
do
	case ${opt} in
		M)
			export MERGE=`echo ${OPTARG}|tr '[:lower:]' '[:upper:]'`
    			LogAndEcho "  ${opt}  - Merge $MERGE"
			if [ ! "$MERGE" == "PULL" ] && [ ! "$MERGE" == "PUSH" ]; then
				LogAndEcho "Invalid Merge option"
				LogAndEcho "Please select Push/Pull"
				LogAndEcho "    Push to ADC / Pull from ADC"
				exit 1
                        fi
			;;
		n)
			export PATCH_NUM=`echo ${OPTARG}|tr '[:lower:]' '[:upper:]'`
    			LogAndEcho "  ${opt}  - PATCH_NUM = $PATCH_NUM"
			;;
		S)
			export SCM_GROUP=`echo ${OPTARG}|tr '[:lower:]' '[:upper:]'`
			LogAndEcho "  ${opt}  - SCM_GROUP = $SCM_GROUP"
			if [ ! "$SCM_GROUP" == "PPIN" ] && [ ! "$SCM_GROUP" == "CCS" ] && [ ! "$SCM_GROUP" == "ADC" ]; then
				LogAndEcho "Invalid SCM Group"
				LogAndEcho "Only PPIN, CCS, ADC are supported at the moment"
				exit 1
			fi                                                 
			;;
		V)
			export VERSION=${OPTARG}
			LogAndEcho "  ${opt}  - Version = $VERSION" 
			;;
		a)
			# Automated run - setting defaults
			LogAndEcho "  ${opt}  - Automated run"
			# if automated, assume we want to checkout and compile the code for each branch
			# (depends on if you supply -b)
			automated=true
			checkout_code=true
			compile_code=true
			verify_code=true
			;;
		b)
			# Specifying the branch to process.
			# If not specified, then it will loop through branches specified
			# in $BRANCH_LIST  
			multiple_branches=false
			export single_branch=${OPTARG}
			LogAndEcho "  ${opt}  - Branch provided - ${single_branch}"
			;;
		c)
			# Set when checking out the code. THIs is to allow us to checkout
			# code without compiling it
			LogAndEcho "  ${opt}  - Checkout code"
			checkout_code=true
			;;
		h)
			display_help
			;;
		m)
			# Set when compiling the code. ThIs is to allow us to checkout
			# code without checking out the code.
			LogAndEcho "  ${opt}  - Compile code "
			compile_code=true
			verify_code=true
			;;
		g|G)
			# Identify the group's s/w to process.
			# rbm = CCS charging & PPIN data
			# sma = cust care - SMA
			# db = CCS database group
			# voice = PPIN Voice
			# pom = CCS SSS/ PPIN POM
			# BRT = voice brt solaris 8 release

			export DevGroup=${OPTARG}
			export DevGroup=`echo $DevGroup|tr '[:upper:]' '[:lower:]'`
			LogAndEcho "  ${opt}  - Run for $DevGroup"
			if [ ! "$DevGroup" == "rbm" ] && [ ! "$DevGroup" == "data" ] && [ ! "$DevGroup" == "sma" ] && [ ! "$DevGroup" == "db" ] && [ ! "$DevGroup" == "voice" ]  && [ ! "$DevGroup" == "brt" ] && [ ! "$DevGroup" == "pom" ]; then
				LogAndEcho "Invalid Development Group"
				LogAndEcho "Only RBM, SMA, POM, Voice, BRT, Data & DB supported at the moment"
				exit 1
			fi
			;;	
		v)
			# Set when we want to verify a compilation.
			# This can be run without checking out or compiling the code.
			# It uses the verification lists which contain required target files
			# for packaging the Tecnotree product.
			LogAndEcho "  ${opt}  - Verify the code"
			verify_code=true
			;;
		*)
			LogAndEcho "  ${opt} parameter not supported for run_build.sh"
			exit 1
			;;
	esac
done

if [ "$DevGroup" == "db" ]; then
	compile_code=false
	verify_code=false
fi
setup_email_lists

export automated
export run_regression
if [ ! -d "$RESULT_DIR" ];
then
    mkdir -p $RESULT_DIR
    LogAndEcho "$RESULT_DIR created"
fi

export branch=$single_branch
if [ "$DevGroup" == "pom" ]; then
    DevBranch=`echo $branch|tr '[:upper:]' '[:lower:]'`
    if [ "$DevBranch" == "trunk" ]; then
        export branch=$DevBranch
    fi
fi
mkdir -p $HOME/AutomationEnvironments/
ppin_initial_bld_env="$HOME/AutomationEnvironments/ppin_$DevGroup.bashrc_$branch"
adc_initial_bld_env="$HOME/AutomationEnvironments/adc_$DevGroup.bashrc_$branch"
export RESULT_FILE=${RESULT_DIR}${DATE}_${branch}.txt
cp $HOME/nightlybuild_$DATE.txt $RESULT_FILE
export MY_BRANCH=${branch}
display_seperator
LogAndEcho "Processing ${branch}"
display_seperator
	
LogAndEcho "Result Dir = $RESULT_DIR"
LogAndEcho "Result File = $RESULT_FILE"
SRC_BASE=""
DEST_BASE=""
# Create a working .bashrc_$branch file and modify it for this build instance
if [ -f $ENV_DIR/.bashrc_$DevGroup ]; then
    if [ -f $ppin_initial_bld_env ]; then
        LogAndEcho "$ppin_initial_bld_env already exists, not overwriting" $RED
    else
        cp $ENV_DIR/.bashrc_$DevGroup $ppin_initial_bld_env
        sed -e "s/CCS_BRANCH/PPIN\/$branch/" \
        $ppin_initial_bld_env > $ppin_initial_bld_env.copy
        cp $ppin_initial_bld_env.copy $ppin_initial_bld_env
        rm $ppin_initial_bld_env.copy
    fi
    if [ -f $adc_initial_bld_env ]; then
        LogAndEcho "$adc_initial_bld_env already exists, not overwriting" $RED
    else
        cp $ENV_DIR/.bashrc_$DevGroup $adc_initial_bld_env
        sed -e "s/CCS_BRANCH/ADC\/$branch/" \
        $adc_initial_bld_env > $adc_initial_bld_env.copy
        cp $adc_initial_bld_env.copy $adc_initial_bld_env
        rm $adc_initial_bld_env.copy
    fi
else
    LogAndEcho "$ENV_DIR/.bashrc_$DevGroup does not exist, exiting"
    exit 1
fi

export BUILD_ENV=$ppin_initial_bld_env
export CHECKOUT_DATE=`date '+%Y%m%d%H%M%S'`
if [ "$MERGE" == "PUSH" ]; then
    export BUILD_ENV=$ppin_initial_bld_env
    source $BUILD_ENV
    SRC_BASE=$BASE_PROJ_DIR
    OUTPUT_BACKUP=${OUTPUT_DIR}_${MY_BRANCH}/
    MAKE_OUTPUT=${BASE_PROJ_DIR}/
    checkout_git $branch
    export BINARIES_DIR=${BINARIES_BASE}${PATCH_RELEASE}/
    export HOSTNAME=`hostname`
    export BINARY_RELEASE="MERGE PUSH"
    compile_status=true
    LogAndEcho "Patch # = ${PATCH_RELEASE}" 
    compile_ccs
    display_seperator
    verify_build
    if [ "$compile_status" == "true" ]; then
        export BUILD_ENV=$adc_initial_bld_env
        source $BUILD_ENV
        DEST_BASE=$BASE_PROJ_DIR
        OUTPUT_BACKUP=${OUTPUT_DIR}_${MY_BRANCH}/
        MAKE_OUTPUT=${BASE_PROJ_DIR}/
        export SCM_GROUP=ADC
        checkout_git $branch
        LogAndEcho "SRC_BASE = $SRC_BASE, DEST_BASE = $DEST_BASE"
        cd $SRC_BASE/
        
        LogAndEcho "cp -Rfp * $DEST_BASE/"
        cp -Rfp * $DEST_BASE/
        cd $DEST_BASE
		if [[ "$DevGroup" == "rbm" || "$DevGroup" == "data" ]]; then
			git checkout tocs/source/etc/
		elif [ "$DevGroup" == "voice" ]; then
			git checkout control/rules/
		elif [ "$DevGroup" == "sma" ]; then
			git checkout custcare/etc/
		fi
        git add .
        git commit -m "$GIT_DATE : AUTOMATED MERGE TOOL - $HOSTNAME - TECNOTREE --> ADC : $branch"
        compile_ccs
        display_seperator
        verify_build
        if [ "$compile_status" == "true" ]; then
            git push
            source $ppin_initial_bld_env
            cd $BASE_PROJ_DIR
            git commit --allow-empty -m "$GIT_DATE : AUTOMATED MERGE TOOL - $HOSTNAME - Pushed TECNOTREE --> ADC : $branch"
            git push
        else
            LogAndEcho "$SCM_GROUP $branch Failed to compile, not pushing changes to server"
        fi
    else
        LogAndEcho "$SCM_GROUP $branch Failed to compile, not pushing changes to server"
    fi
elif [ "$MERGE" == "PULL" ]; then
    export BUILD_ENV=$adc_initial_bld_env
    source $BUILD_ENV
    SRC_BASE=$BASE_PROJ_DIR
    OUTPUT_BACKUP=${OUTPUT_DIR}_${MY_BRANCH}/
    MAKE_OUTPUT=${BASE_PROJ_DIR}/
    export SCM_GROUP=ADC
    checkout_git $branch
    export BINARIES_DIR=${BINARIES_BASE}${PATCH_RELEASE}/
    export HOSTNAME=`hostname`
    export BINARY_RELEASE="MERGE PULL"
    compile_status=true
    LogAndEcho "Patch # = ${PATCH_RELEASE}" 
    compile_ccs
    display_seperator
    verify_build
    if [ "$compile_status" == "true" ]; then
        export BUILD_ENV=$ppin_initial_bld_env
        source $BUILD_ENV
        DEST_BASE=$BASE_PROJ_DIR
        OUTPUT_BACKUP=${OUTPUT_DIR}_${MY_BRANCH}/
        MAKE_OUTPUT=${BASE_PROJ_DIR}/
        export SCM_GROUP=PPIN
        checkout_git $branch
        LogAndEcho "SRC_BASE = $SRC_BASE, DEST_BASE = $DEST_BASE"
        cd $SRC_BASE/
        
        cp -Rfp * $DEST_BASE/
        cd $DEST_BASE
        git add .
        git commit -m "$GIT_DATE : AUTOMATED MERGE TOOL - $HOSTNAME - ADC --> TECNOTREE  : $branch"
        compile_ccs
        display_seperator
        verify_build
        if [ "$compile_status" == "true" ]; then
            git push
            source $adc_initial_bld_env
            cd $BASE_PROJ_DIR
            git commit --allow-empty -m "$GIT_DATE : AUTOMATED MERGE TOOL - $HOSTNAME - Pushed ADC --> TECNOTREE : $branch"
            git push
        else
            LogAndEcho "$SCM_GROUP $branch Failed to compile, not pushing changes to server"
        fi
    else
        LogAndEcho "$SCM_GROUP $branch Failed to compile, not pushing changes to server"
    fi
fi

                
rm -rf $BUILD_ENV.copy
generate_email_alert

rm $HOME/nightlybuild_$DATE.txt
if [ "$jenkins_status" == "true" ]; then
	exit 0
else
	exit 1
fi

exit 0 
### @startmarkdown ####

# Checkout / Compile / Verify helper script

This script will allow you to checkout/compile/verify the code from any branch:

     /net/jupiter/swdev/scripts/autobuild/scripts/run_build.sh

Running the script with the **(-h)** option will give the following help display:

     Not overwriting your .bashrc.
     You can get the generic .bashrc @ /net/jupiter/swdev/scripts/autobuild/environment/
     The following paramaters are supplied to scripts/run_build.sh

     ==========================================================================

     /net/jupiter/swdev/scripts/autobuild/scripts/run_build.sh can takes the following paramaters

     Basic options for development (and Pipeline) environment
     --------------------------------------------------------
     -G DevGroup 	--> Specifies which Development Groups source to code to compile.
			--> Currently supporting RBM, Voice, Data, SSS, SMA & DB.
     -b branch   	--> Provide the branch to checkout/compile
			--> If not provided, it will use /export/home/lanedia/Nightly_Config/branchlist.txt, unless you supply (-f) below
     -c          	--> checkout (each) branch
     -m          	--> make/compile (each) branch, also enables verify below
     -v          	--> Verify the code - compare binary, jar, library files....
			--> For RBM/Data lists exist in tocs/source/etc//*list*.txt
			--> For Voice/SSS lists exist in /net/jupiter/swdev/scripts/autobuild/base_checklist.txt /net/jupiter/swdev/scripts/autobuild/pom_checklist.txt /net/jupiter/swdev/scripts/autobuild/voice_checklist.txt

     Advanced options for development (and Pipeline) environment
     --------------------------------------------------------
     -l \ -L	--> USE LEGACY CODE - cvs/svn
     -f file_name	--> Provide file with list of branches (list of branches for 1 group)
     -i			--> Iterative build - do an update rather than a full checkout - where applicable
     -p			--> This will create Package for the group.
     -u			--> Update each branch - used for iterative cvs update (obsolete)

     Advanced options for Pipeline environment
     -----------------------------------------
     -a			--> checks out and compiles all listed branches (depends on if you supply -b)
     -R			--> This will backup binaries and config files on kore for release.
			--> E.g. - Data/RBM --> TINScgwDB, TINScgwPP, .....

     -h			--> display this message

     ==========================================================================


## Examples of use

- In order to checkout the CCS RBM trunk (Phase 3) and compile it, you use the following:

       /net/jupiter/swdev/scripts/autobuild/scripts/run_build.sh -G rbm -b Cgw_TIP -c -m

- In order to checkout the PPIN CGW branch and compile it, you use the following:

       /net/jupiter/swdev/scripts/autobuild/scripts/run_build.sh -G data -b PP4102_maintainance_branch -c -m

- In order to checkout the PPIN Voice branch and compile it, you use the following:

       /net/jupiter/swdev/scripts/autobuild/scripts/run_build.sh -G voice -b prepaid_4.10.3_maintenance -c -m


## How the script works

1. It is intended to run in its own shell, so it creates its own environment. 

1. It checks that .bashrc exists, and sources it.

1. It will then generate a .bashrc for the "branch_name" you are processing.

   -G The branch you are processing will exist in the following location:

          Voice		- $HOME/voice/branch_name
          Data/Rbm 	- $HOME/data/branch_name
          SSS/POM 	- $HOME/pom/branch_name
          SMA 	- $HOME/sma/branch_name

   - There will be a .bashrc_branchname file in the relevant folder (3.a above)

1. It sources the generated .bashrc_branch_name prior to processing the branch.	

**NOTE:** If you want to have a developent environment for editing/compiling you should create a *.bashrc_development* script, which sources the required .bashrc_branch_name file you want.

### @endmarkdown ###
