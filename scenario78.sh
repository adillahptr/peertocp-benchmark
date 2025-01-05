#!/bin/bash

PROJECT_ID="infra-filament-361106"
USERNAME="adillah_putri"

TOTAL_CLIENTS=$1
DELAY=$2            #minutes
TEST_PLUGIN=$3
TEST_SCENARIO=$4
DURATION=$5
PACKET_LOSS=$6
NETWORK_CONDITION=$7

SERVER_HOSTNAME="server.adillahptr.cloud"
SERVER_EXTERNAL_IP=""

if [[ $TEST_SCENARIO -eq 3 ]] && [[ -n $NETWORK_CONDITION ]]; then
	RESULT_DIR="n$TOTAL_CLIENTS/scenario-7/$NETWORK_CONDITION/"
elif [[ $TEST_SCENARIO -eq 4 ]] && [[ -n $NETWORK_CONDITION ]]; then
	RESULT_DIR="n$TOTAL_CLIENTS/scenario-8/$NETWORK_CONDITION/"
fi

echo $RESULT_DIR

rm -f start_client_log.txt

clients=()

remove_packet_loss() {
	sudo tc qdisc del dev ens4 root
    sudo tc filter del dev ens4 parent ffff: prio 50
}

apply_packet_loss() {
	sudo tc qdisc del dev ens4 root
    sudo tc filter del dev ens4 parent ffff: prio 50

    sudo tc qdisc add dev ens4 root netem loss $1	
}

netd() {
    DIR_NAME=$4

	curl "http://$1:19999/api/v1/data?chart=apps.mem&dimension=node&after=$2&points=0&group=average&gtime=0&timeout=0&format=csv&options=seconds" > $DIR_NAME/mem-$3.csv
	curl "http://$1:19999/api/v1/data?chart=system.ip&after=$2&points=0&group=average&gtime=0&timeout=0&format=csv&options=seconds" > $DIR_NAME/network-$3.csv
	curl "http://$1:19999/api/v1/data?chart=apps.cpu&dimension=node&after=$2&points=0&group=average&gtime=0&timeout=0&format=csv&options=seconds" > $DIR_NAME/cpu-$3.csv
}

scpd() {
	scp -o StrictHostKeyChecking=no -r $USERNAME@$1:~/peertocp-$2/out/ ./$3
}

run_client() {
    SERVER_HOSTNAME=$1
    TEST_DATETIME=$2
    TEST_PLUGIN=$3
    TEST_SCENARIO=$4
    VARIANT=$5
    USERNAME=$6

    cd /home/$USERNAME/peertocp-$VARIANT

    git reset --hard; git pull origin $VARIANT

	sed -i "s|https://[^:]*:3000|https://$SERVER_HOSTNAME:3000|g" renderer/index.js

	sed -i "/const msLeft*/c\const msLeft = Date.parse(\"$TEST_DATETIME\") - Date.now()" renderer/index.js

	sed -i "/const testPlugins*/c\const testPlugins = $TEST_PLUGIN;" renderer/index.js
	sed -i "/const currentTestScenario*/c\const currentTestScenario = $TEST_SCENARIO;" renderer/index.js
	sed -i "/\/\/ checker()/c\checker()" renderer/index.js

	source ~/.nvm/nvm.sh; npm install && rm -rf out && pkill Xvfb; xvfb-run npm start
}

update_dns_record() {
    EXTERNAL_IP=$1

    gcloud dns record-sets update server.adillahptr.cloud \
    --type=A \
    --rrdatas=$EXTERNAL_IP \
    --zone=adillahptr-cloud \
    --ttl=300
}

run_server() {
    VARIANT=$1
    DIR_NAME=""

    if [ "$VARIANT" = "crdt-cs-socketio" ]; then
        DIR_NAME="y-websocket-socketio"
    elif [ "$VARIANT" = "ot-cs-socketio" ]; then
        DIR_NAME="peertocp-ot-server-socketio"
    elif [ "$VARIANT" = "crdt-p2p-socketio" ]; then
        DIR_NAME="y-webrtc-socketio"
    elif [ "$VARIANT" = "crdt-cs-webtransport" ]; then
        DIR_NAME="y-webtransport"
    elif [ "$VARIANT" = "ot-cs-webtransport" ]; then
        DIR_NAME="peertocp-ot-server-webtransport"
    fi

    ssh -f -o StrictHostKeyChecking=no $USERNAME@$SERVER_EXTERNAL_IP "source ~/.nvm/nvm.sh; cd /home/$USERNAME/$DIR_NAME; git reset --hard; git pull; npm install; pkill node; npm start"
}

stop_server_vm() {
    ZONE="us-east1-b"
    INSTANCE_NAME="server"

    echo "Stopping server"
    gcloud compute instances stop $INSTANCE_NAME --zone $ZONE --async
}

stop_client_vm() {
	for client in "${clients[@]}"; do
        IFS=':' read -r INSTANCE_NAME EXTERNAL_IP ZONE <<< "$client"

        echo "Stopping client $INSTANCE_NAME"
        gcloud compute instances stop $INSTANCE_NAME --zone $ZONE --async
    done
}



variants=()
variants+=("crdt-cs-socketio")
variants+=("crdt-p2p-socketio")
variants+=("ot-cs-socketio")
variants+=("crdt-cs-webtransport")
variants+=("ot-cs-webtransport")


ZONE="us-east1-b"
INSTANCE_NAME="server"

gcloud compute instances start $INSTANCE_NAME --zone $ZONE

SERVER_EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone $ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

update_dns_record $SERVER_EXTERNAL_IP

sleep 20

ssh -f -o StrictHostKeyChecking=no $USERNAME@$SERVER_EXTERNAL_IP "$(declare -f apply_packet_loss); apply_packet_loss $PACKET_LOSS"

for i in $(seq 1 $TOTAL_CLIENTS); do
    INSTANCE_NAME="client-$i"

    if [ "$i" -gt 62 ]; then
        ZONE="us-central1-a"
    elif [ "$i" -gt 54 ]; then
        ZONE="us-south1-a"
    elif [ "$i" -gt 46 ]; then
        ZONE="us-west3-a"
    elif [ "$i" -gt 39 ]; then
        ZONE="us-west2-a"
    elif [ "$i" -gt 31 ]; then
        ZONE="us-west4-a"
    elif [ "$i" -gt 23 ]; then
        ZONE="us-west1-a"
    elif [ "$i" -gt 15 ]; then
        ZONE="us-east4-a"
    elif [ "$i" -gt 7 ]; then
        ZONE="us-east5-a"
    else
        ZONE="us-east1-b"
    fi

    echo "Starting instance $INSTANCE_NAME"

    gcloud compute instances start $INSTANCE_NAME --zone $ZONE --async

done

sleep 60

for i in $(seq 1 $TOTAL_CLIENTS); do
    INSTANCE_NAME="client-$i"

    if [ "$i" -gt 62 ]; then
        ZONE="us-central1-a"
    elif [ "$i" -gt 54 ]; then
        ZONE="us-south1-a"
    elif [ "$i" -gt 46 ]; then
        ZONE="us-west3-a"
    elif [ "$i" -gt 39 ]; then
        ZONE="us-west2-a"
    elif [ "$i" -gt 31 ]; then
        ZONE="us-west4-a"
    elif [ "$i" -gt 23 ]; then
        ZONE="us-west1-a"
    elif [ "$i" -gt 15 ]; then
        ZONE="us-east4-a"
    elif [ "$i" -gt 7 ]; then
        ZONE="us-east5-a"
    else
        ZONE="us-east1-b"
    fi

    EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone $ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

    echo "$INSTANCE_NAME $EXTERNAL_IP" >> start_client_log.txt
    
    clients+=($INSTANCE_NAME:$EXTERNAL_IP:$ZONE)
    
done

sleep 20

for client in "${clients[@]}"; do
    IFS=':' read -r INSTANCE_NAME EXTERNAL_IP ZONE <<< "$client"
    ssh -f -o StrictHostKeyChecking=no $USERNAME@$EXTERNAL_IP "$(declare -f apply_packet_loss); apply_packet_loss $PACKET_LOSS"
done

sleep 20

for VARIANT in "${variants[@]}"; do
    rm -rf $RESULT_DIR/$VARIANT/server/*

    run_server $VARIANT

    sleep 20

    TEST_DATETIME=$(TZ="Asia/Bangkok" date -d "+$DELAY minutes" +"%Y-%m-%dT%H:%M:%S.000+07:00")
	TEST_TIME=$(date -d $TEST_DATETIME +%s)

	for client in "${clients[@]}"; do
	    IFS=':' read -r INSTANCE_NAME EXTERNAL_IP ZONE <<< "$client"
	    
	    rm -rf $RESULT_DIR/$VARIANT/$INSTANCE_NAME/*

	    ssh -f -o StrictHostKeyChecking=no $USERNAME@$EXTERNAL_IP "$(declare -f run_client); run_client $SERVER_HOSTNAME $TEST_DATETIME $TEST_PLUGIN $TEST_SCENARIO $VARIANT $USERNAME"
	done

	# Wait until test end
	CURRENT_TIME=$(date +%s)
	diff_time=$(($TEST_TIME-$CURRENT_TIME))
	sleep $(($diff_time+$DURATION))

	echo "Epoch time: $TEST_TIME"

	netd $SERVER_HOSTNAME $TEST_TIME server "$RESULT_DIR/$VARIANT/server"


	for client in "${clients[@]}"; do
	    IFS=':' read -r INSTANCE_NAME EXTERNAL_IP ZONE <<< "$client"
	    netd $EXTERNAL_IP $TEST_TIME $INSTANCE_NAME "$RESULT_DIR/$VARIANT/$INSTANCE_NAME"
	    scpd $EXTERNAL_IP $VARIANT "$RESULT_DIR/$VARIANT/$INSTANCE_NAME"
        ssh -f -o StrictHostKeyChecking=no $USERNAME@$EXTERNAL_IP "$(declare -f remove_packet_loss); remove_packet_loss"
	done
done

ssh -f -o StrictHostKeyChecking=no $USERNAME@$SERVER_EXTERNAL_IP "$(declare -f remove_packet_loss); remove_packet_loss"

stop_server_vm
stop_client_vm