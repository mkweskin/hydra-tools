#!/bin/sh
# Given a directory with module files, creates a .version file (if necessary)
# This script needs lots of fleshing out :/
set -e

HYDRA_TOOLS_BASE=~/hydra-tools
source $HYDRA_TOOLS_BASE/lib/mpk-sh-lib.sou || exit 1

checkvar 1
MAMBADIR=$1
checkdir "$MAMBADIR"

# If there's already a .version file, stop
if [ -e $MAMBADIR/.version ]; then
  echo ".version file exists in $MAMBADIR. Stopping"
  exit 0
fi

# If there's more than one module file, stop
FILECOUNT=$(find $MAMBADIR -maxdepth 1 -type f | wc -l)
if [ $FILECOUNT -gt 1 ]; then
  echo "There is more than one file in this directory ($MAMBADIR). Stopping"
  exit 0
fi

# If there are no files, that's another problem
if [ $FILECOUNT -eq 0 ]; then
  echo "ERROR: There are NO files in this directory ($MAMBADIR). Stopping"
  exit 1
fi
echo here
# create the .version module file
# first get the file name (there should be just one, but using head anyway to be safe)
FILENAME=$(ls $MAMBADIR | head -n 1)
VERSION=$(basename $FILENAME)

cat << EOF >$MAMBADIR/.version
#%Module1.0
set ModulesVersion "$VERSION"
EOF
echo "$MAMBADIR/.version created. It contains:"
cat $MAMBADIR/.version

exit 0