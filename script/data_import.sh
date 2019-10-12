#!/bin/bash
#需要提前将数据导入到 '/tmp'下面
#create database user and import data
IS_RUN=$(ps ax | grep "megawise_server" | wc -l)
while [ $IS_RUN -le 1 ];do
	sleep 1
	IS_RUN=$(ps ax | grep "megawise_server" | wc -l)
done


IS_RUN=$(ls /megawise/data/ | grep "postmaster.pid" | wc -l)
while [ $IS_RUN -le 0 ];do
	sleep 1
	IS_RUN=$(ls /megawise/data/ | grep "postmaster.pid" | wc -l)
done

sleep 5

process_id=$(sed -n '1p' /megawise/data/postmaster.pid)

IS_RUN=$(ps ax | grep postgres |grep ${process_id} | wc -l)
while [ $IS_RUN -le 0 ];do
	sleep 1
	IS_RUN=$(ps ax | grep postgres |grep ${process_id} | wc -l)
done

sleep 3
/megawise/bin/psql postgres <<EOF
CREATE USER zilliz WITH PASSWORD 'zilliz';
grant all privileges on database postgres to zilliz;
drop extension if exists zdb_fdw;
create extension zdb_fdw;
EOF
/megawise/bin/psql postgres -U zilliz <<EOF
drop table if exists nyc_taxi;
create table nyc_taxi(
    vendor_id text,
    tpep_pickup_datetime timestamp,
    tpep_dropoff_datetime timestamp,
    passenger_count int,
    trip_distance float,
    pickup_longitute float,
    pickup_latitute float,
    dropoff_longitute float,
    dropoff_latitute float,
    fare_amount float,
    tip_amount float,
    total_amount float
    );
copy nyc_taxi from '/tmp/nyc_taxi_data.csv'
 WITH DELIMITER ',' csv header;
select count(*) from nyc_taxi;
EOF
