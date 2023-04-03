#!/usr/bin/env zsh

typeset -A files_map

#start a list of files with the same date and letter code
list_files=()

for file in mars_v*_*.grib; do
  # Extract the date and letter code
  date_code="${file: : -5}"
  date_code="${date_code#*_}"
  date_code="${date_code%_*}"
  # remove first 3 characters
  date_code="${date_code:3}"

  # Add the file to the files_map associative array
  if [[ -z ${files_map[$date_code]} ]]; then
    files_map[$date_code]="$file"
  else
    files_map[$date_code]="${files_map[$date_code]} $file"
  fi
done

# Print the files with the same date and letter code
for date_code in "${(@k)files_map}"; do
  num_files=(${=files_map[$date_code]})
  if [[ ${#num_files} -gt 1 ]]; then
    echo "Files with date and letter code $date_code:"
    echo "${files_map[$date_code]}"
    # list the files with the same date and letter code
    ls -lh ${=files_map[$date_code]}
    # add the files with the same date and letter code to a list
    list_files+=(${=files_map[$date_code]})
    echo
  fi
done


unset files_map
unset date_code
unset num_files