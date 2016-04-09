Learning BOSH
=============

The full title of this project should be "Learning BOSH by building our own Jenkins BOSH Release". Part of the scripts are taken from the [Cloud Foundry Community Jenkins BOSH Release](https://github.com/cloudfoundry-community/jenkins-boshrelease).



TLDR;
-----

(TODO) Provide minimum necessary steps to use this release!



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
    ├── config
    │   ├── dev.yml                            # TODO find out what this file does
    │   ├── final.yml                          # configures the blobstore to be used for our release
    │   └── private.yml                        # configures paths and credentials for our blobstore
    ├── dev_releases                           # TODO find out what this directory contains
    ├── helpers                                # collection of helper scripts to maintain this release
    │   └── download.rb                        # downloads all binaries required for this release
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
    └── src                                    # source directory for files and binaries required by the release (first lookup)

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

For debugging: in case you want to delete a previously uploaded release, use `bosh delete release <release_name>`

Read the Director UUID with

    bosh status --uuid

We need to create a `manifest.yml` - for further details about this file refer to the [documentation](http://bosh.io/docs/deployment-manifest.html).

Set the deployment manifest via

    bosh deployment manifest.yml

Download the Stemcell and upload it to the BOSH Director (does not work in BCN, need to download in the browser with extended internet access)

    wget --content-disposition https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent
    (TODO) add command to upload the stemcell
    bosh upload stemcell ...

Deploy release

    bosh deploy

See list of deployed vms

    bosh vms

you should now see something like

    ...
    +---------------------------------------------------------+---------+-----+---------+------------+
    | VM                                                      | State   | AZ  | VM Type | IPs        |
    +---------------------------------------------------------+---------+-----+---------+------------+
    | jenkins_master/0 (a30c5f23-e2df-4b93-b570-717f299d04e5) | failing | n/a | warden  | 10.245.0.2 |
    +---------------------------------------------------------+---------+-----+---------+------------+
    ...

### Access Jenkins in your Browser

Add a route to the BOSH Lite network

    sudo route add -net 10.245.0.0/19 192.168.50.4

Open the following URL in your browser: [http://10.245.0.2:8088](http://10.245.0.2:8088)

### Re-build Release (for Debugging)

If something goes wrong and you want to change things in your release, re-build and re-deploy with the following commands:

    bosh delete deployment jenkins_master
    bosh delete release jenkins-release-dev
    bosh create release --force
    bosh upload release
    bosh deploy



Useful Tips & Tricks
====================

BOSH Commands
-------------

* delete a deployment

    bosh delete deployment <DEPLOYMENT_NAME>

* delete a release

    bosh delete release <RELEASE_NAME>



Debugging
---------

For debugging, what's going on in a container (e.g. during packaging), do the following

* put a `sleep 100000` just before the line in the packaging script that throws an error
* run `bosh deploy`
* you'll get a list of running VMs with `bosh vms`:

    +-------------------------------------------------------------------------------------------+---------+-----+---------+------------+
    | VM                                                                                        | State   | AZ  | VM Type | IPs        |
    +-------------------------------------------------------------------------------------------+---------+-----+---------+------------+
    | compilation-16bb6e05-9af0-4264-937d-64c59e239071/0 (26cd91a9-5ecc-4dfd-8b6e-93172305dab9) | running | n/a |         | 10.245.0.3 |
    +-------------------------------------------------------------------------------------------+---------+-----+---------+------------+

* now ssh into the BOSH Lite Vagrant Box with `vagrant ssh` from the directory with the BOSH Lite Vagrantfile
* run `ssh vcap@<IP FROM THE TABLE ABOVE>`
* password is `c1oudc0w`
* cd into `/var/vcap` and poke around...
* inside the container you again have to run `sudo su -` to become root (and see all the artifacts for compilation etc.)
* compilation artifacts reside in `/var/vcap/data/compile`
* you can test packaging scripts via `bash <PACKAGE_SCRIPT>`



Failed: ... is not running after update
---------------------------------------

This error message can be shown after `bosh deploy`. In order to debug it, do the following:

* use `bosh vms` to get a list of VMs and see which IPs they have - remember the IP of the VM you want to debug
* use `vagrant ssh` to ssh into BOSH Lite
* use `ssh vcap@<IP of VM>` with password `c1oudc0w` to ssh into the container
* become root via `sudo su -`
* check the following files / directories for log messages:

````
/var/vcap/sys/log           # and all files below
/var/vcap/monit/monit.log
````


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



Open Issues / TODOs
===================

* Add persistent disks for Jenkins configurations and builds
* Add script that installs a defined list of Jenkins plugins
* For some strange reason we need to `chown` the directories with the packages in the VM after deployment (in the ctl scripts) because the files are owned by root



Further Resources
=================

* [BOSH Website](http://bosh.io)
* [BOSH Terminology](http://bosh.io/docs/terminology.html)
* [Learning BOSH Tutorial](http://mariash.github.io/learn-bosh)
* [Advanced Troubleshooting with the BOSH CLI](https://docs.pivotal.io/pivotalcf/customizing/trouble-advanced.html)
* [Cloud Foundry Community Jenkins BOSH Release](https://github.com/cloudfoundry-community/jenkins-boshrelease)
* [Troubleshooting Cloud Foundry](https://docs.cloudfoundry.org/running/troubleshooting.html)
