# loop through every date in the year 2017 in the format YYYY-MM-DD and print it if the date exists
for i in {2017..2017}-{01..12}-{01..31}; do
    if date -d $i &> /dev/null; then
        echo $i
    fi
done


# loop through every date in the year 2017 in the format YYYY-MM-DD and print it if the date exists and is Monday or Thursday
for i in {2017..2017}-{01..12}-{01..31}; do
    if date -d $i &> /dev/null; then
        if [[ $(date -d $i +%u) == 1 ]] || [[ $(date -d $i +%u) == 4 ]]; then
            echo "$i: $(date -d $i +%u)"
        fi
    fi
done




# check if ssh agent is runnign and start if if not
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval $(ssh-agent -s)
fi


test_command () {
    ls "data/test/file_$1_$(date -d $1 +%a).grib"
}

# loop a command test_command through files in . 
# when it results in an error log that file and the error to errors.log and continue
for i in {2017..2017}-{01..1}-{01..31}; do
    test_command $i || echo $i >> failed_requests.log 
done



# loop through list and execute command test_command multi-threaded
for i in {2017..2017}-{01..12}-{01..31}; do
    test_command $i && touch test2/$i || echo $i >> failed_requests.log &
done


# touch a.txt including parent folder

# colour test_command stdout yellow and stderr red
test_command > >(sed -e "s/^/$(tput setaf 3)/" -e "s/$/$(tput sgr0)/") 2> >(sed -e "s/^/$(tput setaf 1)/" -e "s/$/$(tput sgr0)/" >&2)

cat requests/mars_request_01_full_list_cost.req | mars -o /tmp/list_cost 
 ls /tmp/list_cost
 # output /tmp/list_cost in red
    cat /tmp/list_cost | sed -e "s/^/$(tput setaf 1)/" -e "s/$/$(tput sgr0)/"
 rm /tmp/list_cost
