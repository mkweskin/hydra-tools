#!/bin/sh
HYDRA_TOOLS_BASE="$(cd -- "$(dirname -- "$0")/.." && pwd)"
LIB=$HYDRA_TOOLS_BASE/lib/mpk-sh-lib.sou
source $LIB || lib_error=TRUE

# Capture how the program was invoked. This will be output if there's an error.
ORIG_CMD="$0"
if [ "$#" -gt 0 ]; then
    # Append each original argument, preserving spaces
    for arg in "$@"; do
        ORIG_CMD="$ORIG_CMD $arg"
    done
fi

if [ ! -z "$lib_error" ]; then
  echo "ERROR: could not find $LIB. This file contains required functions needed for this script."
fi

# Program to create modules
CREATEMODULE="$HYDRA_TOOLS_BASE/bin/create-module.sh"
checkfile $CREATEMODULE || die

# Program to change permissions on install dir
SABPERMS="$HYDRA_TOOLS_BASE/bin/sab_perms.sh"
checkfile $SABPERMS || die

checkwhich mamba 2&>/dev/null && MAMBA=mamba

if [ -z "$MAMBA" ]; then
  echo "WARNING: mamba was not found in your path, trying conda (but conda is so much slower!)"
  checkwhich conda 2&>/dev/null && MAMBA=conda
    if [ -z "$MAMBA" ]; then
      echo "ERROR: neither mamba or conda were found in your path. Please fix by loading tools/mamba (or tools/conda)"
      die
    fi
else
  echo "INFO: $MAMBA found in your path. Checking if it's configured."
fi

if checkwhich __mamba_exe 2&>/dev/null && checkwhich __conda_exe >2&>/dev/null; then
  echo "ERROR: $MAMBA does not appear to be fully configured. If you're using the tools/$MAMBA module, make sure to run \"start-$MAMBA\" before starting this program."
  die
else
  echo "INFO: $MAMBA appears to be configured, proceeding."
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
  -a APPS_DIR             The parent directory to install in.
                              (default is '/share/apps/bioinformatics') 
  -C                      Confirm conda packages before installing

Example:
$0 -p mitofinder
    Installs the most recent version of mitofinder available on conda.
    Then creates a module for that version.
EOF
die
}

# Get options
while getopts "p:v:u:c:d:a:fC" option; do
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
        a)
            INSTALLBASE=${OPTARG}
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

[ -z "$CHANNEL" ] && CHANNEL=bioconda

[ -z "$INSTALLBASE" ] && INSTALLBASE=/share/apps/bioinformatics
checkdir $INSTALLBASE || die

if [ -z "$VERSION" ]; then
  # find latest version
  echo "Searching for the latest version of $PROGRAM in $CHANNEL..."
  $MAMBA search --json $CHANNEL::$PROGRAM 2>/tmp/$PROGRAM.out >/tmp/search.$$ || search_error=TRUE
  VERSION=$(grep \"version\" /tmp/search.$$ | tail -n 1 | awk '{print $2}' | sed 's/"//g')
  rm -f /tmp/search.$$
  echo "Latest version found: $VERSION"
fi

# If the install directory name wasn't specified, it's the conda name
if [ -z "$INSTALLDIR" ]; then
  INSTALLDIR=$PROGRAM
fi

# If -C was specified, have conda ask if the packages should be installed
if [ -z "$CONFIRM" ]; then
  CONFIRM="-y"
else
  unset CONFIRM
fi

$MAMBA search $CHANNEL::$PROGRAM=$VERSION 2>/tmp/$PROGRAM.out >/tmp/search.$$ || search_error=TRUE
if [ ! -z "$search_error" ]; then
  echo "  ERROR: There was an error with finding $PROGRAM $VERSION in $CHANNEL."
  echo "         View the error log here: /tmp/$PROGRAM.out"
  rm -f /tmp/search.$$
  die
fi
rm /tmp/$PROGRAM.out

echo "  found $VERSION."

env_dir=$INSTALLBASE/$INSTALLDIR/$VERSION

# dief there's already a directory in the destination
if [ -d $env_dir ]; then
  if [ -z "$FORCE" ]; then
    echo "ERROR: the destination directory already exists."
    echo "  $env_dir"
    echo "Remove it and re-run this program or use the -f to overwite automatically"
    die
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
MAMBACOMMAND="$MAMBA create $CONFIRM -c conda-forge -c bioconda --override-channels --strict-channel-priority -p $env_dir $CHANNEL::$PROGRAM=$VERSION"
echo "Running:"
echo $MAMBACOMMAND

eval "$MAMBACOMMAND 2>/tmp/$PROGRAM.out || create_error=TRUE"

if [ ! -z "$create_error" ]; then
  echo "ERROR: There was an error when creating the environment"
  echo "       View the error log here: /tmp/$PROGRAM.out"
  die
fi
rm /tmp/$PROGRAM.out

# List the programs that were installed for the focal program.
# Other files in the env's bin are not included.

# Check for the expected json file
JSON="$env_dir/conda-meta/$PROGRAM-$VERSION-*.json"
if [ ! -f $JSON ]; then
  echo "ERROR: something went wrong. The file $env_dir/conda-meta/$PROGRAM-$VERSION-*.json was expected, but not found."
  echo "  The version that was expected was $VERSION, perhaps a different version was installed?"
  die
fi

echo "Executables now available for $PROGRAM:"

# grep the focal program's json for lines that start with bin/ but don't contain any other /'s (if there's >1 /, then it could be something installed in a subdirectory
#grep -E '^ *.\"bin/[^/]+\"' $env_dir/conda-meta/$PROGRAM-$VERSION-*.json | sed -r -e 's/^ *"bin\///' -e 's/\",?$//' | column -c 67 >/tmp/executables.$$

echo "Setting permissions for $INSTALLBASE/$PROGRAM..."
$SABPERMS $INSTALLBASE/$PROGRAM

echo "creating module..."

# format the url tag, if url was given
[ ! -z "$URL" ] && URL="-u $URL"

# Create the module location based on $INSTALLBASE
MODULEBASE="$(printf "%s" "$INSTALLBASE" | sed 's|^/share/apps|/share/apps/modules|')"

$CREATEMODULE -p $INSTALLDIR -v $VERSION "$URL" -m $MODULEBASE -j $JSON $FORCE 
# rm /tmp/executables.$$

exit $?
