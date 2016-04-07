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



Preparational Tasks
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
    ├── blobs                                  # source directory for files and binaries required by the release (second lookup)
    ├── src                                    # source directory for files and binaries required by the release (first lookup)
    ├── config
    │   ├── dev.yml                            # TODO find out what this file does
    │   ├── final.yml                          # configures the blobstore to be used for our release
    │   └── private.yml                        # configures paths and credentials for our blobstore
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

Within the jobs in our release, we can have two kinds of *dependencies*:

1. *compile-time dependencies* that define that one package needs another package before it can be build (e.g. a library or a compiler)
1. *runtime dependencies* that define that one job depends on another package at runtime

We have to find out the compile-time and runtime dependencies for our release. Those dependencies will then be configure within the `dependencies` array in our `package/PACKAGE_NAME/spec` files.

### Create Package Skeletons

Here it says, we have to make packages starting "from the bottom of the dependency graph".

    bosh generate package <package_name>

The tutorial states that using the `pre_packaging` file is not recommended.

To maximize portability of your release across different versions of stemcells, never depend on the presence of libraries or other software on stemcells.

### Download Required Files and Binaries

The files given in the `files` block within the `spec` of your package need to be stored into the `blobs` or `src` (`src` has precedence) directory of your release.

### Write Packaging Scripts

At compile time, BOSH takes the source files referenced in the package specs, and renders them into the executable binaries and scripts that your deployed jobs need.

Within `packages/PACKAGE_NAME/packaging` we have to write a shell scripts that do this job for us.

### Blobstores

The files of your release are likely to be put into version control. For larger binary files (e.g. the java `.tar` archive) this is not a good solution. Hence BOSH allows you to configure so called *Blobstores*. Here you have two choices:

* for development releases use local copies of blobs
* for final releases upload blobs to blobstores (e.g. Amazon S3) and direct BOSH to obtain blobs from there

You configure the blobstore in the `config` directory

* the `final.yml` names the blobstore and declares its type (e.g. `local`)
* the `private.yml` specifies the blobstore path along with credentials

So for local development, we use this `final.yml`

    ---
    blobstore:
      provider: local
      options:
        blobstore_path: /tmp/jenkins-blobs
    final_name: jenkins_blobstore

along with this `private.yml`

    ---
    blobstore_secret: 'does-not-matter'
    blobstore:
      local:
        blobstore_path: /tmp/ardo-blobs

### Add Blobs

Run the command

    bosh add blob <path_to_blob_on_local_system> <package_name>

(TODO) currently I am not sure what this command does and where the blobs are stored after they've been added.



Using this Release
------------------

If you want to use this release, make sure to have [BOSH Lite](https://github.com/cloudfoundry/bosh-lite) on your system. See "Preparational Tasks" above.

### Connect BOSH CLI to BOSH Lite

    bosh target 192.168.50.4

### Create the BOSH Release

Clone this repository with

    git clone https https://github.com/michaellihs/jenkins-boshrelease.git
    cd jenkins-boshrelease

Create the BOSH release with

    bosh create release --force

Upload the release to the BOSH Director now

    bosh upload release

Read the Director UUID with

    bosh status --uuid

Set the deployment manifest with




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
