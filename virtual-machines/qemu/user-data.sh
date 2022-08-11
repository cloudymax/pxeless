#!/bin/bash
set -Eeuo pipefail

log() {
    echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}"
}

export_metatdata(){
  export VM_NAME="null"
  export VM_USER="${VM_NAME}admin"
  export USER="null"
  export VM_KEY="null"
  export PASSWD="null"
  export UPDATE="false"
  export UPGRADE="false"
  export GITHUB_USER="null"
  export APT_PACKAGES="null"
  export KERNEL="null"
}

parse_params() {
        while :; do
                case "${1-}" in
                -h | --help) usage ;;
                -v | --verbose) set -x ;;
                -upd | --update) UPDATE="true" ;;
                -upg | --upgrade) UPGRADE="true" ;;
                -p | --password)
                        PASSWD=$(mkpasswd -m sha-512 "${2-}" -s "saltsaltlettuce" | sed 's/\$/\\$/g')
                        shift
                        ;;
                -k | --key)
                        VM_KEY="${2-}"
                        shift
                        ;;
                -u | --user-name)
                        USER="${2-}"
                        shift
                        ;;
                -gh | --github-username)
                        GITHUB_USER="${2-}"
                        shift
                        ;;
                -n | --vm-name)
                        VM_NAME="${2-}"
                        shift
                        ;;
                -?*) die "Unknown option: $1" ;;
                *) break ;;
                esac
                shift
        done

        log "👶 Starting up..."

        return 0
}

verify_deps(){
        log "🔎 Checking for required utilities..."
        [[ ! -x "$(command -v whois)" ]] && die "💥 whois is not installed. On Ubuntu, install  the 'whois' package."
        log "👍 All required utilities are installed."
}

create_user_data(){
cat > user-data <<EOF
#cloud-config
#vim:syntax=yaml
hostname: ${VM_NAME}
fqdn: ${VM_NAME}
manage_etc_hosts: false
disable_root: false
no_ssh_fingerprints: true
ssh:
  emit_keys_to_console: false
users:
  - name: ${USER}
    gecos: Max R.
    groups: users, admin, docker, sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: "${PASSWD}"
    ssh_import_id:
      - gh:"${GITHUB_USER}"
  - name: ${VM_USER}
    gecos: system acct
    groups: users, admin, docker, sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: "${PASSWD}"
    ssh_authorized_keys:
      - ${VM_KEY}
apt:
  primary:
    - arches: [default]
      uri: http://us.archive.ubuntu.com/ubuntu/
  sources:
    kubectl.list:
      source: deb [arch=amd64] https://apt.kubernetes.io/ kubernetes-xenial main
      keyid: 59FE0256827269DC81578F928B57C5C2836F4BEB
    helm.list:
      source: deb https://baltocdn.com/helm/stable/debian/ all main
      keyid: 81BF832E2F19CD2AA0471959294AC4827C1A168A
package_update: true
package_upgrade: true
packages:
  - kubectl
  - wget
  - helm
  - htop
  - docker.io
  - build-essential
  - python3-pip
  - procps
  - file
  - ubuntu-drivers-common
  - xinit
  - xterm
  - xfce4
  - xfce4-goodies
  - x11vnc
runcmd:
  - mkdir -p /new_kernel
  - wget -O /new_kernel/linux-headers-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.19/amd64/linux-headers-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb
  - wget -O /new_kernel/linux-headers-5.19.0-051900_5.19.0-051900.202207312230_all.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.19/amd64/linux-headers-5.19.0-051900_5.19.0-051900.202207312230_all.deb
  - wget -O /new_kernel/linux-image-unsigned-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.19/amd64/linux-image-unsigned-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb
  - wget -O /new_kernel/linux-modules-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.19/amd64/linux-modules-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb
  - dpkg -i /new_kernel/*
  - apt-get purge linux-headers-5.15*
  - apt-get purge linux-image-5.15*
  - apt-get --purge autoremove
  - ubuntu-drivers autoinstall
  - wget https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
  - chmox +x /install.sh
  - chmod 777 /install.sh
  - sudo -u ${VM_USER} NONINTERACTIVE=1 /bin/bash /install.sh
  - sudo -u ${VM_USER} /home/linuxbrew/.linuxbrew/bin/brew shellenv >> /home/${VM_USER}/.profile
  - sudo -u max /home/linuxbrew/.linuxbrew/bin/brew shellenv >> /home/max/.profile
  - reboot now
EOF
}

export_metatdata
parse_params "$@"
