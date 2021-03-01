#!/bin/bash

FILENAME=$1

if [ "$#" -ne 1 ]; then
    echo "You must enter exactly 1 command line arguments!"
    echo "The first param must be the file with the configuration!"
    exit 127
fi

if [[ ! -f ${FILENAME} ]]; then
    echo "File ${FILENAME} doesn't exist."
    echo "The first param must be the file with the configuration!"
    exit 127
fi

source "${FILENAME}"

count=0

for i in ${machines}; do
    listOfMachines[${count}]=${i}
    result[${count}]=$(mysql -u ${USER} -p${PASSWD} -h ${i} --execute="SHOW STATUS LIKE 'wsrep_last_committed';" 2> /dev/null | tr -dc '0-9')

    if [[ -z ${result[${count}]} ]]; then
        echo "CRITICAL -  mariadb_replication_check - ${i}: An error appeared while connecting mariadb."
        exit 2
    fi
    count=$(expr ${count} + 1)
done

for i in $(seq 0 $(expr ${count} - 2)); do
    if [[ ${result[i]} -ne ${result[i+1]} ]]; then
        echo "CRITICAL -  mariadb_replication_check - The result from ${machines[1]} (${result[i]}) is not equal to the result from ${machines[i+1]} (${result[i+1]})"
        exit 2
    fi
done

echo "OK - mariadb_replication_check - OK"
exit 0
