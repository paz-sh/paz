Paz
===
_Continuous deployment production environments, built on Docker, CoreOS, etcd and fleet._

Paz is an in-house service platform with a PaaS-like workflow.

![Screenshot](https://raw.githubusercontent.com/yldio/paz/206283f9f2b0c21bc4abf3a1f3926bd5e0f0a962/docs/images/Screen%20Shot%202014-11-22%20at%2016.39.07.png)

## What is Paz?

Paz is...
* Like your own private PaaS that you can host anywhere
* Free
* Open-source
* Simple
* A web front-end to CoreOS' Fleet with a PaaS-like workflow
* Like a clustered/multi-host Dokku
* Alpha software
* Written in Node.js

Paz is not...
* A hosted service
* A complete, enterprise-ready orchestration solution

## Features
* Beautiful web UI
* Run anywhere (Vagrant, public cloud or bare metal)
* No special code required in your services
  - i.e. it will run any containerised application unmodified
* Built for Continuous Deployment
* Zero-downtime deployments
* Service discovery
* Same workflow from dev to production
* Easy environments

## Components
* Web front-end - A beautiful UI for configuring and monitoring your services.
* Service directory - A catalog of your services and their configuration.
* Scheduler - Deploys services onto the platform.
* Orchestrator - REST API used by the web front-end; presents a unified subset of functionality from Scheduler, Service Directory, Fleet and Etcd.
* Centralised monitoring and logging.

### Service Directory
This is a database of all your services and their configuration (e.g. environment variables, data volumes, port mappings and the number of instances to launch). Ultimately this information will be reduced to a set of systemd unit files (by the scheduler) to be submitted to Fleet for running on the cluster.
The service directory is a Node.js API backed by a LevelDB database.

### Scheduler
This service receives HTTP POST commands to deploy services that are defined in the service directory. Using the service data from the directory it will render unit files and run them on the CoreOS cluster using Fleet. A history of deployments and associated config is also available from the scheduler.

For each service the scheduler will deploy a container for the service and an announce sidekick container.

The scheduler is a Node.js API backed by a LevelDB database and uses Fleet to launch services.

### Orchestrator
This is a service that ties all of the other services together, providing a single access-point for the front-end to interface with. Also offers a web socket endpoint for realtime updates to the web front-end.

The orchestrator is a Node.js API server that communicates with Etcd, Fleet, the scheduler and service directory.

### Web Front-End
A beautiful and easy-to-use web UI for managing your services and observing the health of your cluster. Built in Ember.js.

### HAProxy
Paz uses Confd to dynamically configure HAProxy based on service availability information declared in Etcd. HAProxy is configured to route external and internal requests to the correct host for the desired service.

### Monitoring and Logging
Currently cAdvisor is used for monitoring, and there is not yet any centralised logging. Monitoring and logging are high-priority features on the roadmap.

## Installation

Paz's Docker repositories are hosted at Quay.io, but they are public so you don't need any credentials.

You will need to install `fleetctl` and `etcdctl`. On OS/X you can install both with brew:
```
$ brew install etcdctl fleetctl
```

### Vagrant

Clone this repository and run the following from the root directory of this repository:

```
$ ./scripts/install-vagrant.sh
```

This will bring up a three-node CoreOS Vagrant cluster and install Paz on it. Note that it may take 10 minutes or more to complete.

For extra debug output, run with `DEBUG=1` environment variable set.

If you already have a Vagrant cluster running and want to reinstall the units, use:

```
$./script/reinstall-units-vagrant.sh
```

To interact with the units in the cluster via Fleet, just specify the URL to Etcd on one of your hosts as a parameter to Fleet. e.g.:

```
$ fleetctl -strict-host-key-checking=false -endpoint=http://172.17.8.101:4001 list-units
```

You can also SSH into one of the VMs and run `fleetctl` from there:

```
$ cd coreos-vagrant
$ vagrant ssh core-01
```

...however bear in mind that Fleet needs to SSH into the other VMs in order to perform operations that involve calling down to systemd (e.g. `journal`), and for this you need to have SSHd into the VM running the unit in question. For this reason you may find it simpler (albeit more verbose) to run `fleetctl` from outside the CoreOS VMs.

### DigitalOcean

Paz has been tested on Digital Ocean but there isn't currently an install script for it. It shouldn't take much, just be sure to edit the PAZ_DNSIMPLE_* values in `digitalocean/user-data`. Stay tuned...

## Tests

There is an integration test that brings up a CoreOS Vagrant cluster, installs Paz and then runs a contrived service on it and verifies that it works:

```
$ cd test
$ ./integration.sh
```

Each paz repository (service directory, orchestrator, scheduler) has tests that run on paz-ci.yld.io (in StriderCD), triggered by a Github webhook.

## Paz Repositories

The various components of Paz are spread across several repositories:
* [Orchestrator](https://github.com/yldio/paz-orchestrator)
* [Service Directory](https://github.com/yldio/paz-service-directory)
* [Scheduler](https://github.com/yldio/paz-scheduler)
* [Web](https://github.com/yldio/paz-web)
* [HAProxy](https://github.com/yldio/paz-haproxy)
