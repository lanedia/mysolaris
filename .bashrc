#	This is the default standard profile provided to a user.
#	They are expected to edit it to meet their own needs.

MAIL=/usr/mail/${LOGNAME:?}
export PS1='[\h : \u] \w> '

export EDITOR=/usr/local/bin/vim
export SVN_EDITOR=/net/jupiter/swdev/services/scripts/development/svn_template
export BUILD_MACHINE=LDG2

export PLATFORM=SOLARIS10

# This doesnt change except for GCC
export COMPILER=SUNPRO-5.8
#export COMPILER=GCC-4.1.1

# Doesnt matter except for GCC
export GNU_VER=3.2.1


# *********************
# sybase
# *********************
export DSQUERY=SYBASE
export SYBASE=/opt/sybase
if [ "$BUILD_MACHINE" == "LDG2" ]; then
        export SYBASE=/net/den/opt/sybase
fi

export SYBASE_OCS=OCS-15_0
export SYBASE_ASE=ASE-15_0
unset LANG



export PATH=/usr/ccs/bin/
export PATH=${PATH}:/usr/local/bin/
export PATH=${PATH}:/bin
export PATH=${PATH}:/usr/sbin/
export PATH=${PATH}:/usr/dt/bin/
export PATH=${PATH}:/usr/openwin/bin/
export PATH=${PATH}:/usr/X11/bin/
export PATH=${PATH}:/opt/csw/bin/
export PATH=${PATH}:/net/den/usr/local/bin


export LD_LIBRARY_PATH=/usr/sfw/lib
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/opt/csw/lib
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/net/den/usr/local/lib
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/net/den/usr/local/apr/lib
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/net/den/usr/local/BerkeleyDB.4.2/lib
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/net/den/usr/local/ssl/lib

# aliases to help is get around

alias git='LD_LIBRARY_PATH="/opt/csw/lib:$LD_LIBRARY_PATH" git'
alias l='clear'
alias lsd='ls -ltr | grep dr'
alias lsf='ls -ltr | grep -v dr'
alias lsa='ls -lta'
alias lsh='ls -ltr *.h* *H* | grep -v dr'
alias lsc='ls -ltr *.C* *.c* | grep -v dr'
alias lsl='ls -ltr'
alias lslt='ls -ltr | tail -5'
alias cs='cscope'
alias csc='cscope -C'
alias h='history'
alias ll='ls -al'
alias ls='ls -p'
alias setdev_old='source /net/jupiter/swdev/scripts/ccs_build/Environment/bashrc_development.sh'
alias setdev='source /net/jupiter/swdev/scripts/autobuild/environment/bashrc_development.sh'
alias runbuild='/net/jupiter/swdev/scripts/autobuild/scripts/run_build.sh'

#colour
red='\e[0;31m'
RED='\e[1;31m'
blue='\e[0;34m'
BLUE='\e[1;34m'
cyan='\e[0;36m'
CYAN='\e[1;36m'
NC='\e[0m'

PS1='\[\e[1;32m\][\u@\h \W]\[\e[0m\] > '
# BUILD_MACHINE=LDG2 is the Developer Zone env in SNN
if [ "$BUILD_MACHINE" == "0" ]; then
	echo "Not building on LDG2 Dev zone"
	export BUILD_MACHINE="none"
fi
