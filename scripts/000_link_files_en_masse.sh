#!/bin/bash


src="$HOME/rfs/rfs-ens-forecasts-E0ZFMheHB7M/data/ecmfw-ens/"
dest="$HOME/rds/hpc-work/data/ecmwf-ens/"

cd "$src" || exit 1

find . -type f -print0 | while IFS= read -r -d '' file; do
    rel_path=${file#*/}
    mkdir -p "$dest/$(dirname $rel_path)"
    ln -s "$src$file" "$dest/$rel_path"
done