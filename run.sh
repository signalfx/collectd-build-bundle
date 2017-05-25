#!/bin/bash

set -ex

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Wait and export these until the very end
LD_LIBRARY_PATH=$SCRIPT_DIR/lib:$SCRIPT_DIR/lib/x86_64-linux-gnu
PYTHONHOME=$SCRIPT_DIR/lib/python2.7
PYTHONPATH=$SCRIPT_DIR/lib/python2.7:$SCRIPT_DIR/lib/python2.7/plat-x86_64-linux-gnu:$SCRIPT_DIR/lib/python2.7/lib-tk:$SCRIPT_DIR/lib/python2.7/lib-old:$SCRIPT_DIR/lib/python2.7/lib-dynload:$SCRIPT_DIR/lib/python2.7/dist-packages:$SCRIPT_DIR/lib/python2.7/site-packages

export PATH=$SCRIPT_DIR/bin:$PATH

echo 'Patching binaries to use custom loader'
for bin in $SCRIPT_DIR/sbin/collectd{,mon} $SCRIPT_DIR/bin/curl
do
  patchelf --set-interpreter $SCRIPT_DIR/lib64/ld-linux-x86-64.so.2 $bin
done

SFX_INGEST_URL=${SFX_INGEST_URL:-https://ingest.signalfx.com}
[[ -z $API_TOKEN ]] && echo 'API_TOKEN envvar must be given!' >&2 && exit 1

WRITE_QUEUE_CONFIG="WriteQueueLimitHigh 500000\\nWriteQueueLimitLow  400000\\nCollectInternalStats true"

if [[ -z $HOSTNAME ]]
then
  HOSTNAME_CONFIG="FQDNLookup   true"
else
  HOSTNAME_CONFIG="Hostname   \"$HOSTNAME\""
fi

run_curl() {
  # We can't export LD_LIBRARY_PATH to everything yet or else it breaks basic
  # shell commands, so do a one-off for curl to use our bundled version
  LD_LIBRARY_PATH=$LD_LIBRARY_PATH curl $@
}

AWS_UNIQUE_ID=$($(run_curl -s --connect-timeout 1 http://169.254.169.254/latest/dynamic/instance-identity/document) | jq -r '.instanceId + "_" + .accountId + "_" + .region' || true)

[ -n "$AWS_UNIQUE_ID" ] && EXTRA_DIMS="sfxdim_AWSUniqueId=$AWS_UNIQUE_ID"

COLLECTD_CONF=${SCRIPT_DIR}/etc/collectd.conf

mkdir -p $SCRIPT_DIR/log

# We are appending into specific lines in the files so ideally we would lock
# down the versions of the template config files or else pull them into this
# repo for better control
sed -e "s#%%%TYPESDB%%%#${SCRIPT_DIR}/share/collectd/types.db#" \
    -e "34aPluginDir \"$SCRIPT_DIR/lib/collectd\"" \
    -e "34aBaseDir \"$SCRIPT_DIR\"" \
    -e "s#%%%SOURCENAMEINFO%%%#${HOSTNAME_CONFIG}#" \
    -e "s#%%%WRITEQUEUECONFIG%%%#${WRITE_QUEUE_CONFIG}#" \
    -e "s#%%%COLLECTDMANAGEDCONFIG%%%#${SCRIPT_DIR}/etc/managed_config#" \
    -e "s#%%%COLLECTDFILTERINGCONFIG%%%#${SCRIPT_DIR}/etc/filtering_config#" \
    -e "s#%%%LOGTO%%%#\"${SCRIPT_DIR}/log/collectd.log\"#" \
    "${SCRIPT_DIR}/templates/collectd.conf.tmpl" | tee $COLLECTD_CONF

sed -e "s#%%%API_TOKEN%%%#${API_TOKEN}#g" \
    -e "s#%%%INGEST_HOST%%%#${SFX_INGEST_URL}#g" \
    -e "s#%%%EXTRA_DIMS%%%#${EXTRA_DIMS}#g" \
    -e "9aCACert \"${SCRIPT_DIR}/ca-certificates.crt\"" \
    "${SCRIPT_DIR}/templates/10-write_http-plugin.conf" | tee "$SCRIPT_DIR/etc/managed_config/10-write_http-plugin.conf"

sed -e "s#%%%API_TOKEN%%%#${API_TOKEN}#g" \
    -e "s#URL.*#URL \"${SFX_INGEST_URL}/v1/collectd${EXTRA_DIMS}\"#g" \
    -e "s#/opt/signalfx-collectd-plugin#$SCRIPT_DIR/plugins/signalfx#g" \
    -e "s#plugins/signalfx\"#plugins/signalfx/src\"#g" \
    "${SCRIPT_DIR}/templates/10-signalfx.conf" | tee "$SCRIPT_DIR/etc/managed_config/10-signalfx.conf"

export LD_LIBRARY_PATH PYTHONPATH PYTHONHOME

exec $SCRIPT_DIR/sbin/collectdmon -c $SCRIPT_DIR/sbin/collectd -P $SCRIPT_DIR/pid -- -C $SCRIPT_DIR/etc/collectd.conf
