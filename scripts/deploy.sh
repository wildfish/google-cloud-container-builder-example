#!/usr/bin/env bash
cd `dirname $0`/..

set -e

IMAGE_NAME=eu.gcr.io/wildfish-directory/gckb-example
IMAGE_TAG=${IMAGE_NAME}:$1

gcloud docker -- tag $IMAGE_NAME $IMAGE_TAG
gcloud docker -- push $IMAGE_TAG

gcloud --quiet container clusters get-credentials gckp-example
kubectl -- patch deployment django -p'{"spec":{"template":{"spec":{"containers":[{"name":"django","image":"${IMAGE_TAG}"}]}}}}'
