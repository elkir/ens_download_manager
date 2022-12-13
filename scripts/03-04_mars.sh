#!/usr/bin/env bash
## 02-04_mars.sh  
# arguments
# $1: type: list[_cost]/request
# $2: version: v04[d,e,...]
# $3: date: YYYY-MM-DD

#check for optional -v flag
if [[ $1 == "-v" ]]
    then
        verbose=true
        shift
    else
        verbose=false
fi

#check for notif flag
if [[ $1 == "-N" ]]
    then
        notif=true
        shift
    else
        notif=false
fi

# check if all arguments are given
if [[ $# -ne 3 ]]
    then
        echo "Usage: $0 [-v] [-N] <type> <version> <date>"
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

filename_req="mars_$2_europe";
filename_date="mars_$2_$3_$(date -d $3 +%a)"; #date + Mon/Thu
datetime=$(date -Iminutes | sed "s/T/ /"| sed "s/+.*//")
out_file="$out_folder/$filename_date.$extension"

Npar=$(($(cat requests/$filename_req.req | sed -n "s/param=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))
Nens=$(($(cat requests/$filename_req.req | sed -n "s/number=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))
Nstep=$(($(cat requests/$filename_req.req | sed -n "s/step=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))
Nfields=$(($Npar*$Nens*$Nstep))


# capitalize type
type=$(echo $1 | awk '{print toupper($0)}')
# line
echo "----------------------------------------"
echo "$type specifying: $Npar parameters, $Nens ensemble members, $Nstep steps"

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
            filesize=$(cat "/tmp/$filename_date.list_cost" | sed -n "s/^size=\([0-9]*\);/\1/p" | awk "{print int(\$1/61*2.88)}")
            echo "The file size should be $(numfmt --to=iec $filesize)"
            rm /tmp/$filename_date.list_cost
    fi
    #print start line in colour
    echo "--------------start -----------------" | sed -e "s/^/$(tput setaf 3)/" -e "s/$/$(tput sgr0)/"

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
    # main request
    mars -o $2 &&
        # notification if request was successful and notif flag was set
        if [[ $1 == request ]] && $notif
            then
                curl -X POST -H "Content-Type: application/json" \
                    -d "{\"value1\":\"($datetime) ECMWF $1 at $(hostname).hpc file: $filename_date\"}" \
                   https://maker.ifttt.com/trigger/notify/with/key/dHmvWjsHHJvHLg6ejV48do ;
        fi
    echo "--------------end -----------------" | sed -e "s/^/$(tput setaf 3)/" -e "s/$/$(tput sgr0)/"
 } 

# ------------------ main ------------------
# call function
send_request $1 $out_file $3 |&
# logging for requests
if [[ $1 == request ]]
    then
        tee "logs/$filename_date.log" #-a
    else
        cat
fi
# # for list_cost print size in GB
if [[ $1 == list_cost ]]
    then
        echo "LIST_COST:"
        echo "The total full request size is: $(cat "$out_folder/$filename_date.list_cost" | sed -n "s/^size=\([0-9]*\);/\1/p" | numfmt --to=iec)"
        echo "The cropped size should be $(cat "$out_folder/$filename_date.list_cost" | sed -n "s/^size=\([0-9]*\);/\1/p" | awk "{print int(\$1/61*2.88)}" | numfmt --to=iec)"
        echo "Number of fields requested: $(($Npar*$Nens*$Nstep))"
        echo "Number of fields available: $(cat "$out_folder/$filename_date.list_cost" | sed -n "s/^number_of_fields=\([0-9]*\);/\1/p")"
fi

