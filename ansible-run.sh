#!/bin/bash

#Объявляем переменные
server_ip=$1
master_ip=$2
worker_ip=$3

#Подключаемся к каждой ВМ
while : ; do
ssh -q -o "StrictHostKeyChecking=no" -o "ConnectTimeout=10" ubuntu@$master_ip exit && ssh -q -o "StrictHostKeyChecking=no" -o "ConnectTimeout=10" ubuntu@$worker_ip exit && ssh -q -o "StrictHostKeyChecking=no" -o "ConnectTimeout=10" ubuntu@$server_ip exit
[ $? -eq 0 ]&& break
echo "Waiting for instances initialization..."
done

#Запускаем playbook с inventory
echo "CONNECTING TO INSTANCES FOR PROVISIONING..."
ansible-playbook -i inventory playbook.yml
