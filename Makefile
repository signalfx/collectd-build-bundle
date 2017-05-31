
collectd.tar.gz: VERSION collect-libs.sh Dockerfile run.sh plugins.yaml install-plugins.sh $(shell find templates -type f)
	docker pull quay.io/signalfx/collectd-build-bundle || true
	docker build -t quay.io/signalfx/collectd-build-bundle .
	docker run --rm quay.io/signalfx/collectd-build-bundle cat /opt/collectd.tar.gz > collectd.tar.gz
