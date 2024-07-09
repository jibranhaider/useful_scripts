#!/bin/bash

#-------------------------------------------------------------------------------
# Colours and formatting
#-------------------------------------------------------------------------------
RED="31"
GREEN="32"
YELLOW="33"
LIGHTYELLOW="93"
ENDCOLOUR="\e[0m"

BOLD="1"
ITALIC="3"

#-------------------------------------------------------------------------------
# Print heading and subheading
#-------------------------------------------------------------------------------
function heading {
    echo -e "\e[$BOLD;${LIGHTYELLOW}m\n${1^^}$ENDCOLOUR"
}

function subheading {
    echo -e "\e[${YELLOW}m\n${1^}$ENDCOLOUR"
}

#-------------------------------------------------------------------------------
# Print success and error and warning logs
#-------------------------------------------------------------------------------
function success_log {
    echo -e "\e[${GREEN}m$1$ENDCOLOUR"
}

function error_log {
    echo -e "\e[41mERROR: $1$ENDCOLOUR"
}

function warning_log {
    echo -e "\e[${RED}mWARN: $1$ENDCOLOUR"
}

#-------------------------------------------------------------------------------
# Check if previous command succeeded or not
#-------------------------------------------------------------------------------
function check_command {
    if [ $? -eq 0 ]; then
        success_log "$1 successful"
    else
        error_log "$1 failed"
        exit 1
    fi
}

#-------------------------------------------------------------------------------
# Confirm action from user
#-------------------------------------------------------------------------------
function confirm_action {
    action=$1
    echo -e "$action"
    read -p "Press 'y' to continue or any other key to abort: "
}
