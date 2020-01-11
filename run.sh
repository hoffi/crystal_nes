#!/bin/bash
shards build --error-trace || exit 1
./bin/crystal_nes $@
