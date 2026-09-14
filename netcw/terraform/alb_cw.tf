resource "yandex_alb_backend_group" "web_bg" {
  name = "web-servers-backend-group"

  http_backend {
    name   = "http-backend"
    weight = 1
    port   = 80
    
     target_group_ids = [yandex_compute_instance_group.web_ig.application_load_balancer.0.target_group_id]

    load_balancing_config {
      panic_threshold = 50
    }

    healthcheck {
      timeout             = "1s"
      interval            = "2s"
      healthy_threshold   = 2
      unhealthy_threshold = 2
      
      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "web_router" {
  name = "web-http-router"
}

resource "yandex_alb_virtual_host" "web_vh" {
  name           = "web-virtual-host"
  http_router_id = yandex_alb_http_router.web_router.id
  # authority      = ["netcw.ru"]

  route {
    name = "root-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_bg.id
        timeout          = "3s"
      }
    }
  }
}

resource "yandex_alb_load_balancer" "web_alb" {
  name               = "web-application-load-balancer"
  network_id         = yandex_vpc_network.main.id
  security_group_ids = [yandex_vpc_security_group.alb_sg.id]

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.public_a.id
    }
    # location {
    #   zone_id   = "ru-central1-b"
    #   subnet_id = yandex_vpc_subnet.public_b.id
    # }
  }

  # listener {
  #   name = "http-listener"
  #   endpoint {
  #     address {
  #       external_ipv4_address {
  #         #address = yandex_vpc_address.alb_static_ip.external_ipv4_address[0].address
  #       }
  #     }
  #     ports = [443]
  #   }
  #   tls {
  #     default_handler {
  #       certificate_ids = [yandex_cm_certificate.site_certificate.id]
  #       http_handler {
  #         http_router_id = yandex_alb_http_router.web_router.id
  #       }  
  #     }
  #   }
  # }

  listener {
    name = "http-listener"
    endpoint {
      address {
        external_ipv4_address {
          address = yandex_vpc_address.alb_static_ip.external_ipv4_address[0].address
        }
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.web_router.id
      }
    }
  }
}