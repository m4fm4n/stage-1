#Подключаемся к мастер-ноде используя имя и ssh ключ
resource "null_resource" "k8s-master-init" {
  depends_on = [yandex_compute_instance.k8s-master01]
  connection {
    user        = var.ssh_credentials.user
    private_key = file(var.ssh_credentials.private_key)
    host        = yandex_compute_instance.k8s-master01.network_interface.0.nat_ip_address
  }

#Записываем в файл hosts наши узлы
  provisioner "remote-exec" {
    inline = [
      "echo '192.168.20.3 k8s-master01' | sudo tee -a /etc/hosts",
      "echo '192.168.20.4 k8s-worker01' | sudo tee -a /etc/hosts",
#Подготавливаемся к установке k8s
      "sudo tee /etc/modules-load.d/containerd.conf <<EOF\noverlay\nbr_netfilter\nEOF",
      "sudo modprobe overlay",
      "sudo modprobe br_netfilter",
      "sudo tee /etc/sysctl.d/kubernetes.conf <<EOF\nnet.bridge.bridge-nf-call-ip6tables = 1\nnet.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nEOF",
      "sudo sysctl --system",
#Добавляем репозиторий и устанавливаем необходимое для containerd
      "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg",
      "sudo add-apt-repository -y 'deb [arch=amd64] https://download.docker.com/linux/ubuntu jammy stable'",
      "sudo apt update",
      "sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates containerd.io",
#Генерируем конфигурацию по умолчанию. Включаем поддержку CRI
      "containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1",
      "sudo sed -i 's/SystemdCgroup \\= false/SystemdCgroup \\= true/g' /etc/containerd/config.toml",
      "sudo systemctl restart containerd",
      "sudo systemctl enable containerd",
#Добавляем репозиторий и устанавливаем kublet, kubeadm, kubectl. Фиксируем их версию
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      "sudo apt-add-repository -y 'deb http://apt.kubernetes.io/ kubernetes-xenial main'",
      "sudo apt update",
      "sudo apt install -y kubelet=1.27.4-00 kubeadm=1.27.4-00 kubectl=1.27.4-00 -V",
      "sudo apt-mark hold kubelet kubeadm kubectl",
#Инициализируем kubeadm 
      "sudo kubeadm init --control-plane-endpoint=k8s-master01",
#Создаём папку под конфиг, копируем и выдаём права
      "mkdir -p $HOME/.kube",
      "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config"
    ]
  }

#Забираем join token с мастер ноды и сохраняем локально
  provisioner "local-exec" {
    command = "TOKEN=$(ssh -i ${var.ssh_credentials.private_key} -o StrictHostKeyChecking=no ${var.ssh_credentials.user}@${yandex_compute_instance.k8s-master01.network_interface.0.nat_ip_address} kubeadm token create --print-join-command); echo \"#!/usr/bin/env bash\nsudo $TOKEN\nexit 0\" >| join.sh"
  }
}

#Подключаемся к воркер ноде
resource "null_resource" "k8s-worker-init" {
  depends_on = [yandex_compute_instance.k8s-worker01, null_resource.k8s-master-init]
  connection {
    user        = var.ssh_credentials.user
    private_key = file(var.ssh_credentials.private_key)
    host        = yandex_compute_instance.k8s-worker01.network_interface.0.nat_ip_address
  }

#Копируем join token 
  provisioner "file" {
    source      = "join.sh"
    destination = "join.sh"
  }
#Делаем тоже что и на мастер ноде, кроме: а) конфиг директории не создаём, б) запускаем join.sh с join token
  provisioner "remote-exec" {
    inline = [
      "echo '192.168.20.4 k8s-worker01' | sudo tee -a /etc/hosts",
      "echo '192.168.20.3 k8s-master01' | sudo tee -a /etc/hosts",
      "sudo tee /etc/modules-load.d/containerd.conf <<EOF\noverlay\nbr_netfilter\nEOF",
      "sudo modprobe overlay",
      "sudo modprobe br_netfilter",
      "sudo tee /etc/sysctl.d/kubernetes.conf <<EOF\nnet.bridge.bridge-nf-call-ip6tables = 1\nnet.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nEOF",
      "sudo sysctl --system",
      "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg",
      "sudo add-apt-repository -y 'deb [arch=amd64] https://download.docker.com/linux/ubuntu jammy stable'",
      "sudo apt update",
      "sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates containerd.io",
      "containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1",
      "sudo sed -i 's/SystemdCgroup \\= false/SystemdCgroup \\= true/g' /etc/containerd/config.toml",
      "sudo systemctl restart containerd",
      "sudo systemctl enable containerd",
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      "sudo apt-add-repository -y 'deb http://apt.kubernetes.io/ kubernetes-xenial main'",
      "sudo apt update",
      "sudo apt install -y kubelet=1.27.4-00 kubeadm=1.27.4-00 kubectl=1.27.4-00 -V",
      "sudo apt-mark hold kubelet kubeadm kubectl",
      "chmod +x ~/join.sh",
      "~/join.sh"
    ]
  }

#Избавляемся от локального join скрипта
  provisioner "local-exec" {
    command = "rm join.sh"
  }
}

#Настройка сети на мастер ноде через манифест calico.yaml
resource "null_resource" "k8s-network-init" {
  depends_on = [yandex_compute_instance.k8s-master01, yandex_compute_instance.k8s-worker01, null_resource.k8s-master-init]
  connection {
    user        = var.ssh_credentials.user
    private_key = file(var.ssh_credentials.private_key)
    host        = yandex_compute_instance.k8s-master01.network_interface.0.nat_ip_address
  }

  provisioner "file" {
    source      = "calico.yaml"
    destination = "calico.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl apply -f calico.yaml"
    ]
  }
}
#Генерирование файла invertory для playbook. При terraform destroy файл удаляется 
resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tpl",
    {
      server_ip = yandex_compute_instance.srv01.network_interface.0.nat_ip_address
      master_node_ip = yandex_compute_instance.k8s-master01.network_interface.0.nat_ip_address
      worker_node_ip = yandex_compute_instance.k8s-worker01.network_interface.0.nat_ip_address
    }
  )
  filename = "inventory"
}

resource "null_resource" "Ansible" {
  depends_on = [null_resource.k8s-network-init, yandex_compute_instance.srv01]

#Испраляем недуг нашего локального скрипта и передаём значения public ip в него
  provisioner "local-exec" {
    command = "sed -i -e 's/\r$//' ./ansible-run.sh  && ./ansible-run.sh  ${yandex_compute_instance.k8s-master01.network_interface.0.nat_ip_address} ${yandex_compute_instance.k8s-worker01.network_interface.0.nat_ip_address} ${yandex_compute_instance.srv01.network_interface.0.nat_ip_address}"
  }
}
