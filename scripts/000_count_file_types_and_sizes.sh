# list number of diles and their sizes in specified directory
dir=$1
find $dir -type f -name "mars_v0??_????*.grib" -print0 | xargs -0 ls -l | awk '{print $5, $9}' | sed -n 's/.*\(mars_v0.._....\).*/\1 \0/p' | awk '{sum[$1] += $2; count[$1]++} END {for (i in sum) print count[i], sum[i], i}' | sort -k3 | awk '
{
    filecount = $1;
    size = $2;
    unit = "B";
    if (size > 1024) { size = size / 1024; unit = "K"; }
    if (size > 1024) { size = size / 1024; unit = "M"; }
    if (size > 1024) { size = size / 1024; unit = "G"; }
    if (size > 1024) { size = size / 1024; unit = "T"; }
    printf "%4d files, %7.2f%s %s\n", filecount, size, unit, $3;
}'
