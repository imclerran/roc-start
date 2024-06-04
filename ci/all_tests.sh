#!/usr/bin/env bash

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euxo pipefail

roc='./roc_nightly/roc'
# roc=$(which roc) # for local use

src_dir='./src'

# roc check
$roc check $src_dir/main.roc

# roc build
$roc build $src_dir/main.roc --linker=legacy

# roc test
$roc test $src_dir/test-stub.roc