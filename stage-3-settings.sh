#!/usr/bin/bash

echo "deb [trusted=yes] https://mirror.yandex.ru/mirrors/elastic/8/ stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
apt update
systemctl restart packagekit.service
apt install apt-transport-https -y

apt install elasticsearch=8.6.2 -V
systemctl enable elasticsearch

sed -i 's/#network.host: 192.168.0.1/network.host: 0.0.0.0/g' /etc/elasticsearch/elasticsearch.yml
sed -i 's/#discovery.seed_hosts: \["host1", "host2"]/discovery.seed_hosts: \["192.168.20.3", "192.168.20.4"]/g' /etc/elasticsearch/elasticsearch.yml
sed -i 's/xpack.security.enabled: true/xpack.security.enabled: false/g' /etc/elasticsearch/elasticsearch.yml
systemctl restart elasticsearch

apt install kibana=8.6.2 -V
systemctl enable kibana

sed -i 's/#server.host: "localhost"/server.host: "0.0.0.0"/g' /etc/kibana/kibana.yml
sed -i 's/#elasticsearch.hosts: \["http:\/\/localhost:9200"]/elasticsearch.hosts: \["http:\/\/192.168.20.5:9200"]/g' /etc/kibana/kibana.yml
systemctl restart kibana

sleep 45

cp -R .kube /root/
kubectl apply -f /opt/monitoring/fluentd/fluentd.yaml
