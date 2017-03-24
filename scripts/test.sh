#!/usr/bin/env bash
cd `dirname $0`/..

set -e

gcloud docker -- run --rm eu.gcr.io/wildfish-directory/gckb-example python manage.py test
