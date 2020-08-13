#!/bin/bash
today=`date +%a`
bucket=`echo $(aws s3 ls s3://mongo-001 ) | grep -o "dump-01"`
echo "Folder:$bucket"
if [[ $today == "Thu" && $bucket == "dump-01" ]]; then
    aws s3api put-object --bucket mongo-001 --key dump-02/
    echo "Added bucket-2"
    echo "dump-02" > bucket.txt
    echo "1970-01-01T00:00:00Z" > time_now.txt
elif [[ $bucket == "" ]]; then
    aws s3api put-object --bucket mongo-001 --key dump-01/
    echo "Added bucket-1"
    echo "dump-01" > bucket.txt
fi

mongo --quiet --eval  "db.getMongo().getDBNames()"> db.txt
cat db.txt
sed -e 's/\[//g;s/"//g;s/]//g;s/,//g;s/admin//g;s/local//g;s/config//g' db.txt > db2.txt
for i in `cat db2.txt`
do  
    echo "database:$i"
    mongo  $i --quiet --eval "db.getCollectionNames()"> col.txt
    sed -e 's/\[//g;s/"//g;s/]//g;s/,//g' col.txt> col2.txt
    for j in `cat col2.txt`
    do
    echo "col:$j"
    mongodump -d $i -c $j -o dump/
    done 
done

cat bucket.txt
if [[ "$(cat bucket.txt)" == "dump-01" ]]
then
   echo "copied to mongo-001/dump-01"
   aws s3 cp ./dump s3://mongo-001/dump-01 --recursive
else
   echo "copied to mongo-002/dump-02"
   aws s3 cp ./dump s3://mongo-001/dump-02 --recursive
fi
if [[ ($today == "Thu") && "$(cat bucket.txt)" == "dump-02" ]]
then
    aws s3 rm s3://mongo-001/dump-01 --recursive
    echo "deleted mongo-001/dump-01"
elif [[ ($today == "Thu") && "$(cat bucket.txt)" == "dump-01" && $(aws s3 ls s3://mongo-001) != "" ]];
then
    echo "deleted mongo-002/dump-02"
    aws s3 rm s3://mongo-001/dump-02 --recursive
else
    echo "Process Completed"
fi
