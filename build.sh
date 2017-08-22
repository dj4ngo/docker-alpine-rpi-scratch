#!/bin/bash -e

#TODO : add keys for apk


### ENV VARS ###
#TMP_DIR="/tmp/alpine-tmp-$$"
TMP_DIR="alpine-tmp"
#TMP_ROOTFS="/tmp/alpine-rootfs-$$"
TMP_ROOTFS="alpine-rootfs"
MIRROR="http://nl.alpinelinux.org/alpine"
RELEASE="latest-stable"
REPO="${MIRROR}/${RELEASE}/main"
ARCH="armhf"
TAG="dj4ngo/alpine-rpi"
DOCKER_BUILD="dockerBuild"


function test_root_user () {
	echo "-> Test root user"
	if [ "$(id -u)" -ne 0 ]; then 
		echo "$0 needs to be runned as root ! " >&2
		exit 100
	fi 
}

function install_dep () {
	echo "-> Install dependencies for build"
	apt-get update
	apt-get install -y  curl golang qemu-arm-static
}

function create_arbo () {
	echo "-> Prepare build env"
	echo "---> Create ${TMP_DIR} ${TMP_ROOTFS}" 
	mkdir -p ${TMP_DIR}
	mkdir -p ${TMP_ROOTFS}
	mkdir -p ${DOCKER_BUILD}
	# clean
	trap "rm -rf ${TMP_DIR} ${TMP_ROOTFS}" EXIT TERM INT
}

function get_apk_static () {
	echo "-> Install apk.static for $(uname -m)"
	apk_version=$(curl -s $REPO/$(uname -m)/APKINDEX.tar.gz | tar -Oxz | sed -n '/apk-tools-static/{n;s/V://p}')
	echo "---> APK version=$apk_version"
	curl -s ${REPO}/$(uname -m)/apk-tools-static-${apk_version}.apk | tar -xz -C $TMP_DIR sbin/apk.static 2>/dev/null
}

function compile_resin-xbuild () {
	echo "-> Compile resin-xbuild"
	echo "---> Check go is installed or install it"
	echo "---> Get resin-xbuild from https://github.com/resin-io-projects/armv7hf-debian-qemu"
	mkdir -p ${TMP_DIR}/resin-xbuild
	pushd ${TMP_DIR}/resin-xbuild
	curl "https://raw.githubusercontent.com/resin-io-projects/armv7hf-debian-qemu/master/resin-xbuild.go" -o resin-xbuild.go
	echo "---> Compile resin-xbuild"
	go build -ldflags "-w -s" resin-xbuild.go
	popd

}

function install_resin-xbuild () {

	echo "-> Install resin-xbuild"
	echo "---> Check qemu-user-static is installed or install it"
	which qemu-arm-static 2>/dev/null || apt-get install qemu binfmt-support qemu-user-static

	echo "---> Create /usr/bin and /bin"
	mkdir -p $TMP_ROOTFS/{usr/,}bin

	echo "---> Copy resin-xbuild binary"
	cp ${TMP_DIR}/resin-xbuild/resin-xbuild $TMP_ROOTFS/usr/bin

	echo "---> Create sh.real"
	ln -s /bin/busybox $TMP_ROOTFS/bin/sh

	echo "---> Create crossbuild start and end links"
	
	ln -s resin-xbuild $TMP_ROOTFS/usr/bin/cross-build-end
	ln -s resin-xbuild $TMP_ROOTFS/usr/bin/cross-build-start


	echo "---> Create sh and sh-shim"
	cat <<EOF | tee $TMP_ROOTFS/bin/sh > $TMP_ROOTFS/bin/sh-shim
#!/usr/bin/qemu-arm-static /bin/sh.real

set -o errexit

cp /bin/sh.real /bin/sh  
/bin/sh "$@"
cp /usr/bin/sh-shim /bin/sh
EOF
	echo "---> Copy qemu-arm-static"
	cp $(which qemu-arm-static) $TMP_ROOTFS/usr/bin/

	echo "---> Set erveything executable"
	chmod +x $TMP_ROOTFS/bin/sh* $TMP_ROOTFS/usr/bin/*
}

function install_rootfs () {

	chroot $TMP_ROOTFS cross-build-start
	${TMP_DIR}/sbin/apk.static -v --arch $ARCH --repository $REPO --update-cache --root $TMP_ROOTFS --initdb add alpine-base --allow-untrusted --purge --no-progress
	chroot $TMP_ROOTFS cross-build-end
}

function configure_repository () {

	echo "-> Configure repository"
	echo "$REPO" > $TMP_ROOTFS/etc/apk/repositories

}

function generate_tgz () {
	echo "-> Create alpine rootfs.tgz"
	tar --numeric-owner -C $TMP_ROOTFS -zcf ${DOCKER_BUILD}/rootfs.tgz .
}


function import_in_docker () {

	echo "-> Import in Dockerfile"
	image_id=$(tar --numeric-owner -C $TMP_ROOTFS -c .  | docker import - ${TAG}:${RELEASE})
	docker tag $image_id ${TAG}:latest
	echo "Alpine imported : ${TAG}:latest"
}
### MAIN ###

test_root_user
#install_dep
create_arbo
get_apk_static
compile_resin-xbuild
install_resin-xbuild
install_rootfs
if [ "$1" == "import" ]; then 
	import_in_docker
else
	generate_tgz
fi


