
collectd.tar.gz: collect-libs.sh Dockerfile run.sh
	#docker pull quay.io/signalfuse/collectd-build-bundle
	docker build -t quay.io/signalfuse/collectd-build-bundle .
	docker run --rm quay.io/signalfuse/collectd-build-bundle cat /opt/collectd.tar.gz > collectd.tar.gz
