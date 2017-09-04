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
BUILD_PATH="dockerBuild"
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
	apt-get install -y  curl qemu-user-static docker-ce
	
}

function create_arbo () {
	
	echo "-> Prepare build env"
	echo "---> Create ${TMP_DIR} ${TMP_ROOTFS}" 
	rm -rf ${TMP_DIR} ${TMP_ROOTFS} ${BUILD_PATH}
	mkdir -p ${TMP_DIR}
	mkdir -p ${TMP_ROOTFS}
	mkdir -p ${BUILD_PATH}
	
}

function get_apk_static () {
	echo "-> Install apk.static for $(uname -m)"
	apk_version=$(curl -s $REPO/$(uname -m)/APKINDEX.tar.gz | tar -Oxz | sed -n '/apk-tools-static/{n;s/V://p}')
	echo "---> APK version=$apk_version"
	curl -s ${REPO}/$(uname -m)/apk-tools-static-${apk_version}.apk | tar -xz -C $TMP_DIR sbin/apk.static 
}


function install_xbuild () {
	
	echo "-> Install resin-xbuild"
	echo "---> Create /usr/bin and /bin"
	mkdir -p $TMP_ROOTFS/{,usr/}bin

	echo "---> Copy resin-xbuild binary"
	cp -rd x86_64 $TMP_ROOTFS/
	ln -sf /x86_64/cross-build-start $TMP_ROOTFS/usr/bin/cross-build-start
	ln -sf /x86_64/cross-build-end $TMP_ROOTFS/usr/bin/cross-build-end

	echo "---> Copy qemu-arm-static"
	cp $(which qemu-arm-static) $TMP_ROOTFS/x86_64/
	ln -sf /x86_64/qemu-arm-static $TMP_ROOTFS/usr/bin/

	echo "---> Set erveything executable"
	chmod +x -f $TMP_ROOTFS/x86_64/{cross-build-end,cross-build-start,sh-shim}
}

function install_rootfs () {
	echo "-> Install root FS"
	cp ${TMP_DIR}/sbin/apk.static $TMP_ROOTFS/x86_64/apk.static
	mkdir -p $TMP_ROOTFS/etc/apk
	
	echo "-> Configure repository"
	echo "$REPO" > $TMP_ROOTFS/etc/apk/repositories
	
	echo "-> Copy temporarly resolv.conf"
	cp /etc/resolv.conf $TMP_ROOTFS/etc/


	chroot $TMP_ROOTFS /x86_64/apk.static -v --arch $ARCH --update-cache --root / --initdb add alpine-base ca-certificates --allow-untrusted --purge --no-progress
	# clean 
	rm $TMP_ROOTFS/etc/resolv.conf
}

function generate_rootfstgz () {
	echo "-> Create alpine rootfs.tgz"
	tar -C $TMP_ROOTFS -zcf ${BUILD_PATH}/rootfs.tgz .

}


function import_in_docker () {
	# Not used anymore, replaced by a local build as dockerhub
	echo "-> Import in Dockerfile"
	image_id=$(tar --numeric-owner -C $TMP_ROOTFS -c .  | docker import - ${TAG}:${RELEASE})
	docker tag $image_id ${TAG}:latest
	echo "Alpine imported : ${TAG}:latest"
	
}

function local_docker_build () {
	tag=$1
	dockerfile=${2:-$BUILD_PATH/Dockerfile}
	cat <<EOF > $dockerfile
FROM scratch
ADD rootfs.tgz /
CMD ["/bin/sh"]
EOF


	echo "-> Build docker as dockerhub will do"
	docker build -t ${tag} -f $dockerfile $BUILD_PATH

}

function test_docker_build () {
	local_docker_build ${TAG}-test $BUILD_PATH/Dockerfile-docker_build-test
	echo "-> Start the container"
	docker run -it ${TAG}-test /usr/bin/qemu-arm-static /bin/echo 'WORKING !!!'
  
}

function test_docker_use_img () {
	cat <<EOF > $BUILD_PATH/Dockerfile-docker_use_img-test
FROM ${TAG}-test
RUN ["cross-build-start"]
RUN ["apk", "update"]
RUN ["apk", "add", "--update", "python"]
RUN ["cross-build-end"]
CMD ["/usr/bin/python", "-c",'print(\"WORKING !!!\")' ]
EOF
	
	echo "-> Build new docker image using generated as base image"
	docker build -t ${TAG}-python -f $BUILD_PATH/Dockerfile-docker_use_img-test $BUILD_PATH

	echo "-> Start the container"
	docker run -it ${TAG}-python /usr/bin/qemu-arm-static /usr/bin/python -c 'print("WORKING !!!!")'
}

function trigger_build_on_dockerhub () {
	# curl -q -H "Content-Type: application/json" --data '{"source_type": "Tag", "source_name": "v0.1.13", "docker_tag": "0.1.13"}' -X POST https://registry.hub.docker.com/u/dj4ngo/alpine-rpi/trigger/${DOCKERHUB_TOKEN}/
	# curl -H "Content-Type: application/json" --data '{"source_type": "Tag", "source_name": "v0.1.24"}' -X POST https://registry.hub.docker.com/u/dj4ngo/alpine-rpi/trigger/${DOCKERHUB_TOKEN}/
 	:
}

function mr_proper () {
	trap "rm -rf ${TMP_DIR} ${TMP_ROOTFS}" EXIT TERM INT
}

### MAIN ###

available_functions="$(typeset -F | sed -n 's/^declare -f \([^_].*\)/\1/p')"
func_name="$1"
if [ -z "$func_name" ]; then
	$0 install_dep
	$0 create_arbo
	$0 get_apk_static
	$0 install_xbuild
	$0 install_rootfs
	$0 generate_rootfstgz
#	$0 mr_proper
	$0 local_docker_build $TAG	
	$0 test_docker_build
	$0 test_docker_use_img
fi
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
