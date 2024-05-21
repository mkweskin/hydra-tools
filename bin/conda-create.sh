#!/bin/sh
HYDRA_TOOLS_BASE=~/hydra-tools
LIB=$HYDRA_TOOLS_BASE/lib/mpk-sh-lib.sou
source $LIB || lib_error=TRUE
install_base=/share/apps/bioinformatics

if [ ! -z $lib_error ]; then
  echo "ERROR: could not find $LIB. This file contains required functions needed for this script."
fi

checkdir $install_base || exit 1

# Program to create modules
CREATEMODULE="$HYDRA_TOOLS_BASE/bin/create-module.sh"
checkfile $CREATEMODULE || exit 1

# Program to change permissions on install dir
SABPERMS="$HYDRA_TOOLS_BASE/bin/sab_perms.sh"
checkfile $SABPERMS || exit 1

# Where your envs are located, The new env will be created in here
install_base=/share/apps/bioinformatics

checkwhich mamba && MAMBA=mamba

if [ -z $MAMBA ]; then
  echo "WARNING: mamba was not found in your path, trying conda (but conda is so much slower!)"
  checkwhich conda && MAMBA=conda
    if [ -z $MAMBA ]; then
      echo "ERROR: neither mamba or conda were found in your path. Please fix this by loading tools/mamba (or tools/conda)"
      exit 1
    fi
fi

if [ -z $CONDA_PREFIX ]; then
  echo "Attempting to run start-$MAMBA"
  start-$MAMBA
  if [ -z $CONDA_PREFIX ]; then
    echo "ERROR: Attempted to run start-$MAMBA to initialize the $MAMBA environment, but it failed"
    exit 1
  fi
fi

function usage
{
    cat << EOF

Usage: $0
  -p PROGRAM_NAME:        The program name (as found in mamba) (REQUIRED)
  -v PROGRAM_VERSION:     Program version to install. If not given,
                          the latest version on bioconda is installed (OPTIONAL)
  -f                      Force the creation (OPTIONAL)
                             - Overwrites exsiting install directory
                               (IF IT WAS INSTALLED BY CONDA/MAMBA)
                             - Overwrites exsiting module file
  -u "URL"                Add this URL to the module documentation (OPTIONAL)
  -c CHANNEL              Conda channel to search for the focal package (OPTIONAL)
                             (default is bioconda)
  -d INSTALLDIR           In rare cases, the install directory name on Hydra
                          (& the module's name) aren't the same as the conda package
                          name. Use this to specify the name used on Hydra.
                          E.g: bioperl is called perl-bioperl on bioconda.
                          You would use -p perl-bioperl and -d bioperl. (OPTIONAL)
  -C                      Confirm conda packages before installing

Example:
$0 -p mitofinder
    Installs the most recent version of mitofinder available on conda.
    Then creates a module for that version.
EOF
exit 1
}

# Get options
while getopts "p:v:u:c:d:fC" option; do
    case "${option}" in
        p)
            PROGRAM=${OPTARG}
            ;;
        v)
            VERSION=${OPTARG}
            ;;
        f)
            FORCE="-f"
            ;;
        u)
            URL="${OPTARG}"
            ;;
        c)
            CHANNEL=${OPTARG}
            ;;
        d)
            INSTALLDIR=${OPTARG}
            ;;
        C)
            CONFIRM=TRUE
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

checkvar PROGRAM || usage

[ -z $CHANNEL ] && CHANNEL=bioconda

if [ -z $VERSION ]; then
  # find latest version
  echo "Searching for the latest version of $PROGRAM in $CHANNEL..."
  $MAMBA search $CHANNEL::$PROGRAM 2>/tmp/$PROGRAM.out >/tmp/search.$$ || search_error=TRUE
  VERSION=$(tail -n 1 /tmp/search.$$ | awk '{print $2}')
  rm -f /tmp/search.$$
fi

# If the install directory name wasn't specified, it's the conda name
if [ -z $INSTALLDIR ]; then
  INSTALLDIR=$PROGRAM
fi

# If -C was specified, have conda ask if the packages should be installed
if [ -z $CONFIRM ]; then
  CONFIRM="-y"
else
  unset CONFIRM
fi

$MAMBA search $CHANNEL::$PROGRAM=$VERSION 2>/tmp/$PROGRAM.out >/tmp/search.$$ || search_error=TRUE
if [ ! -z $search_error ]; then
  echo "  ERROR: There was an error with finding $PROGRAM $VERSION in $CHANNEL."
  echo "         View the error log here: /tmp/$PROGRAM.out"
  rm -f /tmp/search.$$
  exit 1
fi
rm /tmp/$PROGRAM.out

echo "  found $VERSION."

env_dir=$install_base/$INSTALLDIR/$VERSION

# exit if there's already a directory in the destination
if [ -d $env_dir ]; then
  if [ -z $FORCE ]; then
    echo "ERROR: the destination directory already exists."
    echo "  $env_dir"
    echo "Remove it and re-run this program or use the -f to overwite automatically"
    exit 1
  else
    # check if this is a conda/mamba env dir
    # I'm saying if there's a conda-meta dir, it's conda installed
    if [ -d $env_dir/conda-meta ]; then
      echo "WARNING: found previous conda installed verion in $env_dir."
      echo "  Removing it (because you used the -f flag)..."
      rm -rf $env_dir
    fi
  fi
fi

echo "Creating new env in: $env_dir"

# Install the package into the designated directory
# Note that the version ISN'T specified here. I want mamba to choose the version again.
# You can add -q for less output
MAMBACOMMAND="$MAMBA create $CONFIRM -c conda-forge -c bioconda --override-channels -p $env_dir $CHANNEL::$PROGRAM=$VERSION"
echo "Running:"
echo $MAMBACOMMAND

eval "$MAMBACOMMAND 2>/tmp/$PROGRAM.out || create_error=TRUE"

if [ ! -z $create_error ]; then
  echo "ERROR: There was an error when creating the environment"
  echo "       View the error log here: /tmp/$PROGRAM.out"
  exit 1
fi
rm /tmp/$PROGRAM.out

# List the programs that were installed for the focal program.
# Other files in the env's bin are not included.

# Check for the expected json file
JSON="$env_dir/conda-meta/$PROGRAM-$VERSION-*.json"
if [ ! -f $JSON ]; then
  echo "ERROR: something went wrong. The file $env_dir/conda-meta/$PROGRAM-$VERSION-*.json was expected, but not found."
  echo "  The version that was expected was $VERSION, perhaps a different version was installed?"
  exit 1
fi

echo "Executables now available for $PROGRAM:"

# grep the focal program's json for lines that start with bin/ but don't contain any other /'s (if there's >1 /, then it could be something installed in a subdirectory
#grep -E '^ *.\"bin/[^/]+\"' $env_dir/conda-meta/$PROGRAM-$VERSION-*.json | sed -r -e 's/^ *"bin\///' -e 's/\",?$//' | column -c 67 >/tmp/executables.$$

echo "Setting permissions for $install_base/$PROGRAM..."
$SABPERMS $install_base/$PROGRAM

echo "creating module..."

# format the url tag, if url was given
[ ! -z "$URL" ] && URL="-u $URL"

$CREATEMODULE -p $INSTALLDIR -v $VERSION "$URL" -j $JSON $FORCE 
# rm /tmp/executables.$$

exit 0
