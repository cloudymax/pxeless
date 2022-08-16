#!/bin/bash
set -Eeuo pipefail

export DEBUG="false"
export INVENTORY="none"
export ANSIBLE_USER="none"
export PROFILE="none"
export ANSIBLE_NOCOWS=1
export ANSIBLE_COW_SELECTION="none"
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export NC='\033[0m'

[[ ! -x "$(command -v date)" ]] && echo "💥 date command not found." && exit 1

# Parse command line args and set flags accordingly
parse_params() {
        while :; do
                case "${1-}" in
                -h | --help) usage ;;
                -v | --verbose) set -x ;;
                -d | --debug) DEBUG="true";;
                -c | --cows)
                        ANSIBLE_COW_SELECTION="${2-}"
                        shift
                        ;;
                -p | --profile)
                        PROFILE="${2-}"
                        shift
                        ;;
                -au | --ansible-user)
                        ANSIBLE_USER="${2-}"
                        shift
                        ;;
                -i | --inventory-file)
                        INVENTORY="${2-}"
                        shift
                        ;;
                -?*) die "Unknown option: $1" ;;
                *) break ;;
                esac
                shift
        done

        log "⏰ Starting up..."
        log "📋 Setting variables"

        if [[ "$DEBUG" == "false" ]]; then
           log "🔎 DEBUG not set." 
           log "   $GREEN  ➡️ Defaulting to 'False' $NC"
        fi

        if [[ "$INVENTORY" == "none" ]]; then
           log "🔎 No inventory specified"
           log "   $GREEN  ➡️ asumming localhost. $NC"
        else
            if [[ -f "$INVENTORY" ]]; then
                log "✅ $INVENTORY exists. Continuing."
            else
                log "💥 $INVENTORY does not exist."
                exit
            fi
        fi

        if [[ "$ANSIBLE_USER" == "none" ]]; then
           log "💥 No ansible user specified"
           exit
        fi
        
        if [[ "$PROFILE" == "none" ]]; then
           log "🔎 No profile selected."
           log "   $GREEN  ➡️ Defaulting to 'basic_desktop' $NC"
           export PROFILE="basic_desktop"
        else
           export PROFILE="$PROFILE"
        fi
        
        if [[ "none" == "$ANSIBLE_COW_SELECTION" ]]; then
           log "🐄 No cowsay charcter specified"
           log "   $RED  ➡️ disabling cows. $NC"
           ANSIBLE_NOCOWS=1
        else
           ANSIBLE_NOCOWS=0
        fi
}

# help text
usage() {
        cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-c cow_name] [-p /path/to/profile] [-au ansible-user] [-i /path/to/inventory] [-d] 

💁 This script will execute an ansible role that loops over a yaml file, 
   and performs the defined actions.

Available options:

-c, --cows              select a cow to use for cowsay

-p, --profile           Path to the ansible profile directory.

-au, --ansible-user     The user account that Ansible will use to execute tasks

-i, --inventory-file    Path to Ansible inventory file

-d, --debug             print ansibke debug text

EOF
        exit
}

# check and install dependancies
deps() {
    log "🔎 Checking for required utilities..."
    if [[ ! -x "$(command -v pip3)" ]]; then
       log "💥 python3-pip is not installed. Installing"
       sudo apt-get install --yes python3-pip
    else    
       log "✅ python3-pip installed."
    fi
    
    if [[ ! -x "$(command -v ansible)" ]]; then
        log "💥 ansible is not installed. Installing..."
        sleep 1
        umask 022
        pip3 install ansible-core
    else
        log "✅ ansible is installed."
    fi

    if [[ "0" == "$(/home/$ANSIBLE_USER/.local/bin/ansible-galaxy collection list |grep -c community.general)" ]]; then
        log "💥 collection community.general is not installed. Installing..."
        sleep 1
        /home/$ANSIBLE_USER/.local/bin/ansible-galaxy collection install community.general
    else
        log "✅ collection community.general installed."
    fi
    
    if [[ "0" == "$(/home/$ANSIBLE_USER/.local/bin/ansible-galaxy collection list |grep -c community.crypto)" ]]; then
        log "💥 collection community.crypto is not installed. Installing..."
        sleep 1
        /home/$ANSIBLE_USER/.local/bin/ansible-galaxy collection install community.crypto
    else
        log "✅ collection community.crypto installed."
    fi

    if [[ "0" == "$(/home/$ANSIBLE_USER/.local/bin/ansible-galaxy collection list |grep -c ansible.posix)" ]]; then
        log "💥 collection ansible.posix. Installing..."
        sleep 1
        /home/$ANSIBLE_USER/.local/bin/ansible-galaxy collection install ansible.posix
    else
        log "✅ collection ansible.posix installed."
    fi
    
    log "🥳 All required utilities are installed."
}

# Logging method
log() {
        echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}"
}

# kill on error
die() {
        local MSG=$1
        local CODE=${2-1} # Bash parameter expansion - default exit status 1. See https://wiki.bash-hackers.org/syntax/pe#use_a_default_value
        log "${MSG}"
        exit "${CODE}"
}

main() {
    deps
    parse_params "$@"

    # Profile to use for demo (absolute path)
    USER=$(whoami)
    export WORKING_DIR=$(sudo find / -name "pxeless" -type d)
    export DEMO_DIR="$WORKING_DIR/provisioner/ansible_profiles/$PROFILE"
    export ANSIBLE_PLAYBOOK="$WORKING_DIR/provisioner/playbooks/main-program.yaml"

    # Program verbosity
    export VERBOSITY=""
    export DEBUG="false"
    export SQUASH="false"

    for file in "${DEMO_DIR}"/*.yaml
    do
        #echo "running $file ..."
        /home/${ANSIBLE_USER}/.local/bin/ansible-playbook $ANSIBLE_PLAYBOOK \
            --extra-vars \
            "profile_path='${file}' \
            profile_dir='${DEMO_DIR}' \
            ansible_user='${ANSIBLE_USER}' \
            squash='${SQUASH}' \
            debug_output='${DEBUG}' \
            $VERBOSITY"
    done
}

main "$@"