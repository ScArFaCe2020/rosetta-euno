<p align="center">
  <a href="https://www.rosetta-api.org">
    <img width="90%" alt="Rosetta" src="https://www.rosetta-api.org/img/rosetta_header.png">
  </a>
</p>
<h3 align="center">
   Rosetta EUNO
</h3>

<p align="center"><b>
ROSETTA-EUNO IS CONSIDERED <a href="https://en.wikipedia.org/wiki/Software_release_life_cycle#Alpha">ALPHA SOFTWARE</a>.
USE AT YOUR OWN RISK! COINBASE ASSUMES NO RESPONSIBILITY OR LIABILITY IF THERE IS A BUG IN THIS IMPLEMENTATION.
</b></p>

## Overview
`rosetta-euno` provides a reference implementation of the Rosetta API for
Euno in Golang. If you haven't heard of the Rosetta API, you can find more
information [here](https://rosetta-api.org).

## Features
* Rosetta API implementation (both Data API and Construction API)
* UTXO cache for all accounts (accessible using the Rosetta `/account/balance` API)
* Stateless, offline, curve-based transaction construction from any SegWit-Bech32 Address

### Network Settings
To increase the load `rosetta-euno` can handle, it is recommended to tune your OS
settings to allow for more connections. On a linux-based OS, you can run the following commands ([source](http://www.tweaked.io/guide/kernel)):
```text
sysctl -w net.ipv4.tcp_tw_reuse=1
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.ipv4.tcp_max_syn_backlog=10000
sysctl -w net.core.somaxconn=10000
sysctl -p (when done)
```
_We have not tested `rosetta-euno` with `net.ipv4.tcp_tw_recycle` and do not recommend
enabling it._

You should also modify your open file settings to `100000`. This can be done on a linux-based OS
with the command: `ulimit -n 100000`.

### Memory-Mapped Files
`rosetta-euno` uses [memory-mapped files](https://en.wikipedia.org/wiki/Memory-mapped_file) to
persist data in the `indexer`. As a result, you **must** run `rosetta-euno` on a 64-bit
architecture (the virtual address space easily exceeds 100s of GBs).

If you receive a kernel OOM, you may need to increase the allocated size of swap space
on your OS. There is a great tutorial for how to do this on Linux [here](https://linuxize.com/post/create-a-linux-swap-file/).

## Usage
As specified in the [Rosetta API Principles](https://www.rosetta-api.org/docs/automated_deployment.html),
all Rosetta implementations must be deployable via Docker and support running via either an
[`online` or `offline` mode](https://www.rosetta-api.org/docs/node_deployment.html#multiple-modes).

**YOU MUST INSTALL DOCKER FOR THE FOLLOWING INSTRUCTIONS TO WORK. YOU CAN DOWNLOAD DOCKER [HERE](https://www.docker.com/get-started).**

### Install
Running the following commands will create a Docker image called `rosetta-euno:latest`.

#### From GitHub
To download the pre-built Docker image from the latest release, run:
```text
curl -sSfL https://raw.githubusercontent.com/ScArFaCe2020/rosetta-euno/master/install.sh | sh -s
```
_Do not try to install rosetta-euno using GitHub Packages!_

#### From Source
After cloning this repository, run:
```text
make build-local
```

### Run
Running the following commands will start a Docker container in
[detached mode](https://docs.docker.com/engine/reference/run/#detached--d) with
a data directory at `<working directory>/euno-data` and the Rosetta API accessible at port `8080`.

#### Mainnet:Online
```text
docker run -d --rm --ulimit "nofile=100000:100000" -v "$(pwd)/euno-data:/data" -e "MODE=ONLINE" -e "NETWORK=MAINNET" -e "PORT=8080" -p 8080:8080 -p 46462:46462 rosetta-euno:latest
```
_If you cloned the repository, you can run `make run-mainnet-online`._

#### Mainnet:Offline
```text
docker run -d --rm -e "MODE=OFFLINE" -e "NETWORK=MAINNET" -e "PORT=8081" -p 8081:8081 rosetta-euno:latest
```
_If you cloned the repository, you can run `make run-mainnet-offline`._

#### Testnet:Online
```text
docker run -d --rm --ulimit "nofile=100000:100000" -v "$(pwd)/euno-data:/data" -e "MODE=ONLINE" -e "NETWORK=TESTNET" -e "PORT=8080" -p 8080:8080 -p 46464:46464 rosetta-euno:latest
```
_If you cloned the repository, you can run `make run-testnet-online`._

#### Testnet:Offline
```text
docker run -d --rm -e "MODE=OFFLINE" -e "NETWORK=TESTNET" -e "PORT=8081" -p 8081:8081 rosetta-euno:latest
```
_If you cloned the repository, you can run `make run-testnet-offline`._

## Architecture
`rosetta-euno` uses the `syncer`, `storage`, `parser`, and `server` package
from [`rosetta-sdk-go`](https://github.com/coinbase/rosetta-sdk-go) instead
of a new Bitcoin-specific implementation of packages of similar functionality. Below
you can find a high-level overview of how everything fits together:
<p align="center">
  <a href="https://www.rosetta-api.org">
    <img width="90%" alt="Architecture" src="https://www.rosetta-api.org/img/rosetta_bitcoin_architecture.jpg">
  </a>
</p>

### Optimizations
* Automatically prune bitcoind while indexing blocks
* Reduce sync time with concurrent block indexing
* Use [Zstandard compression](https://github.com/facebook/zstd) to reduce the size of data stored on disk without needing to write a manual byte-level encoding

#### Concurrent Block Syncing
To speed up indexing, `rosetta-euno` uses concurrent block processing with a "wait free" design (using [the channels function](https://golangdocs.com/channels-in-golang) instead of [the sleep function](https://pkg.go.dev/time#Sleep) to signal which threads are unblocked). This allows `rosetta-euno` to fetch multiple inputs from disk while it waits for inputs that appeared in recently processed blocks to save to disk.

<p align="center">
  <a href="https://www.rosetta-api.org">
    <img width="90%" alt="Concurrent Block Syncing" src="https://www.rosetta-api.org/img/rosetta_bitcoin_concurrent_block_synching.jpg">
  </a>
</p>

## Testing with rosetta-cli
To validate `rosetta-euno`, [install `rosetta-cli`](https://github.com/coinbase/rosetta-cli#install)
and run one of the following commands:
* `rosetta-cli check:data --configuration-file rosetta-cli-conf/testnet/config.json` - This command validates that the Data API information in the `testnet` network is correct. It also ensures that the implementation does not miss any balance-changing operations.
* `rosetta-cli check:construction --configuration-file rosetta-cli-conf/testnet/config.json` - This command validates the blockchain’s construction, signing, and broadcasting.
* `rosetta-cli check:data --configuration-file rosetta-cli-conf/mainnet/config.json` - This command validates that the Data API information in the `mainnet` network is correct. It also ensures that the implementation does not miss any balance-changing operations.

## Issues
Interested in helping fix issues in this repository? You can find to-dos in the [Issues](https://github.com/ScArFaCe2020/rosetta-euno/issues) section with the `help wanted` tag. Be sure to reach out on our [community](https://community.rosetta-api.org) before you tackle anything on this list.


## Development
* `make deps` to install dependencies
* `make test` to run tests
* `make lint` to lint the source code
* `make salus` to check for security concerns
* `make build-local` to build a Docker image from the local context
* `make coverage-local` to generate a coverage report

## License
This project is available open source under the terms of the [Apache 2.0 License](https://opensource.org/licenses/Apache-2.0).

© 2021 Coinbase
© 2022 EUNO