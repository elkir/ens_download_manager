# use as ./scripts/loop_days.sh [-fnDL] [-t <telegram_url>] [-r REGIME] v05-05 2017-01[-01] 2017-12[-20] edrf


# loop through every date between the specified start and end dates and print it if the date exists and is Monday or Thursday (or daily if -r flag is provided or -r D is provided)
# print Thu for Thursday and Mon for Monday

# Arguments:
# -h: help flag, prints usage
# -n: dry run flag, if set, then the script will not download any files
# -f: force flag, if set, then the script will not check if the file already exists and will overwrite it
# -r REGIME: regime flag, determines the looping regime, options are "D" for daily and "S" for semiweekly (default is semiweekly)
# -D: daily flag, equivalent to -r D
# -t TELEGRAM_URL: telegram url to send notifications to
# -L: run only requests, not list-checks 
# v05-07: version: first number is the version of the script, second number is the version of the request
# start_date: start date in the format YYYY-MM-DD or YYYY-MM
# end_date: end date in the format YYYY-MM-DD or YYYY-MM
# edrf: request types to loop through

# URL for telegram notifications
read -r TELEGRAM_URL < ./telegram_url

# Initialize variables with default values
force=false
regime="S"
dry_run=false
request_only_option=""

# Process command line options
while getopts "hnfDLr:t:" opt; do
    case $opt in
        h) 
            echo "Usage: ./scripts/loop_days.sh [-f] [-n] [-t TELEGRAM_URL|file][-r REGIME] v05-05 2017-01[-01] 2017-12[-20] edrf"
            exit 1
            ;;
        f)
            force=true
            ;;
        D)
            regime="D"
            ;;
        n)
            dry_run=true
            ;;
        L)
            request_only_option="-L"
            ;;
        r)
            regime="$OPTARG"
            ;;
        t)
            if [[ $OPTARG == http* ]]; then
                TELEGRAM_URL="$OPTARG"
            else
                # if relative path or absolute path
                if [[ $OPTARG == /* ]]; then
                    read -r TELEGRAM_URL < "$OPTARG"
                else
                    read -r TELEGRAM_URL < "./$OPTARG"
                fi
            fi
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

# Check if all required positional arguments are provided
if [ $# -lt 4 ]; then
    echo "Usage: ./scripts/loop_days.sh [-f] [-n] [-t <telegram_url>] [-r REGIME] v05-05 2017-01[-01] 2017-12[-20] edrf"
    exit 1
fi

version=$1
version_script=$(echo $version | cut -d'-' -f1)
version_request=$(echo $version | cut -d'-' -f2)
start_date=$2
end_date=$3
request_types=$4



# Format start_date if it's in the format YYYY-MM
if [[ $start_date =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
    start_date="${start_date}-01"
fi

# Format end_date if it's in the format YYYY-MM
if [[ $end_date =~ ^[0-9]{4}-[0-9]{2}$ ]]; then 
    end_date=$(date -d "${end_date}-01 + 1 month - 1 day" +%Y-%m-%d);
fi


# Check if start_date is a valid date
if ! date -d "$start_date" >/dev/null 2>&1; then
    echo "Invalid start date format. Please provide a valid date in the format YYYY-MM-DD or YYYY-MM."
    exit 1
fi

# Check if end_date is a valid date
if ! date -d "$end_date" >/dev/null 2>&1; then
    echo "Invalid end date format. Please provide a valid date in the format YYYY-MM-DD or YYYY-MM."
    exit 1
fi

# Extract year, month, and day from start_date and end_date
start_year=$(date -d "$start_date" +%Y)
start_month=$(date -d "$start_date" +%m)
start_day=$(date -d "$start_date" +%d)
end_year=$(date -d "$end_date" +%Y)
end_month=$(date -d "$end_date" +%m)
end_day=$(date -d "$end_date" +%d)

# check and create log folders $version_$start_year
if [ ! $dry_run ] && [ ! -d "logs/${version}_$start_year" ]; then
    mkdir -p "logs/${version}_$start_year"
fi

# make sure to run the main version of the script
git switch main.mirror
git merge main

params=()
files=()
# Check file for the date and version doesn't exist and output the file name
process_date() {
    local current_date=$1
    local x=$2

    local filename="mars_v$version_request${x}_${current_date}_$(date -d $current_date +%a).grib"

    # skip if file already exists and force flag is not set
    if [ -f "data/$filename" ] && [[ $force == false ]]; then
        echo "data/$filename already exists"
        return 0
    fi

    # save the request parameters to an array
    params+=("$current_date,$x")
    files+=("$filename")
}

# generate the list of dates to loop through
current_date=$start_date
while true; do
    if [[ "$current_date" > "$end_date" ]]; then
        break
    fi

    if [[ "$regime" == "S" && ( $(date -d "$current_date" +%u) == 1 || $(date -d "$current_date" +%u) == 4 ) ]]; then
        for x in $(echo $request_types | grep -o .); do
            process_date "$current_date" "$x"
        done
    elif [[ "$regime" == "D" ]]; then
        for x in $(echo $request_types | grep -o .); do
            process_date "$current_date" "$x"
        done
    fi
    current_date=$(date -I -d "$current_date + 1 day")
done

# save PID of this process and print it, to be used to wait for the process to finish
echo "This loop has PID: $$" | 
    sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
        -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/"

# concatenate the files array to a string using url new line character
# need to escape the new line character with another % sign
all_files=$(printf "%s%%0A" "${files[@]}")
# Notify telegram loop has started
MESSAGE="ECMWF MARS Loop between $start_date and $end_date STARTED at $(hostname).hpc%0AProcess PID: $$%0AFiles:%0A$all_files"
[[ $dry_run == true ]] && MESSAGE="DRY RUN: $MESSAGE"
curl -s "$TELEGRAM_URL&text=$MESSAGE"
echo -e "\n"


# Function to run when the script exits
onScriptExit() {
    MESSAGE="ERROR: Loop_days.sh script exited unexpectedly. Possibly due to server shutdown or an error in the script."
    curl -s "$TELEGRAM_URL&text=$MESSAGE"
}
# Set a trap for any kind of termination signal
trap 'onScriptExit' EXIT

# loop through the list of request parameters and run the script
for param in "${params[@]}"; do
    i=$(echo "$param" | cut -d',' -f1)
    x=$(echo "$param" | cut -d',' -f2)
    # print the file name
    echo "data/mars_v$version_request${x}_${i}_$(date -d "$i" +%a).grib" | 
        # print bold and colored
        sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
            -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/"
    if [[ $dry_run == true ]]; then
        echo "Dry run: ./scripts/mars.sh -N $request_only_option -t $TELEGRAM_URL request v$version_request$x \"$i\""
    else
        ./scripts/mars.sh -N -t $TELEGRAM_URL $request_only_option request v$version_request$x "$i"
    fi
    #|| 
    #   echo "v04${x}_$i" >> logs/$version_$start_year/failed_requests.log
done

if [[ $dry_run == true ]]; then
    echo "Dry run complete. No files were processed." | 
        sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
            -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/"
    missing_files=()
    missing_files+="N/A dry-run"
else
    # check if all files exist and print missing files
    echo "Checking if all files exist:" | 
        sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
            -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/"
    missing_files=()

    for file in "${files[@]}"; do
        if [ ! -f "data/$file" ]; then
            echo "$file does not exist" | 
                sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
                    -e "s/^/$(tput setaf 1)/" -e "s/$/$(tput sgr0)/"
            missing_files+=("$file")
        fi
    done

    # if no files are missing, then print a message
    if [ ${#missing_files[@]} -eq 0 ]; then
        echo "All files exist" | 
            sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/" \
                -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/"
    fi
fi
# if all the processes are done, then send a notification to telegram
MESSAGE="MARS Loop between $start_date and $end_date DONE at $(hostname).hpc%0AFiles unsuccessful:%0A$(printf "%s%%0A" "${missing_files[@]}")"
[[ $dry_run == true ]] && MESSAGE="DRY RUN: $MESSAGE"
wait && curl -s "$TELEGRAM_URL&text=$MESSAGE"
echo -e '\n'
trap - EXIT
