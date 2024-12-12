#!/usr/bin/env bash

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euxo pipefail

# roc='./roc_nightly/roc'
# roc=$(which roc) # for local use

if roc_path=$(which roc 2>/dev/null); then
    roc="$roc_path"
else
    roc="./roc_nightly/roc"
fi

src_dir='./src'
ci_dir='./ci'

# validate the repository
$roc run $ci_dir/check-repo.roc --linker=legacy

# test-stub.roc
$roc check $src_dir/Tests.roc
$roc test $src_dir/Tests.roc

# main.roc
$roc check $src_dir/main.roc
$roc build $src_dir/main.roc --linker=legacy