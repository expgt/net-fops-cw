resource "yandex_compute_snapshot_schedule" "daily_snapshot" {
  name = "daily-snapshot-schedule"

  schedule_policy {
    expression = "0 2 * * *"
  }

  snapshot_spec {
    description = "Daily backup with 7 days retention"
  }

  retention_period = "168h"

  disk_ids = [
    yandex_compute_instance.bastion.boot_disk.0.disk_id,
    yandex_compute_instance.prometheus.boot_disk.0.disk_id,
    yandex_compute_instance.grafana.boot_disk.0.disk_id,
    yandex_compute_instance.elasticsearch.boot_disk.0.disk_id,
    yandex_compute_instance.kibana.boot_disk.0.disk_id
  ]
}

resource "yandex_backup_policy" "web_backup_policy" {
  name = "web-servers-backup-policy"

  retention {
    after_backup = false
    rules {
      max_age = "7d"
    }
  }

  scheduling {
    enabled = true
    backup_sets {
      execute_by_time {
        type      = "DAILY"
        repeat_at = ["02:00"]
      }
    }
  }

  vm_snapshot_reattempts {
    enabled      = true
    interval     = "5m"
    max_attempts = 3
  }

  reattempts {
    enabled      = true
    interval     = "5m"
    max_attempts = 3
  }
}