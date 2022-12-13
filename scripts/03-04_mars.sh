#!/usr/bin/env bash
## 02-04_mars.sh  
# arguments
# $1: type: list[_cost]/request
# $2: version: v04[d,e,...]
# $3: date: YYYY-MM-DD

# check if all arguments are given
if [[ $# -ne 3 ]]
    then
        echo "Usage: $0 <type> <version> <date>"
        exit 1
fi


conda activate mars-api;

# print which day of the week date is (in cyan)
echo "The date is $(date -d $3 +%A)" | sed -e "s/^/$(tput setaf 6)/" -e "s/$/$(tput sgr0)/"

# grab and define output folder and extension
if [[ $1 == list* ]]
    then
        out_folder="lists"
elif [[ $1 == request ]]
    then
        out_folder="data"
    else
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

Npar=$(($(cat requests/$filename_req.req | sed -n "s/param=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))
Nens=$(($(cat requests/$filename_req.req | sed -n "s/number=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))
Nstep=$(($(cat requests/$filename_req.req | sed -n "s/step=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))
Nfields=$(($Npar*$Nens*$Nstep))


# function  definition (for recursion)
# $1: type: list[_cost]/request
# $2: filename of outfile
# $3: date: YYYY-MM-DD
function send_request() { 
    # recursion: run list_cost to check fields
    if [[ $1 == request ]]
        then
            echo "REQUEST: Checking if fields are available"
            #TODO run a request and check fields 
            send_request list_cost /tmp/$filename_date.list_cost $3 
            if [[ $(cat "/tmp/$filename_date.list_cost" | sed -n "s/^number_of_fields=\([0-9]*\);/\1/p") -lt $(($Npar*$Nens*$Nstep)) ]]
                then
                    echo "LIST_COST Not enough fields available"
                    Navail=$(cat "/tmp/$filename_date.list_cost" | sed -n "s/^number_of_fields=\([0-9]*\);/\1/p")
                    echo "Fields: $Navail/$Nfields"
                    exit 1
            else 
                echo "LIST_COST: All $Nfields fields available"
            fi
            filesize=$(cat "/tmp/$filename_date.list_cost" | sed -n "s/^size=\([0-9]*\);/\1/p" | awk "{print int(\$1/61*2.88)}")
            echo "The file size should be $(numfmt --to=iec $filesize)"
            # rm /tmp/$filename_date.list_cost
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
    tee "/tmp/$filename_date.req" | # save request to file
    # main request
    # print in colour
    sed -e "s/^/$(tput setaf 2)/" -e "s/$/$(tput sgr0)/" 
    # print line in colour
    echo "---------------------------------"    | sed -e "s/^/$(tput setaf 3)/" -e "s/$/$(tput sgr0)/"

    # print all input parameters
 
    echo "1 = $1"
    echo "2 = $2"
    echo "3 = $3"

    echo "---------------------------------"    | sed -e "s/^/$(tput setaf 3)/" -e "s/$/$(tput sgr0)/"

    # if list_cost 
    if [[ $1 == list_cost ]]
        then
            cat /tmp/$filename_date.req | mars -o $2 > /dev/null
    else
        # print request code only
        cat << EOF
mars -o $2 &&
# notification if request was successful
        if [[ $1 == request ]]
            then
                curl -X POST -H "Content-Type: application/json" \
                    -d "{\"value1\":\"($datetime) ECMWF $1 at $(hostname).hpc file: $filename_date\"}" \
                   https://maker.ifttt.com/trigger/notify/with/key/dHmvWjsHHJvHLg6ejV48do ;
        fi
EOF

    fi

    

#     echo <<EOF
#         mars -o "$out_folder/$filename_date.$extension" && 
#         # notification if request was successful
#         if [[ $1 == request ]]
#             then
#                 curl -X POST -H "Content-Type: application/json" \
#                     -d "{\"value1\":\"($datetime) ECMWF $1 at $(hostname).hpc file: $filename_date\"}" \
#                    https://maker.ifttt.com/trigger/notify/with/key/dHmvWjsHHJvHLg6ejV48do ;
#         fi
# EOF

    # print end line in colour
    echo "--------------end -----------------" | sed -e "s/^/$(tput setaf 3)/" -e "s/$/$(tput sgr0)/"

 } 

echo "Npar = $Npar"
echo "Nens = $Nens"
echo "Nstep = $Nstep"
echo "Nfields = $((Npar*Nens*Nstep))" | sed -e "s/^/$(tput setaf 1)/" -e "s/$/$(tput sgr0)/"
echo "filename_req = $filename_req"
echo "filename_date = $filename_date"
echo "datetime = $datetime"
echo "out_folder = $out_folder"
echo "extension = $extension"
 
send_request $1 "$out_folder/$filename_date.$extension" $3
#  |&
# # logging for requests
# if [[ $1 == request ]]
#     then
#         tee "logs/$filename_date.log" #-a
#     else
#         cat
# fi
# # for list_cost print size in GB
if [[ $1 == list_cost ]]
    then
        echo "The total full request size is: $(cat "$out_folder/$filename_date.list_cost" | sed -n "s/^size=\([0-9]*\);/\1/p" | numfmt --to=iec)"
        echo "The cropped size should be $(cat "$out_folder/$filename_date.list_cost" | sed -n "s/^size=\([0-9]*\);/\1/p" | awk "{print int(\$1/61*2.88)}" | numfmt --to=iec)"
        echo "Number of fields requested: $(($Npar*$Nens*$Nstep))"
        echo "Number of fields available: $(cat "$out_folder/$filename_date.list_cost" | sed -n "s/^number_of_fields=\([0-9]*\);/\1/p")"
fi

