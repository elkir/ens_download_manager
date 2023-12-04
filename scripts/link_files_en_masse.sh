#!/bin/bash

# Function to create symbolic links
create_symlink() {
    local file_path=$1
    local src=$2
    local dest=$3
    local verbose=$4
    local rel_path=${file_path#$src}
    local dest_path="$dest/$rel_path"

    # Create the necessary directories in the destination
    mkdir -p "$(dirname "$dest_path")"

    # Check if the file or link already exists at the destination
    if [ -e "$dest_path" ]; then
        if [ "$verbose" = true ]; then
            echo "File or link already exists: $dest_path"
        fi
        return
    fi

    # Create the symbolic link
    ln -s "$file_path" "$dest_path"
    echo "Created link: $dest_path -> $file_path"
}

# Check for verbose flag
verbose=false
while getopts ":v" opt; do
  case $opt in
    v)
      verbose=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Define RFS and RDS directories
source "../directories"

# Find and process files
find "$RDS" -type f -name "*.grib" -print0 | while IFS= read -r -d '' file; do
    create_symlink "$file" "$RDS" "$RFS" "$verbose"
done

