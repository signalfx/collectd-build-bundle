#!/bin/bash

set -ex

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

libs=$(find_deps)
for lib in $libs
do
  relative_path=$(perl -pe 's!^/usr!!' <<< $lib)

  new_path=${INSTALL_DIR}${relative_path}
  mkdir -p $(dirname $new_path)

  cp $lib $new_path

  echo "Pulled in $lib to $new_path"
done

echo "Processed $(wc -w <<< $libs) libraries"

echo "Checking for missing lib dependencies..."

# LD_LIBRARY_PATH gets priority over default system paths
export LD_LIBRARY_PATH=$INSTALL_DIR/lib:$INSTALL_DIR/lib/x86_64-linux-gnu
new_deps=$(find_deps)
export LD_LIBRARY_PATH=

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
