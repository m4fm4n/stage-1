[server]
srv ansible_host=${server_ip}

[k8s_cluster]
master_node ansible_host=${master_node_ip}
worker_node ansible_host=${worker_node_ip}
