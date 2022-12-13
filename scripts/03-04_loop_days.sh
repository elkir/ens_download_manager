# loop through every date in the year 2017 in the format YYYY-MM-DD and print it if the date exists and is Monday or Thursday
# print Thu for Thursday and Mon for Monday
mkdir logs/v03-04_$1
touch logs/v03-04_$1/failed_requests.log


for i in $(eval echo {$1..$1}-{$2..$3}-{01..31}); do
    if date -d $i &> /dev/null; then
        if [[ $(date -d $i +%u) == 1 ]] || [[ $(date -d $i +%u) == 4 ]]; then
            { echo "data/test/file_${i}_$(date -d $i +%a).grib"
            touch "data/test/file_${i}_$(date -d $i +%a).grib" || echo $i >> failed_requests.log; } &
        fi
    fi
done
