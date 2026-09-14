# Группа безопасности Bastion Host
resource "yandex_vpc_security_group" "bastion_sg" {
  name        = "bastion-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH from anywhere"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "ssh_internal_sg" {
  name        = "ssh-internal-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol          = "TCP"
    description       = "Allow SSH from Bastion only"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }
}

resource "yandex_vpc_security_group" "alb_sg" {
  name        = "alb-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    description    = "Allow HTTP from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow HTTPS from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "web_sg" {
  name        = "web-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol          = "TCP"
    description       = "Allow HTTP traffic from ALB"
    security_group_id = yandex_vpc_security_group.alb_sg.id
    port              = 80
  }

  ingress {
    protocol          = "TCP"
    description       = "Allow HTTP traffic from Bastion"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }

  ingress {
    protocol          = "TCP"
    description       = "Allow scraping from Prometheus"
    security_group_id = yandex_vpc_security_group.prometheus_sg.id
    port              = 9100
  }

  ingress {
    protocol          = "TCP"
    description       = "Allow log scraping from Prometheus"
    security_group_id = yandex_vpc_security_group.prometheus_sg.id
    port              = 4040
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "prometheus_sg" {
  name        = "prometheus-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol          = "TCP"
    description       = "Allow Prometheus API/UI from Grafana"
    security_group_id = yandex_vpc_security_group.grafana_sg.id
    port              = 9090
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "postgresql_sg" {
  name        = "postgresql-sg"
  description = "Managed PostgreSQL"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol          = "TCP"
    description       = "Allow inbound traffic from Prometheus adapter"
    security_group_id = yandex_vpc_security_group.prometheus_sg.id
    port              = 6432
  }

  ingress {
    protocol       = "ANY"
    description    = "Allow replication and internal cluster traffic"
    v4_cidr_blocks = ["10.0.10.0/24", "10.0.20.0/24"]
    from_port      = 0
    to_port        = 65535
  }

  egress {
    protocol       = "ANY"
    description    = "Allow outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "grafana_sg" {
  name        = "grafana-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    description    = "Allow Grafana UI from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 3000
  }

    ingress {
    protocol       = "ANY"
    description    = "Allow Grafana from prometheus"
    v4_cidr_blocks = ["10.0.0.0/16"]
    port           = 8428
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "elasticsearch_sg" {
  name        = "elasticsearch-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol          = "TCP"
    description       = "Allow API traffic from Kibana"
    security_group_id = yandex_vpc_security_group.kibana_sg.id
    port              = 9200
  }

  ingress {
    protocol          = "TCP"
    description       = "Allow Logstash/Web traffic if needed"
    security_group_id = yandex_vpc_security_group.web_sg.id
    port              = 9200
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "kibana_sg" {
  name        = "kibana-sg"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    description    = "Allow Kibana UI from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}