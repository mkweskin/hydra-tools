#!/bin/sh
GROUP=bioinformatics
if [ -z $1 ]; then
  echo "ERROR: Give the directory as a parameter"
  exit 1
fi

if [ ! -d $1 ]; then
  echo "ERROR: Directory not found: $1"
  exit 1
fi

echo "+ Starting $1"
echo "  Changing group to $GROUP..."
chgrp -R $GROUP $1
echo "  Changing perms to a+r,g+w..."
chmod -R a+r,g+w $1
echo "  Changing executables to a+x..."
find $1 -executable -exec chmod a+x {} \;

echo "- Done"
exit 0
