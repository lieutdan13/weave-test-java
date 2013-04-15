#!/bin/bash

### Copyright 2012-2013 by Garth Johnson as weave.sh
#
#  This script will start the alpha_engine for testing
#  
# 

cd "$( dirname "${BASH_SOURCE[0]}" )"

############### Set registered user ##################
#If you have registered, you can change the workerId
REGISTERED_WORKER_ID='hello-world'

############### Set optional logfile location ##################
## These setup a logfile if your interested in analyzing the output later
##   The filename to use will be based on the hour that you start the client
##   eg: <LOG_PATH>/130334-01.log
LOG_PATH="./log/"
LOG_DATE=$(date +'%y%m%d-%H')

## uncomment the following line to dump the java logs into a file for review
# WEAVE_LOG="${LOG_PATH}${LOG_DATE}.log"

############### Set java location ##################
## Use this location for the raspberry pi and the preview ARM jdk
JAVA_EXEC=/opt/jdk1.8.0/bin/java

############### Set java heap memory ##################
## If you have a 256MB version B1 raspberry pi, use the following settings
##   You may have to change your gpu_mem setting in /boot/config.txt (I have it set to 16)
MAX_MEMORY=100m
MIN_MEMORY=100m

## If you have a 512MB version raspberry pi, use the following settings
#MAX_MEMORY=256m
#MIN_MEMORY=256m

############### Run weave as a cron ###############
## Enabling this option will allow you to run Weave as a cron. At every run,
## it will check the log for recent activity. If no activity has been detected,
## the script will kill weave and start a new one in the background.
## The WEAVE_LOG must be defined in order to use the CRON option. It's also
## required that the log name is static and does not have a variable.
CRON=0

############### Pid file for running as a Cron ###############
PID_FILE=/var/run/weave.pid


############### Load the values from the config file ###############
if [ -f /etc/weave.conf ]; then
  . /etc/weave.conf
fi

############### Check User Agreements ###############
## Make sure user has acknowledged partner/network agreements
for file in README-*.pdf
do
  if [ ! -e "${file}.accept" ]; then
    echo "Please accept third party agreements by typing the following: "
    echo -e "touch ${file}.accept\n"
    UNACCEPTED_AGREEMENTS="FAIL"
  fi
done

## Bail if there are agreements to accept
if [ "NONE" != "${UNACCEPTED_AGREEMENTS:-NONE}" ];then
  exit 1
fi

## If java is currently in your executable path, this will find it
if [ ! -x ${JAVA_EXEC} ]; then
  JAVA_EXEC=$(which java)
fi

## Make sure java is here and executable
if [ ! -x ${JAVA_EXEC} ]; then
  echo "Unable to locate java virtual machine at: ${JAVA_EXEC}"
  echo "Please go here to download and install the Java SDK for RaspberryPi"
  echo "If you're using a different platform, install Java SDK >= v1.6"
  echo "  http://jdk8.java.net/fxarmpreview/"
  exit 1
fi

function checkLog() {
  if [ "`find $WEAVE_LOG -mmin -20`" != "" ] && [ "`cat $WEAVE_LOG`" != "" ]; then
    return 0
  else
    return 1
  fi
}

function checkPid() {
  if [ -e $PID_FILE ]; then
    pid=`cat $PID_FILE`
    if kill -0 &>1 > /dev/null $pid; then
      exit 1
    else
      rm $PID_FILE
    fi
  fi
}

############### Now startup the client, enabling logging if requested ##################
## If WEAVE_LOG is set and has a path that exists
if [ -n "${WEAVE_LOG}" ]; then
  # Make sure we can access the log file
  if [ ! -f ${WEAVE_LOG} ]; then
    touch ${WEAVE_LOG}
  fi
  if [ -f ${WEAVE_LOG} ];then
    if [ "$CRON" == "1" ]; then
      checkLog
      if [ $? -eq 1 ]; then
        checkPid
        ${JAVA_EXEC} -Xmx${MAX_MEMORY} -Xms${MIN_MEMORY} -XX:+CMSClassUnloadingEnabled sh.weave.alpha_engine ${REGISTERED_WORKER_ID} >> ${WEAVE_LOG} 2>&1 &
        echo $! > $PID_FILE
      fi
    else
      ${JAVA_EXEC} -Xmx${MAX_MEMORY} -Xms${MIN_MEMORY} -XX:+CMSClassUnloadingEnabled sh.weave.alpha_engine ${REGISTERED_WORKER_ID} >> ${WEAVE_LOG}
    fi
  else
    echo -e "Unable to create logfile ${WEAVE_LOG}\n"
  fi
else
  ${JAVA_EXEC} -Xmx${MAX_MEMORY} -Xms${MIN_MEMORY} -XX:+CMSClassUnloadingEnabled sh.weave.alpha_engine ${REGISTERED_WORKER_ID} 
fi
