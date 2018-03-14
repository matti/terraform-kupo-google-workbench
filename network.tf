data "google_compute_network" "default" {
  name = "default"
}

data "google_compute_subnetwork" "subnetworks" {
  count  = "${length(data.google_compute_network.default.subnetworks_self_links)}"
  name   = "${data.google_compute_network.default.name}"
  region = "${element(split("/", data.google_compute_network.default.subnetworks_self_links[count.index]), 8)}"
}

resource "google_compute_firewall" "allow-internal-all" {
  name    = "allow-internal-all"
  network = "${data.google_compute_network.default.name}"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "esp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    "${data.google_compute_subnetwork.subnetworks.*.ip_cidr_range}",
  ]
}

resource "google_compute_firewall" "allow-all-ssh" {
  name    = "allow-all-ssh"
  network = "${data.google_compute_network.default.name}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["fw-allow-all-ssh"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-all-master" {
  name    = "allow-all-master"
  network = "${data.google_compute_network.default.name}"

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  target_tags   = ["fw-allow-all-master"]
  source_ranges = ["0.0.0.0/0"]
}
