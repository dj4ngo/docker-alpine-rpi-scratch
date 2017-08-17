#!/bin/bash 

# Test root user
if [ "$(id -u)" -ne 0 ]; then 
	echo "$0 needs to be runned as root ! " >&2
	exit 100
fi 

### ENV VARS ###
TMP_DIR="/tmp/alpine-tmp-$$"
TMP_ROOTFS="/tmp/alpine-rootfs-$$"
MIRROR="http://nl.alpinelinux.org/alpine"
RELEASE="latest-stable"
REPO="${MIRROR}/${RELEASE}/main"
ARCH="armhf"
TAG="dj4ngo/alpine-rpi"
DOCKER_BUILD="dockerBuild"

### MAIN ###

echo "Prepare build env"
echo "  create ${TMP_DIR} ${TMP_ROOTFS}"
mkdir -p ${TMP_DIR}
mkdir -p ${TMP_ROOTFS}
mkdir -p ${DOCKER_BUILD}
# clean
trap "rm -rf ${TMP_DIR} ${TMP_ROOTFS}" EXIT TERM INT

apk_version=$(curl -s $REPO/$ARCH/APKINDEX.tar.gz | tar -Oxz | sed -n '/apk-tools-static/{n;s/V://p}')
echo "  APK version=$apk_version"
curl -s ${REPO}/${ARCH}/apk-tools-static-${apk_version}.apk | tar -xz -C $TMP_DIR sbin/apk.static 2>/dev/null

echo "Create Base rootfs"
${TMP_DIR}/sbin/apk.static --repository $REPO --update-cache --root $TMP_ROOTFS --initdb add alpine-base --allow-untrusted

echo "Configure repository"
echo "$REPO" > $TMP_ROOTFS/etc/apk/repositories

### TODO: directly compile qemu for more transparency 
#echo "Compile qemu-arm"
#git clone git://git.qemu.org/qemu.git  
#cd qemu  
#./configure --target-list=arm-linux-user --static
#make  

echo "Add cots to /cots"
cp -rfv cots $TMP_ROOTFS/cots

echo "Create alpine-rootfs.tgz"
# Check if runned only to generate Docker build environment
if [ "$1" == "genDocker" ]; then 
	tar --numeric-owner -C $TMP_ROOTFS -zcvf ${DOCKER_BUILD}/rootfs.tgz .
else
	echo "Import in Dockerfile"
	image_id=$(tar --numeric-owner -C $TMP_ROOTFS -c .  | docker import - ${TAG}:${RELEASE})
	docker tag $image_id ${TAG}:latest
	echo "Alpine imported : ${TAG}:latest"
fi


