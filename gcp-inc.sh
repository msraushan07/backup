#!/bin/bash
today=`date "+%A-%H:%M"`
bucket=`echo $(gsutil ls gs://videous-dump/ ) | grep -o "dump-01"`
bucket2=`echo $(gsutil ls gs://videous-dump/ ) | grep -o "dump-02"`
echo "Bucket contains(dump-01):$bucket"
echo "Bucket2 contains(dump-02):$bucket2"
mkdir -p dump

if [[ ! -f "time_now.txt" ]];
then
    echo "1970-01-01T00:00:00Z added to time_now.txt since time_now.txt not present"
    touch time_now.txt 
    echo "1970-01-01T00:00:00Z" > time_now.txt
fi


if [[ $bucket == "dump-01" && ! ($today == "Monday-19:30") ]];
then
    echo "Again creating directory dump-01"
    mkdir -p dump-01
elif [[ $bucket2 == "dump-02" && ! ($today == "Monday-19:30") ]];
then
    echo "Again creating directory dump-02"
    mkdir -p dump-02
fi

if [[ $today == "Monday-19:30" && $bucket == "dump-01" ]];
then
    mkdir -p dump-02
    echo "Added bucket-2"
    echo "dump-02" > bucket.txt
    echo "1970-01-01T00:00:00Z" > time_now.txt
    
elif [[ $bucket == "" ]]; 
then
    mkdir -p dump-01
    echo "Added bucket-1"
    echo "dump-01" > bucket.txt
    echo "1970-01-01T00:00:00Z" > time_now.txt
fi



last_date=\"$(cat time_now.txt)\"
DATE=`date -u +%FT%TZ`
echo "Dumper script running for time : $last_date"
mongo --quiet "mongodb://dumper:sXtnNufLT5LvvqZFP87deVGBxhYqDQxv8U6DRdnsaRVum35x5rHKRHVJSq5PXGpC@mongo.01.videous.io:27017,mongo.02.videous.io:27017,mongo.03.videous.io:27017/?authSource=videous&replicaSet=rs0&readPreference=secondary"  --eval  "db.getMongo().getDBNames()"> db.txt
cat db.txt
sed -e 's/\[//g;s/"//g;s/]//g;s/,//g;s/admin//g;s/local//g;s/config//g' db.txt | tail -n +6 > db2.txt
cat db2.txt
for i in `cat db2.txt`
do  
    echo "db:$i"
    mongo "mongodb://dumper:sXtnNufLT5LvvqZFP87deVGBxhYqDQxv8U6DRdnsaRVum35x5rHKRHVJSq5PXGpC@mongo.01.videous.io:27017,mongo.02.videous.io:27017,mongo.03.videous.io:27017/$i?authSource=videous&replicaSet=rs0&readPreference=secondary" --quiet --eval  "db.getCollectionNames()"> col.txt
    sed -e 's/\[//g;s/"//g;s/]//g;s/,//g'  col.txt | tail -n +6 > col2.txt
    for j in `cat col2.txt`
    do
    echo "col:$j"
    mongodump --uri="mongodb://dumper:sXtnNufLT5LvvqZFP87deVGBxhYqDQxv8U6DRdnsaRVum35x5rHKRHVJSq5PXGpC@mongo.01.videous.io:27017,mongo.02.videous.io:27017,mongo.03.videous.io:27017/$i?authSource=videous&replicaSet=rs0&readPreference=secondary" --collection ${j} --query "{\"updatedAt\": { \"\$gt\" : { \"\$date\": $last_date } } }" --out ${Output_Directory}
    done 
done

echo "$DATE" | cat > time_now.txt

tar -czvf ./dump-$DATE.tar.gz ${Output_Directory} -C /tmp
cat bucket.txt
if [[ "$(cat bucket.txt)" == "dump-01" ]]
then
   echo "copied to dump-01...."
   mv -f ./dump-$DATE.tar.gz ./dump-01
   gsutil -m -o GSUtil:parallel_composite_upload_threshold=150M cp -r ./dump-01 gs://videous-dump/
   rm -rf dump-01 ${Output_Directory}
else
   echo "copied to dump-02...."
   mv -f ./dump-$DATE.tar.gz ./dump-02
   gsutil -m -o GSUtil:parallel_composite_upload_threshold=150M cp -r ./dump-02 gs://videous-dump/
   rm -rf dump-02 ${Output_Directory}
fi



CH=`echo $(gsutil ls gs://videous-dump/ ) | grep -o "dump-02"`
echo "CH:$CH"
if [[ ($today == "Monday-19:30") && "$(cat bucket.txt)" == "dump-02" ]]
then
    gsutil -m rm gs://videous-dump/dump-01/**
    echo "deleted dump-01...."
elif [[ ($today == "Monday-19:30") && "$(cat bucket.txt)" == "dump-01" && ("dump-02" == $CH) ]];
then
    gsutil -m rm  gs://videous-dump/dump-02/**
    echo "deleted dump-02...."
else
    echo "Process Completed"
fi
                                 
