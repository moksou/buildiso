#!/bin/bash
# buildiso - build custom CentOS 7 image based on Minimal ISO

# Base variables
IMAGE=
OUTPUT="/var/lib/libvirt/images/CentOS-7-x86_64-Minimal-1804-Kickstart.iso"
WORKDIR="$(pwd)"
DATA="${WORKDIR}/data"
SRC="${WORKDIR}/src"
EFI="${WORKDIR}/efi"
CFG="${WORKDIR}/cfg"

# New ISO properties, may be overrun with script arguments
PACKAGES="${WORKDIR}/packages"
HOSTNAME="hostname"
KICKSTART="${CFG}/ks.cfg"

function finish {
    echo "exiting..."
    umount -v ${EFI} > /dev/null 2>&1
    umount -v ${SRC} > /dev/null 2>&1
    exit
}
trap finish EXIT

while getopts ":i:h:k:o:p:" OPT; do
    case $OPT in
        i)
            IMAGE=${OPTARG};;
        o)
            [ ! -z "${OPTARG}" ] && OUTPUT="${OPTARG}";;
        h)
            [ ! -z "${OPTARG}" ] && HOSTNAME="${OPTARG}";;
        k)
            [ ! -z "${OPTARG}" ] && KICKSTART="${OPTARG}";;
        p)
            [ ! -z "${OPTARG}" ] && PACKAGES="${OPTARG}";;
        /?)
            echo "Invalid option: -$OPTARG" >&2;;
    esac
done

[ ! -d "${DATA}" ] && mkdir "${DATA}"
[ ! -d "${EFI}" ] && mkdir "${EFI}"
[ ! -d "${SRC}" ] && mkdir "${SRC}"

if [ ! -f "${IMAGE}" ] || [ -z "${IMAGE}" ]; then
    echo "file ${IMAGE} does not exist"
    exit
fi
if [ ! -f "${KICKSTART}" ]; then
    echo "file ${KICKSTART} does not exist"
    exit
fi
echo "====================";
echo "Output:    ${OUTPUT}";
echo "Source:    ${IMAGE}";
echo "Hostname:  ${HOSTNAME}";
echo "Kickstart: ${KICKSTART}";
echo "====================";

# removing previous building results
rm -rf "${DATA}/"*

echo "==== Mount CentOS 7 Image ===="
mount -v "${IMAGE}" "${SRC}" -o ro,loop;

echo "==== Copy data from image ===="
cp -r "${SRC}/"* "${DATA}"
echo "==== Unmounting image ===="
umount -v "${SRC}"

echo "==== Copying new packages to image ===="
cp -v "${PACKAGES}/"* "${DATA}/Packages"

echo "==== Recreating package DB ===="
COMPS_XML="${DATA}/repodata/$(find ${DATA}/repodata -name '*-c7-x86_64-comps.xml' ! -name 'repomd.xml' -exec basename {} \; )"
mv "${COMPS_XML}" "${DATA}/repodata/comps.xml"

find "${DATA}/repodata" -type f ! -name 'comps.xml' -exec rm '{}' +

createrepo -g "${DATA}/repodata/comps.xml" "${DATA}"

echo "==== Copying configuration files to image ===="
cp -v "${KICKSTART}"       "${DATA}/ks.cfg"
cp -v "${CFG}/isolinux.cfg" "${DATA}/isolinux/isolinux.cfg"
cp -v "${CFG}/grub.cfg"     "${DATA}/EFI/BOOT/grub.cfg"
sed -i "s/hostname=vlabs/hostname=${HOSTNAME}/" "${DATA}/ks.cfg"

echo "==== Configuring EFI Boot ===="
chmod 644 "${DATA}/images/efiboot.img"
mount -o loop -v "${DATA}/images/efiboot.img" "${EFI}"
cp -v "${CFG}/grub.cfg" "${EFI}/EFI/BOOT/grub.cfg"
umount -v "${EFI}"
chmod 444 "${DATA}/images/efiboot.img"

echo "==== Building ISO image ===="
genisoimage \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-info-table \
    -boot-load-size 4 \
    -joliet-long \
    -eltorito-alt-boot -e images/efiboot.img \
    -no-emul-boot \
    -V "CentOS 7 x86_64" \
    -o ${OUTPUT} \
    -R -J -v -T \
    "${DATA}"

# Inserting md5sum to allow checking the media
implantisomd5 "${OUTPUT}"
# Make ISO bootable from UEFI
isohybrid --uefi "${OUTPUT}"
# Remove unneeded data
rm -rf "${DATA}/"*
