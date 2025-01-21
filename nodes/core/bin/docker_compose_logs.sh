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
source ${NRCORE_WORKING_DIR}/bin/general_functions.sh

CURRENT_DIR=$(pwd)

cd ${NRCORE_DOCKER_COMPOSE_WD}

docker-compose -f docker-compose-basic-nrf.yaml logs -f > ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/docker-compose-all-containers.log 2>&1 &

cd ${CURRENT_DIR}
