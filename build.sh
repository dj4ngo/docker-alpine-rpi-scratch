#!/bin/bash -e

#TODO : add keys for apk


### ENV VARS ###
TMP_DIR="/tmp/alpine-tmp"
TMP_ROOTFS="/tmp/alpine-rootfs"
MIRROR="http://nl.alpinelinux.org/alpine"
RELEASE="latest-stable"
REPO="${MIRROR}/${RELEASE}/main"
ARCH="armhf"
TAG="dj4ngo/alpine-rpi"
DOCKER_BUILD="dockerBuild"
export GOPATH=""
export GOROOT="/usr/lib/go"
export GOTOOLDIR="/usr/lib/go/pkg/tool/linux_amd64"

function usage () {
	cat << EOF
USAGE : ${0} <function_name>
	list of available <function_name> :
EOF
	for func in $available_functions; do
		echo -e "\t- $func"
	done
	cat << EOF
	If you want to build localy the Docker Container and add it to your local docker, just run :
	${0} local_build
EOF
}


function test_root_user () {
	
	echo "-> Test root user"
	if [ "$(id -u)" -ne 0 ]; then 
		echo "$0 needs to be runned as root ! " >&2
		exit 100
	fi 
	
}

function install_dep () {
	
	echo "-> Install dependencies for build"
	apt-get update -qq
	apt-get install -y  curl golang qemu-user-static
	
}

function create_arbo () {
	
	echo "-> Prepare build env"
	echo "---> Create ${TMP_DIR} ${TMP_ROOTFS}" 
	rm -rf ${TMP_DIR} ${TMP_ROOTFS} ${DOCKER_BUILD}
	mkdir -p ${TMP_DIR}
	mkdir -p ${TMP_ROOTFS}
	mkdir -p ${DOCKER_BUILD}
	cp Dockerfile ${DOCKER_BUILD}/
	
}

function get_apk_static () {
	
	echo "-> Install apk.static for $(uname -m)"
	apk_version=$(curl -s $REPO/$(uname -m)/APKINDEX.tar.gz | tar -Oxz | sed -n '/apk-tools-static/{n;s/V://p}')
	echo "---> APK version=$apk_version"
	curl -s ${REPO}/$(uname -m)/apk-tools-static-${apk_version}.apk | tar -xz -C $TMP_DIR sbin/apk.static 
	
}

function get_resin-xbuild () {
	echo "---> Get resin-xbuild from https://github.com/resin-io-projects/armv7hf-debian-qemu"
	mkdir -p ${TMP_DIR}/resin-xbuild
	pushd ${TMP_DIR}/resin-xbuild
	curl -s "https://raw.githubusercontent.com/resin-io-projects/armv7hf-debian-qemu/master/resin-xbuild.go" -o resin-xbuild.go
	popd
}

function compile_resin-xbuild () {
	echo "-> Compile resin-xbuild"
	pushd ${TMP_DIR}/resin-xbuild
	go build -ldflags "-w -s" resin-xbuild.go
	popd
}

function install_resin-xbuild () {
	
	echo "-> Install resin-xbuild"
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
	
	echo "-> Install root FS"
	chroot $TMP_ROOTFS cross-build-start
	${TMP_DIR}/sbin/apk.static -v --arch $ARCH --repository $REPO --update-cache --root $TMP_ROOTFS --initdb add alpine-base --allow-untrusted --purge --no-progress
	chroot $TMP_ROOTFS cross-build-end
	echo "-> Configure repository"
	echo "$REPO" > $TMP_ROOTFS/etc/apk/repositories
	

}

function generate_rootfstgz () {
	
	echo "-> Create alpine rootfs.tgz"
	tar --numeric-owner -C $TMP_ROOTFS -zcf ${DOCKER_BUILD}/rootfs.tgz .

}


function import_in_docker () {
	
	echo "-> Import in Dockerfile"
	image_id=$(tar --numeric-owner -C $TMP_ROOTFS -c .  | docker import - ${TAG}:${RELEASE})
	docker tag $image_id ${TAG}:latest
	echo "Alpine imported : ${TAG}:latest"
	
}


function test_docker_build () {
 : TODO
}

function test_docker_use_img () {
 : TODO
}

function deploy_on_dockerhub () {
 : TODO
}

function mr_proper () {
	trap "rm -rf ${TMP_DIR} ${TMP_ROOTFS}" EXIT TERM INT
}

### MAIN ###
function local_build () {
	install_dep
	create_arbo
	get_apk_static
	get_resin-xbuild
	compile_resin-xbuild
	install_resin-xbuild
	install_rootfs
	generate_rootfstgz
	mr_proper
}



available_functions="$(typeset -F | sed -n 's/^declare -f \([^_].*\)/\1/p')"
func_name="$1"
if [ -z "$func_name" ]; then usage; fi
shift
args="${@}"

if grep -q "\<$func_name\>" <<< $available_functions; then
	test_root_user
	echo ">>>>>> RUN $func_name"
	set -x
	$func_name $args	
	set +x
else
	usage
fi
