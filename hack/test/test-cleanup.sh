#!/bin/bash

# Copyright (c) 2017 by General Electric Company. All rights reserved.

# The copyright to the computer software herein is the property of
# General Electric Company. The software may be used and/or copied only
# with the written permission of General Electric Company or in accordance
# with the terms and conditions stipulated in the agreement/contract
# under which the software has been supplied.

if [ -d _container-app-service ]; then
	cd _container-app-service
	make clean
	cd -
	rm -rf _container-app-service
fi
docker rmi helloyutao || echo "no such image: helloyutao"
