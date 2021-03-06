#!/bin/bash

##
# Based from script found at: https://drupal.org/node/244924
#
# See README or code below for usage
##

# Help menu.
print_help() {
cat <<-HELP

This script is used to fix permissions of a Drupal installation
you need to provide the following arguments:

1) Path to your Drupal installation.
2) Username of the user that you want to give files/directories ownership.
3) HTTPD group name (defaults to www-data for Apache).

Usage: (sudo) bash ${0##*/} DRUPAL_PATH DRUPAL_USER [HTTPD_GROUP]

Example: (sudo) bash ${0##*/} . john
Example: (sudo) bash ${0##*/} . john www-data

HELP
}

# Check for correct number of arguments.
if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
  print_help
	exit 0
fi

# Check for root being the executing user.
# (TODO: Is this really necessary?)
if [ $(id -u) != 0 ]; then
  printf "This script must be run as root.\n"
  exit 1
fi

# Set (default) script arguments.
drupal_path=${1%/}
drupal_user=${2}
httpd_group=${3}

drupal_path=`realpath ${drupal_path}`

if [ -z "${httpd_group}" ]; then
	httpd_group=www-data
fi

# Basic check to see if this is a valid Drupal install.
if [ -z "${drupal_path}" ] || [ ! -d "${drupal_path}/sites" ] || [ ! -f "${drupal_path}/modules/system/system.module" ]; then
  printf "Error: ${drupal_path} is not a valid Drupal path.\n"
  exit 1
fi

# Basic check to see if a valid user is provided.
if [ -z "${drupal_user}" ] || [ "$(id -un "${drupal_user}" 2> /dev/null)" != "${drupal_user}" ]; then
  printf "Error: ${drupal_user} is not a valid user.\n"
  exit 1
fi

cat <<-CONFIRM
The following settings will be used:

Drupal path: ${drupal_path}
Drupal user: ${drupal_user}
HTTPD group: ${httpd_group}

CONFIRM
read -p "Proceed? [y/N]" -n 1 -r
echo

if ! [[ $REPLY =~ ^[Yy]$ ]]; then
	exit 0
fi

cd $drupal_path
printf "Changing ownership of all contents in ${drupal_path} to\n"
printf "\tuser:  ${drupal_user}\n"
printf "\tgroup: ${httpd_group}\n"

chown -R ${drupal_user}:${httpd_group} .

printf "Changing permissions...\n"
printf "rwxr-x--- on all directories inside ${drupal_path}\n"
find . -type d -exec chmod u=rwx,g=rx,o= '{}' \;

printf "rw-r----- on all files       inside ${drupal_path}\n"
find . -type f -exec chmod u=rw,g=r,o= '{}' \;

printf "rwx------ on all files       inside ${drupal_path}/scripts\n"
cd ${drupal_path}/scripts
find . -type f -exec chmod u=rwx,g=,o= '{}' \;

printf "rwxrwx--- on \"files\" directories in ${drupal_path}/sites\n"
cd ${drupal_path}/sites
find . -type d -name files -exec chmod ug=rwx,o= '{}' \;

printf "rw-rw---- on all files       inside all /files directories in ${drupal_path}/sites,\n"
printf "rwxrwx--- on all directories inside all /files directories in ${drupal_path}/sites:\n"
for x in ./*/files; do
  printf "\tChanging permissions in `realpath ${x}`\n"
  find ${x} -type d -exec chmod ug=rwx,o= '{}' \;
  find ${x} -type f -exec chmod ug=rw,o= '{}' \;
done

cd ${drupal_path}
if [ -d ".git" ]; then
	printf "rwx------ on .git/ directories and files in ${drupal_path}/.git\n"
	cd ${drupal_path}
	chmod -R u=rwx,go= .git
	chmod u=rw,go= .gitignore
fi

printf "rwx------ on various Drupal text files in   ${drupal_path}\n"
cd ${drupal_path}
chmod u=rw,go= \
	CHANGELOG.txt \
	COPYRIGHT.txt \
	INSTALL.*.txt \
	INSTALL.txt \
	LICENSE.txt \
	MAINTAINERS.txt \
	README.txt \
	UPGRADE.txt

# Boost module permissions as recommended in https://www.drupal.org/node/1459690.
cd ${drupal_path}
if [ -d "cache" ]; then
	printf "rwxrwxr-x on Boost module cache directory   ${drupal_path}\n"
	cd ${drupal_path}/cache
	for x in ./*
	do
		 find ${x} -type d -exec chmod ug=rwx,o= '{}' \;
		 find ${x} -type f -exec chmod ug=rw,o= '{}' \;
	done
fi

echo "Done setting proper permissions on files and directories."
