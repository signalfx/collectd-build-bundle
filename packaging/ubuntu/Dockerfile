FROM ubuntu:14.04

RUN mkdir -p /collectd/DEBIAN /collectd/opt
COPY collectd.tar.gz /
RUN tar -xf /collectd.tar.gz -C collectd/opt
COPY control /collectd/DEBIAN/control
COPY collectd.upstart.conf /collectd/etc/init/collectd.conf
RUN dpkg-deb --build /collectd
