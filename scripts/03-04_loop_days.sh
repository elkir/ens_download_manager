# use as ./scripts/03-04_loop_days.sh [-f] 2017 01 12

# loop through every date in the year 2017 in the format YYYY-MM-DD and print it if the date exists and is Monday or Thursday
# print Thu for Thursday and Mon for Monday
mkdir logs/v03-04_$1
touch logs/v03-04_$1/failed_requests.log

# URL for telegram notifications
TELEGRAM_URL="https://api.telegram.org/bot5906083900:AAGkxZsnL-YvnoHVzotK-_VHNLdhx-UoAOM/sendMessage?chat_id=5889704030"



# catch force flag
if [[ $4 == "-f" ]]; then
    force=true
else
    force=false
fi


params=()
files=()
# generate a list of request parameters i and x
# for dates
for i in $(eval echo {$1..$1}-{$2..$3}-{01..31}); do
    if date -d $i &> /dev/null; then # if date exists
        if [[ $(date -d $i +%u) == 1 ]] || [[ $(date -d $i +%u) == 4 ]]; then # if monday of thursday
            for x in e d;
            do
                # skip if file already exists and force flag is not set
                if [ -f "data/mars_v04${x}_${i}_$(date -d $i +%a).grib" ] && [ $force == false ];
                    then
                    echo "data/mars_v04${x}_${i}_$(date -d $i +%a).grib already exists"
                    continue
                fi
                # save the request paramters to an array
                params+=("$i,$x")
                files+=("mars_v04${x}_${i}_$(date -d $i +%a).grib")
                
            done
        fi
    fi
done

all_files=$(printf "%s%0A" "${files[@]}")
# Notify telegram loop has started
MESSAGE="ECMWF MARS Loop through year $1 for months $2 to $3 STARTED at $(hostname).hpc%0AFiles:%0A$all_files"
curl -s "$TELEGRAM_URL&text=$MESSAGE"

# loop through the list of request parameters and run the script
for param in ${params[@]}; do
    i=$(echo $param | cut -d',' -f1)
    x=$(echo $param | cut -d',' -f2)
    # print the file name
    echo "data/mars_v04${x}_${i}_$(date -d $i +%a).grib" | 
        # print bold and colored
        sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
            -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/";
    ./scripts/03-04_mars.sh -N request v04$x $i || 
        echo "v04${x}_$i" >> logs/v03-04_$1/failed_requests.log
done

# check if all files exist and print missing files
echo "Checking if all files exist:" | 
    sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
        -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/";
missing_files=()


for file in ${files[@]}; do
    if [ ! -f "data/$file" ]; then
        echo "$file does not exist"
        missing_files+=("$file")
    fi
done

# if all the processes are done, then send a notification to telegram
MESSAGE="MARS Loop through year $1 for months $2 to $3 DONE at $(hostname).hpc%0AFiles unsuccesful:%0A$(printf "%s%0A" "${missing_files[@]}")"
wait && curl -s "$TELEGRAM_URL&text=$MESSAGE"
echo -e '\n'
