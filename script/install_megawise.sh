#!/bin/bash

if [ $# -eq 1 ];then
	dir_location=$1
	megawise_tag=0.4.0
elif [ $# -eq 2 ];then
	dir_location=$1
	megawise_tag=$2
else
	echo "Error: please use install_megawise.sh [path(required)] [megawise_tag(optional)] to run it."
	exit -1
fi

if [ -d ${dir_location} ];then
	echo "Error: file /home/zilliz/megawise already exists, please try again."
  	exit 0
fi

echo "magawise_tag :" $megawise_tag
mkdir ${dir_location}/
docker pull zilliz/megawise:$megawise_tag

if [ -d ${dir_location} ];then
    echo "Information: installation manual : ${dir_location}."
else
    echo "Error: can't create ${dir_location}, please check out the permission."
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
if [ -f "/tmp/nyc_taxi_data.csv" ];then
	echo "Warning: /tmp/nyc_taxi_data.csv already exists, you can delete it."
else
	wget -P /tmp https://raw.githubusercontent.com/Infini-Analytics/infini/master/sample_data/nyc_taxi_data.csv
fi
echo "Information: Configuration parameter"
echo " 1.egawise username:        MEGAWISE_USER=zilliz"
echo " 2.megawise password:       MEGAWISE_PWD=zilliz"
echo " 3.megawise database name:  MEGAWISE_DB=postgres"
echo " 4.megawise port            MEGAWISE_PORT=5433"

mkdir ${dir_location}/data
mkdir ${dir_location}/server_data
docker run --gpus all --shm-size 4294967296 \
 -v ${dir_location}/conf:/megawise/conf  \
 -v ${dir_location}/data:/megawise/data  \
 -v ${dir_location}/server_data:/megawise/server_data  \
 -v $HOME/.nv:/home/megawise/.nv  \
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
		echo "Error: start megawise in docker failed, please check it."
		exit -1
	fi
	TRY_CNT=$[$TRY_CNT + 1]
done

echo "State: start megawise in docker successfully!"

container_id=$(docker ps |grep ${megawise_image_id} |awk '{printf "%s\n",$1}')

echo "State: copying example data into meagwise.......please wait....."
docker exec -u megawise -it ${container_id} /tmp/data_import.sh
if [ $? -ne 0 ]; then
    echo "Error: import test data failed, you do it by hand using data_import.sh!"
    exit 0
else
	echo "State: Successfully installed MegaWise and imported test data"
fi
echo "listen_addresses = '*'" >> ${dir_location}/data/postgresql.conf
echo "host    all             all             0.0.0.0/0          password" >> ${dir_location}/data/pg_hba.conf

docker restart ${container_id}

echo "State: restart megawise successfully! Finished!"
