FROM ubuntu:trusty as base

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update &&\
    apt-get install -y \
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

ENV COLLECTD_VERSION=5.8.0-sfx0

WORKDIR /usr/src/collectd
RUN wget -O /tmp/collectd.tar.gz https://github.com/signalfx/collectd/archive/collectd-${COLLECTD_VERSION}.tar.gz &&\
    tar -zxf /tmp/collectd.tar.gz -C /tmp &&\
    mv /tmp/collectd-*/* /usr/src/collectd

RUN ./build.sh &&\
    ./configure \
        --prefix /opt/collectd/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --enable-all-plugins \
        --disable-ascent \
        --disable-rrdcached \
        --disable-lvm \
        --disable-turbostat \
        --disable-write_kafka \
        --disable-cpusleep \
        --disable-curl_xml \
        --disable-dpdkstat \
        --disable-dpdkevents \
        --disable-grpc \
        --disable-gps \
        --disable-ipmi \
        --disable-lua \
        --disable-mqtt \
        --disable-intel_pmu \
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
        --disable-redis \
        --disable-write_redis \
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

RUN make -j6 &&\
    make install &&\
    mkdir -p /opt/collectd/etc/collectd/filtering_config &&\
    mkdir -p /opt/collectd/etc/collectd/managed_config

# jq and netcat are used to get the AWS unique id out from the AWS metadata
# endpoint.
RUN wget -O /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 &&\
    chmod +x /usr/bin/jq &&\
    pip install yq


COPY install-plugins.sh plugins.yaml /tmp/plugins/
# Install other python plugins
RUN bash /tmp/plugins/install-plugins.sh

RUN find /usr/share/collectd /usr/lib/python2.7/ -name "*.pyc" -print0 | xargs --null rm
RUN cp -R --parents -a /usr/share/collectd /usr/lib/python2.7 /usr/local/lib/python2.7 /opt/collectd

RUN wget -O /opt/collectd/usr/bin/gomplate https://github.com/hairyhenderson/gomplate/releases/download/v1.7.0/gomplate_linux-amd64 &&\
    chmod +x /opt/collectd/usr/bin/gomplate

# Get filtering config filtering config
RUN wget -O /opt/collectd/etc/collectd/filtering_config/filtering.conf \
      https://raw.githubusercontent.com/signalfx/integrations/master/collectd-match_regex/filtering.conf
RUN wget -O /opt/collectd/usr/bin/get_aws_unique_id https://raw.githubusercontent.com/signalfx/signalfx-collectd-installer/master/get_aws_unique_id &&\
    chmod +x /opt/collectd/usr/bin/get_aws_unique_id

COPY VERSION /opt/collectd/VERSION

COPY collect-libs.sh /opt/
RUN bash /opt/collect-libs.sh /opt/collectd /opt/collectd

# Install JRE along with signalfx types.db file needed for JMX config
RUN cp -R --parents -a -f /etc/java-7-openjdk /usr/lib/jvm/ /opt/collectd &&\
    mkdir -p /opt/collectd/usr/share/collectd/java &&\
    wget -O /opt/collectd/usr/share/collectd/java/signalfx_types_db \
      https://raw.githubusercontent.com/signalfx/integrations/master/collectd-java/signalfx_types_db

# Clean up unnecessary man files
RUN rm -rf /opt/collectd/usr/share/man /opt/collectd/usr/lib/jvm/java-7-openjdk-amd64/jre/man/

RUN wget -O /opt/collectd/usr/bin/collectd-install https://dl.signalfx.com/collectd-install &&\
    chmod +x /opt/collectd/usr/bin/collectd-install

# Ensure versions are consistent and bundle everything up
RUN bash -c 'ver=$(cat /opt/collectd/VERSION); \
            [[ ${ver%-*} == $COLLECTD_VERSION ]] || \
            (echo "VERSION MISMATCH ($ver / $COLLECTD_VERSION)" >&2 && exit 1)'

FROM scratch as final-image

COPY --from=base /etc/ssl/certs/ca-certificates.crt /collectd/etc/ssl/certs/ca-certificates.crt
COPY --from=base /opt/collectd/ /collectd
COPY --from=base /bin/ /collectd/bin
COPY --from=base /lib64/ /collectd/lib64
COPY --from=base /lib/ /collectd/lib
COPY templates /collectd/templates
COPY configure /collectd/configure
