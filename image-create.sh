#!/bin/bash
set -Eeuo pipefail

trap cleanup SIGINT SIGTERM ERR EXIT
[[ ! -x "$(command -v date)" ]] && echo "💥 date command not found." && exit 1

# export initial varibales 
export_metadata(){

        export TODAY=$(date +"%Y-%m-%d")
        export USER_DATA_FILE=''
        export META_DATA_FILE=''
        export CODE_NAME=""
        export BASE_URL=""
        export ISO_FILE_NAME=""
        export ORIGINAL_ISO="ubuntu-original-$TODAY.iso"
        export EFI_IMAGE="ubuntu-original-$TODAY.efi"
        export MBR_IMAGE="ubuntu-original-$TODAY.mbr"
        export SOURCE_ISO="${ORIGINAL_ISO}"
        export DESTINATION_ISO="ubuntu-autoinstall.iso"
        export SHA_SUFFIX="${TODAY}"
        export UBUNTU_GPG_KEY_ID="843938DF228D22F7B3742BC0D94AA3F0EFE21092"
        export GPG_VERIFY=1
        export ALL_IN_ONE=0
        export USE_HWE_KERNEL=0
        export MD5_CHECKSUM=1
        export USE_RELEASE_ISO=0
        export EXTRA_FILES_FOLDER=""

        export LEGACY_IMAGE=0
        export CURRENT_RELEASE=""
        export ISO_NAME=""
        export IMAGE_NAME=""

        export TMP_DIR=""
        export BUILD_DIR=""
}

# help text
usage() {
        cat <<EOF
Usage: image-create.sh [-h] [-v] [-n] [-a] [-e] [-u user-data-file] [-m meta-data-file] [-k] [-c] [-r] [-s source-iso-file] [-d destination-iso-file]

💁 This script will create fully-automated Ubuntu installation media.

Available options:

-h, --help              Print this help and exit

-v, --verbose           Print script debug info

-n, --code-name         The Code Name of the Ubuntu release to download (bionic, focal, jammy etc...)

-a, --all-in-one        Bake user-data and meta-data into the generated ISO. By default you will
                        need to boot systems with a CIDATA volume attached containing your
                        autoinstall user-data and meta-data files.
                        For more information see: https://ubuntu.com/server/docs/install/autoinstall-quickstart

-e, --use-hwe-kernel    Force the generated ISO to boot using the hardware enablement (HWE) kernel. Not supported
                        by early Ubuntu 20.04 release ISOs.

-u, --user-data         Path to user-data file. Required if using -a

-m, --meta-data         Path to meta-data file. Will be an empty file if not specified and using -a

-x, --extra-files       Specifies an folder with files and folders, which will be copied into the root of the iso image.
                        If not set, nothing is copied

-k, --no-verify         Disable GPG verification of the source ISO file. By default SHA256SUMS-<current date> and
                        SHA256SUMS-<current date>.gpg files in the script directory will be used to verify the authenticity and integrity
                        of the source ISO file. If they are not present the latest daily SHA256SUMS will be
                        downloaded and saved in the script directory. The Ubuntu signing key will be downloaded and
                        saved in a new keyring in the script directory.

-r, --use-release-iso   Use the current release ISO instead of the daily ISO. The file will be used if it already
                        exists.

-s, --source            Source ISO file path. By default the latest daily ISO for Ubuntu server will be downloaded
                        and saved as <script directory>/ubuntu-original-<current date>.iso
                        That file will be used by default if it already exists.

-l, --legacy            When using the -s, --source flags you must specify the --legacy flag if the source image is based on isolinux.
                        Otherwise, eltorito usage is assumed 

-d, --destination       Destination ISO file. By default <script directory>/ubuntu-autoinstall-<current date>.iso will be
                        created, overwriting any existing file.
EOF
        exit
}

# Parse command line args and set flags accordingly
parse_params() {
        while :; do
                case "${1-}" in
                -h | --help) usage ;;
                -v | --verbose) set -x ;;
                -a | --all-in-one) ALL_IN_ONE=1 ;;
                -e | --use-hwe-kernel) USE_HWE_KERNEL=1 ;;
                -c | --no-md5) MD5_CHECKSUM=0 ;;
                -k | --no-verify) GPG_VERIFY=0 ;;
                -r | --use-release-iso) USE_RELEASE_ISO=1 ;;
                -l | --legacy) LEGACY_OVERRIDE="true" ;;
                -u | --user-data)
                        USER_DATA_FILE="${2-}"
                        shift
                        ;;
                -s | --source)
                        SOURCE_ISO="${2-}"
                        [[ ! -f "$SOURCE_ISO" ]] && die "💥 Source ISO file could not be found."
                        shift
                        ;;
                -d | --destination)
                        DESTINATION_ISO="${2-}"
                        shift
                        ;;
                -m | --meta-data)
                        META_DATA_FILE="${2-}"
                        shift
                        ;;
                -n | --code-name)
                        CODE_NAME="${2-}"
                        shift
                        ;;
                -x | --extra-files)
                        EXTRA_FILES_FOLDER="${2-}"
                        shift
                        ;;
                -?*) die "Unknown option: $1" ;;
                *) break ;;
                esac
                shift
        done

        log "👶 Starting up..."

        # check required params and arguments
        if [ ${ALL_IN_ONE} -ne 0 ]; then
                [[ -z "${USER_DATA_FILE}" ]] && die "💥 user-data file was not specified."
                [[ ! -f "$USER_DATA_FILE" ]] && die "💥 user-data file could not be found."
                [[ -n "${META_DATA_FILE}" ]] && [[ ! -f "$META_DATA_FILE" ]] && die "💥 meta-data file could not be found."
        fi

        return 0
}

# Create temporary directories for fie download and expansion
create_tmp_dirs(){
        export TMP_DIR=$(mktemp -d)
        if [[ ! "${TMP_DIR}" || ! -d "${TMP_DIR}" ]]; then
                die "💥 Could not create temporary working directory."
        else
                log "📁 Created temporary working directory ${TMP_DIR}"
        fi

        export BUILD_DIR=$(mktemp -d)
        if [[ ! "${BUILD_DIR}" || ! -d "${BUILD_DIR}" ]]; then
                die "💥 Could not create temporary build directory."
        else
                log "📁 Created temporary build directory ${BUILD_DIR}"
        fi
}

# Determine if the requested ISO will be based on legacy Isolinux
# or current eltorito image base. 
check_legacy(){
        if [ ! -f "${SOURCE_ISO}" ] ; then
                if $(dpkg --compare-versions "${CURRENT_RELEASE}" "lt" "20.10"); then 
                        log "❗ ${CURRENT_RELEASE} is lower than 20.10. Marking image as legacy."
                        export LEGACY_IMAGE=1
                else
                        log "✅ ${CURRENT_RELEASE} is greater than 20.10. Not a legacy image."
                        export LEGACY_IMAGE=0
                fi
        fi
}

# verify that system dependancies are in-place
verify_deps(){
        log "🔎 Checking for required utilities..."
        [[ ! -x "$(command -v xorriso)" ]] && die "💥 xorriso is not installed. On Ubuntu, install  the 'xorriso' package."
        [[ ! -x "$(command -v sed)" ]] && die "💥 sed is not installed. On Ubuntu, install the 'sed' package."
        [[ ! -x "$(command -v curl)" ]] && die "💥 curl is not installed. On Ubuntu, install the 'curl' package."
        [[ ! -x "$(command -v gpg)" ]] && die "💥 gpg is not installed. On Ubuntu, install the 'gpg' package."
        [[ ! -x "$(command -v fdisk)" ]] && die "💥 fdisk is not installed. On Ubuntu, install the 'fdisk' package."
        
        if [ ${LEGACY_IMAGE} -eq 1 ]; then      
                [[ ! -f "/usr/lib/ISOLINUX/isohdpfx.bin" ]] && die "💥 isolinux is not installed. On Ubuntu, install the 'isolinux' package."
        fi

        log "👍 All required utilities are installed."
}

# get the url and iso infor for the latest release
latest_release(){
        BASE_URL="https://releases.ubuntu.com/${CODE_NAME}/"
        log "🔎 Checking for latest ${CODE_NAME} release..."
        ISO_FILE_NAME=$(curl -sSL "${BASE_URL}" |grep -oP "ubuntu-.*-server-amd64.iso" |head -n 1)
        IMAGE_NAME=$(curl -sSL ${BASE_URL} |grep -o 'Ubuntu .* LTS .*)' |head -n 1)
        CURRENT_RELEASE=$(echo "${ISO_FILE_NAME}" | cut -f2 -d-)
        SHA_SUFFIX="${CURRENT_RELEASE}"
        log "✅ Latest release is ${CURRENT_RELEASE}"
}

# get the url and iso info for a daily release
daily_release(){
        BASE_URL="https://cdimage.ubuntu.com/ubuntu-server/${CODE_NAME}/daily-live/current"
        log "🔎 Checking for daily ${CODE_NAME} release..."
        ISO_FILE_NAME=$(curl -sSL "${BASE_URL}" |grep -oP "${CODE_NAME}-live-server-amd64.iso" |head -n 1)
        IMAGE_NAME=$(curl -sSL ${BASE_URL} |grep -o 'Ubuntu .* LTS .*)' |head -n 1)
        CURRENT_RELEASE=$(echo "${IMAGE_NAME}" | awk '{print $3}')
        SHA_SUFFIX="${CURRENT_RELEASE}"
        log "✅ Daily release is ${CURRENT_RELEASE}"
}

# download the specified ISO
download_iso(){

        if [ ! -f "${SOURCE_ISO}" ]; then
                log "🌎 Downloading ISO image for ${IMAGE_NAME} ..."
                wget -O "${ORIGINAL_ISO}" "${BASE_URL}/${ISO_FILE_NAME}" -q
                log "👍 Downloaded and saved to ${ORIGINAL_ISO}"
        else
                log "☑️ Using existing ${SOURCE_ISO} file."
                if [ ${GPG_VERIFY} -eq 1 ]; then
                        export GPG_VERIFY=0
                        log "⚠️ Automatic GPG verification disabled. Assume ISO file is already verified."
                fi
        fi
}

# Verify iso GPG keys
verify_gpg(){
        if [ ${GPG_VERIFY} -eq 1 ]; then
                export GNUPGHOME=${TMP_DIR}
                if [ ! -f "${TMP_DIR}/SHA256SUMS-${SHA_SUFFIX}" ]; then
                        log "🌎 Downloading SHA256SUMS & SHA256SUMS.gpg files..."
                        curl -NsSL "${BASE_URL}/SHA256SUMS" -o "${TMP_DIR}/SHA256SUMS-${SHA_SUFFIX}"
                        curl -NsSL "${BASE_URL}/SHA256SUMS.gpg" -o "${TMP_DIR}/SHA256SUMS-${SHA_SUFFIX}.gpg"
                else
                        log "☑️ Using existing SHA256SUMS-${SHA_SUFFIX} & SHA256SUMS-${SHA_SUFFIX}.gpg files."
                fi

                if [ ! -f "${TMP_DIR}/${UBUNTU_GPG_KEY_ID}.keyring" ]; then
                        log "🌎 Downloading and saving Ubuntu signing key..."
                        gpg -q --no-default-keyring --keyring "${TMP_DIR}/${UBUNTU_GPG_KEY_ID}.keyring" --keyserver "hkp://keyserver.ubuntu.com" --recv-keys "${UBUNTU_GPG_KEY_ID}" 2>/dev/null
                        log "👍 Downloaded and saved to ${TMP_DIR}/${UBUNTU_GPG_KEY_ID}.keyring"
                else
                        log "☑️ Using existing Ubuntu signing key saved in ${TMP_DIR}/${UBUNTU_GPG_KEY_ID}.keyring"
                fi

                log "🔐 Verifying ${SOURCE_ISO} integrity and authenticity..."
                gpg -q --keyring "${TMP_DIR}/${UBUNTU_GPG_KEY_ID}.keyring" --verify "${TMP_DIR}/SHA256SUMS-${SHA_SUFFIX}.gpg" "${TMP_DIR}/SHA256SUMS-${SHA_SUFFIX}" 2>/dev/null
                if [ $? -ne 0 ]; then
                        rm -f "${TMP_DIR}/${UBUNTU_GPG_KEY_ID}.keyring~"
                        die "👿 Verification of SHA256SUMS signature failed."
                fi

                rm -f "${TMP_DIR}/${UBUNTU_GPG_KEY_ID}.keyring~"
                digest=$(sha256sum "${SOURCE_ISO}" | cut -f1 -d ' ')
                set +e
                grep -Fq "$digest" "${TMP_DIR}/SHA256SUMS-${SHA_SUFFIX}"
                if [ $? -eq 0 ]; then
                        log "👍 Verification succeeded."
                        set -e
                else
                        die "👿 Verification of ISO digest failed."
                fi
        else
                log "🤞 Skipping verification of source ISO."
        fi
}

# extract the EFI and disk image formt the ISO
extract_images(){

        log "🔧 Extracting ISO image..."
        xorriso -osirrox on -indev "${SOURCE_ISO}" -extract / "${BUILD_DIR}" &>/dev/null
        chmod -R u+w "${BUILD_DIR}"
        rm -rf "${BUILD_DIR}/"'[BOOT]'
        log "👍 Extracted to ${BUILD_DIR}"

        if [ ${LEGACY_IMAGE} -eq 0 ]; then   
                log "🔧 Extracting MBR image..."
                dd if="${SOURCE_ISO}" bs=1 count=446 of="${TMP_DIR}/${MBR_IMAGE}" &>/dev/null
                log "👍 Extracted to ${TMP_DIR}/${MBR_IMAGE}"

                log "🔧 Extracting EFI image..."
                START_BLOCK=$(fdisk -l "${SOURCE_ISO}" | fgrep '.iso2 ' | awk '{print $2}')
                SECTORS=$(fdisk -l "${SOURCE_ISO}" | fgrep '.iso2 ' | awk '{print $4}')
                dd if="${SOURCE_ISO}" bs=512 skip="${START_BLOCK}" count="${SECTORS}" of="${TMP_DIR}/${EFI_IMAGE}" &>/dev/null
                log "👍 Extracted to ${TMP_DIR}/${EFI_IMAGE}"
        fi
}

# enable the hardware execution kernel if desired
set_hwe_kernel(){
        if [ ${USE_HWE_KERNEL} -eq 1 ]; then
                if grep -q "hwe-vmlinuz" "${TMP_DIR}/boot/grub/grub.cfg"; then
                        log "☑️ Destination ISO will use HWE kernel."

                        sed -i -e 's|/casper/vmlinuz|/casper/hwe-vmlinuz|g' "${TMP_DIR}/boot/grub/grub.cfg"
                        sed -i -e 's|/casper/initrd|/casper/hwe-initrd|g' "${TMP_DIR}/boot/grub/grub.cfg"
                        sed -i -e 's|/casper/vmlinuz|/casper/hwe-vmlinuz|g' "${TMP_DIR}/boot/grub/loopback.cfg"
                        sed -i -e 's|/casper/initrd|/casper/hwe-initrd|g' "${TMP_DIR}/boot/grub/loopback.cfg"

                        if [ -f "${BUILD_DIR}/isolinux/txt.cfg" ]; then  
                                export LEGACY_IMAGE=1   
                                sed -i -e 's|/casper/vmlinuz|/casper/hwe-vmlinuz|g' "${TMP_DIR}/isolinux/txt.cfg"
                                sed -i -e 's|/casper/initrd|/casper/hwe-initrd|g' "${TMP_DIR}/isolinux/txt.cfg"                         
                        fi
                else
                        log "⚠️ This source ISO does not support the HWE kernel. Proceeding with the regular kernel."
                fi
        fi
}

# add the auto-install kerel param
set_kernel_autoinstall(){
        log "🧩 Adding autoinstall parameter to kernel command line..."
        sed -i -e 's/---/ autoinstall  ---/g' "${BUILD_DIR}/boot/grub/grub.cfg"
        sed -i -e 's/---/ autoinstall  ---/g' "${BUILD_DIR}/boot/grub/loopback.cfg"

        if [ -f "${BUILD_DIR}/isolinux/txt.cfg" ]; then   
                log "🧩 Adding autoinstall parameter to isolinux..."   
                export LEGACY_IMAGE=1
                sed -i -e 's/---/ autoinstall  ---/g' "${BUILD_DIR}/isolinux/txt.cfg"
        fi

        log "👍 Added parameter to UEFI and BIOS kernel command lines."

        if [ ${ALL_IN_ONE} -eq 1 ]; then
                log "🧩 Adding user-data and meta-data files..."
                mkdir "${BUILD_DIR}/nocloud"
                cp "$USER_DATA_FILE" "${BUILD_DIR}/nocloud/user-data"

                if [ -n "${META_DATA_FILE}" ]; then
                        cp "$META_DATA_FILE" "${BUILD_DIR}/nocloud/meta-data"
                else
                        touch "${BUILD_DIR}/nocloud/meta-data"
                fi

                if [ ${LEGACY_IMAGE} -eq 1 ]; then    
                        sed -i -e 's,---, ds=nocloud;s=/cdrom/nocloud/  ---,g' "${BUILD_DIR}/isolinux/txt.cfg"
                fi

                sed -i -e 's,---, ds=nocloud\\\;s=/cdrom/nocloud/  ---,g' "${BUILD_DIR}/boot/grub/grub.cfg"
                sed -i -e 's,---, ds=nocloud\\\;s=/cdrom/nocloud/  ---,g' "${BUILD_DIR}/boot/grub/loopback.cfg"
                log "👍 Added data and configured kernel command line."
        fi
}

# Add extra files from a folder into the build dir
insert_extra_files(){
        log "➕ Adding additional files to the iso image..."
        cp -R "${EXTRA_FILES_FOLDER}/." "${BUILD_DIR}/"
        log "👍 Added additional files"
}

# re-create the MD5 checksum data
md5_checksums(){
        if [ ${MD5_CHECKSUM} -eq 1 ]; then
                log "👷 Updating ${BUILD_DIR}/md5sum.txt with hashes of modified files..."
                md5=$(md5sum "${BUILD_DIR}/boot/grub/grub.cfg" | cut -f1 -d ' ')
                sed -i -e 's,^.*[[:space:]] ./boot/grub/grub.cfg,'"$md5"'  ./boot/grub/grub.cfg,' "${BUILD_DIR}/md5sum.txt"
                md5=$(md5sum "${BUILD_DIR}/boot/grub/loopback.cfg" | cut -f1 -d ' ')
                sed -i -e 's,^.*[[:space:]] ./boot/grub/loopback.cfg,'"$md5"'  ./boot/grub/loopback.cfg,' "${BUILD_DIR}/md5sum.txt"
                log "👍 Updated hashes."
        else
                log "🗑️ Clearing MD5 hashes..."
                echo > "${BUILD_DIR}/md5sum.txt"
                log "👍 Cleared hashes."
        fi
}

# add the MBR, EFI, Disk Image, and Cloud-Init back to the ISO
reassemble_iso(){

        if [ "${SOURCE_ISO}" != "${BUILD_DIR}/${ORIGINAL_ISO}" ]; then
                [[ ! -f "${SOURCE_ISO}" ]] && die "💥 Source ISO file could not be found."
        fi
        
        log "📦 Repackaging extracted files into an ISO image..."
        if [ ${LEGACY_IMAGE} -eq 1 ]; then 

                log "📦 Using isolinux method..."
        
                xorriso -as mkisofs -r -V "ubuntu-autoinstall-${TODAY}" -J \
                        -b isolinux/isolinux.bin \
                        -c isolinux/boot.cat \
                        -no-emul-boot \
                        -boot-load-size 4 \
                        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
                        -boot-info-table \
                        -input-charset utf-8 \
                        -eltorito-alt-boot \
                        -e boot/grub/efi.img \
                        -no-emul-boot \
                        -isohybrid-gpt-basdat -o "${DESTINATION_ISO}" "${BUILD_DIR}" &>/dev/null
        else
                log "📦 Using El Torito method..."
                
                xorriso -as mkisofs \
                        -r -V "ubuntu-autoinstall-${TODAY}" -J -joliet-long -l \
                        -iso-level 3 \
                        -partition_offset 16 \
                        --grub2-mbr "${TMP_DIR}/${MBR_IMAGE}" \
                        --mbr-force-bootable \
                        -append_partition 2 0xEF "${TMP_DIR}/${EFI_IMAGE}" \
                        -appended_part_as_gpt \
                        -c boot.catalog \
                        -b boot/grub/i386-pc/eltorito.img \
                        -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
                        -eltorito-alt-boot \
                        -e '--interval:appended_partition_2:all::' \
                        -no-emul-boot \
                        -o "${DESTINATION_ISO}" "${BUILD_DIR}" &>/dev/null
        fi

        log "👍 Repackaged into ${DESTINATION_ISO}"
        die "✅ Completed." 0
}

# Cleanup folders we created
cleanup() {
        trap - SIGINT SIGTERM ERR EXIT
        if [ -n "${TMP_DIR+x}" ]; then
                #rm -rf "${TMP_DIR}"
                #rm -rf "${BUILD_DIR}"
                log "🚽 Deleted temporary working directory ${TMP_DIR}"
        fi
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


main(){
        export_metadata
        create_tmp_dirs

        parse_params "$@"

        if [ ! -f "$SOURCE_ISO" ]; then
        
                if [ "${USE_RELEASE_ISO}" -eq 1 ]; then
                        latest_release
                else
                        daily_release
                fi
                
                check_legacy
        fi

        verify_deps
        download_iso

        if [ ${GPG_VERIFY} -eq 1 ]; then
                verify_gpg
        fi

        extract_images
        set_kernel_autoinstall
        set_hwe_kernel
        
        if [ -n "$EXTRA_FILES_FOLDER" ]; then
                insert_extra_files
        fi

        if [ ${MD5_CHECKSUM} -eq 1 ]; then
                md5_checksums
        fi

        reassemble_iso
        cleanup
}

main "$@"
