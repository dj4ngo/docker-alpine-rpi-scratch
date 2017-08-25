#!/bin/bash -e

#
#
# This script is used to help TAG creation
# The aim is to do the bumpversion, push the commits, push the new tag
# Once the travais-ci will finish, it is used to create the BRANCH (same name as tag) to autobuild a tagged docker image in dockerhub
#

BRANCH="develop"
CUR_BRANCH="$(git branch --color=never  | sed -n 's/^* //p')"
TRAVIS_TIMEOUT="$(( 10 * 60 ))"


function usage () {
	cat <<EOF
USAGE:  $0 [major|minor|patch]
EOF
}


### MAIN ###


# args check
case $1 in
	major|minor|patch)
		BUMP=$1
	;;
	"")
		BUMP="patch"
	;;
	*)
		usage
	;;
esac


# Check current BRANCH
if [ "${CUR_BRANCH}" != "${BRANCH}" ]; then 
	echo "ERROR: Must be on branch ${BRANCH} to run this script"
	exit 1
fi

# update local git repo .... 
git pull
git fetch origin

# let's do the bumpversion
echo "-> bumpversion to $BUMP"
bumpversion $BUMP
# Print tag created
git push --tags --dry-run
# get tag name
version=$( sed -n  's/current_version = //p' .bumpversion.cfg)
tag="v$version"

echo "-> push local commits"
git push 

echo "-> push tags"
git push --tags

# get URL of release file needed (rootfs.tgz)
url=$(sed -n 's#ADD ##;s# /$##p' Dockerfile)
end_time=$(( $(date +%s) + $TRAVIS_TIMEOUT ))

echo -n "Waiting travis-ci build to finish to tag the branch and merge on master "
until curl --output /dev/null --silent --head --fail "$url"; do
	sleep 5
	if [ "$(date +%s)" -ge "$end_time" ]; then
		echo -e "KO\nTIMEOUT ERROR: file $cmd never found, travais-ci build may be KO !"
		exit 2
	fi
	echo -n '.'
done
echo 'DONE'

echo "-> Create branch $version from tag $tag"
git branch $version $tag
git push --set-upstream origin $version

echo "-> Merge to branch master"
git checkout master
git merge $version

