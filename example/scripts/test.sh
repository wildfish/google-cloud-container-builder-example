#!/usr/bin/env bash

set -e

docker run --rm eu.gcr.io/wildfish-gckb-example/gckb-example python manage.py test
