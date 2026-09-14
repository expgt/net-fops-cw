resource "local_file" "inventory" {
  filename = "/home/linu/netcw/ansible/hosts.ini"
  content  = <<-XYZ

  [bastioncw]
  ${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}

  [webserverscw]
  %{ for idx, instance in yandex_compute_instance_group.web_ig.instances ~}
  web-${idx + 1} ansible_host=${instance.network_interface[0].ip_address}
  %{ endfor ~}
  [webserverscw:vars]
  ansible_ssh_common_args='-o ProxyCommand="ssh -p 22 -W %h:%p -q cwuser@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'

  [prometheuscw]
  prometheus ansible_host=${yandex_compute_instance.prometheus.network_interface.0.ip_address}
  [prometheuscw:vars]
  ansible_ssh_common_args='-o ProxyCommand="ssh -p 22 -W %h:%p -q cwuser@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'
  pg_host="c-${yandex_mdb_postgresql_cluster.pg_cluster.id}.mdb.yandexcloud.net"
  pg_user="${yandex_mdb_postgresql_user.pg_user.name}"
  pg_password="${yandex_mdb_postgresql_user.pg_user.password}"
  pg_database="${yandex_mdb_postgresql_database.pg_database.name}"
  pg_port=5432
  
  [grafanacw]
  grafana ansible_host=${yandex_compute_instance.grafana.network_interface.0.ip_address}
  [grafanacw:vars]
  ansible_ssh_common_args='-o ProxyCommand="ssh -p 22 -W %h:%p -q cwuser@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'

  [elasticsearchcw]
  elasticsearch ansible_host=${yandex_compute_instance.elasticsearch.network_interface.0.ip_address}
  [elasticsearchcw:vars]
  ansible_ssh_common_args='-o ProxyCommand="ssh -p 22 -W %h:%p -q cwuser@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'

  [kibanacw]
  kibana ansible_host=${yandex_compute_instance.kibana.network_interface.0.ip_address}
  [kibanacw:vars]
  ansible_ssh_common_args='-o ProxyCommand="ssh -p 22 -W %h:%p -q cwuser@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'
  
  XYZ
  
}