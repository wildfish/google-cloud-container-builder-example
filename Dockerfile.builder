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
