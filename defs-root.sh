#!/bin/sh -e

# ----------------------------------------------------------------------
# defs-root.sh
# Root definitions for FPP models
# ----------------------------------------------------------------------

# Require environment variables to be set
require_vars()
{
  for var in $@
  do
    cmd='echo $'$var
    out="`eval $cmd`"
    if test -z "$out"
    then
      echo "$var not set" 1>&2
      exit 1
    fi
  done
}

# Require and canonicalize FPRIME_ROOT
require_vars FPRIME_ROOT
export FPRIME_ROOT=`cd $FPRIME_ROOT; echo $PWD`
export FPP_LOCS="$FPRIME_ROOT/locs.fpp $CLIENT_FPP_LOCS"

redo-ifchange defs.sh
redo-ifchange $FPRIME_ROOT/defs-root.sh

# Run command on all files matching regex
doall()
{
  cmd=$1
  shift
  for regex in "$@"
  do
    shift
    for file in `find . -name "$regex" -maxdepth 1`
    do
      $cmd $file
    done
  done
}

# Find and run all subdirectory targets
subdir_targets()
{
  for dir in $SUBDIRS
  do
    echo $dir/$2
  done | xargs $1
}

# Clean files
clean_do()
{
  doall 'rm -rf' '*~' depend xml '*.targets.txt'
}

# Generate depend directory
depend_do()
{
  require_vars FPP_FILES
  # Regenerate the dependencies if any of these files have changed
  redo-ifchange $FPP_LOCS $FPP_FILES
  rm -rf $3
  mkdir $3
  fpp-depend -m $3/missing.txt $FPP_LOCS $FPP_FILES > $3/noinclude.txt
  fpp-depend -i $FPP_LOCS $FPP_FILES > $3/include.txt
  missing=`cat $3/missing.txt`
  if test -n "$missing"
  then
    echo "WARNING: missing dependency files" 1>&2
    echo $missing 1>&2
  fi
  # If the generated dependencies have not changed, then we don't
  # need to report a change upwards in the build
  cat $3/*.txt | redo-stamp
}

# Convert import dependencies to comma-separated format
get_comma_deps()
{
  # Recompute all dependencies
  redo-ifchange depend
  # Compute the files this build depends on
  # Count included dependencies
  build_deps=`cat depend/include.txt`
  redo-ifchange $FPP_FILES $build_deps
  # Compute the files to import
  # Don't count included dependencies
  import_deps=`cat depend/noinclude.txt`
  if test -n "$import_deps"
  then
    echo $import_deps | sed 's/ /,/g'
  fi
}

# Generate XML files
xml_do()
{
  comma_deps=`get_comma_deps`
  if test -n "$comma_deps"
  then
    import_deps="-i $comma_deps"
  else
    unset import_deps
  fi
  rm -rf $3
  mkdir $3
  fpp-to-xml -d $3 -p $FPRIME_ROOT$FPP_PATH_PREFIXES $import_deps $FPP_FILES
}

# Locate uses
locate_uses_do()
{
  comma_deps=`get_comma_deps`
  if test -n "$comma_deps"
  then
    import_deps="-i $comma_deps,$FPP_LOCS"
  else
    import_deps="-i $FPP_LOCS"
  fi
  fpp-locate-uses $import_deps $FPP_FILES
}

# Update generated files
update()
{
  for file in $@
  do
    base=`basename $file`
    if ! test -f $base || ! diff -q $file $base > /dev/null
    then
      cp $file $base
    fi
  done
}
