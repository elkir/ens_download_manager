# loop through every date in the year 2017 in the format YYYY-MM-DD and print it if the date exists and is Monday or Thursday
# print Thu for Thursday and Mon for Monday
mkdir logs/v03-04_$1
touch logs/v03-04_$1/failed_requests.log

# catch force flag
if [[ $4 == "-f" ]]; then
    force=true
else
    force=false
fi

for i in $(eval echo {$1..$1}-{$2..$3}-{01..31}); do
    if date -d $i &> /dev/null; then
        if [[ $(date -d $i +%u) == 1 ]] || [[ $(date -d $i +%u) == 4 ]]; then
            for x in e d;
            do
                # skip if file already exists and force flag is not set
                if [ -f "data/mars_v04${x}_${i}_$(date -d $i +%a).grib" ] && ! $force
                    then
                    echo "data/mars_v04${x}_${i}_$(date -d $i +%a).grib already exists"
                    continue
                fi
                # request data for date $i
                { echo "data/mars_v04${x}_${i}_$(date -d $i +%a).grib" | 
                    # print bold and colored
                    sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
                        -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/";
                ./scripts/03-04_mars.sh -N request v04$x $i || 
                    echo "v04${x}_$i" >> logs/v03-04_$1/failed_requests.log; }
            done
        fi
    fi
done


# if all the processes are done, then send a notification to telegram
wait &&
 curl -X POST \
 -H "Content-Type: application/json" \
 -d "{\"value1\":\"MARS Loop through year $1 for months $2 to $3\"}" \
  https://maker.ifttt.com/trigger/notify/with/key/dHmvWjsHHJvHLg6ejV48do ;