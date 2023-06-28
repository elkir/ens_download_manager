#!/bin/env zsh
# Description: Convert v0.4 to v0.5
# the only difference between these two versions is 
# that v04 has an extra parameter the z geopotential
# with nonsense values (it had a code of 129)
# therefore the files can be easily converted by
# removing the extra parameter
# for single file use:
# cdo delcode,129 mars_v0{4d,5d}_2017-03-02_Thu.grib  

for file in $*; do
  # Replace the version 'v04' with 'v05' in the file name
    new_file_name="${file/v04/v05}"
   
    # # test1
    # echo $file "->" $new_file_name    
    
    # # test2
    # ls -lh $file

    
    #  Perform the CDO operation to delete the parameter with code 129
     cdo delcode,129 "$file" "${new_file_name}"
    # # remove the old file
    rm "$file"
done

# # diff outputs of ls -lh in ../copy and ../copy2
# # column comparison
# # only show filename and size
# diff -y  <(ls -lh ../copy | awk '{print $9,$5}') <(ls -lh ../copy2 | awk '{print $9,$5}')

# # fast byte comaprison of two files
# # mars_v05e_2018-08-09_Thu_cdo.grib mars_v05e_2018-08-09_Thu_ecmwf.grib
# cmp -l mars_v05e_2018-08-09_Thu_cdo.grib mars_v05e_2018-08-09_Thu_ecmwf.grib