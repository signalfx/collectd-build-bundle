collectd.tar.gz: make-bundle.sh VERSION collect-libs.sh Dockerfile configure plugins.yaml install-plugins.sh $(shell find templates -type f)
	bash ./make-bundle.sh

packaging/ubuntu/collectd.deb: packaging/ubuntu/control packaging/ubuntu/Dockerfile packaging/ubuntu/make-package packaging/ubuntu/collectd.upstart.conf collectd.tar.gz
	bash packaging/ubuntu/make-package
