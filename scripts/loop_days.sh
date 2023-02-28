# use as ./scripts/loop_days.sh [-f] v03-04 2017 01 12

# loop through every date in the year 2017 in the format YYYY-MM-DD and print it if the date exists and is Monday or Thursday
# print Thu for Thursday and Mon for Monday

# Arguments:
# -f: force flag, if set, then the script will not check if the file already exists and will overwrite it
# v03-04: version: first number is the version of the script, second number is the version of the request
# 2017: year to loop through
# 01: start month
# 12: end month




# URL for telegram notifications
TELEGRAM_URL="https://api.telegram.org/bot5906083900:AAGkxZsnL-YvnoHVzotK-_VHNLdhx-UoAOM/sendMessage?chat_id=5889704030"


# catch force flag
if [ "$1" == "-f" ]; then
    force=true
    shift
else
    force=false
fi

version=$1
version_script=$(echo $version | cut -d'-' -f1)
version_request=$(echo $version | cut -d'-' -f2)
year=$2
month_start=$3
month_end=$4


# check and create log folders $version_$year
if [ ! -d "logs/$version_$year" ]; then
    mkdir -p "logs/$version_$year"
fi


params=()
files=()
# generate a list of request parameters i and x
# for dates
for i in $(eval echo {$year..$year}-{$month_start..$month_end}-{01..31});
    if date -d $i &> /dev/null; then # if date exists
        if [[ $(date -d $i +%u) == 1 ]] || [[ $(date -d $i +%u) == 4 ]]; then # if monday of thursday
            for x in e d;
            do
                # skip if file already exists and force flag is not set
                if [ -f "data/mars_v$version_request${x}_${i}_$(date -d $i +%a).grib" ] && [ $force == false ];
                    then
                    echo "data/mars_v$version_request${x}_${i}_$(date -d $i +%a).grib already exists"
                    continue
                fi
                # save the request paramters to an array
                params+=("$i,$x")
                files+=("mars_v$version_request${x}_${i}_$(date -d $i +%a).grib")
                
            done
        fi
    fi
done

# save PID of this process and print it, to be used to wait for the process to finish
echo "This loop has PID: $$" | 
    sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
        -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/"

# concatenate the files array to a string using url new line character
# need to escape the new line character with another % sign
all_files=$(printf "%s%%0A" "${files[@]}")
# Notify telegram loop has started
MESSAGE="ECMWF MARS Loop through year $year for months $month_start to $month_end STARTED at $(hostname).hpc%0AProcess PID: $$%0AFiles:%0A$all_files"
curl -s "$TELEGRAM_URL&text=$MESSAGE"
echo -e "\n"


# loop through the list of request parameters and run the script
for param in ${params[@]}; do
    i=$(echo $param | cut -d',' -f1)
    x=$(echo $param | cut -d',' -f2)
    # print the file name
    echo "data/mars_v$version_request${x}_${i}_$(date -d $i +%a).grib" | 
        # print bold and colored
        sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
            -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/";
    ./scripts/mars.sh -N request v$version_request$x $i 
    #|| 
     #   echo "v04${x}_$i" >> logs/$version_$year/failed_requests.log
done

# check if all files exist and print missing files
echo "Checking if all files exist:" | 
    sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
        -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/";
missing_files=()


for file in ${files[@]}; do
    if [ ! -f "data/$file" ]; then
        echo "$file does not exist" | 
            sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
                -e "s/^/$(tput setaf 1)/" -e "s/$/$(tput sgr0)/";
        missing_files+=("$file")
    fi
done
# if no files are missing, then print a message
if [ ${#missing_files[@]} -eq 0 ]; then
    echo "All files exist" | 
        sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
            -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/";
fi

# if all the processes are done, then send a notification to telegram
MESSAGE="MARS Loop through year $year for months $month_start to $month_end DONE at $(hostname).hpc%0AFiles unsuccesful:%0A$(printf "%s%%0A" "${missing_files[@]}")"
wait && curl -s "$TELEGRAM_URL&text=$MESSAGE"
echo -e '\n'
