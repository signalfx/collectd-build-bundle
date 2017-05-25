# Collectd Self-Contained Bundle

This is an attempt at bundling collectd in a completely relocatable and
self-contained manner.  This was initially motivated by the Cloud Foundry
integration, but might find application elsewhere.  Cloud Foundry really likes
having self-contained apps, and dislikes using system paths to install things.

## Goals
 - Installable to any path in the host filesystem without additional config

 - Runnable as non-root

 - Runnable in both containerized and traditional Linux environments

 - Support all Linux distros

 - Support all of the existing plugins

 - Not require any modifications to the collectd Makefile (configure options
     are OK)

 - Be relatively lightweight (ideally under 100MB uncompressed)

## Approach

The basic technique here is to try and do what container engines do to create
portable apps, except without using kernel namespaces.  One of the goals is to
be able to run as non-root and within already existing containers so we can't
just package it up with something like _runc_, since creating containers on
Linux effectively requires root (technically kernels with user namespace support
can support non-root containerization but it requires pre-configured root-user
configuration to map the users).

We could try and recompile collectd to be statically compiled, but this is
complicated to get right, and would ultimately result in a larger size since
there are a lot of plugin modules that share dependencies (and statically
compiling the plugins into a single collectd binary would require modifying the
collectd code to not use `dlopen` on plugin files).

Instead of static compilation, the `LD_LIBRARY_PATH` envvar that the Linux
dynamic loader uses is perfect for the job.  We can bundle all of the libraries
that collectd and its plugins depend on into a single dir and point the loader
to it.  The `collect-libs.sh` script is responsible for determining the
libraries to pull into the repo from the build image.

Finally, the dynamic linker/loader used to run collectd must be swapped out for
the one used on the build machine for maximum portability.  This is essentially
what containers do when they provide their own `/lib64/ld-linux-x86_64.so.2`
file in the container image, but in our case, we have to patch the ELF
executable for collectd to tell it to use that loader.  The
[patchelf](https://nixos.org/patchelf.html) tool is used for that.  This seems
to be relatively safe.

This attempts to reuse the [collectd Install
script](https://github.com/signalfx/signalfx-collectd-installer) to some
extent, as well as the config templates that it pulls from the [integrations
repo](https://github.com/signalfx/integrations).  These are not currently
versioned, but they probably should be at some point to avoid breaking this if
they are updated significantly.

### Python
Python is a bit more involved because it has a lot of `.py` files in its
standard library that must get bundled in and configured for use.  This isn't
too hard and just involves some copying and manipulation of
`PYTHONPATH`/`PYTHONHOME`.

### Java
Currently this doesn't support Java plugins.  This should be possible to add
at some point.

## Installation and Running
`make collectd.tar.gz` will create a bundle from the current repo.  Once you
have a bundle, you should extract its contents to whatever directory on
whatever Linux distro you want.  It contains a single dir called `collectd`
which has everything needed.  Collectd is run with the `run.sh` script in that
dir.  You **cannot** execute the `sbin/collectd` binary directly.  The `run.sh`
script expects at a bare minimum the SignalFx api token provided as an envvar
called `API_TOKEN`.  

```sh
$ API_TOKEN=abcdefg collectd/run.sh
```

This will run Collectd with the collectdmon tool that handles automatically
restarting collectd should it crash.


## Configuration
To add plugins, just add them to the `collectd/plugins` directory once the
bundle is extracted.  If a plugin requires pip dependencies, install them into
the `collectd/lib/python2.7/site-packages` dir.

Plugin configuration is handled like vanilla collectd -- simply add files to
the `collectd/etc/managed_config` dir.

## Notes
This has been tested on Ubuntu 14.04 and Centos 7 but needs a lot more testing
as well as an automated test suite.

## TODO
 - Automated testing across multiple Linux distros
 - Vendor all of the Python plugins with this (similar to what's in the
     collectd-build-ubuntu repo in the `plugins` dir)
 - Add Java support
