#!/bin/bash

if [ $# -eq 1 ];then
	dir_location=$1
	megawise_tag=0.3.0-d091919-1679
elif [ $# -eq 2 ];then
	dir_location=$1
	megawise_tag=$2
else
	echo "usage install_megawise.sh /path/to/data_dir "
	exit -1
fi

echo "magawise_tag :" $megawise_tag

docker pull zilliz/megawise:$megawise_tag

if [ -d ${dir_location} ];then
	echo "the catelog has already existed"
    exit 0
fi

mkdir $dir_location

if [ -d ${dir_location} ];then
    echo "data location :" $dir_location
else
    echo "can't create $dir_location"
    exit -1
fi

cp data_import.sh /tmp
megawise_image_id=$(docker images |grep "zilliz/megawise" | grep "$megawise_tag" \
 |awk '{printf "%s\n",$3}')
echo "megawise_image_id:" $megawise_image_id

MEGAWISE_CNT=$(docker ps | grep $megawise_image_id | wc -l)

if [ $MEGAWISE_CNT -ne 0 ];then
	echo "megawise is running..."
	exit 0
fi

mkdir ${dir_location}/conf

wget -P ${dir_location}/conf https://raw.githubusercontent.com/Infini-Analytics/infini/master/config/db/chewie_main.yaml
wget -P ${dir_location}/conf https://raw.githubusercontent.com/Infini-Analytics/infini/master/config/db/etcd.yaml
wget -P ${dir_location}/conf https://raw.githubusercontent.com/Infini-Analytics/infini/master/config/db/megawise_config.yaml
wget -P ${dir_location}/conf https://raw.githubusercontent.com/Infini-Analytics/infini/master/config/db/megawise_config_template.yaml
wget -P ${dir_location}/conf https://raw.githubusercontent.com/Infini-Analytics/infini/master/config/db/render_engine.yaml
wget -P ${dir_location}/conf https://raw.githubusercontent.com/Infini-Analytics/infini/master/config/db/scheduler_config_template.yaml
wget -P /tmp https://raw.githubusercontent.com/Infini-Analytics/infini/master/sample_data/nyc_taxi_data.csv

mkdir ${dir_location}/data
mkdir ${dir_location}/server_data

docker run --gpus all --shm-size 17179869184 \
 -v ${dir_location}/conf:/megawise/conf  \
 -v ${dir_location}/data:/megawise/data  \
 -v ${dir_location}/server_data:/megawise/server_data  \
 -v /tmp:/tmp  \
 -p 5433:5432  \
 -d  \
 ${megawise_image_id}

IS_RUN=$(docker ps | grep ${megawise_image_id} | wc -l)
TRY_CNT=0
while [ $IS_RUN -eq 0 ];do
	sleep 1
	IS_RUN=$(docker ps | grep ${megawise_image_id} | wc -l)
	if [ $TRY_CNT -ge 60 ];then
		echo "start megawise in docker failed, check config please..."
		exit -1
	fi
	TRY_CNT=$[$TRY_CNT + 1]
done

echo "start megawise in docker"

container_id=$(docker ps |grep ${megawise_image_id} |awk '{printf "%s\n",$1}')

echo "copying example data into meagwise"
docker exec -u megawise -it ${container_id} /tmp/data_import.sh
echo "copy example data into megawise finished"

echo "listen_addresses = '*'" >> ${dir_location}/data/postgresql.conf
echo "host    all             all             0.0.0.0/0          password" >> ${dir_location}/data/pg_hba.conf

docker restart ${container_id}

echo "finished..."
