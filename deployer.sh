#!/bin/bash
# This script acts as scheduler-control-loop, and runs every minute.
# The purpose is to read the 'todo' file , deploy stuff, and then update the 'done' file.

################# START - User Defined Variables ##############################
#

# All of the following file/directory locations must be full/absolute paths.

# This is the main directory where all the run-time definitions of your compose apps reside -
#   - each in a separate directory:
CONTAINER_RUNTIME_DIRECTORY=/home/containers-runtime

# The name of directory in which  docker-manager tools/scripts reside:
DEPLOY2DOCKER_DIRECTORY=/home/deploy2docker

# This is the name of the docker-compose file in your applications:
DOCKER_COMPOSE_FILE=docker-compose.server.yml

#
################# END - User Defined Variables ################################



################# START - System Variables ####################################
#


TASKS_DIRECTORY=${DEPLOY2DOCKER_DIRECTORY}/deployer.tasks.d
DONE_FILE=${DEPLOY2DOCKER_DIRECTORY}/logs/deployer.done.log
LOG_FILE=${DEPLOY2DOCKER_DIRECTORY}/logs/deployer.log

#
################# END - System Variables ######################################



#######################   START - Functions    ################################
#

function timeStamp() { 
  echo $(date +"%F_%T")
}

function echolog() {
  echo -e "$(timeStamp) $@" | tee -a ${LOG_FILE}
}


# --------------

function findRepoAndCheckForChanges() {
  local UPSTREAM_GIT_URL=$1
  local UPSTREAM_GIT_HASH=$2

  local REPO_NAME=$(extractBaseDirectoryNameFromGitURL ${UPSTREAM_GIT_URL})
  local LOCAL_REPO_LOCATION=${CONTAINER_RUNTIME_DIRECTORY}/${REPO_NAME}
  if [ ! -d ${LOCAL_REPO_LOCATION}/.git ]; then
    echo
    echolog "Local directory '${CONTAINER_RUNTIME_DIRECTORY}/${REPO_NAME}' does not exist - OR - is not a 'git' directory."
    echolog "Attempting to clone the repo '${UPSTREAM_GIT_URL}' into '${CONTAINER_RUNTIME_DIRECTORY}/${REPO_NAME}' ..."
    cloneGitRepoAndStartDockerCompose ${UPSTREAM_GIT_URL}
    if [ $? -eq 0 ]; then
      echo
      echolog "Application in the repo '${REPO_NAME}' has been started successfully."
      recordResultInDoneFile  ${UPSTREAM_GIT_URL}  ${UPSTREAM_GIT_HASH} GIT-CLONE-DOCKER-SUCCESS
    else
      echo
      echolog "Some error encountered while trying to restart the application using docker-compose. Please investigate."
      recordResultInDoneFile  ${UPSTREAM_GIT_URL}  ${UPSTREAM_GIT_HASH} GIT-CLONE-DOCKER-FAIL
    fi

  else
    compareGitHashAndPullChanges  ${UPSTREAM_GIT_URL}  $UPSTREAM_GIT_HASH
  fi
}

# --------------
function recordResultInDoneFile() {
  local UPSTREAM_GIT_URL=$1
  local UPSTREAM_GIT_HASH=$2
  local ERROR_CODE=$3
  echolog "Recording '${ERROR_CODE}' in: ${DONE_FILE} ..."
  echo -e "$(timeStamp) \t ${UPSTREAM_GIT_URL} \t ${UPSTREAM_GIT_HASH} \t ${ERROR_CODE}" >> ${DONE_FILE}
  echo
  removeDeploymentTaskFile
}


function removeDeploymentTaskFile() {
  echolog "Removing deployment task file: ${TASK_FILE} ..."
  rm ${TASK_FILE}
}

# --------------

function compareGitHashAndPullChanges() {
  local UPSTREAM_GIT_URL=$1
  local UPSTREAM_GIT_HASH=$2

  local REPO_NAME=$(extractBaseDirectoryNameFromGitURL ${UPSTREAM_GIT_URL})

  # Find the git hash of the repo directory, and compare. 
  # Sub-shell helps change directory, and then come back to previous one automatically when sub-shell exists.
  (
  cd ${CONTAINER_RUNTIME_DIRECTORY}/${REPO_NAME}
  DIRECTORY_GIT_HASH=$(git rev-parse --short HEAD)
  echo
  if [ "${DIRECTORY_GIT_HASH}" == "${UPSTREAM_GIT_HASH}" ]; then
    echolog "Directory hash '${DIRECTORY_GIT_HASH}' , and  Upstream Repo hash '${UPSTREAM_GIT_HASH}' - are same. Nothing to do."
    recordResultInDoneFile  ${UPSTREAM_GIT_URL}  ${UPSTREAM_GIT_HASH} NOOP
  else
    echolog "Local directory hash '${DIRECTORY_GIT_HASH}' , and  upstream repo hash '${UPSTREAM_GIT_HASH}' - are different. Changes need to be applied."
    echolog "Performing 'git pull' inside: ${CONTAINER_RUNTIME_DIRECTORY}/${REPO_NAME} ..."
    git pull
    if [ $? -ne 0 ]; then
      echolog "A problem encountered while executing 'git pull'. Please investigate."
      recordResultInDoneFile  ${UPSTREAM_GIT_URL}  ${UPSTREAM_GIT_HASH} GIT-PULL-FAIL
      return 1
    fi
    # Now restart docker-compose application in this directory:
    restartDockerCompose ${REPO_NAME}
    if [ $? -eq 0 ]; then
      echo
      echolog "Application in the repo '${REPO_NAME}' has been started successfully."
      recordResultInDoneFile  ${UPSTREAM_GIT_URL}  ${UPSTREAM_GIT_HASH} GIT-PULL-DOCKER-SUCCESS
    else
      echo
      echolog "Some error encountered while trying to restart the application using docker-compose. Please investigate."
      recordResultInDoneFile  ${UPSTREAM_GIT_URL}  ${UPSTREAM_GIT_HASH} GIT-PULL-DOCKER-FAIL
    fi
  fi
  )
  return
}

# --------------

function restartDockerCompose() {
  local REPO_NAME=$1

  # run a sub-shell
  (
  cd ${CONTAINER_RUNTIME_DIRECTORY}/${REPO_NAME}
  echo
  echolog "Stopping docker-compose application - ${REPO_NAME} ..."
  docker-compose -f ${DOCKER_COMPOSE_FILE} stop

  echo
  echolog "Removing older containers - ${REPO_NAME} ..."
  docker-compose -f ${DOCKER_COMPOSE_FILE} rm -f

  echo
  echolog "Starting docker-compose application - ${REPO_NAME} ..."
  echolog "This may take a while depending on the size/design of the application."
  docker-compose -f ${DOCKER_COMPOSE_FILE} up -d
  return $?
  )
  	
}


# ------------

function cloneGitRepoAndStartDockerCompose() {
  local UPSTREAM_GIT_URL=$1
  local REPO_NAME=$(extractBaseDirectoryNameFromGitURL ${UPSTREAM_GIT_URL})
  local LOCAL_REPO_LOCATION=${CONTAINER_RUNTIME_DIRECTORY}/${REPO_NAME}

  echolog "Creating directory ${CONTAINER_RUNTIME_DIRECTORY}/${REPO_NAME} ..."
  mkdir -p ${CONTAINER_RUNTIME_DIRECTORY}/${REPO_NAME}

  echolog "Cloning repo ${UPSTREAM_GIT_URL} into ${CONTAINER_RUNTIME_DIRECTORY}/${REPO_NAME} ..."
  git clone ${UPSTREAM_GIT_URL} ${CONTAINER_RUNTIME_DIRECTORY}/${REPO_NAME}

  # run a sub-shell
  (
  cd ${CONTAINER_RUNTIME_DIRECTORY}/${REPO_NAME}
  echo
  echolog "Starting docker-compose application - ${REPO_NAME} ..."
  echolog "This may take a while depending on the size/design of the application."
  docker-compose -f ${DOCKER_COMPOSE_FILE} up -d
  return $?
  )

}

# ------------

function checkGitURL() {
  local UPSTREAM_GIT_URL=$1
  REGEX='^http.*.git$'

  # Note: double brackets!
  if [[ ${UPSTREAM_GIT_URL} =~ ${REGEX} ]]; then
    echolog "Syntax is OK for GIT repository URL: '${UPSTREAM_GIT_URL}'"
    return 0
  else
    echolog "Syntax is NOT OK for GIT repository URL: '${UPSTREAM_GIT_URL}'" 
    echolog "The URL '${UPSTREAM_GIT_URL}' needs to be a git repo - (URL ending in .git)! Exiting ..."
    return 1
  fi
}

# ------------

function checkGitHash() {
  local UPSTREAM_GIT_HASH=$1
  REGEX='^[[:alnum:]]+$'
  # Note: double brackets below!
  if [[ ${UPSTREAM_GIT_HASH} =~ ${REGEX} ]]; then
    echolog "Syntax is OK for GIT repository hash: '${UPSTREAM_GIT_HASH}'"
    return 0
  else
    echolog "Syntax is NOT OK for GIT repository hash: '${UPSTREAM_GIT_HASH}'" 
    echolog "The hash '${UPSTREAM_GIT_HASH}' needs to be a git hash - (Alphanumeric only)! Exiting ..."
    return 1
  fi
}

# ---------------

function extractBaseDirectoryNameFromGitURL() {
  local GIT_URL=$1
  BASE_DIRECTORY_NAME=$(basename ${GIT_URL} | sed 's/\.git$//g')
  echo ${BASE_DIRECTORY_NAME}
}

#
#######################   END - Functions    #################################



#######################   START - Main code   #################################
#

echo
echolog "Starting the script $0"

if [ ! -d ${DEPLOY2DOCKER_DIRECTORY} ] ; then
  echo "The directory ${DEPLOY2DOCKER_DIRECTORY} DOES NOT exist. Please check configuration. Exiting ..."
  exit 1
fi

GIT=$(which git)

if [ -z "${GIT}" ]; then
  echolog "'git' was not found on this system. Please install that, and retry. Exiting ..."
  echo
  exit 1
fi

# If the log directory (/home/deploy2docker/logs) does not exist, 
#   create it before starting the main program.
# Reason: This may be a fresh system!

if [ ! -d $(dirname ${LOG_FILE}) ]; then
  mkdir -p $(dirname ${LOG_FILE})
fi

# If the TASKS directory does not exist, create it before starting the main program.
# Ideally this will never happen on a running system.
# On newly setup system this directory may be missing. 
# So, the script will create it the first time it runs.
if [ ! -d ${TASKS_DIRECTORY} ]; then
  echolog "TASKS_DIRECTORY '${TASKS_DIRECTORY}' was not found. Creating it ..."
  mkdir -p ${TASKS_DIRECTORY}
fi


# Process the TASKS_DIRECTORY
for TASK_FILE in $(find ${TASKS_DIRECTORY} -type f -print); do
  echolog "=====>  Processing deployment task file: ${TASK_FILE}"
  # We expect only a single line in the TASK_FILE
  TASK=$(egrep -v "\#|^$" ${TASK_FILE})
  
  if [ -z "${TASK}" ]; then
    echolog "TASK file is empty! Skipping ${TASK_FILE} ..."
    continue
  
  fi

  UPSTREAM_GIT_URL=$(echo ${TASK} | awk '{print $1}')
  UPSTREAM_GIT_HASH=$(echo ${TASK} | awk '{print $2}')


  if [ -z "${UPSTREAM_GIT_URL}" ] || [ -z "${UPSTREAM_GIT_HASH}" ] ; then
    echolog "UPSTREAM_GIT_URL or UPSTREAM_GIT_HASH was found empty in ${TASK_FILE}. Please investigate."
    echolog "Skipping ${TASK_FILE} ..."
    continue
  fi

  checkGitURL ${UPSTREAM_GIT_URL}
  if [ $? -ne 0 ]; then
    recordResultInDoneFile ${UPSTREAM_GIT_URL} ${UPSTREAM_GIT_HASH} "CONFIG-ERROR"
    echolog "Skipping ${TASK_FILE} ..."
    continue
  fi

  checkGitHash ${UPSTREAM_GIT_HASH}
  if [ $? -ne 0 ]; then
  ${UPSTREAM_GIT_HASH}  recordResultInDoneFile ${UPSTREAM_GIT_URL} ${UPSTREAM_GIT_HASH} "CONFIG-ERROR"
    echolog "Skipping ${TASK_FILE} ..."
    continue
  fi

  findRepoAndCheckForChanges ${UPSTREAM_GIT_URL} ${UPSTREAM_GIT_HASH}
done
	
echo
echolog "Finished running the script $0"
echo

#
#######################   END - Main code   #################################

