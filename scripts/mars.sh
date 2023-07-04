#!/usr/bin/env bash
## use as mars.sh [-v] [-N] [-t <telegram_url>] <type> <version> <date>  
# arguments
# $1: type: list[_cost]/request
# $2: version: v05[d,e,...]
# $3: date: YYYY-MM-DD
#
# flags
# -v: verbose
# -N: send notification
# -t: telegram_url
# -h: help
version_script="05"

# URL for telegram notifications
read -r TELEGRAM_URL < ./telegram_url

# Initialize variables with default values
verbose=false
notif=false

# Process command line options
while getopts "vNht:" opt; do
    case $opt in
        v)
            verbose=true
            ;;
        N)
            notif=true
            ;;
        h) 
            echo "Usage: $0 [-v] [-N] [-t <telegram_url>] <type> <version> <date>"
            exit 1
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
if [[ $# -ne 3 ]]; then
    echo "Usage: $0 [-v] [-N] [-t <telegram_url>] <type> <version> <date>"
    exit 1
fi


# print which day of the week date  is (in cyan) and bold it
echo "The date is $(date -d $3 +%A | 
    sed -e "s/^/$(tput bold)/" -e "s/$/$(tput sgr0)/")" | 
    sed -e "s/^/$(tput setaf 6)/" -e "s/$/$(tput sgr0)/" 

# conda activate mars-api
# if exist status 0, suspend error printing
if conda activate mars-api &> /dev/null
    then
        echo "conda: Conda environment mars-api activated" | sed -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/"
    else
        echo "conda: Conda environment mars-api not found" | sed -e "s/^/$(tput setaf 1)/" -e "s/$/$(tput sgr0)/"
        exit 1
fi


# grab and define output folder and extension
if [[ $1 == list* ]]
    then
        out_folder="lists"
        # if not "list_cost" OR "list" exit
        if [[ $1 != "list_cost" ]] && [[ $1 != "list" ]]
            then
                echo "Invalid type: $1" | sed -e "s/^/$(tput setaf 1)/" -e "s/$/$(tput sgr0)/"
                echo "Valid types: list_cost, list, request"
                exit 1 # fail if not valid type
        fi


elif [[ $1 == request ]]
    then
        out_folder="data"
    else
        echo "Invalid type: $1" |  sed -e "s/^/$(tput setaf 1)/" -e "s/$/$(tput sgr0)/"
        echo "Valid types: list_cost, list, request"
        exit 1 # fail if not valid type
fi

if [[ $1 == request ]]
    then
        extension="grib"
    else 
        extension="$1"
fi

date=$3
year=${date:0:4}
version_request=${2:1:2} #only the version number, not the letter
request_letter=${2:3:1}
filename_req="mars_$2_europe";
filename_date="mars_$2_$3_$(date -d $3 +%a)"; #date + Mon/Thu
datetime=$(date -Iminutes | sed "s/T/ /"| sed "s/+.*//")
out_file="$out_folder/$filename_date.$extension"
log_folder="logs/v${version_script}-${version_request}_${year}"

# if version letter is "r" 
if [[ $request_letter == "r" ]] 
    then
        hdates=()
        for i in $(seq $((year-20)) $((year-1))); do
            hdates+=($(date -d "$i-$(date -d $date +%m)-$(date -d $date +%d)" +%Y-%m-%d))
        done
        hdate_line="${hdates[*]}" # two steps because of bash
        hdate_line="hdate=${hdate_line// //},"
        # get length of dates array
        Nyears=${#hdates[@]}
    else
        Nyears=1
fi 

Npar=$(($(cat requests/$filename_req.req | sed -n "s/param=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))
Nens=$(($(cat requests/$filename_req.req | sed -n "s/number=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))
Nstep=$(($(cat requests/$filename_req.req | sed -n "s/step=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))
Nfields=$(($Npar*$Nens*$Nstep*$Nyears))


# capitalize type
type=$(echo $1 | awk '{print toupper($0)}')
# line
echo "----------------------------------------"
echo "$type specifying: $Npar parameters, $Nens ensemble members, $Nstep steps, $Nyears (re)forecast year(s)"

# if verbose

if $verbose
    then # prepend with debug: 
        { sed -e "s/^/debug: /" -e "s/^debug: -/-/" | 
            sed -e "s/^/$(tput setaf 4)/" -e "s/$/$(tput sgr0)/" ;
             } <<EOF
filename_req = $filename_req
filename_date = $filename_date
datetime = $datetime
out_folder = $out_folder
extension = $extension
out_file = $out_file
hdate_line = $hdate_line
EOF
fi


# function  definition (for recursion)
# $1: type: list[_cost]/request
# $2: filename of outfile
# $3: date: YYYY-MM-DD
function send_request() { 
    # if verbose
    if $verbose
        then # prepend with debug if not line: (print dark blue) 
            { sed -e "s/^/debug: /" -e "s/^debug: -/-/" | 
            sed -e "s/^/$(tput setaf 4)/" -e "s/$/$(tput sgr0)/" ;
             } <<EOF 
----------------------------------------
send_request()
1 = $1
2 = $2
3 = $3
----------------------------------------
EOF
    fi
    # recursion: for REQUEST run LIST_COST to check fields
    if [[ $1 == request ]]
        then
            echo "REQUEST: Checking if fields are available"
            #run a list_cost and check fields 
            # if not verbose send output to /dev/null
            send_request list_cost /tmp/$filename_date.list_cost $3 | 
                if $verbose
                    then cat
                    else cat > /dev/null
                fi
            # if not enough fields available, exit
            if [[ $(cat "/tmp/$filename_date.list_cost" | sed -n "s/^number_of_fields=\([0-9]*\);/\1/p") -lt $(($Npar*$Nens*$Nstep)) ]]
                then
                    echo "LIST_COST: Not enough fields available"
                    Navail=$(cat "/tmp/$filename_date.list_cost" | sed -n "s/^number_of_fields=\([0-9]*\);/\1/p")
                    echo "Fields: $Navail/$Nfields"
                    exit 1
            else 
                echo "LIST_COST: All $Nfields fields available"
            fi
            storage=quota | grep /rds-d7 | awk '{print $3-$2}'
            storage_max=quota | grep /rds-d7 | awk '{print $4-$2}'
            filesize=$(cat "/tmp/$filename_date.list_cost" | 
                sed -n "s/^size=\([0-9]*\);/\1/p" | awk "{print int(\$1/61*2.88)}")
            echo "The file size should be $(numfmt --to=iec $filesize)"
            # convert filesize to GB and check if enough storage available
            if (( $(echo "$filesize/1024^3>$storage" | bc) ))
                then
                    echo "WARNING: Not enough storage available, entering grace limit" | sed -e "s/^/$(tput setaf 1)/" -e "s/$/$(tput sgr0)/"
                    MESSAGE="WARNING: Not enough storage available, entering grace limit"
                    curl -s "$TELEGRAM_URL&text=$MESSAGE"
                    if (( $(echo "$filesize/1024^3>$storage_max" |bc) ))
                        then
                            echo "ERROR: Not enough storage available, exiting process" | sed -e "s/^/$(tput setaf 1)/" -e "s/$/$(tput sgr0)/"
                            MESSAGE="ERROR: Not enough storage available, exiting process"
                            curl -s "$TELEGRAM_URL&text=$MESSAGE"
                            exit 1
                    fi
            fi

            rm "/tmp/$filename_date.list_cost"
    fi
    #print start line in colour
    echo "--------------start -----------------" | sed -e "s/^/$(tput setaf 3)/" -e "s/$/$(tput sgr0)/"
    # if request and notif flag is set, send notification
    if [[ $1 == request ]] && $notif
        then
            MESSAGE="Request for $filename_date started"
            curl -s "$TELEGRAM_URL&text=$MESSAGE"
    fi

    cat "requests/$filename_req.req" | 
        sed "s/^#.*//g"| # remove comments
        awk NF | # remove empty lines
        if [[ "$1" == list* ]]
            then
                sed "s/retrieve/list/" 
            else
                cat
        fi |
        if [[ "$1" == *cost ]]
            then
                sed '3 i output = cost,'
            else
                cat
        fi |
        # insert date
        sed "4 i date = $3,"|
        # insert hdate for reforecast
        if [[ $request_letter == "r" ]]
            then
                sed "5 i $hdate_line"
            else
                cat
        fi |
    # main request
    mars -o $2 &&
        # notification if request was successful and notif flag was set
        if [[ $1 == request ]] && $notif
            then
                MESSAGE="Request for $filename_date finished successfully"
                curl -s "$TELEGRAM_URL&text=$MESSAGE"
		echo -e '\n'
        fi
    echo "--------------end -----------------" | sed -e "s/^/$(tput setaf 3)/" -e "s/$/$(tput sgr0)/"
 } 




# ------------------ main ------------------
# call function
send_request $1 $out_file $3 |&
# logging for requests
if [[ $1 == request ]]
    then
        tee "${log_folder}/${filename_date}.log" #-a
    else
        cat
fi
# # for list_cost print size in GB
if [[ $1 == list_cost ]]
    then
        echo "LIST_COST:"
        echo "The total full request size is: $(cat "$out_folder/$filename_date.list_cost" | sed -n "s/^size=\([0-9]*\);/\1/p" | numfmt --to=iec)"
        echo "The cropped size should be $(cat "$out_folder/$filename_date.list_cost" | sed -n "s/^size=\([0-9]*\);/\1/p" | awk "{print int(\$1/61*2.88)}" | numfmt --to=iec)"
        echo "Number of fields requested: $(($Nfields))"
        echo "Number of fields available: $(cat "$out_folder/$filename_date.list_cost" | sed -n "s/^number_of_fields=\([0-9]*\);/\1/p")"
fi

