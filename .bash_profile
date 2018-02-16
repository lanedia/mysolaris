if [ -f /export/home/${LOGNAME}/.bashrc ]; then
   source /export/home/${LOGNAME}/.bashrc
fi


if [ `/usr/ucb/whoami` == "tecnomen" ]; then
    [[ $- == *i* ]] && echo -e "\e[1;34mUser is [tecnomen]: Setting a\e[1;31m production environment\e[0m"
else
    [[ $- == *i* ]] && echo -e "\e[1;34mUser is [`/usr/ucb/whoami`]: Setting a\e[1;32m development environment\e[0m"
fi

