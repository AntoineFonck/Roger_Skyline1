#!/bin/bash

## Import lib 
#

. ./lib.sh

## Error check
#

if [ $# != 3 ]; then
	echo -e "$RED[ERROR]$END $CYA provide server <USERNAME>, <IP> and <PORT>$END" && exit
fi

## Variables definition
#

USER=$1
IP=$2
PORT=$3
SSH_KEY_PRI=id_rs1_opt
SSH_KEY_PUB=$SSH_KEY_PRI.pub

main() {

ok_msg "launching main setup.sh ..."

## Configure ssh keys
#

ssh-keygen -f ~/.ssh/$SSH_KEY_PRI -t rsa -b 4096 
ch_err
ok_msg "ssh keys $SSH_KEY_PRI generated"
ssh-copy-id -i ~/.ssh/$SSH_KEY_PUB -p $PORT $USER@$IP
ch_err
ok_msg "ssh key $SSH_KEY_PUB copied to server"


##  ssh connection
#

scp -rP $PORT ./* $USER@$IP:/home/$USER
ch_err
ok_msg "file in . copied to $USER@$IP:/home/$USER"

}

main
