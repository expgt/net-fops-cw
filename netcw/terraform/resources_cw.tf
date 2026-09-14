data "yandex_iam_service_account" "ig_sa" {
  name = var.service_account
}

data "yandex_compute_image" "ubuntu_2404_lts" {
  family = "ubuntu-2404-lts"
}

resource "yandex_compute_instance" "bastion" {
  name        = "bastion"
  hostname    = "bastion"
  zone        = "ru-central1-a"
  platform_id = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2404_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.bastion_sg.id]
  }

  #depends_on = [yandex_vpc_security_group.bastion_sg]

  metadata = {
    user-data          = templatefile("./cloud-init.tftpl", {
      install_backup_agent = false
      ubuntu_user          = var.ubuntu_user
      ssh_public_key       = var.ssh_public_key
    })
    serial-port-enable = "1"
  }
}

# resource "yandex_compute_instance" "web_1" {
#   name        = "web-1"
#   hostname    = "web-1"
#   zone        = "ru-central1-a"
#   platform_id = "standard-v3"

#   resources {
#     core_fraction = 20
#     cores         = 2
#     memory        = 2
#   }

#   boot_disk {
#     initialize_params {
#       image_id = data.yandex_compute_image.ubuntu_2404_lts.image_id
#       type     = "network-hdd"
#       size     = 10
#     }
#   }

#   network_interface {
#     subnet_id          = yandex_vpc_subnet.private_a.id
#     security_group_ids = [yandex_vpc_security_group.web_sg.id, yandex_vpc_security_group.ssh_internal_sg.id]
#   }

#   metadata = {
#     user-data          = file("./cloud-init.yml")
#     serial-port-enable = "1"
#   }
# }

# resource "yandex_compute_instance" "web_2" {
#   name        = "web-2"
#   hostname    = "web-2"
#   zone        = "ru-central1-b"
#   platform_id = "standard-v3"

#   resources {
#     core_fraction = 20
#     cores         = 2
#     memory        = 2
#   }

#   boot_disk {
#     initialize_params {
#       image_id = data.yandex_compute_image.ubuntu_2404_lts.image_id
#       type     = "network-hdd"
#       size     = 10
#     }
#   }

#   network_interface {
#     subnet_id          = yandex_vpc_subnet.private_b.id
#     security_group_ids = [yandex_vpc_security_group.web_sg.id, yandex_vpc_security_group.ssh_internal_sg.id]
#   }

#   metadata = {
#     user-data          = file("./cloud-init.yml")
#     serial-port-enable = "1"
#   }
# }

resource "yandex_compute_instance_group" "web_ig" {
  name               = "web-servers-instance-group"
  folder_id          = var.folder_id
  service_account_id = data.yandex_iam_service_account.ig_sa.id

  instance_template {
    name = "web-{instance.index}"
    hostname = "web-{instance.index}"
    platform_id = "standard-v3"
    
    resources {
      core_fraction = 20
      cores         = 2
      memory        = 2
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = data.yandex_compute_image.ubuntu_2404_lts.image_id
        size     = 20
      }
    }

    network_interface {
      network_id         = yandex_vpc_network.main.id
      subnet_ids         = [yandex_vpc_subnet.private_a.id, yandex_vpc_subnet.private_b.id]
      security_group_ids = [yandex_vpc_security_group.web_sg.id]
    }

    metadata = {
      backup-policy-id   = yandex_backup_policy.web_backup_policy.id
      user-data          = templatefile("./cloud-init.tftpl", {
        install_backup_agent = true
        ubuntu_user          = var.ubuntu_user
        ssh_public_key       = var.ssh_public_key
      })
      serial-port-enable = "1"
    }
  }

  allocation_policy {
    zones = ["ru-central1-a", "ru-central1-b"]
  }

  scale_policy {
    auto_scale {
      initial_size           = 2
      max_size               = 3
      min_zone_size          = 1
      measurement_duration   = 60
      warmup_duration        = 60
      stabilization_duration = 120

    custom_rule {
        rule_type = "UTILIZATION"
        metric_type = "COUNTER"
        metric_name = "load_balancer.requests_per_second"
        target = 100
        service = "application-load-balancer"
      }
    }
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 1
  }

  application_load_balancer {
    target_group_name = "web-servers-target-group"
  }

}

resource "yandex_compute_instance" "prometheus" {
  name        = "prometheus"
  hostname    = "prometheus"
  zone        = "ru-central1-a"
  platform_id = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2404_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    security_group_ids = [yandex_vpc_security_group.prometheus_sg.id, yandex_vpc_security_group.ssh_internal_sg.id]
  }

  metadata = {
    user-data          = templatefile("./cloud-init.tftpl", {
      install_backup_agent = false
      ubuntu_user          = var.ubuntu_user
      ssh_public_key       = var.ssh_public_key
    })
    serial-port-enable = "1"
  }
}

resource "yandex_compute_instance" "grafana" {
  name        = "grafana"
  hostname    = "grafana"
  zone        = "ru-central1-a"
  platform_id = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2404_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.grafana_sg.id, yandex_vpc_security_group.ssh_internal_sg.id]
  }

  depends_on = [yandex_vpc_security_group.grafana_sg]

  metadata = {
    user-data          = templatefile("./cloud-init.tftpl", {
      install_backup_agent = false
      ubuntu_user          = var.ubuntu_user
      ssh_public_key       = var.ssh_public_key
    })
    serial-port-enable = "1"
  }
}

resource "yandex_compute_instance" "elasticsearch" {
  name        = "elasticsearch"
  hostname    = "elasticsearch"
  zone        = "ru-central1-a"
  platform_id = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 8
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2404_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    security_group_ids = [yandex_vpc_security_group.elasticsearch_sg.id, yandex_vpc_security_group.ssh_internal_sg.id]
  }

  metadata = {
    user-data          = templatefile("./cloud-init.tftpl", {
      install_backup_agent = false
      ubuntu_user          = var.ubuntu_user
      ssh_public_key       = var.ssh_public_key
    })
    serial-port-enable = "1"
  }
}

resource "yandex_compute_instance" "kibana" {
  name        = "kibana"
  hostname    = "kibana"
  zone        = "ru-central1-a"
  platform_id = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2404_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.kibana_sg.id, yandex_vpc_security_group.ssh_internal_sg.id]
  }

  depends_on = [yandex_vpc_security_group.kibana_sg]

  metadata = {
    user-data          = templatefile("./cloud-init.tftpl", {
      install_backup_agent = false
      ubuntu_user          = var.ubuntu_user
      ssh_public_key       = var.ssh_public_key
    })
    serial-port-enable = "1"
  }
}

resource "yandex_mdb_postgresql_cluster" "pg_cluster" {
  name        = "pg_cluster"
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.main.id
  security_group_ids = [yandex_vpc_security_group.postgresql_sg.id]

  config {
    version = var.pg_version
    resources {
      resource_preset_id = var.pg_resource_preset
      disk_type_id       = "network-hdd"
      disk_size          = var.pg_disk_size
    }
  }

  # Master
  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.private_a.id
  }

  # Slave (Failover)
  host {
    zone      = "ru-central1-b"
    subnet_id = yandex_vpc_subnet.private_b.id
  }
}

resource "yandex_mdb_postgresql_database" "pg_database" {
  cluster_id = yandex_mdb_postgresql_cluster.pg_cluster.id
  name       = var.pg_database
  owner      = yandex_mdb_postgresql_user.pg_user.name
}

resource "yandex_mdb_postgresql_user" "pg_user" {
  cluster_id = yandex_mdb_postgresql_cluster.pg_cluster.id
  name       = var.pg_user
  password   = var.pg_password
}

# resource "yandex_cm_certificate" "site_certificate" {
#   name    = "site-certificate"
#   domains = ["cw.ru"] # Укажите ваше доменное имя

#   managed {
#     challenge_type = "DNS_CNAME" # или HTTP в зависимости от настройки проверки
#   }
# }