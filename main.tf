provider "google" {
  project = "${var.gcp_project}"
  region  = "${var.gcp_region}"
}

data "google_compute_image" "ubuntu_1604" {
  project = "ubuntu-os-cloud"
  family  = "ubuntu-1604-lts"
}

module "master" {
  source  = "matti/gce-stateful-zonal-instance-groups/google"
  version = "0.0.1"

  machine_type           = "n1-standard-1"
  boot_disk_source_image = "${data.google_compute_image.ubuntu_1604.self_link}"
  boot_disk_size         = "10"

  base_name = "m"

  tags = [
    "fw-allow-all-ssh",
    "fw-allow-all-master",
  ]

  preemptible = true
  amount      = 1

  address_fixed  = true
  can_ip_forward = true
}

module "workers" {
  source  = "matti/gce-stateful-zonal-instance-groups/google"
  version = "0.0.1"

  machine_type           = "n1-standard-1"
  boot_disk_source_image = "${data.google_compute_image.ubuntu_1604.self_link}"
  boot_disk_size         = "10"

  base_name = "w"

  tags = [
    "fw-allow-all-ssh",
  ]

  preemptible    = true
  amount         = 1
  address_fixed  = true
  address_offset = 1
  can_ip_forward = true
}

module "kupo_config" {
  source  = "matti/config/kupo"
  version = "0.2.0"

  master_addresses         = ["${module.master.nat_ips}"]
  master_private_addresses = ["${module.master.addresses}"]

  master_fields = {
    role = "master"
    user = "${var.user}"
  }

  worker_addresses         = ["${module.workers.nat_ips}"]
  worker_private_addresses = ["${module.workers.addresses}"]

  worker_fields = {
    role = "worker"
    user = "${var.user}"

    labels = {
      ingress = "nginx"
    }
  }

  network = {}

  addons = {
    ingress-nginx = {
      enabled = false
    }

    kured = {
      enabled = true
    }
  }
}

output "kupo" {
  value = "${module.kupo_config.rendered}"
}

module "until_ssh_up" {
  source  = "matti/until/tcp"
  version = "0.1.1"

  depends_id = "${module.master.id}"
  addresses  = "${concat(module.master.nat_ips, module.workers.nat_ips)}"
  port       = 22
  interval   = 3
}

module "ssh_fingerprints_removed" {
  source  = "matti/remove-known-hosts/ssh"
  version = "0.0.1"

  depends_id = "${module.until_ssh_up.id}"
  hosts      = ["${concat(module.master.nat_ips, module.workers.nat_ips)}"]
}

module "kupo_up" {
  source  = "matti/up/kupo"
  version = "0.0.1"

  depends_id = "${module.ssh_fingerprints_removed.id}"
  yaml       = "${module.kupo_config.rendered}"
}

output "kupo_up_output" {
  value = "${module.kupo_up.output}"
}

output "kupo_up_stderr" {
  value = "${module.kupo_up.stderr}"
}

output "kupo_master" {
  value = "${module.master.nat_ips}"
}
