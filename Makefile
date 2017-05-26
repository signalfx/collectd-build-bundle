
collectd.tar.gz: collect-libs.sh Dockerfile run.sh $(shell find templates -type f)
	#docker pull quay.io/signalfx/collectd-build-bundle
	docker build -t quay.io/signalfx/collectd-build-bundle .
	docker run --rm quay.io/signalfx/collectd-build-bundle cat /opt/collectd.tar.gz > collectd.tar.gz
