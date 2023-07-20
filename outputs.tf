output "Master-node" {
  value = "Access to the master-node: ssh ubuntu@${yandex_compute_instance.k8s-master01.network_interface.0.nat_ip_address}"
}

output "Worker-node" {
  value = "Access to the worker-node: ssh ubuntu@${yandex_compute_instance.k8s-worker01.network_interface.0.nat_ip_address}"
}

output "Server" {
  value = "Access to the service server SRV: ssh ubuntu@${yandex_compute_instance.srv01.network_interface.0.nat_ip_address}"
}
