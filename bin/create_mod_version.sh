#!/bin/sh

# If there's already a .version file, stop
if [ -e .version ]; then
  echo ".version file exists: $PWD. stopping"
  exit 0
fi

# If there's more than one module file, stop
FILECOUNT=$(find . -maxdepth 1 -type f | wc -l)
if [ $FILECOUNT -gt 1 ]; then
  echo "ERROR: there is more than one module file in this directory ($PWD)."
  exit 1
fi

# If there are no files, that's another problem

if [ $FILECOUNT -eq 0 ]; then
  echo "ERROR: There's no module file here ($PWD)."
  exit 1
fi


# create the .version module file
# first get the file name (there should be just one, but using head anyway to be safe)
VERSION=$(ls | head -n 1)

cat << EOF >.version
#%Module1.0
set ModulesVersion "$VERSION"
EOF

exit 0