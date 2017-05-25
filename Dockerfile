FROM ubuntu:trusty

RUN apt-get update &&\
    apt-get install -y -q \
        build-essential \
        git \
        curl \
        libtool \
        automake \
        autoconf \
        bison \
        flex \
        autotools-dev \
        libltdl-dev \
        pkg-config \
        iptables-dev \
        javahelper \
        libcurl4-gnutls-dev \
        libdbi0-dev \
        libesmtp-dev \
        libganglia1-dev \
        libgcrypt11-dev \
        libglib2.0-dev \
        liblvm2-dev \
        libmemcached-dev \
        libmicrohttpd-dev \
        libmodbus-dev \
        libmnl-dev \
        libmysqlclient-dev \
        libnotify-dev \
        libopenipmi-dev \
        liboping-dev \
        libow-dev \
        libpcap0.8-dev \
        libperl-dev \
        libpq-dev \
        librabbitmq-dev \
        librrd-dev \
        libsensors4-dev \
        libsnmp-dev \
        libsnmp-dev>=5.4.2.1~dfsg-4~ \
        libudev-dev \
        libvarnishapi-dev \
        libvirt-dev>=0.4.0-6 \
        libxml2-dev \
        libyajl-dev \
        linux-libc-dev \
        default-jdk \
        protobuf-c-compiler \
        python-dev \
        python-pip \
        libprotobuf-c0-dev \
        libtokyocabinet-dev \
        libtokyotyrant-dev \
        libupsclient-dev \
        libi2c-dev \
        librdkafka-dev \
        libatasmart-dev \
        libldap2-dev \
        wget

ENV COLLECTD_VERSION=5.7.0

WORKDIR /src/collectd
RUN wget -O /tmp/collectd.tar.gz https://github.com/signalfx/collectd/archive/collectd-${COLLECTD_VERSION}-sfx0.tar.gz &&\
    tar -zxf /tmp/collectd.tar.gz -C /tmp &&\
    mv /tmp/collectd-*/* /src/collectd

ENV INSTALL_DIR=/opt/collectd
RUN ./build.sh &&\
    ./configure \
        --prefix $INSTALL_DIR \
        --enable-all-plugins \
        --disable-ascent \
        --disable-java \
        --disable-rrdcached \
        --disable-lvm \
        --disable-turbostat \
        --disable-write_kafka \
        --disable-cpusleep \
        --disable-curl_xml \
        --disable-dpdkstat \
        --disable-grpc \
        --disable-gps \
        --disable-ipmi \
        --disable-lua \
        --disable-mqtt \
        --disable-intel_rdt \
        --disable-static \
        --disable-write_riemann \
        --disable-zone \
        --disable-apple_sensors \
        --disable-lpar \
        --disable-tape \
        --disable-aquaero \
        --disable-mic \
        --disable-netapp \
        --disable-onewire \
        --disable-oracle \
        --disable-pf \
        --disable-redis --disable-write_redis \
        --disable-routeros \
        --disable-rrdtool \
        --disable-sigrok \
        --disable-write_mongodb \
        --disable-xmms \
        --disable-zfs-arc \
        --with-perl-bindings="INSTALLDIRS=vendor INSTALL_BASE=" \
        --without-libstatgrab \
        --without-included-ltdl \
        --without-libgrpc++ \
        --without-libgps \
        --without-liblua \
        --without-libriemann \
        --without-libsigrok

RUN make &&\
    make install &&\
    mkdir -p /opt/collectd/etc/filtering_config &&\
    mkdir -p /opt/collectd/etc/managed_config

COPY collect-libs.sh /opt/
RUN bash /opt/collect-libs.sh $INSTALL_DIR &&\
    cp -r /usr/lib/python2.7 /opt/collectd/lib/python2.7

# jq and curl are used to get the AWS unique id out from the AWS metadata endpoint
# The curl binary needs a different libcurl so so copy it in too
RUN wget -O /opt/collectd/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 &&\
    chmod +x /opt/collectd/bin/jq &&\
    cp /usr/bin/curl /opt/collectd/bin &&\
    cp /usr/lib/x86_64-linux-gnu/libcurl.so.4 /opt/collectd/lib/x86_64-linux-gnu/

# Get the patchelf tool in the bundle to change interpreters at runtime
RUN wget -O /tmp/patchelf.tar.gz https://nixos.org/releases/patchelf/patchelf-0.9/patchelf-0.9.tar.gz &&\
    cd /tmp &&\
    tar -xf patchelf.tar.gz &&\
    cd patchelf-* &&\
    ./configure && make &&\
    cp src/patchelf /opt/collectd/bin/ &&\
    mkdir -p /opt/collectd/lib64 &&\
    cp /lib64/ld-linux-x86-64.so.2 /opt/collectd/lib64/

# Install SignalFx plugin
RUN mkdir -p /opt/collectd/plugins &&\
    git clone https://github.com/signalfx/signalfx-collectd-plugin.git /opt/collectd/plugins/signalfx &&\
    pip install --install-option="--prefix=$INSTALL_DIR" -r /opt/collectd/plugins/signalfx/requirements.txt

RUN git clone https://github.com/signalfx/signalfx-collectd-installer.git /src/installer &&\
    cd /src/installer &&\
    bash /src/installer/build.sh &&\
    mkdir -p /opt/collectd/templates &&\
    cp 10-aggregation-cpu.conf /opt/collectd/etc/managed_config &&\
    cp 10-signalfx.conf 10-write_http-plugin.conf *.tmpl /opt/collectd/templates/

RUN cp /etc/ssl/certs/ca-certificates.crt /opt/collectd/ca-certificates.crt

COPY run.sh /opt/collectd/run.sh

RUN chmod +x /opt/collectd/run.sh &&\
    tar -C /opt -zcf /opt/collectd.tar.gz collectd &&\
    echo "Bundle is $(du -h /opt/collectd.tar.gz | awk '{ print $1 }') compressed/$(du -sh /opt/collectd | awk '{ print $1 }') uncompressed"
