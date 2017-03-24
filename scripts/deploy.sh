#!/usr/bin/env bash
cd `dirname $0`/..

set -e

IMAGE_NAME=eu.gcr.io/wildfish-directory/gckb-example
IMAGE_TAG=${IMAGE_NAME}:$1
CLUSTER_NAME=gckb-example
COMP_ZONE=europe-west1-d

gcloud docker -- tag $IMAGE_NAME $IMAGE_TAG
gcloud docker -- push $IMAGE_TAG

gcloud --quiet config set config container/cluster ${CLUSTER_NAME}
gcloud --quiet config set compute/zone ${COMP_ZONE}
gcloud --quiet container clusters get-credentials ${CLUSTER_NAME}
kubectl -- patch deployment django -p'{"spec":{"template":{"spec":{"containers":[{"name":"django","image":"${IMAGE_TAG}"}]}}}}'
