#!/bin/sh

# Copyright (c) 2017 by General Electric Company. All rights reserved.

# The copyright to the computer software herein is the property of
# General Electric Company. The software may be used and/or copied only
# with the written permission of General Electric Company or in accordance
# with the terms and conditions stipulated in the agreement/contract
# under which the software has been supplied.

# This script imports the golang language tooling.
#
# Requirements:
# - The script is intended to be run inside the docker container specified
#   in the Dockerfile for the build container. In other words:
#   DO NOT CALL THIS SCRIPT DIRECTLY.
# - The right way to call this script is to invoke "make" from
#   your checkout of the repository.
#   the Makefile will do a "docker build ... " and then
#   "docker run hack/tool-deps.sh" in the resulting image.
#

go get \
	github.com/tools/godep \
	github.com/golang/lint/golint \
	github.com/golang/dep/cmd/dep
