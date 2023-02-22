# Count total number of possible files for a given year
for i in $(eval echo 2017-{01..12}-{01..31}); do
    if date -d $i &> /dev/null; then # if date exists
        if [[ $(date -d $i +%u) == 1 ]] || [[ $(date -d $i +%u) == 4 ]]; then # if monday of thursday
            for x in e d;
            do
                echo "data/mars_v04${x}_${i}_$(date -d $i +%a).grib" 
            done
        fi
    fi
done |wc -l
