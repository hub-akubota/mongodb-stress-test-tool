echo "`date "+%Y.%m.%d_%H:%M:%S"`: ----------------------------" 
logfile="data.dat"
tot_count=50

count=0
tot_time=0
echo "`date "+%Y.%m.%d_%H:%M:%S"`: Total : ${tot_count} times" 

while [ ${count} -lt ${tot_count} ]; do
    echo "`date "+%Y.%m.%d_%H:%M:%S"`: count : ${count}" 
    count=$(( count + 1 ))
    write_count=50000
    cnt=0

    # just write
    while [ ${cnt} -lt $((write_count-2000)) ]; do
        cnt=$(( cnt + 1 ))
        ./bin/dbAccessor -J config.json -j t -t chipCfg >> log.txt
    done

    cnt=0
    register_time=0
    retrieve_time=0
    write_time=0
    while [ ${cnt} -lt 1000 ]; do
        cnt=$(( cnt + 1 ))
        num=$RANDOM 
        sed -i "4c\            \"Amp2Vbn\": ${num}," config.json

        # measure time to register
        SECONDS=0
        ./bin/dbAccessor -J config.json -j gj -t chipCfg >> log.txt
        register_time=$((register_time+SECONDS))

        # measure time to just write
        SECONDS=0
        ./bin/dbAccessor -J config.json -j t -t chipCfg >> log.txt
        write_time=$((write_time+SECONDS))
    done

    python monitor.py 

    while [ ${cnt} -lt 1000 ]; do
        # measure time to retrieve
        id=`cat id.txt`
        SECONDS=0
        ./bin/dbAccessor -G config.json -i ${id} -t chipCfg >> log.txt
        retrieve_time=$((retrieve_time+SECONDS))
    done

    files_size=`cat files_size.txt`
    echo "${write_count} ${files_size} ${register_time} ${retrieve_time} ${write_time}" >> ${logfile}
    tot_time=$((tot_time+register_time+retrieve_time+write_time))
done

echo "`date "+%Y.%m.%d_%H:%M:%S"`: ----------------------------" 
echo "`date "+%Y.%m.%d_%H:%M:%S"`: Total counts: ${tot_count} times"
echo "`date "+%Y.%m.%d_%H:%M:%S"`: Total time:   ${tot_time} [s]" 
echo "`date "+%Y.%m.%d_%H:%M:%S"`: Average time: $((tot_time/tot_count)) [s]" 
echo "`date "+%Y.%m.%d_%H:%M:%S"`: ----------------------------"
