#!/usr/bin/env bash
## 02-02_mars.sh list/list_cost/request filename

source $CONDA_PREFIX/etc/profile.d/conda.sh
conda activate mars-api;

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

filename="$2";
datetime=$(date -Iminutes | sed "s/T/ /"| sed "s/+.*//")

Npar=$(($(cat requests/$filename.req | sed -n "s/param=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))
Nens=$(($(cat requests/$filename.req | sed -n "s/number=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))
Nstep=$(($(cat requests/$filename.req | sed -n "s/step=\(.*\)/\1/p" | tr -dc "/" | wc -c )+1))



# main request loop with logging 
{ 
    cat "requests/$filename.req" | 
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
    # main request
    mars -o "$out_folder/$filename.$extension" && 
    # notification
    curl -X POST -H "Content-Type: application/json" \
        -d "{\"value1\":\"($datetime) ECMWF $1 at $(hostname).hpc file: $filename\"}" \
       https://maker.ifttt.com/trigger/notify/with/key/dHmvWjsHHJvHLg6ejV48do ;
    echo -e "\n"

 } |&
# logging for requests
if [[ $1 == request ]]
    then
        tee "logs/$filename.log" #-a
    else
        cat
fi
# for list_cost print size in GB
if [[ $1 == list_cost ]]
    then
        echo "The total request size is:"
        cat "$out_folder/$filename.list_cost" | sed -n "s/^size=\([0-9]*\);/\1/p" | numfmt --to=iec
        echo "Number of fields requested:"
        echo "$(($Npar*$Nens*$Nstep))"
        echo "Number of fields available:"
        cat "$out_folder/$filename.list_cost" | sed -n "s/^number_of_fields=\([0-9]*\);/\1/p"
fi