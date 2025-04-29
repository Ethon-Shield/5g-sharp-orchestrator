#!/bin/bash
#######################################################################
#
#   Author:     ETHON SHIELD SL
#   Version:    0.0.5
#   License:    AGPLv3
#   Copyright:  Copyright (C) 2021-2025, 5G Sharp Orchestrator
#   Email:      sharp-orchestrator@ethonshield.com
#
#######################################################################

source ${HOME}/sharp-orchestrator.src
source ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/general_functions.sh

# Check if specified docker versions exist 

for image in "${!NRCORE_DC_IMAGES_TAGS[@]}"; do
	image_name="$(echo ${NRCORE_DC_IMAGES_TAGS[$image]} | cut -d: -f1)"
	image_tag="$(echo ${NRCORE_DC_IMAGES_TAGS[${image}]} | cut -d: -f2)"
	image_exists=$(docker image ls | grep -v 'rdefosseoai' | grep ${image_name} | grep -c ${image_tag})

	if ! [[ ${image_exists} -ge 1 ]]; then
		echo "ERROR: Could not find IMAGE ${image_name} with TAG ${image_tag}" 
		echo "Please check you have the correct images"
		exit 1
	fi

done

for image in "${!NRCORE_DC_IMAGES_TAGS[@]}"; do
	node_name="$(echo ${image} | awk '{print tolower($0)}')"
	new_version="$(echo ${NRCORE_DC_IMAGES_TAGS[$image]})"
	old_version="$(grep ${node_name} ${DC_FILE_PATH} | grep "image" | awk '{print$2}' | uniq)"		
	if [[ -n ${old_version} && "${old_version}" != "${new_version}" ]]; then
    if [[ ${new_version} =~ "/" ]]; then
      new_version=$(echo "${new_version}" | sed 's/\//\\\//g')
    fi
    if [[ ${old_version} =~ "/" ]]; then
      old_version=$(echo "${old_version}" | sed 's/\//\\\//g')
    fi
    echo "Modifying ${node_name} from ${old_version} to ${new_version}"
    sed -i "s/${old_version}/${new_version}/g" ${DC_FILE_PATH}
  fi
done
