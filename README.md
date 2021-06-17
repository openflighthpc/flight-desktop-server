# Flight Desktop RestAPI

A REST API to manage interactive GUI desktop sessions via the `flight-desktop`
tool.

## Overview

Flight Desktop RestAPI is a REST API that in conjunction with [Flight
Desktop Webapp](https://github.com/openflighthpc/flight-desktop-webapp) and
[Flight Desktop](https://github.com/openflighthpc/flight-desktop) provides
browser access to interactive GUI desktop sessions within HPC environments.

## Installation

### From source

Flight Desktop RestAPI requires a recent version of Ruby and `bundler`.

The following will install from source using `git`:

```
git clone https://github.com/alces-flight/flight-desktop-restapi.git
cd flight-desktop-restapi
bin/bundle install --without development test pry --path vendor
```

### Installing with Flight Runway

Flight Runway provides a Ruby environment and command-line helpers for running
openflightHPC tools.  Flight Desktop RestAPI integrates with Flight Runway to
provide an easy way for multiple users of an HPC environment to use the tool.

To install Flight Runway, see the [Flight Runway installation
docs](https://github.com/openflighthpc/flight-runway#installation).

These instructions assume that `flight-runway` has been installed from
the openflightHPC yum repository and that either [system-wide
integration](https://github.com/openflighthpc/flight-runway#system-wide-integration) has been enabled or the
[`flight-starter`](https://github.com/openflighthpc/flight-starter) tool has been
installed and the environment activated with the `flight start` command.

 * Enable the Alces Flight RPM repository:

    ```
    yum install https://alces-flight.s3-eu-west-1.amazonaws.com/repos/alces-flight/x86_64/alces-flight-release-1-1.noarch.rpm
    ```

 * Rebuild your `yum` cache:

    ```
    yum makecache
    ```
    
 * Install the `flight-desktop-restapi` RPM:

    ```
    [root@myhost ~]# yum install flight-desktop-restapi
    ```

 * Install a websockify server such as `python-websockify`:

    ```
    [root@myhost ~]# yum install python-websockify
    ```

 * Optionally, install screenshotting programs.  If these are not installed
   the session previews will not work.

    ```
    [root@myhost ~]# yum install netpbm-progs xorg-x11-apps
    ```

 * Enable HTTPs support

    Flight Desktop RestAPI is designed to operate over HTTPs connections.  You
    can enable HTTPs with self-signed certificates by running the commands
    below.  You will be asked to enter a passphrase and to answer some
    questions about your organization.

    ```
    [root@myhost ~]# flight www enable-https
    ```


## Configuration

Making changes to the default configuration is optional and can be achieved by editing the [flight-desktop-restapi.yaml](etc/flight-desktop-restapi.yaml) file.

This version has been tested with:

`flight-desktop` version `1.5.0`

## Operation

### When installed with Flight Runway

The server can be started by running the following command:

```
[root@myhost ~]# flight service start desktop-restapi
```

The server can be stopped by running the following command:

```
[root@myhost ~]# flight service stop desktop-restapi
```

### When installed from source

The server can be started by running the following from the root directory of
the source checkout.

```
bin/puma -p <port> -e production -d \
          --redirect-append \
          --redirect-stdout <stdout-log-file-path> \
          --redirect-stderr <stderr-log-file-path> \
          --pidfile         <pid-file-path>
```

You will need to determine appropriate paths for the log files and pid file.

The server can be stopped by running the following from the root of the source
checkout.

```
bin/pumactl stop
```

# Contributing

Fork the project. Make your feature addition or bug fix. Send a pull
request. Bonus points for topic branches.

Read [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

# Copyright and License

Eclipse Public License 2.0, see LICENSE.txt for details.

Copyright (C) 2020-present Alces Flight Ltd.

This program and the accompanying materials are made available under the terms of the Eclipse Public License 2.0 which is available at https://www.eclipse.org/legal/epl-2.0, or alternative license terms made available by Alces Flight Ltd - please direct inquiries about licensing to licensing@alces-flight.com.

FlightDesktopRestAPI is distributed in the hope that it will be useful, but WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more details.
