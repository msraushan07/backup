#!/bin/bash
today=`date +%a`
bucket=`echo $(aws s3 ls "s3://${BUCKET_NAME}" 2>&1) | grep -o "mongo-001"`
echo "mongo-001:$bucket"
if [[ $today == "Thu" && $bucket == "mongo-001" ]]; then
    aws s3 mb s3://mongo-002 --region=ap-south-1 
    echo "Added bucket-2"
    echo "mongo-002" > bucket.txt
    echo "1970-01-01T00:00:00Z" > time_now.txt
elif [[ $bucket == "" ]]; then
    aws s3 mb s3://mongo-001 --region=ap-south-1 
    echo "Added bucket-1"
    echo "mongo-001" > bucket.txt
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
if [[ "$(cat bucket.txt)" == "mongo-001" ]]
then
   echo "copied to mongo-001"
   aws s3 cp ./dump s3://mongo-001/ --recursive
else
   echo "copied to mongo-002"
   aws s3 cp ./dump s3://mongo-002/ --recursive
fi
if [[ ($today == "Thu") && "$(cat bucket.txt)" == "mongo-002" ]]
then
    aws s3 rb s3://mongo-001 --force
    echo "deleted mongo-001"
elif [[ ($today == "Thu") && "$(cat bucket.txt)" == "mongo-001" ]];
then
    echo "deletedmongo-002"
    aws s3 rb s3://mongo-002 --force
else
    echo "Process Completed"
fi
