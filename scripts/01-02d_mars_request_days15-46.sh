conda activate mars-api;
filename="mars_v02d_2017-07-10";
{ 
    cat "requests/$filename.req" | 
    sed "s/^#.*//g" |
    # sed "s/retrieve/list/" | 
    # sed '3 i output = cost,' | 
    mars -o "data/$filename.grib" && 
    curl -X POST -H "Content-Type: application/json" \
        -d "{\"value1\":\"(2022-12-01 18:58) ECMWF 61GB request at $(hostname).hpc, file: $filename\"}" \
        https://maker.ifttt.com/trigger/notify/with/key/dHmvWjsHHJvHLg6ejV48do
; } &2>1 |
tee -a "logs/$filename.log" &&
