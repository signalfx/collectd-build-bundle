#!/bin/bash

set -exo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

y() {
  filter=$1
  # yq is like jq for yaml
  cat $SCRIPT_DIR/plugins.yaml | PATH=/opt/collectd/bin:$PATH yq -r "$1"
}

for i in $(seq 0 $(y '. | length - 1'))
do
  plugin_name=$(y ".[$i].name")
  version=$(y ".[$i].version")
  repo=$(y ".[$i].repo")
  plugin_dir=/opt/collectd/plugins/${plugin_name}

  git clone --branch $version --depth 1 --single-branch https://github.com/${repo}.git $plugin_dir
  rm -rf $plugin_dir/.git

  if $(y ".[$i] | has(\"pip_packages\")")
  then
    pip install --install-option="--prefix=$INSTALL_DIR" $(y ".[$i].pip_packages | join(\" \")")
  fi
done
