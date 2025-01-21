#!/bin/bash
#######################################################################
#
#   Author:     ETHON SHIELD SL
#   Version:    0.0.1
#   License:    AGPLv3
#   Copyright:  Copyright (C) 2021-2025, 5G Sharp Orchestrator
#   Email:      sharp-orchestrator@ethonshield.com
#
#######################################################################

source ${HOME}/sharp-orchestrator.src
source ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/general_functions.sh

######################################################
# Copy general functions script to NRCORE and gNB working directories
#
# Globals:
#   SHARP_ORCHESTRATOR_WORKING_DIR
# Arguments:
#   None
# Outputs:
#   None
######################################################

function copy_general_functions_script {
  cp ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/general_functions.sh ${SHARP_ORCHESTRATOR_WORKING_DIR}/nodes/gnb/bin/
  cp ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/general_functions.sh ${SHARP_ORCHESTRATOR_WORKING_DIR}/nodes/core/bin/
}

######################################################
# Modify configuration BASE files with ENV variables specified in main source file 
#
# Globals:
#   NRCORE_TECH
#   TAC
#   INT_ALGO_PRIORITY_LIST
#   CIPH_ALGO_PRIORITY_LIST
#   MCC
#   MNC
#   DNS_IP_ADDRESS
#   DC_CONFIG_FILE_PATH
#   SUFFIX
#   NRCORE_WORKING_DIR
#   NR_BIN_INDEX
#   NR_BIN_LOG
#   NR_BIN_CONF
#   OPEN5GS_CONF_DIR
#   SHARP_ORCHESTRATOR_WORKING_DIR
#   DC_FILE_PATH
#   DC_FILE
#   NRCORE_DOCKER_COMPOSE_WD
#   DC_CONFIG_FILE_PATH
#   DC_CONFIG_FILE
#   DDBB_FILE_PATH
#   DDBB_FILE
# Arguments:
#   None
# Outputs:
#   None
######################################################


function modify_nrcore_parameters {
  
  # The parameters that need to be modified are:
  #   - MCC (OAI & open5GS)
  #   - MNC (OAI & open5GS)
  #   - TAC (OAI & open5GS)
  #   - DNS_IP_ADDRESS (OAI & open5GS)
  #   - AMF_IP_ADDRESS (OAI & open5GS)
  #   - INT_ALGO_PRIORITY_LIST (OAI & open5GS)
  #   - CIPH_ALGO_PRIORITY_LIST (OAI & open5GS)
  
  ##################################
  ### Preprocessing of variables ###
  ##################################  
  # TAC
  HEX_TAC=0x$(printf "%X\n" ${TAC})

  # INT_ALGO_PRIORITY_LIST & CIPH_ALGO_PRIORITY_LIST
  if [[ "${NRCORE_TECH}" == "OAI" ]]; then
    # ALGO list is in the format:
    #   - "NEA0"
    #   - "NEA1"
    #   - "NEA2"
    integrity_algorithm_list=$(echo "${INT_ALGO_PRIORITY_LIST}" | awk -F, '{for(i=1;i<=NF;i++) printf "    - \"" $i "\"\\n"}' | rev | sed 's/n\\//' | rev) 
    ciphering_algorithm_list=$(echo "${CIPH_ALGO_PRIORITY_LIST}" | awk -F, '{for(i=1;i<=NF;i++) printf "    - \"" $i "\"\\n"}' | rev | sed 's/n\\//' | rev) 
  fi

  #################################
  ### Substitution of variables ###
  #################################

  if [[ "${NRCORE_TECH}" == "OAI" ]]; then
      
      sed -e "s/__MCC__/${MCC}/g" -e "s/__MNC__/${MNC}/g" -e "s/__TAC__/${HEX_TAC}/g" -e "s/__DNS_IP_ADDRESS__/${DNS_IP_ADDRESS}/g" -e "s/__INT_ALGO_PRIORITY_LIST__/${integrity_algorithm_list}/g" -e "s/__CIPH_ALGO_PRIORITY_LIST__/${ciphering_algorithm_list}/g" "${DC_CONFIG_FILE_PATH}${SUFFIX}" > ${DC_CONFIG_FILE_PATH}
      sed -e "s/__MCC__/${MCC}/g" -e "s/__MNC__/${MNC}/g" -e "s/__TAC__/${HEX_TAC}/g" -e "s/__DNS_IP_ADDRESS__/${DNS_IP_ADDRESS}/g" -e "s/__INT_ALGO_PRIORITY_LIST__/${integrity_algorithm_list}/g" -e "s/__CIPH_ALGO_PRIORITY_LIST__/${ciphering_algorithm_list}/g" "${DC_FILE_PATH}${SUFFIX}" > ${DC_FILE_PATH}
  
elif [[ "${NRCORE_TECH}" == "OPEN5GS" ]]; then

    OPEN5GS_CONF_DIR=${NRCORE_WORKING_DIR}/conf/open5gs
    for binary in "${NR_BIN_INDEX[@]}"
    do
      LOG_ROUTE=${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/${NR_BIN_LOG[${binary}]}
      BASE_ROUTE=${NRCORE_OPEN5GS_WD}
      ESCAPED_LOG_ROUTE=$(echo "${LOG_ROUTE}" | sed 's/\//\\\//g')
      ESCAPED_BASE_ROUTE=$(echo "${BASE_ROUTE}" | sed 's/\//\\\//g')
      sed -e "s/__LOG_ROUTE__/${ESCAPED_LOG_ROUTE}/g" -e "s/__BASE_ROUTE__/${ESCAPED_BASE_ROUTE}/g" "${OPEN5GS_CONF_DIR}/${NR_BIN_CONF[${binary}]}${SUFFIX}" > ${OPEN5GS_CONF_DIR}/${NR_BIN_CONF[${binary}]}
    done

    sed -i -e "s/__MCC__/${MCC}/g" -e "s/__MNC__/${MNC}/g" -e "s/__TAC__/${TAC}/g" -e "s/__AMF_IP_ADDRESS__/${AMF_IP_ADDRESS}/g" -e "s/__INT_ALGO_PRIORITY_LIST__/${INT_ALGO_PRIORITY_LIST}/g" -e "s/__CIPH_ALGO_PRIORITY_LIST__/${CIPH_ALGO_PRIORITY_LIST}/g" ${OPEN5GS_CONF_DIR}/amf.yaml
    sed -i -e "s/__MCC__/${MCC}/g" -e "s/__MNC__/${MNC}/g" ${OPEN5GS_CONF_DIR}/nrf.yaml
    sed -i -e "s/__AMF_IP_ADDRESS__/${AMF_IP_ADDRESS}/g" ${OPEN5GS_CONF_DIR}/upf.yaml
    sed -i -e "s/__DNS_IP_ADDRESS__/${DNS_IP_ADDRESS}/g" ${OPEN5GS_CONF_DIR}/smf.yaml

  fi 
  #############################################
  ### Copy files to corresponding directory ###
  #############################################

  if [[ "${NRCORE_TECH}" == "OAI" ]]; then

    # Modifying docker compose file if necessary - docker images versions
    ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/modify_docker_images_versions.sh 
    if [[ $? -eq 1 ]]; then
      echo "Error while modifying docker compose file - docker images versions"
      exit 1
    fi

    # Copy docker compose files
    cp ${DC_FILE_PATH} ${NRCORE_DOCKER_COMPOSE_WD}/${DC_FILE}
    cp ${DC_CONFIG_FILE_PATH} ${NRCORE_DOCKER_COMPOSE_WD}/conf/${DC_CONFIG_FILE}
    # Copy database files
    cp ${DDBB_FILE_PATH} ${NRCORE_DOCKER_COMPOSE_WD}/database/${DDBB_FILE} 

  fi

}

######################################################
# Modify gNB configuration BASE files with ENV variables specified in main source file 
#
# Globals:
#   DEPLOY_NRCORE_ONLY
#   NRCORE_TECH
#   GNB_TECH
#   MCC
#   MNC
#   GNB_IP_ADDRESS
#   TAC
#   BAND
#   ARFCN
#   POINT_A
#   CHANNEL_BW
#   SCS
#   GNB_USERNAME
#   AMF_IP_ADDRESS
#   SUFFIX
#   SHARP_ORCHESTRATOR_WORKING_DIR
#   CENTRALISED_GNB_CONFIG_FILE
# Arguments:
#   None
# Outputs:
#   None
######################################################


function modify_gnb_parameters {

  # The parameters that need to be modified are:
  #   - MCC (OAI & srsRAN)
  #   - MNC (OAI & srsRAN)
  #   - MNC_LENGTH (OAI)
  #   - TAC (OAI & srsRAN)
  #   - BAND (srsRAN)
  #   - ARFCN (OAI & srsRAN)
  #   - POINT_A (OAI)
  #   - CHANNEL_BW (srsRAN)
  #   - SCS (srsRAN)

  if [[ "${DEPLOY_NRCORE_ONLY}" == "false" ]]; then

    ##################################
    ### Preprocessing of variables ###
    ##################################

    # IP Address
    GNB_IP_ADDRESS_IN_CONF_FILE="${GNB_IP_ADDRESS}"
    if [[ "${GNB_IP_ADDRESS}" == "127.0.0.1" && "${NRCORE_TECH}" == "OAI" ]]; then
      GNB_IP_ADDRESS_IN_CONF_FILE="192.168.70.129"
    fi

    # Point A
    if [[ -z "${POINT_A}" && "${GNB_TECH}" == "OAI" ]]; then
      # Check if URL is reachable
      is_reachable=$(curl -Is 'https://www.sqimway.com/calc_pointA.php' | head -1 | grep -c "HTTP/2 200")
      if [[ ${is_reachable} -ge 1 ]]; then 
        # Get freq point A
        get_pointA_from_arfcn=$(curl -s 'https://www.sqimway.com/calc_pointA.php' -X POST --data-raw "band=n78&bmu=30&ssmu=30&bandwidth=40&arfcn=${ARFCN}&msi=0+(24+RBs%2C+offset+0)")
        POINT_A=$(echo "${get_pointA_from_arfcn}" | grep -A 6 "Point A Arfcn" | tail -1 | awk -F "<b>" '{print $2}' | awk -F "</b>" '{print $1}')
        echo "POINT A calculated: ${POINT_A}"
      else 
        echo "Error: Cannot reach https://www.sqimway.com/calc_pointA.php, please manually add ARFCN Point A"
        exit 1
      fi
    fi

    #################################
    ### Substitution of variables ###
    #################################

    if [[ "${GNB_TECH}" == "OAI" ]]; then
      sed -e "s/__MCC__/${MCC}/g" -e "s/__MNC__/${MNC}/g" ${CENTRALISED_GNB_CONFIG_FILE}${SUFFIX} > ${CENTRALISED_GNB_CONFIG_FILE}
      sed -i -e "s/__TAC__/${HEX_TAC}/g" ${CENTRALISED_GNB_CONFIG_FILE}
      sed -i -e "s/__MNC_LENGTH__/${#MNC}/g" ${CENTRALISED_GNB_CONFIG_FILE}	
      sed -i -e "s/__GNB_IP_ADDRESS__/${GNB_IP_ADDRESS_IN_CONF_FILE}/g" -e "s/__AMF_IP_ADDRESS__/${AMF_IP_ADDRESS}/g" ${CENTRALISED_GNB_CONFIG_FILE}
      sed -i -e "s/__ARFCN__/${ARFCN}/g" -e "s/__POINT_A__/${POINT_A}/g" ${CENTRALISED_GNB_CONFIG_FILE} 
    elif [[ "${GNB_TECH}" == "SRS" ]]; then
      sed -e "s/__MCC__/${MCC}/g" -e "s/__MNC__/${MNC}/g" ${CENTRALISED_GNB_CONFIG_FILE}${SUFFIX} > ${CENTRALISED_GNB_CONFIG_FILE}
      sed -i -e "s/__TAC__/${TAC}/g" ${CENTRALISED_GNB_CONFIG_FILE}
      sed -i -e "s/__GNB_IP_ADDRESS__/${GNB_IP_ADDRESS_IN_CONF_FILE}/g" -e "s/__AMF_IP_ADDRESS__/${AMF_IP_ADDRESS}/g" ${CENTRALISED_GNB_CONFIG_FILE}
      sed -i -e "s/__BAND__/${BAND}/g" -e "s/__ARFCN__/${ARFCN}/g" -e "s/__CHANNEL_BW__/${CHANNEL_BW}/g" -e "s/__SCS__/${SCS}/g" ${CENTRALISED_GNB_CONFIG_FILE} 
    fi

    ########################################
    ### Synchronization with remote node ###
    ########################################
    echo "Synching files.." 

    rsync -a --delete ${SHARP_ORCHESTRATOR_WORKING_DIR}/nodes/gnb/ ${GNB_USERNAME}@${GNB_IP_ADDRESS}:${GNB_WORKING_DIR}
    if [[ $? -eq 1 ]]; then
      echo "Error synching gnb files"
      exit 1
    fi

    ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "mkdir -p ${GNB_WORKING_DIR}/tmp ${GNB_WORKING_DIR}/logs"
    if [[ $? -eq 1 ]]; then
      echo "Error creating gnb directories"
      exit 1
    fi

    # Copy src file to gNB	
    scp ${HOME}/sharp-orchestrator.src ${GNB_USERNAME}@${GNB_IP_ADDRESS}:/home/${GNB_USERNAME}/ > /dev/null 2>&1
    if [[ $? -eq 1 ]]; then
      echo "Error copying src file to gnb directory"
      exit 1
    fi

    # Remove centralised gnb config file
    rm ${CENTRALISED_GNB_CONFIG_FILE}

  fi

}

copy_general_functions_script
modify_nrcore_parameters
modify_gnb_parameters
