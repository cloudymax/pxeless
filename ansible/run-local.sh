#!/bin/bash

set -Eeuo pipefail

sudo apt-get install --yes python3-pip
pip3 install ansible-core

export PATH="$HOME/.local/bin:$PATH"
#export ANSIBLE_COW_SELECTION="random"
export ANSIBLE_NOCOWS=1 

ansible-galaxy collection install community.general
ansible-galaxy collection install community.crypto
ansible-galaxy collection install ansible.posix

# Profile to use for demo (absolute path)
USER=$(whoami)
export WORKING_DIR=$(pwd)
export DEMO_DIR="$WORKING_DIR/ansible_profiles/kind-host"
export ANSIBLE_PLAYBOOK="$WORKING_DIR/playbooks/main-program.yaml"

# Program verbosity
export VERBOSITY=""
export DEBUG="false"
export SQUASH="false"

for file in "${DEMO_DIR}"/*.yaml
do
    #echo "running $file ..."
    ansible-playbook $ANSIBLE_PLAYBOOK \
        --extra-vars \
        "profile_path='${file}' \
        profile_dir='${DEMO_DIR}' \
        ansible_user='$USER' \
        squash='${SQUASH}' \
        debug_output='${DEBUG}' \
        $VERBOSITY"
done
