trafficserver-add_cache_lookup_status_header-plugin-rpm
=======================================================

A Dockerfile to build [hnakamur/trafficserver-add_cache_lookup_status_header-plugin](https://github.com/hnakamur/trafficserver-add_cache_lookup_status_header-plugin) RPM for [Apache Traffic Server](http://trafficserver.apache.org/) rpm for CentOS 6 and 7 using [Mock](https://fedoraproject.org/wiki/Mock) or [fedora copr](https://copr.fedoraproject.org/).

This plugin is built for Apache Traffic Server rpm hosted on copr project: https://copr.fedorainfracloud.org/coprs/hnakamur/apache-traffic-server-6/

## Setup

1. Copy `.envrc.example` to `.envrc`.
2. Go https://copr.fedoraproject.org/api/ and login in and see the values to set.
3. Then modify `.envrc`

## Usage: How to build rpms

### Build docker image

To build the docker image to build the srpm or rpm files, run the following command.

```
./docker_wrapper.sh build
```

### Build rpms interactively

To try building rpm files with mock, run the following command.

```
source .envrc
./docker_wrapper.sh bash
```

Then in the docker container, run the fowllowing command to build rpms with mock.

```
./build.sh mock
```

If the build finish successfully, run the following command to upload the srpm file to copr.

```
./build.sh copr
```

### Build srpm and upload it to copr

If you are sure your rpms will be built successfully,
skip the above section "Build rpms interactively" and run the following command
to run the docker image to build the srpm file and upload it to copr.

```
source .envrc
./docker_wrapper.sh run
```

## NOTE: Using direnv

I recommend you to use [direnv/direnv](https://github.com/direnv/direnv)
instead of running `source .envrc` yourself.

## Modify this scripts to build other rpms

1. Edit `imagename` in `docker_wrapper.sh`
2. See NOTE comments in `script/build.sh` and edit variables and commands
3. Put the spec file in the `SPECS` directory
4. Put the source files in the `SOURCES` directory

## License
Apache License 2.0
