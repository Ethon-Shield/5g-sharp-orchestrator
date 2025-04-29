#!/bin/bash 
#######################################################################
#
#   Author:     ETHON SHIELD SL
#   Version:    0.0.4
#   License:    AGPLv3
#   Copyright:  Copyright (C) 2021-2025, 5G Sharp Orchestrator
#   Email:      sharp-orchestrator@ethonshield.com
#
#######################################################################

full_path=$(realpath $0)
working_directory=$(echo "${full_path}" | rev | cut -d "/" -f3- | rev)

cp ${working_directory}/conf/sharp-orchestrator.src ${HOME}/
source ${HOME}/sharp-orchestrator.src

# We assume everything is correct
# If something is wrong the variable will be set to False
correct_initialization="True"

# LOG SEVERITY
SUCCESS='\033[0;32m'
WARNING='\033[0;33m'
ERROR='\033[0;31m'
FATAL='\033[0;88m'
DEBUG_C='\033[0;90m'
NC='\033[0m' # No Color

#######################
#####  BASIC DIRS #####
#######################

function check_basic_variables {
  local are_basic_var_ok="YES"

  echo "##################################"
  echo "Checking basic variables"
  echo "##################################"

  if [[ -z "${SHARP_ORCHESTRATOR_WORKING_DIR}" ]]; then
    printf "SHARP_ORCHESTRATOR_WORKING_DIR is empty ... ${ERROR}EMPTY${NC}\n"
    are_basic_var_ok="NO"
  fi
  
  if [[ -z "${NRCORE_TECH}" ]]; then
    printf "NRCORE_TECH is empty ... ${ERROR}EMPTY${NC}\n"
    are_basic_var_ok="NO"
  fi

  if [[ -z "${NRCORE_OAI_WD}" && "${NRCORE_TECH}" == "OAI" ]]; then
    printf "NRCORE_OAI_WD is empty ... ${ERROR}EMPTY${NC}\n"
    are_basic_var_ok="NO"
  fi

  if [[ -z "${NRCORE_OPEN5GS_WD}" && "${NRCORE_TECH}" == "OPEN5GS" ]]; then
    printf "NRCORE_OPEN5GS_WD is empty ... ${ERROR}EMPTY${NC}\n"
    are_basic_var_ok="NO"
  fi

  if [[ "${are_basic_var_ok}" == "NO" ]]; then
    echo ""
    echo "Please add the full paths of the corresponding variables."
    exit 1
  else
    printf "BASIC variables are ${SUCCESS}OK${NC}\n"
  fi

  echo ""

}

###############################
#####  BINARIES CHECK  #####
##############################

######################################################
# Check docker binary version is supported
#
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Print the result of the check process to stdout
######################################################

function check_docker_version {
  docker_version=$(docker --version | awk '{print $3}' | cut -d',' -f1) 

  # Check first, second and third values
  docker_version_first_value="$(echo ${docker_version} | cut -d'.' -f1)"
  docker_version_second_value="$(echo ${docker_version} | cut -d'.' -f2)"
  docker_version_third_value="$(echo ${docker_version} | cut -d'.' -f3)"

  if [[ $((docker_version_first_value)) -lt 19 ]]; then
    printf "${WARNING}WARNING${NC} - Current docker version ${docker_version} should be \
      19.03.0 or higher to support compose file version 3.8 \n"

  elif [[ $((docker_version_first_value)) -eq 19 ]]; then
    if [[ $((docker_version_second_value)) -lt 03 ]]; then
      printf "${WARNING}WARNING${NC} - Current docker version ${docker_version} should be\
        19.03.0 or higher to support compose file version 3.8 \n"

    elif [[ $((docker_version_second_value)) -eq 03 ]]; then
      if [[ $((docker_version_third_value)) -lt 0 ]]; then
        printf "${WARNING}WARNING${NC} - Current docker version ${docker_version} should be \
          19.03.0 or higher to support compose file version 3.8 \n"
      fi
    fi
  fi
}

###################################################
# Check docker compose binary version is supported
#
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Print the result of the check process to stdout
#####################################################

function check_docker_compose_version {
  docker_compose_version=$(docker-compose --version | awk '{print $3}' | cut -d',' -f1)
  # Check first, second and third values
  docker_compose_version_first_value="$(echo ${docker_compose_version} | cut -d'.' -f1)"
  docker_compose_version_second_value="$(echo ${docker_compose_version} | cut -d'.' -f2)"
  docker_compose_version_third_value="$(echo ${docker_compose_version} | cut -d'.' -f3)"

  if [[ $((docker_compose_version_first_value)) -lt 1 ]]; then
    printf "${WARNING}WARNING${NC} - Current docker compose version ${docker_compose_version} should be \
      1.29.2 or higher to support compose file version 3.8 \n"

  elif [[ $((docker_compose_version_first_value)) -eq 1 ]]; then
    if [[ $((docker_compose_version_second_value)) -lt 29 ]]; then
      printf "${WARNING}WARNING${NC} - Current docker compose version ${docker_compose_version} should be\
        1.29.2 or higher to support compose file version 3.8 \n"

    elif [[ $((docker_compose_version_second_value)) -eq 29 ]]; then
      if [[ $((docker_compose_version_third_value)) -lt 2 ]]; then
        printf "${WARNING}WARNING${NC} - Current docker compose version ${docker_compose_version} should be \
          1.29.2	or higher to support compose file version 3.8 \n"
      fi
    fi
  fi
}

###################################################
# Check necessary binaries are installed
#
# Globals:
#   DEPLOY_NRCORE_ONLY
#   NRCORE_TECH
#   NR_BIN_INDEX
#   NRCORE_OPEN5GS_WD
# Arguments:
#   None
# Outputs:
#   Print the result of the check process to stdout
#####################################################

function check_binaries {

  echo "##################################"
  echo "Checking necessary binaries"
  echo "##################################"

  general_binaries="tshark expect"
  uhd_binaries="uhd_find_devices uhd_usrp_probe"

  for binary in ${general_binaries}; do
    if command -v ${binary} &> /dev/null; then
      printf "${binary} ... ${SUCCESS}YES${NC}\n"
    else
      printf "${binary} ... ${ERROR}NO${NC}\n"
      correct_initialization="False"
    fi
  done

  if command -v "tmux" &> /dev/null; then
    if [[ $(tmux -V | awk '{print $2}') == "3.5a" ]]; then
      printf "tmux ... ${SUCCESS}YES${NC}\n"
    else
      printf "tmux ... ${ERROR}NO${NC} - tmux version should be 3.5a\n"
    fi
  else
    printf "tmux ... ${ERROR}NO${NC}\n"
  fi

  if [[ "${DEPLOY_NRCORE_ONLY}" == "false" ]]; then
    for binary in ${uhd_binaries}; do
      if command -v ${binary} &> /dev/null; then
        printf "${binary} ... ${SUCCESS}YES${NC}\n"
      else
        printf "${binary} ... ${ERROR}NO${NC}\n"
        correct_initialization="False"
      fi
    done

  fi

  if [[ "${NRCORE_TECH}" == "OAI" ]]; then

    check_docker_version
    check_docker_compose_version

  else
    for binary in "${NR_BIN_INDEX[@]}"; do
      if [[ -f ${NRCORE_OPEN5GS_WD}/install/bin/${binary} ]]; then
        printf "${binary} ... ${SUCCESS}YES${NC}\n"
      else
        printf "${binary} ... ${ERROR}NO${NC}\n"
        correct_initialization="False"
      fi
    done
  fi
  echo ""

}

#################################
#####  Check NRCORE info  #####
#################################

###################################################
# Check that specified NRCORE parameters are correct
#
# Globals:
#   NRCORE_IP_ADDRESS
#   NRCORE_USERNAME
#   NRCORE_WORKING_DIR
# Arguments:
#   None
# Outputs:
#   Print the result of the check process to stdout
#####################################################

function check_nrcore_info {

  echo "##################################"
  echo "Checking CORE IP address, username and working dir"
  echo "##################################"
  echo ""

  find_core_ip_address=$(ifconfig | grep -c ${NRCORE_IP_ADDRESS})
  if [[ "${find_core_ip_address}" -ge 1 ]]; then 
    printf "CORE IP ADDRESS ... ${SUCCESS}YES${NC}\n"
  else
    printf "CORE IP ADDRESS ... ${ERROR}NO${NC} - Check if ${NRCORE_IP_ADDRESS} is your current IP address\n"
    correct_initialization="False"
    fi

    find_core_username=$(grep -c ${NRCORE_USERNAME} /etc/passwd)
    if [[ "${find_core_username}" -ge 1 ]]; then 
      printf "CORE USERNAME ... ${SUCCESS}YES${NC}\n"
    else
      printf "CORE USERNAME ... ${ERROR}NO${NC} - Check if ${NRCORE_USERNAME} is your current user\n"
      correct_initialization="False"
      fi

      find_core_wd=$([[ -d ${NRCORE_WORKING_DIR} ]] && echo 1 || echo 0)
      if [[ "${find_core_wd}" -eq 1 ]]; then 
        printf "CORE WORKING DIR ... ${SUCCESS}YES${NC}\n"
      else
        printf "CORE WORKING DIR ... ${ERROR}NO${NC} - NRCORE_WORKING_DIR: ${NRCORE_WORKING_DIR}, should be the same as $(cd ../ && pwd) directory\n"
        correct_initialization="False"
      fi

      echo ""

    }

######################################################
#####  DOCKER IMAGES CHECK | OPEN5GS SERVICES  #####
######################################################

###################################################
# Check that NRCORE dependencies are fulfilled
#
# Globals:
#   NRCORE_TECH
#   NRCORE_DC_IMAGES_TAGS
#   BASIC_DEPLOYMENT
# Arguments:
#   None
# Outputs:
#   Print the result of the check process to stdout
#####################################################


function check_nrcore_services {
  if [[ "${NRCORE_TECH}" == "OAI" ]]; then

    echo "##################################"
    echo "Checking existance of docker images"
    echo "##################################"
    echo ""

    # Basic Deployment with UPF Checksum
    bdu_cks=1

    # Iterate through NRCORE docker compose images
    for image in "${!NRCORE_DC_IMAGES_TAGS[@]}"; do
      image_name="$(echo ${NRCORE_DC_IMAGES_TAGS[$image]} | cut -d: -f1)"
      image_tag="$(echo ${NRCORE_DC_IMAGES_TAGS[${image}]} | cut -d: -f2)"
      image_exists=$(docker image ls | grep -v 'rdefosseoai'	| grep "${image_name}" | grep -c "${image_tag}")

      if [[ ${image_exists} -ge 1 ]]; then
        printf "${image_name}:${image_tag} ... ${SUCCESS}YES${NC} \n"	
        if [[ "${BASIC_DEPLOYMENT}" == *"${image_name}"* ]]; then
          let "bdu_cks*=1"		
        fi
      else
        printf "${image_name}:${image_tag} ... ${ERROR}NO${NC} - Possible problems: no image, no retag, wrong tag\n"	
        if [[ "${BASIC_DEPLOYMENT}" == *"${image_name}"* ]]; then
          let "bdu_cks*=0"		
        fi
      fi
    done 

    echo ""

    if [[ ${bdu_cks} -eq 1 ]]; then
      printf "NRCORE BASIC DEPLOYMENT ... ${SUCCESS}YES${NC} \n"
    else
      printf "NRCORE BASIC DEPLOYMENT ... ${ERROR}NO${NC} \n"
      correct_initialization="False"
    fi

    echo ""

  else
    echo "Checking if open5gs services are active "
    echo ""

    is_mongo_running=$(systemctl status mongod | grep -c "active (running)")

    if [[ "${is_mongo_running}" -eq 1 ]];then
      printf "MongoDB is running ... ${SUCCESS}YES${NC}\n"
    else
      printf "MongoDB is running ... ${ERROR}NO${NC}\n"
      printf "${ERROR}ERROR:${NC} MongoDB service needs to be active and running before executing Open5Gs core technology\n"
      correct_initialization="False"
    fi

    echo ""

    fi

  }

########################################
#####  4 Checking SSH Connections  #####
########################################

###################################################
# Check that SSH connections between nodes work correctly
#
# Globals:
#   DEPLOY_NRCORE_ONLY
#   GNB_IP_ADDRESS
#   SHARP_ORCHESTRATOR_WORKING_DIR
#   GNB_USERNAME
#   GNB_IP_ADDRESS
#   NRCORE_USERNAME
#   NRCORE_IP_ADDRESS
# Arguments:
#   None
# Outputs:
#   Print the result of the check process to stdout
#####################################################


function check_ssh_connections {
  echo "##################################"
  echo "Checking SSH connections"
  echo "##################################"
  echo ""

  core_2_gnb_ping=0
  core_2_gnb_ssh=0
  gnb_2_core_ssh=0

  if [[ ${DEPLOY_NRCORE_ONLY} == "false" ]]; then

    ping -c 5 ${GNB_IP_ADDRESS} >> ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/checking_repo_ping.log  2>&1 
    if [[ $? -eq 0 ]]; then
      core_2_gnb_ping=1
      ssh -o BatchMode=yes ${GNB_USERNAME}@${GNB_IP_ADDRESS} "true" > /dev/null 2>&1 
      if [[ $? -eq 0 ]]; then
        core_2_gnb_ssh=1
        printf "CORE --> GNB ... ${SUCCESS}YES${NC}\n"

        # Check ssh other direction gNB --> CORE
        ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "ssh -o BatchMode=yes ${NRCORE_USERNAME}@${NRCORE_IP_ADDRESS} \"true\" > /dev/null 2>&1"
        if [[ $? -eq 0 ]]; then
          gnb_2_core_ssh=1
          printf "GNB --> CORE ... ${SUCCESS}YES${NC}\n"
        else
          printf "GNB --> CORE ... ${ERROR}NO${NC} - Check ip address, username, auth keys or fingerprint in known hosts has been added\n"
          correct_initialization="False"
        fi
      else
        printf "CORE --> GNB ... ${ERROR}NO${NC} - gNB IP address is reachable, check username, auth keys or fingerprint in known hosts has been added\n"
        printf "GNB --> CORE ... ${ERROR}NO${NC} - Couldn't check this direction\n"
        correct_initialization="False"
      fi
    else
      printf "CORE --> GNB ... ${ERROR}NO${NC} - gNB IP address ${GNB_IP_ADDRESS} not reachable\n"
      printf "GNB --> CORE ... ${ERROR}NO${NC} - Couldn't check this direction as gNB IP address is not reachable\n"
      correct_initialization="False"
    fi

  else
    echo "No need to check SSH connections for core-only deployment"
  fi
  echo ""

}

#####################################
#####  Checking Repositories  #####
#####################################

###################################################
# Check that NRCORE repositories containing binaries and/or configuration exist
#
# Globals:
#   NRCORE_TECH
#   NRCORE_DOCKER_COMPOSE_WD
#   NRCORE_OPEN5GS_WD
#   DEPLOY_NRCORE_ONLY
#   GNB_USERNAME
#   GNB_IP_ADDRESS
#   GNB_TECH
#   NR_SOFTMODEM_BIN
#   SRS_GNB_BIN
# Arguments:
#   None
# Outputs:
#   Print the result of the check process to stdout
#####################################################


function check_repositories {

  echo "##################################"
  echo "Checking necessary repositories & binaries"
  echo "##################################"
  echo ""

  if [[ "${NRCORE_TECH}" == "OAI" ]]; then

    # For OAI CORE we need to check that the docker-compose dir exists
    echo "OAI CORE"
    if [[ -d "${NRCORE_DOCKER_COMPOSE_WD}" ]]; then
      printf "	${NRCORE_DOCKER_COMPOSE_WD}/ directory ... ${SUCCESS}YES${NC} \n"
      vtag=$(git -C ${NRCORE_DOCKER_COMPOSE_WD} describe --tags)
      echo "     NOTES:"
      if [[ $(echo ${vtag} | grep -c "fatal" ) -ge 1 ]]; then 
        printf "       - ${NRCORE_DOCKER_COMPOSE_WD} TAG ${WARNING}could not be detected${NC}, please check branch tag \n"
      else
        printf "       - ${NRCORE_DOCKER_COMPOSE_WD} in TAG ${vtag}\n"
        printf "       - ${vtag} should be the same as docker images\n"
      fi
    else
      printf "${NRCORE_DOCKER_COMPOSE_WD}/ directory... ${ERROR}NO${NC} \n"
      correct_initialization="False"
    fi

  else

    # For OPEN5GS CORE we need to check that the cloned project dir exists
    echo "OPEN5GS CORE"
    if [[ -d "${NRCORE_OPEN5GS_WD}" ]]; then
      printf "        ${NRCORE_OPEN5GS_WD}/ directory ... ${SUCCESS}YES${NC} \n"
      vtag=$(git -C ${NRCORE_OPEN5GS_WD} describe --tags)
      echo "     NOTES:"
      if [[ $(echo ${vtag} | grep -c "fatal" ) -ge 1 ]]; then
        printf "       - ${NRCORE_OPEN5GS_WD} TAG ${WARNING}could not be detected${NC}, please check branch tag \n"
      else
        printf "       - ${NRCORE_OPEN5GS_WD} in TAG ${vtag}\n"
      fi
    else
      printf "${NRCORE_OPEN5GS_WD}/ directory... ${ERROR}NO${NC} \n"
      correct_initialization="False"
    fi

  fi

  if [[ ${DEPLOY_NRCORE_ONLY} == "false" ]]; then

    # For the gNB we need to check that the nr-softmodem binary exists
    echo "gNB"
    if [[ "${core_2_gnb_ssh}" -eq 1 ]]; then 

      if [[ "${GNB_TECH}" == "OAI" ]]; then	

        # For OAI gNB we need to check that the nr-softmodem binary exists
        if ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "[[ -f ${NR_SOFTMODEM_BIN} ]]"; then 
          printf "     nrsoftmodem bin ... ${SUCCESS}YES${NC} \n"
        else
          printf "     nrsoftmodem bin ... ${ERROR}NO${NC} \n"
          correct_initialization="False"
        fi
      else

        # For SRS gNB we need to check that the gnb binary exists
        if ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "[[ -f ${SRS_GNB_BIN} ]]"; then
          printf "     SRS gnb bin ... ${SUCCESS}YES${NC} \n"
        else
          printf "     SRS gnb bin ... ${ERROR}NO${NC} \n"
          correct_initialization="False"
        fi
      fi

    else
      if [[ "${GNB_TECH}" == "OAI" ]]; then
        printf "     nrsoftmodem bin ... ${ERROR}NO${NC} - Couldn't check, no access via ssh\n"
      else
        printf "     SRS gnb bin ... ${ERROR}NO${NC} - Couldn't check, no access via ssh\n"

      fi
    fi
  fi
  echo ""
}

##################################
#####  Check sudoers file  #####
##################################

###################################################
# Check that sudoers file have correctly configured permissions
#
# Globals:
#   NRCORE_USERNAME
#   DEPLOY_NRCORE_ONLY
#   GNB_USERNAME
#   GNB_IP_ADDRESS
# Arguments:
#   None
# Outputs:
#   Print the result of the check process to stdout
#####################################################


function check_sudoers {

  local orch_and_core_sudo_commands=$(cat <<END
  /usr/bin/kill -9 \*
  /usr/bin/chown -R \* /tmp
  /usr/bin/chown -R \* /logs
  /usr/bin/python3 core-network.py --type start-basic
  /usr/bin/python3 core-network.py --type stop-basic
  /usr/sbin/ip tuntap add name ogstun mode tun
  /usr/sbin/ip addr del 10.45.0.1/16 dev ogstun
  /usr/sbin/ip addr add 10.45.0.1/16 dev ogstun
  /usr/sbin/ip addr del 2001\\\:db8\\\:cafe\\\:\\\:1/48 dev ogstun
  /usr/sbin/ip addr add 2001\\\:db8\\\:cafe\\\:\\\:1/48 dev ogstun
  /usr/sbin/ip link set ogstun up
  /usr/sbin/sysctl net.ipv4.conf.all.forwarding\\\=1
  /usr/sbin/iptables -P FORWARD ACCEPT
  /usr/sbin/iptables -S
END
)

local gnb_sudo_commands=$(cat <<END
/usr/sbin/ip route del \*
/usr/sbin/ip route add \*
/usr/bin/unbuffer \*
/usr/bin/kill -9 \*
END
)

  # username has to have NOPASSWD for ALL commands in CORE, eNB and gNB
  echo "##################################"
  echo "Checking sudoers file"
  echo "##################################"
  echo ""

  # ORCH & CORE
  while read -r line; do
    is_command_in_sudoers=$(sudo -l | grep "(ALL) NOPASSWD: " | grep -c -- "${line}" 2>/dev/null)
    if [[ "${is_command_in_sudoers}" -eq 0 ]]; then
      printf "NOPASSWD in ORCH & CORE for ${SHARP_ORCHESTRATOR_USERNAME} for command ${line} ... ${ERROR}NO${NC}\n"
      correct_initialization="False"
    else
      printf "NOPASSWD in ORCH & CORE for ${SHARP_ORCHESTRATOR_USERNAME} for command ${line} ... ${SUCCESS}YES${NC}\n"
    fi
  done < <(echo "${orch_and_core_sudo_commands}")

  if [[ ${DEPLOY_NRCORE_ONLY} == "false" ]]; then

    # gNB
    if [[ "${core_2_gnb_ping}" -eq 1 ]]; then
      if [[ "${core_2_gnb_ssh}" -eq 1 ]]; then
        while read -r line; do
          is_command_in_sudoers=$(ssh -n ${GNB_USERNAME}@${GNB_IP_ADDRESS} "sudo -l | grep \"(ALL) NOPASSWD:\" | grep -c -- \"${line}\" 2> /dev/null")
          if [[ "${is_command_in_sudoers}" -eq 0 ]]; then
            printf "NOPASSWD for ${GNB_USERNAME} for command ${line} in GNB ... ${ERROR}NO${NC}\n"
            correct_initialization="False"
          else
            printf "NOPASSWD in GNB for ${GNB_USERNAME} for command ${line} in GNB ... ${SUCCESS}YES${NC}\n"
          fi
        done < <(echo "${gnb_sudo_commands}")
      else
        printf "NOPASSWD for ${GNB_USERNAME} in gNB ... ${ERROR}NO${NC} - Cannot check gNB repositories - no access via ssh\n"
        correct_initialization="False"
      fi
    else
      printf "NOPASSWD for ${GNB_USERNAME} in gNB ... ${ERROR}NO${NC} - Cannot check gNB repositories - gNB IP address ${GNB_IP_ADDRESS} not reachable\n"
      correct_initialization="False"
    fi

  fi

  echo ""

}


#####################################################
#####  Check sharp-orchestrator.src parameters  #####
#####################################################

###################################################
# Check that parameters specified in main configuration file are correct
#
# Globals:
#   MCC
#   MNC
#   DEBUG
#   DEPLOY_NRCORE_ONLY
#   DNS_IP_ADDRESS
#   AMF_IP_ADDRESS
#   SHARP_ORCHESTRATOR_IP_ADDRESS
#   GNB_IP_ADDRESS
#   NRCORE_TECH
#   NRCORE_IP_ADDRESS
#   NRCORE_DEPLOYMENT_VERSION
#   NRCORE_DOCKER_COMPOSE_WD
# Arguments:
#   None
# Outputs:
#   Print the result of the check process to stdout
#####################################################


function check_src_parameters {

  echo "##################################"
  echo "Checking sharp-orchestrator.src parameters"
  echo "##################################"
  echo ""

  #
  # MCC can only have 3 decimal digits
  #

  if [[ ${#MCC} -eq 3 ]]; then
    printf "MCC ${INPUT}${MCC}${NC} ... ${SUCCESS}YES${NC}\n"
  else
    printf "MCC ${INPUT}${MCC}${NC} ... ${ERROR}NO${NC} - MCC should have 3 decimal digits\n"
  fi

  #
  # MNC can only have 2 decimal digits
  #

  if [[ ${#MNC} -eq 2 ]] || [[ ${#MNC} -eq 3 ]]; then
    printf "MNC ${INPUT}${MNC}${NC} ... ${SUCCESS}YES${NC}\n"
  else
    printf "MNC ${INPUT}${MNC}${NC} ... ${ERROR}NO${NC} - MCC should have 2 or 3 decimal digits\n"
  fi

  #
  # DEBUG can only be true or false
  #

  if [[ "${DEBUG}" == "true" || "${DEBUG}" == "false" ]]; then
    printf "DEBUG ${INPUT}${DEBUG}${NC} ... ${SUCCESS}YES${NC}\n"
  else
    printf "DEBUG ${INPUT}${DEBUG}${NC} ... ${ERROR}NO${NC} - DEBUG variable can only be true or false\n"
  fi

  #
  # DEPLOY_NRCORE_ONLY should be true or false
  #

  if [[ "${DEPLOY_NRCORE_ONLY}" == "true" ]] ||  [[ "${DEPLOY_NRCORE_ONLY}" == "false" ]]; then
    printf "DEPLOY_NRCORE_ONLY ${INPUT}${DEPLOY_NRCORE_ONLY}${NC} ... ${SUCCESS}YES${NC}\n"
  else
    printf "DEPLOY_NRCORE_ONLY ${INPUT}${DEPLOY_NRCORE_ONLY}${NC} ... ${ERROR}NO${NC} - DEPLOY_NRCORE_ONLY variable can only be true or false\n"
  fi


  #
  # DNS_IP_ADDRESS should be an ip address
  #

  if [[ ${DNS_IP_ADDRESS} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    printf "DNS_IP_ADDRESS ${INPUT}${DNS_IP_ADDRESS}${NC} ... ${SUCCESS}YES${NC}\n"
  else
    printf "DNS_IP_ADDRESS ${INPUT}${DNS_IP_ADDRESS}${NC} ... ${ERROR}NO${NC} - DNS_IP_ADDRESS should be an ip address\n"
  fi

  #
  # AMF_IP_ADDRESS should be an ip address
  #

  if [[ ${AMF_IP_ADDRESS} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    printf "AMF_IP_ADDRESS ${INPUT}${AMF_IP_ADDRESS}${NC} ... ${SUCCESS}YES${NC}\n"
  else
    printf "AMF_IP_ADDRESS ${INPUT}${AMF_IP_ADDRESS}${NC} ... ${ERROR}NO${NC} - AMF_IP_ADDRESS should be an ip address\n"
  fi

  #
  # SHARP_ORCHESTRATOR_IP_ADDRESS should be an ip address
  #

  if [[ ${SHARP_ORCHESTRATOR_IP_ADDRESS} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    printf "SHARP_ORCHESTRATOR_IP_ADDRESS ${INPUT}${SHARP_ORCHESTRATOR_IP_ADDRESS}${NC} ... ${SUCCESS}YES${NC}\n"
  else
    printf "SHARP_ORCHESTRATOR_IP_ADDRESS ${INPUT}${SHARP_ORCHESTRATOR_IP_ADDRESS}${NC} ... ${ERROR}NO${NC} - SHARP_ORCHESTRATOR_IP_ADDRESS should be an ip address\n"
  fi

  #
  # NRCORE_IP_ADDRESS should be an ip address
  #

  if [[ ${NRCORE_IP_ADDRESS} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    printf "NRCORE_IP_ADDRESS ${INPUT}${NRCORE_IP_ADDRESS}${NC} ... ${SUCCESS}YES${NC}\n"
  else
    printf "NRCORE_IP_ADDRESS ${INPUT}${NRCORE_IP_ADDRESS}${NC} ... ${ERROR}NO${NC} - NRCORE_IP_ADDRESS should be an ip address\n"
  fi

  #
  # AMF_IP_ADDRESS should be an ip address
  #
  if [[ ${DEPLOY_NRCORE_ONLY} == "false" ]]; then
    if [[ ${GNB_IP_ADDRESS} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      printf "GNB_IP_ADDRESS ${INPUT}${GNB_IP_ADDRESS}${NC} ... ${SUCCESS}YES${NC}\n"
    else
      printf "GNB_IP_ADDRESS ${INPUT}${GNB_IP_ADDRESS}${NC} ... ${ERROR}NO${NC} - GNB_IP_ADDRESS should be an ip address\n"
    fi
  fi

  #
  # For OAI CORE, IP address cannot be localhost if core and gnb are running in the same machine
  # For OPEN5GS CORE, IP address must be localhost if core and gnb are running in the same machine and GNB cannot share IP with AMF
  #
  if [[ ${DEPLOY_NRCORE_ONLY} == "false" ]]; then

    if [[ "${NRCORE_TECH}" == "OPEN5GS" ]] && [[ "${NRCORE_IP_ADDRESS}" == "${GNB_IP_ADDRESS}" ]] && [[ "${NRCORE_IP_ADDRESS}" != "127.0.0.1" ]]; then
      printf "${WARNING}WARNING:${NC} OPEN5GS NRCORE and GNB IP addresses should be 127.0.0.1 if they are running on the same machine\n"

      fi 

      if [[ "${NRCORE_TECH}" == "OPEN5GS" ]] && [[ "${AMF_IP_ADDRESS}" == "${GNB_IP_ADDRESS}" ]]; then
        printf "${ERROR}ERROR:${NC} For OPEN5GS NRCORE, AMF and GNB IP addresses cannot be the same\n"

      fi 
    fi


    if [[ "${NRCORE_TECH}" == "OAI" ]]; then

      #
      # NRCORE_DEPLOYMENT_VERSION can be v2.0.1 or v2.1.0
      #

      if [[ "${NRCORE_DEPLOYMENT_VERSION}" == "v2.0.1" || "${NRCORE_DEPLOYMENT_VERSION}" == "v2.1.0" ]]; then
        printf "NRCORE_DEPLOYMENT_VERSION ${INPUT}${NRCORE_DEPLOYMENT_VERSION}${NC} ... ${SUCCESS}YES${NC}\n"
        if [[ "${vtag}" != "${NRCORE_DEPLOYMENT_VERSION}" ]]; then
          printf "${WARNING}WARNING:${NC} NRCORE_DEPLOYMENT_VERSION ${NRCORE_DEPLOYMENT_VERSION} does not match with \ 
            ${NRCORE_DOCKER_COMPOSE_WD} version ${vtag}\	
            In v2.0.1 the tag is 2024.w04\n"
        fi
      else
        printf "NRCORE_DEPLOYMENT_VERSION ${INPUT}${NRCORE_DEPLOYMENT_VERSION}${NC} ... ${ERROR}NO${NC} - \ 
          NRCORE_DEPLOYMENT_VERSION variable can only be v2.0.1 or v2.1.0\n"
      fi

    fi

    echo ""
  }

#####################
### Check gNB dir ###
#####################

###################################################
# Check that gNB working directory exists
#
# Globals:
#   GNB_IP_ADDRESS
#   GNB_USERNAME
#   GNB_WORKING_DIR
# Arguments:
#   None
# Outputs:
#   Print the result of the check process to stdout
#####################################################


function check_gnb_dir {

  if [[ "${DEPLOY_NRCORE_ONLY}" == "false" ]]; then

    echo "##################################"
    echo "Checking gNB directory"
    echo "##################################"
    echo ""

    if [[ "${core_2_gnb_ssh}" -eq 1 ]]; then

      gnb_dir_exists=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "[ -d ${GNB_WORKING_DIR} ] && echo '1' || echo '0' ")
      if [[ ${gnb_dir_exists} -eq 0 ]]; then
        echo  "GNB_WORKING_DIR does not exist"
        echo "Creating directory..."
        ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "mkdir -p ${GNB_WORKING_DIR}"

        gnb_dir_exists=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "[ -d ${GNB_WORKING_DIR} ] && echo '1' || echo '0' ")
        if [[ ${gnb_dir_exists} -eq 0 ]]; then 
          printf "GNB directory ... ${ERROR}NO${NC} - directory could not be created, please check permissions\n"
          correct_initialization="False"
        else
          printf "GNB directory ... ${SUCCESS}YES${NC}\n"
        fi
      else
        printf "GNB directory ... ${SUCCESS}YES${NC}\n"
      fi
    else
      printf "GNB directory ... ${ERROR}NO${NC} - gNB IP address ${GNB_IP_ADDRESS} not reachable\n"
      correct_initialization="False"
    fi
  fi
}

## Create necessary directories
[[ -d ${working_directory}/tmp/ ]] || mkdir ${working_directory}/tmp
[[ -d ${working_directory}/logs/ ]] || mkdir ${working_directory}/logs

check_basic_variables
check_binaries
check_nrcore_info
check_nrcore_services
check_ssh_connections
check_repositories
check_sudoers
check_src_parameters
check_gnb_dir

if [[ "${correct_initialization}" == "False" ]]; then
  exit 1
fi
