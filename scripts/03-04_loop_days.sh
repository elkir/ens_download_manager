# use as ./scripts/03-04_loop_days.sh [-f] 2017 01 12

# loop through every date in the year 2017 in the format YYYY-MM-DD and print it if the date exists and is Monday or Thursday
# print Thu for Thursday and Mon for Monday
mkdir logs/v03-04_$1
touch logs/v03-04_$1/failed_requests.log

# URL for telegram notifications
TELEGRAM_URL="https://api.telegram.org/bot5906083900:AAGkxZsnL-YvnoHVzotK-_VHNLdhx-UoAOM/sendMessage?chat_id=5889704030"

# Notify telegram loop has started
MESSAGE="ECMWF MARS Loop through year $1 for months $2 to $3 STARTED at $(hostname).hpc"
curl -s "$TELEGRAM_URL&text=$MESSAGE"

# catch force flag
if [[ $4 == "-f" ]]; then
    force=true
else
    force=false
fi


# for dates
for i in $(eval echo {$1..$1}-{$2..$3}-{01..31}); do
    if date -d $i &> /dev/null; then # if date exists
        if [[ $(date -d $i +%u) == 1 ]] || [[ $(date -d $i +%u) == 4 ]]; then # if monday of thursday
            for x in e d;
            do
                # skip if file already exists and force flag is not set
                if [ -f "data/mars_v04${x}_${i}_$(date -d $i +%a).grib" ] && ! $force
                    then
                    echo "data/mars_v04${x}_${i}_$(date -d $i +%a).grib already exists"
                    continue
                fi
                # request data for date $i
                echo "data/mars_v04${x}_${i}_$(date -d $i +%a).grib" | 
                    # print bold and colored
                    sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
                        -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/";
                ./scripts/03-04_mars.sh -N request v04$x $i || 
                    echo "v04${x}_$i" >> logs/v03-04_$1/failed_requests.log
            done
        fi
    fi
done


# if all the processes are done, then send a notification to telegram
MESSAGE="MARS Loop through year $1 for months $2 to $3 DONE at $(hostname).hpc"
wait &&
 curl -s "$TELEGRAM_URL&text=$MESSAGE"
echo -e 'n'
