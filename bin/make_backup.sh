#!/bin/bash
#######################################################################
#
#   Author:     ETHON SHIELD SL
#   Version:    0.0.3
#   License:    AGPLv3
#   Copyright:  Copyright (C) 2021-2025, 5G Sharp Orchestrator
#   Email:      sharp-orchestrator@ethonshield.com
#
#######################################################################

source ${HOME}/sharp-orchestrator.src
source ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/general_functions.sh

network_status=$(cat ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt)
if [[ "${network_status}" == "RUNNING" || "${network_status}" == "STOPPING" ]]; then
  logging "DEBUG" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Starting backup process"

  ################ CREATING BACKUP DIRECTORY #################3

  timestamp=$( date +'%m_%d_%Y_%H_%M_%S' )
  random_value=$( shuf -i 1-1000 -n 1 )
  BACKUP_DIR=${SHARP_ORCHESTRATOR_WORKING_DIR}/backups/${random_value}_${timestamp}_session/
  if ! [[ "${BACKUP_DIR_PREFIX}" == "" ]]; then
    BACKUP_DIR=${SHARP_ORCHESTRATOR_WORKING_DIR}/backups/${BACKUP_DIR_PREFIX}_${random_value}_${timestamp}_session/
  fi
  mkdir ${BACKUP_DIR}
  mkdir ${BACKUP_DIR}/pcaps
  mkdir ${BACKUP_DIR}/logs
  mkdir ${BACKUP_DIR}/conf

  ############### COLLECTING GNB PCAPS AND LOG FILES #######################

  if [[ "${DEPLOY_NRCORE_ONLY}" == "false" ]]; then
    gnb_log_exists=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "[[ -f ${GNB_WORKING_DIR}/logs/gnb.log ]] && echo '1'")
    if [[ "${gnb_log_exists}" -eq 1 ]]; then
      logging "DEBUG" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Retrieving gNB log file"
      scp ${GNB_USERNAME}@${GNB_IP_ADDRESS}:${GNB_WORKING_DIR}/logs/gnb.log ${BACKUP_DIR}/logs
    else
      logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Could not retrieve gNB log file"
    fi

    [[ -f ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/gnb_complete.log ]] && scp ${GNB_USERNAME}@${GNB_IP_ADDRESS}:${GNB_WORKING_DIR}/logs/gnb_complete.log ${BACKUP_DIR}/logs

    gnb_pcap_exists=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "[[ -f ${GNB_WORKING_DIR}/tmp/gnb.pcap ]] && echo '1'")
    if [[ "${gnb_pcap_exists}" -eq 1 ]]; then
      logging "DEBUG" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Retrieving gNB pcap file"
      scp ${GNB_USERNAME}@${GNB_IP_ADDRESS}:${GNB_WORKING_DIR}/tmp/gnb.pcap ${BACKUP_DIR}/pcaps
    else
      logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Could not retrieve gNB pcap file"
    fi

  # log backup
  [[ -f ${LOG_FILE} ]] && cp ${LOG_FILE} ${BACKUP_DIR}

  logging "DEBUG" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "gNB Backup completed"

  fi

  ########### COLLECTING CORE PCAPS AND LOG FILES ############################

  logging "DEBUG" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Retrieving pcap, log and conf files of NRCORE"
  chown -R "${SHARP_ORCHESTRATOR_USERNAME}:${SHARP_ORCHESTRATOR_USERNAME}" ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/
  chown -R "${SHARP_ORCHESTRATOR_USERNAME}:${SHARP_ORCHESTRATOR_USERNAME}" ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/

  [[ -d ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs ]] && cp ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/* ${BACKUP_DIR}/logs/

  if [[ "${NRCORE_TECH}" == "OAI" ]]; then

    [[ -f ${DC_FILE_PATH} ]] && cp ${DC_FILE_PATH} ${BACKUP_DIR}/logs

  fi

  [[ -f ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/nrcore_network.pcap ]] && cp ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/nrcore_network.pcap ${BACKUP_DIR}/pcaps || logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Could not retrieve NRCORE pcap file"

  [[ -f ${BACKUP_DIR}/pcaps/nrcore_network.pcap ]] && chmod +777 ${BACKUP_DIR}/pcaps/nrcore_network.pcap

  ######## COPYING OR MOVING CONFIGURATION FILES #########################

  if [[ "${NRCORE_TECH}" == "OAI" ]]; then
    cp ${DC_CONFIG_FILE_PATH} ${BACKUP_DIR}/conf/${DC_CONFIG_FILE}
    cp ${DC_FILE_PATH} ${BACKUP_DIR}/conf/${DC_FILE}
    if [[ "${network_status}" == "STOPPING" ]]; then
      rm ${DC_CONFIG_FILE_PATH} 
      rm ${DC_FILE_PATH} 
    fi
  else
    for binary in "${NR_BIN_INDEX[@]}"; do
      cp ${SHARP_ORCHESTRATOR_WORKING_DIR}/nodes/core/conf/open5gs/${NR_BIN_CONF[${binary}]} ${BACKUP_DIR}/conf/${NR_BIN_CONF[${binary}]}
      if [[ "${network_status}" == "STOPPING" ]]; then
        rm ${SHARP_ORCHESTRATOR_WORKING_DIR}/nodes/core/conf/open5gs/${NR_BIN_CONF[${binary}]} 
      fi
    done	
  fi

  if [[ "${DEPLOY_NRCORE_ONLY}" == "false" ]]; then
    cp ${GNB_CONFIG_FILE} ${BACKUP_DIR}/conf/gnb.conf
    if [[ "${network_status}" == "STOPPING" ]]; then
      rm ${GNB_CONFIG_FILE} 
    fi
  fi
  logging "INFO" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Backup process completed. Files saved in ${BACKUP_DIR}"

elif [[ "${network_status}" == "STOPPED" || "${network_status}" == "STARTING" ]]; then
  logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Backup can only be done if network is STOPPING or RUNNING"
fi
