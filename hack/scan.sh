#!/bin/sh

# Copyright (c) 2017 by General Electric Company. All rights reserved.

# The copyright to the computer software herein is the property of
# General Electric Company. The software may be used and/or copied only
# with the written permission of General Electric Company or in accordance
# with the terms and conditions stipulated in the agreement/contract
# under which the software has been supplied.

set -o errexit
set -o nounset
set -o pipefail

# This script scans golang source code.
#
# Requirements:
# - Expects the source folders to be scanned as argument
# - The script is intended to be run inside the docker container specified
#   in the Dockerfile for the build container. In other words:
#   DO NOT CALL THIS SCRIPT DIRECTLY.
# - The right way to call this script is to invoke "make" from
#   your checkout of the repository.
#   the Makefile will do a "docker build ... " and then
#   "docker run hack/scan.sh" in the resulting image.
#


TARGETS=$(for d in "$@"; do echo ./${d%/}/...; done)

echo -n "Checking gofmt: "
ERRS=$(find "$@" -type f -name \*.go | xargs gofmt -l 2>&1 || true)
if [ -n "${ERRS}" ]; then
    echo "FAIL - the following files need to be gofmt'ed:"
    for e in ${ERRS}; do
        echo "    $e"
    done
    echo
    exit 1
fi
echo "PASS"
echo

echo -n "Checking golint: "
ERRS=$(echo ${TARGETS} | xargs golint 2>&1 || true)
if [ -n "${ERRS}" ]; then
    echo "FAIL"
    echo "${ERRS}"
    echo
    exit 1
fi
echo "PASS"
echo

echo -n "Checking go vet: "
ERRS=$(GOCACHE=off go vet ${TARGETS} 2>&1 || true)
if [ -n "${ERRS}" ]; then
    echo "FAIL"
    echo "${ERRS}"
    echo
    exit 1
fi
echo "PASS"
echo
