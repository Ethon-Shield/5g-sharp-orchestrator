#!/bin/bash
#######################################################################
##
##   Author:     ETHON SHIELD SL
##   Version:    0.0.1
##   License:    AGPLv3
##   Copyright:  Copyright (C) 2021-2025, 5G Sharp Orchestrator
##   Email:      sharp-orchestrator@ethonshield.com
##
########################################################################

cp ../conf/sharp-orchestrator.src ${HOME}/

source ${HOME}/sharp-orchestrator.src
source ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/general_functions.sh

# Kill existing session if any
stop_process "5g_sharp_orchestrator.sh -i" > /dev/null
tmux kill-session -t interactive_menu > /dev/null 2>/dev/null

# Create new session for the interactive menu
tmux new-session -d -s interactive_menu  

# Split the window into two panes horizontaly
# The left panes occupies 60 %
tmux split-window -h -l "60%" 

# Execute the 5g sharp orchestrator script in the left pane
tmux select-pane -L
tmux send-keys "clear; ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/5g_sharp_orchestrator.sh -i" C-m

# Tail the log file on the right pane 
tmux select-pane -R
sleep 1
tmux send-keys "clear;tail -f ${LOG_FILE}" C-m  

# Divide the left pane into two panes vertically
# The top pane ocuppies the 45%
tmux select-pane -L
tmux split-window -vb -l "45%"

# Show the banner in the top pane
tmux send-keys "clear; cat ${SHARP_ORCHESTRATOR_WORKING_DIR}/images/banner.txt; read p" C-m

# Choose the sharp orchestrator menu 
tmux select-pane -D

# Attach session
tmux attach-session -t interactive_menu
