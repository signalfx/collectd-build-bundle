# Ubuntu 14.04 Collectd Bundle

This will create a .deb package for the collectd bundle that will install at
`/opt/collectd`.  You can create the deb package by running `make
packaging/ubuntu/collectd.deb` from the root dir of this repo.  You can also
[download a release of
it](https://github.com/signalfx/collectd-build-bundle/releases) in lieu of
building.

To install the package, run `sudo dpkg -i collectd.deb`. After installing, you
should run the `/opt/collectd/configure` script (see main README for all the
options to it) to install collectd configuration.  The only option that you
need to provide to `configure` is the `ACCESS_TOKEN` envvar:

```sh
$ ACCESS_TOKEN=abcdefg sudo -E /opt/collectd/configure
```

This will put a basic configuration set in `/etc/collectd.conf` and
`/etc/collectd/managed_config/` that will get you started.  To add more
configuration, just add `*.conf` files to `/etc/collectd/managed_config`.

Then you can start with agent with `sudo service collectd start`.

The deb package includes an Upstart init script, so as long as you have
successfully run the `configure` script, the agent should run automatically on
startup.


## Custom Collectd Plugins
Since this installs collectd and its dependencies in `/opt/collectd`, if you
want to add extra plugins after installation, you should put any extra Collectd
`.so` plugins in `/opt/collectd/usr/lib/collectd` and any extra Python plugins
in `/opt/collectd/usr/share/collectd` and Python dependencies to
`/opt/collectd/usr/local/lib/python2.7/dist-packages`.  Or better yet, extend
this build to include those.

This bundle already comes with most of our supported plugins, both C and
Python, so check what is already installed first.  Just make sure you use the
correct paths in your collectd config files for those plugins.
