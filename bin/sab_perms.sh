#!/bin/sh

# This script changes the group ownership and permissions of the specified directory and its contents.
# It performs the following steps:
# 1. Checks if a directory parameter is provided and exits with an error if not.
# 2. Verifies that the provided parameter is a valid directory and exits with an error if not.
# 3. Changes the group ownership of the directory and its contents to 'bioinformatics'.
# 4. Modifies the permissions to allow read access for all users and write access for the group and user.
# 5. Adds execute permissions for all users to any executable files within the directory.

# Define the group name to be used for changing group ownership
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
echo "  Changing perms to a+r,gu+w..."
chmod -R a+r,gu+w $1
echo "  Changing executables to a+x..."
find $1 -executable -exec chmod a+x {} \;

echo "- Done"
exit 0
