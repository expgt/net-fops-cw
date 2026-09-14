variable "cloud_id" {
  type    = string
}

variable "folder_id" {
  type    = string
}

variable "service_account" {
  type    = string
}

variable "ubuntu_user" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "pg_version" {
  type        = number
  default     = 15
}

variable "pg_resource_preset" {
  type        = string
  default     = "s2.micro"
}

variable "pg_disk_size" {
  type        = number
  default     = 20
}

variable "pg_user" {
  type        = string
  sensitive   = true
}

variable "pg_password" {
  type        = string
  sensitive   = true
}

variable "pg_database" {
  type        = string
}