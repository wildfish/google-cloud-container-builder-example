FROM gcr.io/cloud-builders/gcloud

RUN apt-get update && apt-get install python python-pip -y
RUN gcloud --quiet components update
RUN gcloud --quiet components update kubectl

COPY requirements-ci.txt .
RUN pip install -r requirements-ci.txt

ENTRYPOINT ["/bin/sh", "-c"]
