Recently, we have been using Google's container engine for deploying our apps, an intro to which can be found
[here](https://wildfish.com/blog/2017/03/14/django-google-container-engine-gke/).

Up to now we have been building, testing and deploying our containers from Circle CI, recently however Google have
released the [cloud container builder](https://cloud.google.com/container-builder/) which has piqued our interest
for a few reasons:

1. Our images will be built close to where they are being deployed which will hopefully lead to an increase in
   commit to deploy speed.
2. Having the power to run anything that you can run in a container.
3. A generous amount of free build time (120 mins/day at the time of writing).
4. Simple parallelisation of build steps.

# Introduction

So, what is Google cloud container builder? Simply put, it is a replacement for other CI processes where each build
step is actually its own docker container with your code mounted and working directory set to ``/workspace``.
This means that your build step can do anything that can be done from inside a container without needing to worry
about the environment of the host, this opens up a lot of flexibility.

# Setup

We recently published an article about setting up a kubernetes cluster on google container engine
[here](https://wildfish.com/blog/2017/03/14/django-google-container-engine-gke/) which this post is based on.

For setting up your cloud build you will need to open up the cloud console:

1. From the left hand menu select 'Container Registry' from 'Tools'.
2. Select build triggers.
3. Hit the Create button.
4. Select your source.
5. Authenticate with the source (eg for GitHub or Bitbucket).
6. Select your repository.
7. Configure your build, this includes branch regex, name and build configuration. Here we are using cloudbuild.yaml.

From now on every time you commit code matching the build regex the build will be triggered. Alternatively you can
start a new build by clicking ``Run trigger`` from the build triggers page or running::

    gcloud container builds submit --config cloudbuild.yaml

This will upload a tar of your working directory and use that as the build context.

The details of each build (including the current) can be found in the build history.

# The Config

Depending on the complexity of your container and build process you can specify a docker file to build and leave it
at that. In the majority of cases though you will want to perform some inspection on your container, for this you
will need to create a ``cloudbuild.yaml`` file that will look something like this::

    steps:

      #
      # Building
      #

      - id: build-builder
        name: gcr.io/cloud-builders/docker
        args: ['build', '--rm=false', '-t', 'eu.gcr.io/$PROJECT_ID/gckb-example-builder', '-f', 'Dockerfile.builder', '.']


      - id: build
        name: eu.gcr.io/$PROJECT_ID/gckb-example-builder
        args: ['./scripts/build.sh']
        waitFor:
          - build-builder

      #
      # Testing
      #

      - id: lint
        name: eu.gcr.io/$PROJECT_ID/gckb-example-builder
        args: ['./scripts/lint.sh']
        waitFor:
          - build-builder

      - id: run-tests
        name: eu.gcr.io/$PROJECT_ID/gckb-example-builder
        args: ['./scripts/test.sh']
        waitFor:
          - build

      #
      # Deploying
      #

      - id: deploy
        name: eu.gcr.io/$PROJECT_ID/gckb-example-builder
        args: ['./scripts/deploy.sh $COMMIT_SHA']
        env:
          - PROJECT_ID=$PROJECT_ID
          - CREDS_BUCKET_NAME=gckb-example-creds
        waitFor:
          - run-tests
          - lint

Above we have used the following build parameters:

* ``id`` - A unique identifier so that the step can be referenced later.
* ``name`` - The name of the container to run the command.
* ``args`` - The arguments to pass to the container entrypoint.
* ``waitFor`` - The ids of previous steps to wait for before executing.

For a full description of all available parameters look [here](https://cloud.google.com/container-builder/docs/api/build-steps#build_step_configuration).
Now lets take a look at these build steps in more detail.

## build-builder

The first thing we need to do is prepare our build environment. We use the base cloud-builder docker image to prepare
our build image (``Dokerfile.builder``) ::

    FROM gcr.io/cloud-builders/gcloud

    # install python
    RUN apt-get update && apt-get install python python-pip -y

    # install docker (from the base docker step https://github.com/GoogleCloudPlatform/cloud-builders/blob/master/docker/Dockerfile-1.12.6)
    RUN \
       apt-get -y update && \
       apt-get -y install apt-transport-https ca-certificates curl \
           # These are necessary for add-apt-respository
           software-properties-common python-software-properties && \
       curl -fsSL https://yum.dockerproject.org/gpg | sudo apt-key add - && \
       apt-key fingerprint 58118E89F3A912897C070ADBF76221572C52609D && \
       add-apt-repository \
           "deb https://apt.dockerproject.org/repo/ \
           ubuntu-$(lsb_release -cs) \
           main" && \
       apt-get -y update && \
       apt-get -y install docker-engine=1.12.6-0~ubuntu-trusty

    # update gclod and get kubectl
    RUN gcloud --quiet components update
    RUN gcloud --quiet components update kubectl

    COPY requirements-ci.txt .
    RUN pip install -r requirements-ci.txt

    ENTRYPOINT ["/bin/sh", "-c"]

This builds our ``Dockerfile.builder`` inside the cloud-builder base docker image and stores it in a shared docker
state across all steps. Here we chose to build the builder each time so that our  requirements are always up to date
however it could as easily be pulled from a docker registry or simply use one of the
[cloud builder base containers](https://github.com/GoogleCloudPlatform/cloud-builders) if you don't have any special
requirements. In reality we would do a combination of the 2, where we store a base builder image that installs our
most of our dependencies such as ``python``, ``gcloud``, ``docker`` and ``kubectl`` and extend this per project
installing our project specific requirements.

In our example we install ``flake8`` so that we can lint our python code, however this will likely include more
requirements for inspecting your image such as ``docker-compose`` and maybe tools like ``selenium`` and web drivers.

## build

This is where we actually build our container. We spin up a new instance of our builder image and run
``scripts/build.sh``. Any images built here will also be stored in the docker state for future steps to use.

We specify that this step should wait for the builder to be built by with::

    ...
    waitFor:
      - build-builder
    ...

## lint

Here we check our code for any style errors. We don't really need to run this inside our final container as that
container is using the current directory as its build context and it would be nice to not have to wait for the image
to build before knowing a line is too long or you have missed a blank line somewhere, so we make this step only wait
for ``build-builder``. Therefore this step can start as soon as ``build-builder`` is done and can fail the build
before building the main image has finished.

## run-tests

Here we test our container, this will usually involve spinning up database and redis containers but in this example
we just run ``manage.py test`` with an internal sqlite db.

## deploy

Once all of our tests have passed (wait for ``lint`` and ``run-tests``) we deploy our code, tagging the commit sha.

It is important to note that variables like ``$PROJECT_ID`` and ``$COMMIT_SHA`` are not actually environment variables
but are substituted into your build config at build time. You can pass them into build steps as build environment
variables using the ``env`` parameter on a step like so::

    ...
    - id: my-step
      name: my-image
      args: ['some', 'args']
      env:
        - COMMIT_SHA=$COMMIT_SHA
    ...

A full list of substitutions can be found [here](https://cloud.google.com/container-builder/docs/api/build-requests#substitutions).

**NOTE:** The cloud builder doesnt currently support secrets, this prevents the correct auth scopes to be passed into
you builder to interact with ``kubectl``. For this reason we have some additional work around code that fetches
credentials for another service account from a private storage bucket and activates that for using with ``kubectl``.
The code looks like this::

    gsutil cp gs://${CREDS_BUCKET_NAME}/creds.json /tmp
    export GOOGLE_APPLICATION_CREDENTIALS=/tmp/creds.json
    gcloud auth activate-service-account --key-file /tmp/creds.json

Secret handling is currently being developed so hopefully this workaround won't be needed for much longer.

# Testing your builders locally

There is a little bit of magic that goes into running your builders locally the same as they do during a build. Firstly
notice we didn't copy any of our source into the builder container, that's because we mount the source through volumes
and set the working directory, for this we use ``-v `realpath .`:/workspace`` and ``-w /workspace``.

We also mount the docker state from the host by mounting the socket using ``-v /var/run/docker.sock:/var/run/docker.sock``
so that the builder talks to your docker instance and ``-v ~/.docker:/root/.docker`` to load your config.

This gives us the following run command::

    docker run \
        -v `realpath .`:/workspace
        -v /var/run/docker.sock:/var/run/docker.sock
        -v ~/.docker:/root/.docker
        -w /workspace
        container-name [args...]

You should also add any environment variables specified in your config.

# Gotchas

In figuring this stuff out we hit a few gotchas along the way to do with how the docker state is handled.

The first concerns running tests in parallel, it seemed like a great idea to have our unit and selenium tests
running side by side, both spin up their own instances of the web server, db and redis so both should be completely
independent. In reality however we end up clashing on names based on when containers are created and destroyed by other
processes. One option would be duplicate services for the different test types, alternatively we could move away from
compose and manually link our containers.

The second gotcha we came across was inspecting our services. During our testing we inspect our containers to make sure
the db and redis services are fully running before hooking up our web server instance. Originally we inspected
localhost for this, however it seems that since our containers are running on the hosts' docker engine and not our
builders we can't actually inspect them like this. Instead we create another container that is a copy of our builder
(yup we are running our builder inside our builder to inspect our other containers) and link it to our network. From
here we can inspect our db, redis and web server using hostnames.

# Final thoughts

The technology here is really interesting and the ability to run whatever you like without worrying about your
environment is very attractive. There are however a few things missing though that make it less attractive than the
alternatives in its current incarnation.

* Currently there is no built in notification for failing tests (email or otherwise). On build status changes messages
  are sent to gclouds pub/sub system which could be utilised to send messages to slack for instance but at the time of
  writing there doesnt appear to be anything existing.
* There is no support for build secrets. It is possible to use secret data by baking it into your builder image or
  storing it in a bucket somewhere but a system for handling secret data would be very useful. This is also currently
  preventing deploying using ``kubectl`` but is currently in development.
* There is also no trivial ways to store variables between steps. This leads to hardcoding lots of substitutions or
  storing values in files and reading them when needed.
* Some of the reporting is not quite how I would like. For instance the logs for each step are broken down nicely but
  they are labeled by the container name and not the step id. This seems odd when an id is available as most steps
  will likely use the same image.

Until these are fixed we will be sticking with Circle however the service is still in early beta and hopefully these
will be addressed fairly early on.
