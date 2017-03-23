FROM gcr.io/cloud-builders/docker

COPY requirements-ci.txt .
RUN pip install requirements-ci.txt

ENTRYPOINT ['/bin/sh', '-c']
