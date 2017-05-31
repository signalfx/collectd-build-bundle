#!/bin/bash

set -eo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PID_FILE=${PID_FILE:-$SCRIPT_DIR/pid}

append_dim_qs() {
  local extra_dims=$1
  local dim_name=$2
  local dim_value=$3

  dim_qp="sfxdim_$dim_name=$dim_value"

  if [ -z $extra_dims ]
  then
    echo "?${dim_qp}"
  else
    # Escape & so sed doesn't see it
    echo "${extra_dims}&${dim_qp}"
  fi
}

dims_to_add=$(printenv | grep '^SFX_DIM' || true)
for dim in $dims_to_add
do
  name=$(cut -d'=' -f 1 <<< $dim | sed -e 's/SFX_DIM_//')
  value=$(cut -d'=' -f 2 <<< $dim)
  EXTRA_DIMS=$(append_dim_qs "$EXTRA_DIMS" $name $value)
  echo "Adding extra dimension $name=$value"
done

# Wait and export these until the very end
LD_LIBRARY_PATH=$SCRIPT_DIR/lib:$SCRIPT_DIR/lib/x86_64-linux-gnu
PYTHONHOME=$SCRIPT_DIR/lib/python2.7
PYTHONPATH=$SCRIPT_DIR/lib/python2.7:$SCRIPT_DIR/lib/python2.7/plat-x86_64-linux-gnu:$SCRIPT_DIR/lib/python2.7/lib-tk:$SCRIPT_DIR/lib/python2.7/lib-old:$SCRIPT_DIR/lib/python2.7/lib-dynload:$SCRIPT_DIR/lib/python2.7/dist-packages:$SCRIPT_DIR/lib/python2.7/site-packages

export PATH=$SCRIPT_DIR/bin:$PATH

echo 'Patching binaries to use custom loader'
for bin in $SCRIPT_DIR/sbin/collectd{,mon} $SCRIPT_DIR/bin/{nc,sed}
do
  patchelf --set-interpreter $SCRIPT_DIR/lib64/ld-linux-x86-64.so.2 $bin
done

SFX_INGEST_URL=${SFX_INGEST_URL:-https://ingest.signalfx.com}
[[ -z $ACCESS_TOKEN ]] && echo 'ACCESS_TOKEN envvar must be given!' >&2 && exit 1

get_aws_ident() {
  # Use netcat with sed magic instead of curl since libcurl has issues
  # netcat, jq, and sed are bundled
  (export LD_LIBRARY_PATH=$LD_LIBRARY_PATH; \
    echo -e "GET /latest/dynamic/instance-identity/document HTTP/1.1\r\n\r\n" | \
    nc -q1 -w1 169.254.169.254 80 || true | \
    sed '1,/^\r$/d' | \
    jq -r '.instanceId + "_" + .accountId + "_" + .region' || true)
}
AWS_UNIQUE_ID=$(get_aws_ident)

[ -n "$AWS_UNIQUE_ID" ] && EXTRA_DIMS=$(append_dim_qs "$EXTRA_DIMS" AWSUniqueId $AWS_UNIQUE_ID)

COLLECTD_CONF=${SCRIPT_DIR}/etc/collectd.conf

mkdir -p $SCRIPT_DIR/log

TYPES_DB=${SCRIPT_DIR}/share/collectd/types.db \
PLUGIN_DIR=$SCRIPT_DIR/lib/collectd \
BASE_DIR=$SCRIPT_DIR \
HOSTNAME=$HOSTNAME \
ACCESS_TOKEN=$ACCESS_TOKEN \
INGEST_HOST=$SFX_INGEST_URL \
BASE_DIR=$SCRIPT_DIR \
EXTRA_DIMS=$EXTRA_DIMS \
NO_SYSTEM_METRICS=$NO_SYSTEM_METRICS \
gomplate --input-dir="${SCRIPT_DIR}/templates/" --output-dir="$SCRIPT_DIR/etc"

echo "About to start collectd bundle version $(cat $SCRIPT_DIR/VERSION)"

export LD_LIBRARY_PATH PYTHONPATH PYTHONHOME

exec $SCRIPT_DIR/sbin/collectdmon -c $SCRIPT_DIR/sbin/collectd -P $PID_FILE -- -C $SCRIPT_DIR/etc/collectd.conf
