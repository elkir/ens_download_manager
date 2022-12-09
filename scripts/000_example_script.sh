#!/bin/bash
 
#this example will filter the area of Europe (N/W/S/E) and interpolate the final fields to a lat/lon 0.5/0.5 degrees
AREA="73.5/-27/33/45"
GRID="0.5/0.5"
  
# fixed selection from the same block
STEP="0/1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/17/18/19/20/21/22/23/24/25/26/27/28/29/30/31/32/33/34/35/36/37/38/39/40/41/42/43/44/45/46/47/48/49/50/51/52/53/54/55/56/57/58/59/60/61/62/63/64/65/66/67/68/69/70/71/72/73/74/75/76/77/78/79/80/81/82/83/84/85/86/87/88/89/90/93/96/99/102/105/108/111/114/117/120/123/126/129/132/135/138/141/144/150/156/162/168/174/180/186/192/198/204/210/216/222/228/234/240/246/252/258/264/270/276/282/288/294/300/306/312/318/324/330/336/342/348/354/360,"
PARAMS="134.128/151.128/165.128/166.128/246.228/247.228"
NUMBER="1/to/50"
  
TIMES="0000"
YEAR="2019"
MONTH="03"
 
for y in ${YEAR}; do
 
  for m in ${MONTH}; do
    #get the number of days for this particular month/year
    days_per_month=$(cal ${m} ${y} | awk 'NF {DAYS = $NF}; END {print DAYS}')
     
    #date loop
    for my_date in $(seq -w 1 ${days_per_month}); do
      my_date=${YEAR}${m}${my_date}
       
      #time lop
      for my_time in ${TIMES}; do
        cat << EOF > my_request_${my_date}_${my_time}.mars
RETRIEVE,
    CLASS      = OD,
    TYPE       = PF,
    STREAM     = ENFO,
    EXPVER     = 0001,
    LEVTYPE    = SFC,
    GRID       = ${GRID},
    AREA       = ${AREA},
    PARAM      = ${PARAMS},
    DATE       = ${my_date},
    TIME       = ${my_time},
    STEP       = ${STEP},
    NUMBER     = ${NUMBER},
    TARGET     = "enfo_pf_${my_date}_${my_time}.grib"
EOF
      mars my_request_${my_date}_${my_time}.mars
      if [ $? -eq 0 ]; then
        rm -f my_request_${my_date}_${my_time}.mars
      fi
      done
    done
  done
done