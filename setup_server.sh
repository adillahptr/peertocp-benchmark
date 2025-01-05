#!/bin/bash

PROJECT_ID="infra-filament-361106"
ZONE="us-east1-b"
MACHINE_TYPE="e2-medium"
IMAGE_FAMILY="debian-11"
IMAGE_PROJECT="debian-cloud"
USERNAME="adillah_putri"

setup_server() {
    sudo apt update
    sudo apt install git xvfb zip curl -y
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

    git clone https://github.com/adillahptr/y-websocket-socketio.git
    cd y-websocket-socketio
    npm install
    cd ..

    git clone https://github.com/adillahptr/peertocp-ot-server-socketio.git
    cd peertocp-ot-server-socketio
    npm install
    cd ..

    git clone https://github.com/adillahptr/y-webrtc-socketio.git
    cd y-webrtc-socketio
    npm install
    cd ..

    git clone https://github.com/adillahptr/y-webtransport.git
    cd y-webtransport
    npm install
    cd ..

    git clone https://github.com/adillahptr/peertocp-ot-server-webtransport.git
    cd peertocp-ot-server-webtransport
    npm install
    cd ..
}

INSTANCE_NAME="server"
CERTIFICATE_FILE="../certs/certificate.crt"
PRIV_KEY_FILE="../certs/private.key"

echo "Creating VM instance: $INSTANCE_NAME"

gcloud compute instances create "$INSTANCE_NAME" \
    --zone "$ZONE" \
    --machine-type "$MACHINE_TYPE" \
    --image-family "$IMAGE_FAMILY" \
    --image-project "$IMAGE_PROJECT" \
    --project "$PROJECT_ID" \
    --tags allow-all

EXTERNAL_IP=$(gcloud compute instances describe "$INSTANCE_NAME" --zone "$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

sleep 20

echo "Setting up server"
ssh -o StrictHostKeyChecking=no $USERNAME@$EXTERNAL_IP "$(declare -f setup_server); setup_server"

scp -o StrictHostKeyChecking=no $CERTIFICATE_FILE $PRIV_KEY_FILE $USERNAME@$EXTERNAL_IP:/home/$USERNAME/y-websocket-socketio/bin
scp -o StrictHostKeyChecking=no $CERTIFICATE_FILE $PRIV_KEY_FILE $USERNAME@$EXTERNAL_IP:/home/$USERNAME/peertocp-ot-server-socketio
scp -o StrictHostKeyChecking=no $CERTIFICATE_FILE $PRIV_KEY_FILE $USERNAME@$EXTERNAL_IP:/home/$USERNAME/y-webrtc-socketio/bin
scp -o StrictHostKeyChecking=no $CERTIFICATE_FILE $PRIV_KEY_FILE $USERNAME@$EXTERNAL_IP:/home/$USERNAME/y-webtransport/bin
scp -o StrictHostKeyChecking=no $CERTIFICATE_FILE $PRIV_KEY_FILE $USERNAME@$EXTERNAL_IP:/home/$USERNAME/peertocp-ot-server-webtransport

echo "Stopping VM instance"
gcloud compute instances stop "$INSTANCE_NAME" --zone "$ZONE"