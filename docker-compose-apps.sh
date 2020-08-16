#!/bin/bash
# This script can be run by any user who is a member of 'docker' group.
# This script is part of deploy2docker set of tools.

if [ -z "$1" ]; then
  echo "Usage: $0 <start | stop | status>"
  exit 1
fi 


OPERATION=$1

################# START - User Defined Variables #############################
#

# All of the following file/directory locations must be full/absolute paths.

# This is the main directory where all the run-time definitions of your compose apps reside -
#   - each in a separate directory:
CONTAINERS_RUNTIME_DIRECTORY=/home/containers-runtime

# The name of directory in which  deploy2docker tools/scripts reside:
DEPLOY2DOCKER_DIRECTORY=/home/deploy2docker

# This is the name of the docker-compose file in your applications:
DOCKER_COMPOSE_FILE_NAME=docker-compose.server.yml

#
################# END - User Defined Variables ###############################



################# START - System Variables ###################################
#

LOG_FILE=${DEPLOY2DOCKER_DIRECTORY}/logs/docker-compose-apps.log

#
################# END - System Variables #####################################


#######################  START - Functions  ##################################
#
function timeStamp() { 
  echo $(date +"%F_%T")
}

function echolog() {
   echo -e "$(timeStamp) $@" | tee -a ${LOG_FILE}
}

function recordResultInLogFile() { 
  # Input: $? ${MAIN_OPERATION} ${SUB_OPERATION} ${DIR_NAME}
  # example: 0 dock-compose  status /home/containers-runtime/blogdemo.wbitt.com
  # example: 0 git           pull   /home/containers-runtime/blogdemo.wbitt.com
    
  local ERROR_CODE=$1
  local MAIN_OPERATION=$2
  local SUB_OPERATION=$3
  local DIR_NAME=$4
  
  if [ ${ERROR_CODE} -eq 0 ] ; then
    echolog "'${MAIN_OPERATION} ${SUB_OPERATION}' is 'SUCCESS' on '${DIR_NAME}'."
  else
    echolog "'${MAIN_OPERATION} ${SUB_OPERATION}' is 'ERROR' on '${DIR_NAME}'."
  fi 
}
#
#######################  END - Functions  ####################################



################# START - Main code    #######################################
#

echolog "Starting the script $0 for the '${OPERATION}' operation ..."



if [ ! -d ${DEPLOY2DOCKER_DIRECTORY} ] ; then
  echo "The directory ${DEPLOY2DOCKER_DIRECTORY} DOES NOT exist. Please check configuration. Exiting ..."
  exit 1
fi

# If the log directory (/home/deploy2docker/logs) does not exist, 
#   create it before starting the main program.
# Reason: This may be a fresh system!

if [ ! -d $(dirname ${LOG_FILE}) ]; then
  mkdir -p $(dirname ${LOG_FILE})
fi

DOCKER_COMPOSE_DIRECTORIES=$(find ${CONTAINERS_RUNTIME_DIRECTORY} -name ${DOCKER_COMPOSE_FILE_NAME} | sort -k 1 )

for FILE_PATH in ${DOCKER_COMPOSE_DIRECTORIES}; do
  echo; echo
  DIR_NAME=$(dirname ${FILE_PATH})

  if [ "${OPERATION}" == "start" ]; then
    # below is a sub-shell
    (
    cd ${DIR_NAME}

    echo
    echolog "Pulling latest changes from git repository linked to ${DIR_NAME} ..."
    echo
    git pull
    recordResultInLogFile $? git pull ${DIR_NAME}

    echolog "Removing any existing - but 'stopped' containers ..."
    docker-compose -f ${DOCKER_COMPOSE_FILE_NAME} rm -f
    recordResultInLogFile $? docker-compose rm ${DIR_NAME}
    echolog "Re-building container images ... (This may take some time) ..."
    docker-compose -f ${DOCKER_COMPOSE_FILE_NAME} build --no-cache 
    recordResultInLogFile $? docker-compose build ${DIR_NAME}

    echolog "Bringing up docker-compose application stack ..."
    docker-compose -f ${DOCKER_COMPOSE_FILE_NAME} up -d
    recordResultInLogFile $? docker-compose up ${DIR_NAME}
    )

  fi

  if [ "${OPERATION}" == "stop" ]; then

    (
    cd ${DIR_NAME}
    echolog "Stopping docker-compose application stack inside ${DIR_NAME} ..."
    docker-compose -f ${DOCKER_COMPOSE_FILE_NAME} stop 
    recordResultInLogFile $? docker-compose stop ${DIR_NAME}
    echolog "Removing 'stopped' containers ..."
    docker-compose -f ${DOCKER_COMPOSE_FILE_NAME} rm -f
    recordResultInLogFile $? docker-compose rm ${DIR_NAME}
    )

  fi
  
  if [ "${OPERATION}" == "status" ]; then

    (
    cd ${DIR_NAME}
    echolog "Showing status of docker-compose application stack inside ${DIR_NAME} ..."
    docker-compose -f ${DOCKER_COMPOSE_FILE_NAME} ps
    recordResultInLogFile $? docker-compose status ${DIR_NAME}
    )

  fi
  

done

echo
echolog "Finished running the script $0 ."
echo

#
################# END - Main code    #########################################

