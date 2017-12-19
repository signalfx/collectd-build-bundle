#!/bin/bash

set -ex

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

output=${output:-collectd.tar.gz}
output_tar=$(basename $output .gz)

image=quay.io/signalfx/collectd-build-bundle

docker pull $image || true
docker build -t $image .

cid=$(docker create $image true)
trap "docker rm -f $cid; rm -f $output_tar" EXIT

docker export $cid | gzip -f - > $output
