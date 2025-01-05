#!/bin/bash

PROJECT_ID="infra-filament-361106"
MACHINE_TYPE="e2-small"
IMAGE_FAMILY="debian-11"
IMAGE_PROJECT="debian-cloud"
USERNAME="adillah_putri"

setup_client() {
    sudo apt update
    sudo apt install git xvfb zip curl speedtest-cli -y
    sudo apt install -y wget screen nginx python-is-python3 g++ make
    sudo apt install -y build-essential clang libdbus-1-dev libgtk2.0-dev \
                   libnotify-dev libgconf2-dev libgbm-dev \
                   libasound2-dev libcap-dev libcups2-dev libxtst-dev \
                   libxss1 libnss3-dev libnss3 libatk1.0-0 libcups2 libgtk-3-0 \
                   libatk-bridge2.0-0 gcc-multilib g++-multilib libasound2 xvfb

    export DISPLAY=192.168.0.5:0.0

    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
    source ~/.bashrc

    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    nvm install 18

    wget https://github.com/netdata/netdata/releases/download/v1.35.0/netdata-latest.gz.run && echo y | sudo sh netdata-latest.gz.run

    git config --global user.name "Adillah Putri"
    git config --global user.email "adllhputri@gmail.com"

    git clone -b crdt-cs-socketio --single-branch https://github.com/adillahptr/peertocp.git && mv peertocp peertocp-crdt-cs-socketio
    cd peertocp-crdt-cs-socketio
    npm install
    cd ..

    git clone -b ot-cs-socketio --single-branch https://github.com/adillahptr/peertocp.git && mv peertocp peertocp-ot-cs-socketio
    cd peertocp-ot-cs-socketio
    npm install
    cd ..

    git clone -b crdt-p2p-socketio --single-branch https://github.com/adillahptr/peertocp.git && mv peertocp peertocp-crdt-p2p-socketio
    cd peertocp-crdt-p2p-socketio
    npm install
    cd ..

    git clone -b crdt-cs-webtransport --single-branch https://github.com/adillahptr/peertocp.git && mv peertocp peertocp-crdt-cs-webtransport
    cd peertocp-crdt-cs-webtransport
    npm install
    cd ..

    git clone -b ot-cs-webtransport --single-branch https://github.com/adillahptr/peertocp.git && mv peertocp peertocp-ot-cs-webtransport
    cd peertocp-ot-cs-webtransport
    npm install
    cd ..
}

CLIENTS_TOTAL=$1

for i in $(seq 2 $CLIENTS_TOTAL); do
    INSTANCE_NAME="client-$i"

    echo "Creating VM instance: $INSTANCE_NAME"

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

    gcloud compute instances create "$INSTANCE_NAME" \
        --zone "$ZONE" \
        --machine-type "$MACHINE_TYPE" \
        --image-family "$IMAGE_FAMILY" \
        --image-project "$IMAGE_PROJECT" \
        --project "$PROJECT_ID" \
        --tags allow-all

    EXTERNAL_IP=$(gcloud compute instances describe "$INSTANCE_NAME" --zone "$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

    sleep 20

    echo "Setting up client"
    ssh -o StrictHostKeyChecking=no $USERNAME@$EXTERNAL_IP "$(declare -f setup_client); setup_client"

    echo "Stopping VM instance"
    gcloud compute instances stop "$INSTANCE_NAME" --zone "$ZONE" --async
done