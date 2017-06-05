#!/bin/bash

set -e

# Find all dependent shared object files for the collectd installation and move
# them into the installation directory

INSTALL_DIR=$1

size() {
  du -sh $INSTALL_DIR | head | awk '{ print $1 }'
}

former_size=$(size)

find_deps() {
# Run all of the collectd libs/binaries through ldd and pull out the deps
find $INSTALL_DIR -executable -type f ! -name "*.la" | \
    xargs ldd | \
    perl -ne 'print if /.* => (.+) \(0x[0-9a-f]+\)/' | \
    perl -pe 's/.* => (.+) \(0x[0-9a-f]+\)/\1/' | \
    perl -ne '/^\ s/ || print' | \
    perl -ne '/:$/ || print' | \
    grep -v "/opt/collectd" | \
    sort | uniq
}

mkdir -p $INSTALL_DIR/lib

libs=$(find_deps)
for lib in $libs
do
  cp $lib $INSTALL_DIR/lib/

  echo "Pulled in $lib" # to $new_path"
done

echo "Processed $(wc -w <<< $libs) libraries"

echo "Checking for missing lib dependencies..."

# LD_LIBRARY_PATH gets priority over default system paths
LIB_PATHS=$INSTALL_DIR/lib:$INSTALL_DIR/jre/lib/amd64
new_deps=$(LD_LIBRARY_PATH=$LIB_PATHS find_deps)

# Look for any libs still pointing out of our install path
missing_deps=$(grep -v "/opt/collectd" <<< $new_deps || true)
if [[ -n $missing_deps ]]
then
  echo "Missing dependencies!!\n$missing_deps" >&2
  exit 1
else
  echo "Everything is there!"
fi

echo "Original installation size: $former_size"
echo "New installation size: $(size)"
