#!/usr/bin/env bash
cd `dirname $0`/..

set -e

docker tag eu.gcr.io/wildfish-directory/gckb-example eu.gcr.io/wildfish-directory/gckb-example:$1
docker push eu.gcr.io/wildfish-directory/gckb-example:$1
