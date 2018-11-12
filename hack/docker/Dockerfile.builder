# Copyright (c) 2017 by General Electric Company. All rights reserved.

# The copyright to the computer software herein is the property of
# General Electric Company. The software may be used and/or copied only
# with the written permission of General Electric Company or in accordance
# with the terms and conditions stipulated in the agreement/contract
# under which the software has been supplied.

FROM golang:1.11.2-alpine3.8

RUN set -ex \
	&& apk add --no-cache \
		bash \
		curl \
		git \
		gcc \
		libc-dev
