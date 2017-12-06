# Container App Service Command Line Interface

This is a basic CLI interface to the REST api of the container app service. The purpose of this CLI is to abstract the operation of container app service from applications that wish to interact with it and use its features.

## License

Copyright (c) 2017 by General Electric Company. All rights reserved.

The copyright to the computer software herein is the property of
General Electric Company. The software may be used and/or copied only
with the written permission of General Electric Company or in accordance
with the terms and conditions stipulated in the agreement/contract
under which the software has been supplied.

## Building

Run `make` or `make build` to compile your app.  This will use a Docker image
to build your app, with the current directory volume-mounted into place.  This
will store incremental state for the fastest possible build.  Run `make
all-build` to build for all architectures.

Run `make image` to build the image  It will calculate the image
tag based on the most recent git tag, and whether the repo is "dirty" since
that tag (see `make version`).  Run `make all-image` to build images
for all architectures.

Run `make test` to test the image.  Unit tests and basic integration regression tests will be
executed.

Run ```make scan``` to scan the image for formatting issues.

Run `make clean` to clean up.

## Corrections and errors

Should you find any inconsistencies or errors in this document, kindly do one of the following:
1. Fork the repo, create your fixes, create a pull request with an explanation.
2. Create an issue on the repo from the ```Issues``` tab above the repo file navigator
3. Email <a href="mailto:edge.appdevdevops@ge.com">edge.appdevdevops@ge.com</a>
