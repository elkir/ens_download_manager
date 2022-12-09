#!/usr/bin/env bash
## 02-04_mars.sh  list[_cost]/request  v04[d,e,...] YYYY-MM-DD

source $CONDA_PREFIX/etc/profile.d/conda.sh
conda activate mars-api;

# print which day of the week date is
echo "The date is $(date -d $3 +%A)";

# grab and define variables
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
filename_date="mars_$2_$3";
datetime=$(date -Iminutes | sed "s/T/ /"| sed "s/+.*//")

Npar=$(($(cat requests/$filename_req.req | sed -n "s/param=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))
Nens=$(($(cat requests/$filename_req.req | sed -n "s/number=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))
Nstep=$(($(cat requests/$filename_req.req | sed -n "s/step=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))



# main request loop with logging 
{ 
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
    mars -o "$out_folder/$filename_date.$extension" && 
    # notification
    if [[ $1 == request ]]
        then
            curl -X POST -H "Content-Type: application/json" \
                -d "{\"value1\":\"($datetime) ECMWF $1 at $(hostname).hpc file: $filename_date\"}" \
               https://maker.ifttt.com/trigger/notify/with/key/dHmvWjsHHJvHLg6ejV48do ;
    fi
 } |&
# logging for requests
if [[ $1 == request ]]
    then
        tee "logs/$filename_date.log" #-a
    else
        cat
fi
# for list_cost print size in GB
if [[ $1 == list_cost ]]
    then
        echo "The total full request size is: $(cat "$out_folder/$filename_date.list_cost" | sed -n "s/^size=\([0-9]*\);/\1/p" | numfmt --to=iec)"
        echo "The cropped size should be $(cat "$out_folder/$filename_date.list_cost" | sed -n "s/^size=\([0-9]*\);/\1/p" | awk "{print int(\$1/61*2.88)}" | numfmt --to=iec)"
        echo "Number of fields requested: $(($Npar*$Nens*$Nstep))"
        echo "Number of fields available: $(cat "$out_folder/$filename_date.list_cost" | sed -n "s/^number_of_fields=\([0-9]*\);/\1/p")"
fi

