#!/usr/bin/env bash

set -e

docker tag eu.gcr.io/wildfish-gckb-example/gckb-example eu.gcr.io/wildfish-gckb-example/gckb-example:$1
docker push eu.gcr.io/wildfish-gckb-example/gckb-example:$1
