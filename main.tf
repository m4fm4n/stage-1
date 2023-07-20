#Выбор провайдера
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

#Данные для коннекта
provider "yandex" {
  token     = "<YC_TOKEN>"
  cloud_id  = "<YC_cloud_id>"
  folder_id = "<YC_folder_id>"
  zone      = "ru-central1-a"
}

#Выбор ОС для инстансов 
data "yandex_compute_image" "my_image" {
  family = var.instance_family_image
}

#Именнуем свой network
resource "yandex_vpc_network" "network" {
  name = "network"
}

#Характеризуем свою подсеть
resource "yandex_vpc_subnet" "subnet" {
  name           = "subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.20.0/24"]
}

#Описываем мастер-ноду
resource "yandex_compute_instance" "k8s-master01" {
  name = "k8s-master01"
  hostname = "k8s-master01"
  platform_id = "standard-v2"

#Прерываемая ВМ
  scheduling_policy {
    preemptible = false
  }

#Ресурсы ЦП и RAM, процентное использование ЦП
  resources {
    cores  = 2
    memory = 4
    core_fraction = 100
  }

#Описывание диска(ОС, размер, тип)
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.my_image.id
      size = 20
      type = "network-ssd"
    }
  }

#Привязка сети(назначаем вручную локальный ip, запрашиваем public ip)
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    ip_address = "192.168.20.3"
    nat = true
  }

#Присваиваем пользователя и ssh ключ для него
  metadata = {
    ssh-keys = "${var.ssh_credentials.user}:${file(var.ssh_credentials.pub_key)}"
  }
}

#Описание воркер-ноды
resource "yandex_compute_instance" "k8s-worker01" {
  name = "k8s-worker01"
  hostname = "k8s-worker01"
  platform_id = "standard-v2"

  scheduling_policy {
    preemptible = false
  }

  resources {
    cores  = 2
    memory = 4
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.my_image.id
      size = 20
      type = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    ip_address = "192.168.20.4"
    nat = true
  }

  metadata = {
    ssh-keys = "${var.ssh_credentials.user}:${file(var.ssh_credentials.pub_key)}"
  }
}

resource "yandex_compute_instance" "srv01" {
  name = "srv01"
  hostname = "srv01"
  platform_id = "standard-v2"

  scheduling_policy {
    preemptible = false
  }

  resources {
    cores  = 4
    memory = 8
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.my_image.id
      size = 30
      type = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    ip_address = "192.168.20.5"
    nat = true
  }

  metadata = {
    ssh-keys = "${var.ssh_credentials.user}:${file(var.ssh_credentials.pub_key)}"
  }
}
