# Copyright 2020 Coinbase, Inc.
# Copyright 2022 EUNO
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Build eunod
FROM ubuntu:20.04 as eunod-builder

RUN mkdir -p /app \
  && chown -R nobody:nogroup /app
WORKDIR /app

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ Etc/UTC
RUN apt-get update && apt-get install -y make gcc g++ autoconf autotools-dev bsdmainutils build-essential git libboost-all-dev \
  libcurl4-openssl-dev libdb++-dev libevent-dev libssl-dev libtool pkg-config python python3-pip libzmq3-dev wget

RUN wget https://github.com/Euno/eunowallet/releases/download/v2.0.2/euno-2.0.2-x86_64-linux-gnu.tar.gz \
  && tar zxvf euno-2.0.2-x86_64-linux-gnu.tar.gz

# RUN cd bitcoin \
#   && ./autogen.sh \
#   && ./configure --disable-tests --without-miniupnpc --without-gui --with-incompatible-bdb --disable-hardening --disable-zmq --disable-bench --disable-wallet \
#   && make

RUN mv euno-2.0.2/bin/eunod /app/eunod \
  && rm -rf euno-2.0.2*

# Build Rosetta Server Components
FROM ubuntu:20.04 as rosetta-builder

RUN mkdir -p /app \
  && chown -R nobody:nogroup /app
WORKDIR /app

RUN apt-get update && apt-get install -y curl make gcc g++
# Install Golang 1.17.5.
ENV GOLANG_VERSION 1.17.5
ENV GOLANG_DOWNLOAD_URL https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz
ENV GOLANG_DOWNLOAD_SHA256 bd78114b0d441b029c8fe0341f4910370925a4d270a6a590668840675b0c653e

RUN curl -fsSL "$GOLANG_DOWNLOAD_URL" -o golang.tar.gz \
  && echo "$GOLANG_DOWNLOAD_SHA256  golang.tar.gz" | sha256sum -c - \
  && tar -C /usr/local -xzf golang.tar.gz \
  && rm golang.tar.gz

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

# Use native remote build context to build in any directory
COPY . src 
RUN cd src \
  && go build \
  && cd .. \
  && mv src/rosetta-euno /app/rosetta-euno \
  && mv src/assets/* /app \
  && rm -rf src 

## Build Final Image
FROM ubuntu:20.04

RUN apt-get update && \
  apt-get install --no-install-recommends -y libevent-dev libboost-system-dev libboost-filesystem-dev libboost-test-dev libboost-thread-dev && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /app \
  && chown -R nobody:nogroup /app \
  && mkdir -p /data \
  && chown -R nobody:nogroup /data

WORKDIR /app

COPY --from=eunod-builder /app/eunod /app/eunod

COPY --from=rosetta-builder /app/* /app/

RUN chmod -R 755 /app/*

CMD ["/app/rosetta-euno"]
