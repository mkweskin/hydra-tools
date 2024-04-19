#!/bin/sh
HYDRA_TOOLS_BASE=~/hydra-tools
source $HYDRA_TOOLS_BASE/lib/mpk-sh-lib.sou || exit 1

###
# Usage message and process command line options
###

function usage
{
    cat << EOF

Usage: $0
  -p PROGRAM_NAME:        The program name (REQUIRED)
  -v PROGRAM_VERSION:     Program version being isntalled (REQUIRED)
  -g GCC_VERSION:         gcc module version used (omit if gcc not sued)
  -u "URL"                URL for the documentation (only one accepted)
                          Make sure to quote the URL (OPTIONAL)
  -j FILE                 Speicfy the full path to a conda-meta json file
                          to use the files lsited in bin for the list of 
                          executables. Otherwise everything in the added bin 
                          will be used. (OPTIONAL)
  -f                      Force the creation:
                             - Overwrites exsiting module file
                             - Doesn't check for expected bin directory

Example:
$0 -p bayescan -g 10.1.0 -v 2.1 -u "http://cmpg.unibe.ch/software/BayeScan/"
    Creates a module, bio/bayescan/2.1, that adds to this directory to the PATH:
    /share/apps/bioinformatics/bayescan/2.1/bin
    and loads the gcc/10.1.0 module
EOF
exit 1
}

while getopts "p:m:v:u:g:j:f" option; do
    case "${option}" in
        p)
            PROGRAM=${OPTARG}
            ;;
        v)
            VERSION=${OPTARG}
            ;;
        u)
            URL=${OPTARG}
            ;;
        g)
            GCCVER=${OPTARG}
            ;;
        j)
            JSONFILE=${OPTARG}
            ;;
        f)
            FORCE=TRUE
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

TEMPLATE=$HYDRA_TOOLS_BASE/share/MODULE_TEMPLATE
MODDIR=/share/apps/modulefiles/bioinformatics
BASEMOD=$(basename $MODDIR)
DATE=$(date)
MODFILE=$MODDIR/$PROGRAM/$VERSION


for var in PROGRAM VERSION TEMPLATE MODDIR DATE; do
  checkvar $var || usage
done 

if [ ! -z $JSONFILE ]; then
  checkfile $JSONFILE || exit
fi

checkfile $TEMPLATE || exit 1
checkdir $MODDIR || exit 1

# prepare a sed command for GCCVER
# Either set the gcc version (if specified) OR
# comment out the line that sets the gccVer variable
if [ ! -z "$GCCVER" ]; then
  GCCVERSED="s!GCCVER!$GCCVER!;"
else
  GCCVERSED="s!set gccVer!#set gccVer!;"
fi

# check that there ISN'T a file with the expected name already
if [ -f $MODFILE ] && [ -z $FORCE ]; then
  ScriptLogging "ERROR: There is an existing module: $MODFILE To recreate it, please delete it first"
  exit 1
fi

BINDIR=/share/apps/bioinformatics/$PROGRAM/$VERSION/bin
# check that the expected install directory exists
ScriptLogging "The new module file will be: $BASEMOD/$PROGRAM/$VERSION"
ScriptLogging "It will add this directory to the PATH: $BINDIR"
if [ -z $FORCE ]; then
  ScriptLogging "Checking if that exists..."
  checkdir $BINDIR || exit 1
  ScriptLogging "   ...found it"
fi



# Get the list of executables to include
if [ -z $JSONFILE ]; then
  find $BINDIR -maxdepth 1 -executable -type f -or -type l | sed "s~$BINDIR/~~" | column -c 67 > /tmp/executables
else
  # grep the focal program's json for lines that start with bin/ but don't contain any other /'s (if there's >1 /, then it could be something installed in a subdirectory
  # also if the listed file starts with a '.', ignore it.
  grep -E '^ *.\"bin/[^\.][^/]+\"' $JSONFILE | sed -r -e 's/^ *"bin\///' -e 's/\",?$//' | column -c 67 >/tmp/executables
fi

if [ ! -d $MODDIR/$PROGRAM ]; then
  mkdir -p $MODDIR/$PROGRAM
  chgrp bioinformatics $MODDIR/$PROGRAM
  chmod g+rwx,a+rx $MODDIR/$PROGRAM
fi
checkdir $MODDIR/$PROGRAM || exit 1

# Modify the TEMPLATE and use as the new 
sed "s/PROGRAM/$PROGRAM/; s/VERSION/$VERSION/; $GCCVERSED s/DATE/$DATE/; s!URL!$URL!" $TEMPLATE >$MODFILE
awk '/EXECUTABLES/ {system("cat /tmp/executables")} !/EXECUTABLES/' $MODFILE > $MODFILE.tmp
mv $MODFILE.tmp $MODFILE
#rm -f /tmp/executables.$$ 2>/dev/null

checkfile $MODFILE || exit 1
chgrp bioinformatics $MODFILE
chmod g+rw,a+r $MODFILE

ScriptLogging "DONE: The new module is: $BASEMOD/$PROGRAM/$VERSION"
ScriptLogging "      module load $BASEMOD/$PROGRAM/$VERSION"
ScriptLogging "      module help $BASEMOD/$PROGRAM/$VERSION"
ScriptLogging "      vi $MODFILE"

exit 0
