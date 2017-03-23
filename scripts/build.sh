#!/usr/bin/env bash
cd `dirname $0`/..

set -e

docker build -t eu.gcr.io/wildfish-directory/gckb-example .
