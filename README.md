Learning BOSH
=============

The full title of this project should be "Learning BOSH by building our own Jenkins BOSH Release". Part of the scripts are taken from the [Cloud Foundry Community Jenkins BOSH Release](https://github.com/cloudfoundry-community/jenkins-boshrelease).

Basic Concepts of BOSH
----------------------

### What is a Stemcell?

A *Stemcell* is a OS image wrapped with IaaS specific packaging. Amongst other tools, it always contains a [BOSH Agent](http://bosh.io/docs/bosh-components.html#agent) (like a Chef client) running on the VM to which the stemcell is deployed to and listens for instructions from the BOSH Director.

Stemcells do **not** contain

* any specific information concerning the software that is later on running on them
* any credentials / sensitive information that would make them unable to be shared with other BOSH users

A list of [all stemcells can be found here](https://bosh.io/stemcells)

### What is a Release?

A release is a **versioned** collection of

* configuration properties
* configuration templates
* start up scripts
* source code
* binary artifacts
* ...

to build and deploy software in a reproducible way.

Fundamental elements of a release:

* *Jobs* describes a chunk of work that a release performs
* *Packages* provide source code and dependencies to jobs
* *Source* provides packages the non-binary files they need
* *Blobs* provides packages the binary files they need

A list of [all releases can be found here](https://bosh.io/releases)

### What is a Deployment?

A [Deployment](http://bosh.io/docs/deployment.html) is

* a collection of VMs
* built from a [Stemcell](http://bosh.io/docs/stemcell.html)
* with [Releases](http://bosh.io/docs/release.html) deployed onto them

Description of the deployment process:

1. describe which operating system image to use (the stemcell)
1. describe which software needs to be deployed on the VMs created with these images
1. describe how to keep track of persisted data (e.g. during an update process)
1. describe how to deploy images to an IaaS

BOSH builds upon previously introduced primitives (stemcells and releases) by providing a way to state an explicit combination of stemcells, releases, and operator-specified properties in a human readable file. This file is called a *deployment manifest*.

Deployment manifests are uploaded to the BOSH [Director](http://bosh.io/docs/bosh-components.html#director). The Director allocates resources and stores them. These resources form a Deployment. A deployment consists of allocated VMs and persistent storage. As deployment manifests change, VMs are updated and persistent disks are re-attached to the newer VMs.

The deployment manifest describes the deployment in an IaaS-agnostic way, which means it abstracts the differences between different IaaSes.

Preperational Tasks
-------------------

### Install BOSH-Lite

When connecting to the BOSH-Lite instance provided by the *Learning BOSH* tutorial, the credentials will be `admin/admin`

    $ vagrant init cloudfoundry/bosh-lite
    $ vagrant up --provider=virtualbox
    Bringing machine 'default' up with 'virtualbox' provider...

### Install BOSH CLI

    $ gem install bosh_cli
    $ bosh target 192.168.50.4

Create a Release
----------------

### Directory Structure of a Release

    .
    ├── blobs                                  # (temporary) source directory for files and binaries required by the release (second lookup)
    ├── src                                    # (temporary) source directory for files and binaries required by the release (first lookup)
    ├── config
    │   └── blobs.yml
    ├── jobs                                   # contains a job for each application / service that is installed in the VM
    │   └── jenkins_master                     # sub directory for the job installing a Jenkins master
    │       ├── monit                          # monit script that configures how to watch the service(s)
    │       ├── spec                           # configuration file for the job
    │       └── templates                      # control scripts that can be written as `.erb` templates
    │           ├── helpers                    # helper scripts for the control scripts
    │           │   ├── ctl_setup.sh
    │           │   └── ctl_utils.sh
    │           └── bin
    │               └── jenkins_master_ctl     # control script for the Jenkins master service
    ├── packages                               # packages contain information about how to generate the binaries for the job
    │   └── jenkins
    │       ├── packaging
    │       ├── pre_packaging                  # usage is NOT recommended
    │       └── spec                           # the spec file states: the package name, the package’s dependencies,
    │                                          #   the location where BOSH can find the binaries and other files that the package needs at compile time
    └── src

### Create Release Directory

    bosh init release <release_name>

### Create a Job

    bosh generate job <job_name>

### Create a Control Script

Add a file to `jobs/<job_name>/templates/bin`

### Make Dependency Graph

(TODO) The tutorial now explains how to [make a dependency graph](http://bosh.io/docs/create-release.html#graph), but does not explain how to actually add any file or configuration that contains this graph.

### Create Package Skeletons

Here it says, we have to make packages starting "from the bottom of the dependency graph" - which means we "only" need the dependency graph made in the previous section in order to bring the packages into the right order here.

    bosh generate package <package_name>

The tutorial states that using the `pre_packaging` file is not recommended.

To maximize portability of your release across different versions of stemcells, never depend on the presence of libraries or other software on stemcells.

### Download Required Files and Binaries

The files given in the `files` block within the `spec` of your package need to be stored into the `blob/src` directory of your release.


Useful Tips & Tricks
====================

Directory and Folder Structure
------------------------------

### `/var/vcap`

The directory `/var/vcap` is created on the job VMs and contains

* jobs within `/var/vcap/jobs`
* packages within `/var/vcap/packages`
* src within `/var/vcap/src`
* blobs within `/var/vcap/blobs`


Helper Scripts
--------------

There is a bunch of helper scripts in the `helpers` directory.

### `download.rb`

The `download.rb` scripts downloads all (binary) dependencies required for the release and puts them in the `src` directory.

Usage: `ruby helpers/download.rb` from within the repository root.


Mac Helpers
-----------

### md5sum

Install `md5sum` on the Mac with `brew install md5sha1sum`


Further Resources
=================

* [BOSH Website](http://bosh.io)
* [BOSH Terminology](http://bosh.io/docs/terminology.html)
* [Learning BOSH Tutorial](http://mariash.github.io/learn-bosh)
* [Advanced Troubleshooting with the BOSH CLI](https://docs.pivotal.io/pivotalcf/customizing/trouble-advanced.html)
* [Cloud Foundry Community Jenkins BOSH Release](https://github.com/cloudfoundry-community/jenkins-boshrelease)
