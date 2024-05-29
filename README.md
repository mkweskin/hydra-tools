# hydra-tools

Personal tools for using the Hydra cluster

## How I setup centrally installed software

### Orgainization of the install directory

`/share/apps/bioinformatics/PACKAGE/VERSION`

- Within `/share/apps/bioinformatics/` create a subdirectory for the program.
  - Use all-lowercase
- Within the program's subdirectory, create a subdirectory for the version being installed.
- Create a file named `INSTALL_HYDRA` in side the version directory with install notes (they can be abridged, you don't have to include every `cd` or `tar` commands.)

### Conda based package

- `conda-create.sh` does this in addition to some other features.
- Use system-installed mamba or conda
- Create a new env for the install using `-p /path/to/env`
- Install from conda-forge and bioconda only (unless you have to use main, R, etc) 

```bash
ml tools/mamba
start-mamba
mamba create -p /share/apps/bioinformatics/PACKAGE/VERSION -c conda-forge -c bioconda bioconda::PACKAGE
```

- How do you know what version to use for the path before you install the package? Check on anaconda.org or run `mamba search bioconda::PACKAGE` to find the latest version. You can also specify a specific version in the `mamba create` command with `-v VERSION`

### Compiled packages

- When possible use the module `gcc/10.1.0`
  - Need gsl? Use `gcc/10.1/gsl`
    - Need mpi? I'be been using `gcc/10.1/openmpi`
    - Compilation errors? Sometimes I have to use `gcc/7.3.0`
- Executables should go into: `/share/apps/bioinformatics/PACKAGE/VERSION/bin`
  - Specify the install prefix when possible. For example: `./configure --prefix=/share/apps/bioinformatics/vcftools/0.1.16`
  - These can be copies or sympolic links from the original compilation location
- I retain the source code in the directory, but I delete the downloaded source archive (`….tar.gz`)

### Change permissions after install

After install is complete, change the permission of `/share/apps/bioinformatics/PACKAGE/`

`sab_perms.sh` does.

```bash
DIR=/share/apps/bioinformatics/PACKAGE/
echo "  Changing group to bioinformatics..."
chgrp -R bioinformatics $DIR
echo "  Changing perms to a+r,g+w..."
chmod -R a+r,g+w $DIR
echo "  Changing executables to a+x..."
find $DIR -executable -exec chmod a+x {} \;
```

## Module files

- If a packages uses numpy, add `module load tools/mthread-numpy` to the program's module file. This sets environmental variables such that numpy with use, at most, the number of CPUs requested with `qsub`. Without this, the numpy may use all available CPUs.

