# Create the apigeenet network
resource "google_compute_network" "apigeenet" {
  name                    = "apigeenet"
  auto_create_subnetworks = true
}

# Create the apigeenet router
resource "google_compute_router" "apigeenet-router-dc-1" {
  name    = "apigeenet-router"
  network = "${google_compute_network.apigeenet.self_link}"
  region  = "${var.dc_1_gcp_region}"
}
//resource "google_compute_router" "apigeenet-router-dc-2" {
//  name    = "apigeenet-router"
//  network = "${google_compute_network.apigeenet.self_link}"
//  region  = "${var.dc_2_gcp_region}"
//}

module "configure_firewall_apigeenet_allow_mgmt_ui" {
  source                 = "../modules/apigeenet-firewalls-protocol-with-ports"
  firewall_name          = "mgmt-ui"
  firewall_source_tags   = ["mgmt-ui"]
  firewall_network       = "${google_compute_network.apigeenet.self_link}"
  firewall_protocol      = "tcp"
  firewall_ports         = ["9000", "80", "8080", "9001"]
  firewall_source_ranges = ["10.0.0.0/8"]
}

module "configure_firewall_apigeenet_allow_validate_test" {
  source                 = "../modules/apigeenet-firewalls-protocol-with-ports"
  firewall_name          = "validate-rmp"
  firewall_source_tags   = ["validate-rmp"]
  firewall_network       = "${google_compute_network.apigeenet.self_link}"
  firewall_protocol      = "tcp"
  firewall_ports         = ["59001"]
  firewall_source_ranges = ["10.0.0.0/8"]
}

module "configure_firewall_apigeenet_allow_postgresql_testing" {
  source                 = "../modules/apigeenet-firewalls-protocol-with-ports"
  firewall_name          = "postgresql"
  firewall_source_tags   = ["postgresql"]
  firewall_network       = "${google_compute_network.apigeenet.self_link}"
  firewall_protocol      = "tcp"
  firewall_ports         = ["5432"]
  firewall_source_ranges = ["10.0.0.0/8"]
}

module "configure_firewall_apigeenet_allow_icmp" {
  source                 = "../modules/apigeenet-firewalls-protocol-only"
  firewall_name          = "apigeenet-allow-icmp"
  firewall_network       = "${google_compute_network.apigeenet.self_link}"
  firewall_protocol      = "icmp"
  firewall_source_ranges = ["10.0.0.0/8"]
}

module "configure_firewall_apigeenet_allow_ssh" {
  source                 = "../modules/apigeenet-firewalls-protocol-with-ports"
  firewall_name          = "apigeenet-allow-ssh"
  firewall_source_tags   = ["apigeenet-allow-ssh"]
  firewall_network       = "${google_compute_network.apigeenet.self_link}"
  firewall_protocol      = "tcp"
  firewall_ports         = ["22"]
  firewall_source_ranges = ["10.0.0.0/8"]
}

module "configure_firewall_public_allow_ssh" {
  source                 = "../modules/apigeenet-firewalls-protocol-with-ports"
  firewall_name          = "public-allow-ssh"
  firewall_source_tags   = ["public-allow-ssh"]
  firewall_network       = "${google_compute_network.apigeenet.self_link}"
  firewall_protocol      = "tcp"
  firewall_ports         = ["22"]
  firewall_source_ranges = ["0.0.0.0/0"]
}

module "configure_firewall_apigeenet_allow_local" {
  source                 = "../modules/apigeenet-firewalls-protocol-with-ports"
  firewall_name          = "apigeenet-allow-local"
  firewall_source_tags   = ["apigeenet-allow-local"]
  firewall_network       = "${google_compute_network.apigeenet.self_link}"
  firewall_protocol      = "tcp"
  firewall_ports         = ["0-65535"]
  firewall_source_ranges = ["10.0.0.0/8"]
}

//# Add an apigee-vm instance
module "apigee-bastion" {
  source           = "../modules/external-instance"
  instance_name    = "apigee-bastion"
  instance_zone    = "${var.dc_1_zone}"
  instance_network = "${google_compute_network.apigeenet.self_link}"
  instance_type    = "n1-standard-1"
  instance_tags = [
    "apigeenet-allow-icmp",
    "public-allow-ssh",
    "apigeenet-allow-local",
    "g-on-g-notify-ignore",
  ]
  instance_external_ip = "Ephemeral"
  instance_scopes      = ["compute-rw", "storage-ro"]
}

# Create the gateway nat for the apigeenet-subnet-router
resource "google_compute_router_nat" "apigeenet-subnet-nat-dc-1" {
  name                               = "apigeenet-subnet-nat-${var.dc_1_region}"
  router                             = "${google_compute_router.apigeenet-router-dc-1.name}"
  region                             = "${var.dc_1_gcp_region}"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
//resource "google_compute_router_nat" "apigeenet-subnet-nat-dc-2" {
//  name                               = "apigeenet-subnet-nat-${var.dc_2_region}"
//  router                             = "${google_compute_network.apigeenet.name}"
//  region                             = "${var.dc_2_gcp_region}"
//  nat_ip_allocate_option             = "AUTO_ONLY"
//  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
//}

module "apigee-dc-1-ms-ldap-ui" {
  source             = "../modules/internal-instance"
  instance_count     = "${var.dc_1_ms_count}"
  instance_name      = "${var.dc_1_ms_name}"
  instance_zone      = "${var.dc_1_zone}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 250
  instance_type      = "${var.machine_type}"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
  ]
}

module "apigee-dc-2-ms-ldap-ui" {
  source             = "../modules/internal-instance"
  instance_count     = "${var.dc_2_ms_count}"
  instance_name      = "${var.dc_2_ms_name}"
  instance_zone      = "${var.dc_2_zone}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 250
  instance_type      = "${var.machine_type}"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
  ]
}

# Add an apigee-vm instance
module "apigee-dc-1-rmp" {
  source             = "../modules/internal-instance"
  instance_zone      = "${var.dc_1_zone}"
  instance_count     = "${var.dc_1_rmp_count}"
  instance_name      = "${var.dc_1_rmp_name}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 250
  instance_type      = "n1-standard-2"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "validate-rmp"
  ]
}
module "apigee-dc-2-rmp" {
  source             = "../modules/internal-instance"
  instance_zone      = "${var.dc_2_zone}"
  instance_count     = "${var.dc_2_rmp_count}"
  instance_name      = "${var.dc_2_rmp_name}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 250
  instance_type      = "n1-standard-2"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "validate-rmp"
  ]
}
module "apigee-dc-3-rmp" {
  source             = "../modules/internal-instance"
  instance_zone      = "${var.dc_3_zone}"
  instance_count     = "${var.dc_3_rmp_count}"
  instance_name      = "${var.dc_3_rmp_name}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 250
  instance_type      = "n1-standard-2"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "validate-rmp"
  ]
}

# Add an apigee-vm instance
module "apigee-ds-dc-1" {
  source             = "../modules/internal-instance"
  instance_zone      = "${var.dc_1_zone}"
  instance_count     = "${var.dc_1_ds_count}"
  instance_name      = "${var.dc_1_ds_name}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 250
  instance_type      = "n1-standard-2"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "validate-rmp"
  ]
}
module "apigee-ds-dc-2" {
  source             = "../modules/internal-instance"
  instance_zone      = "${var.dc_2_zone}"
  instance_count     = "${var.dc_2_ds_count}"
  instance_name      = "${var.dc_2_ds_name}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 250
  instance_type      = "n1-standard-2"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "validate-rmp"
  ]
}
module "apigee-ds-dc-3" {
  source             = "../modules/internal-instance"
  instance_zone      = "${var.dc_3_zone}"
  instance_count     = "${var.dc_3_ds_count}"
  instance_name      = "${var.dc_3_ds_name}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 250
  instance_type      = "n1-standard-2"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "validate-rmp"
  ]
}

//# Add an apigee-vm instance
module "apigee-qpid-dc-1" {
  source             = "../modules/internal-instance"
  instance_zone      = "${var.dc_1_zone}"
  instance_count     = "${var.dc_1_qpid_count}"
  instance_name      = "${var.dc_1_qpid_name}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 500
  instance_type      = "n1-standard-2"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "postgresql"
  ]
}
module "apigee-qpid-dc-2" {
  source             = "../modules/internal-instance"
  instance_zone      = "${var.dc_2_zone}"
  instance_count     = "${var.dc_2_qpid_count}"
  instance_name      = "${var.dc_2_qpid_name}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 500
  instance_type      = "n1-standard-2"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "postgresql"
  ]
}
module "apigee-qpid-dc-3" {
  source             = "../modules/internal-instance"
  instance_zone      = "${var.dc_3_zone}"
  instance_count     = "${var.dc_3_qpid_count}"
  instance_name      = "${var.dc_3_qpid_name}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 500
  instance_type      = "n1-standard-2"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "postgresql"
  ]
}

# Add an apigee-vm instance
module "apigee-pg-only" {
  source             = "../modules/internal-instance"
  instance_name      = "${var.pg_only_name}"
  instance_count     = "${var.pg_only_count}"
  instance_zone      = "${var.dc_1_zone}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 4000
  instance_disk_type = "pd-ssd"
  instance_type      = "n1-standard-96"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "postgresql"
  ]
}

# Add an apigee-vm instance
module "apigee-pg-pgmaster-dc-1" {
  source             = "../modules/internal-instance"
  instance_name      = "${var.dc_1_pgmaster_name}"
  instance_count     = "${var.dc_1_pgmaster_count}"
  instance_zone      = "${var.dc_1_zone}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 4000
  instance_disk_type = "pd-ssd"
  instance_type      = "n1-standard-96"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "postgresql"
  ]
}
module "apigee-pg-pgmaster-dc-2" {
  source             = "../modules/internal-instance"
  instance_name      = "${var.dc_2_pgmaster_name}"
  instance_count     = "${var.dc_2_pgmaster_count}"
  instance_zone      = "${var.dc_2_zone}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 4000
  instance_disk_type = "pd-ssd"
  instance_type      = "n1-standard-96"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "postgresql"
  ]
}


# Add an apigee-vm instance
module "apigee-pg-pgstandby-dc-1" {
  source             = "../modules/internal-instance"
  instance_name      = "${var.dc_1_pgstandby_name}"
  instance_count     = "${var.dc_1_pgstandby_count}"
  instance_zone      = "${var.dc_1_zone}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 250
  instance_disk_type = "pd-ssd"
  instance_type      = "n1-standard-96"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "postgresql"
  ]
}
module "apigee-pg-pgstandby-dc-2" {
  source             = "../modules/internal-instance"
  instance_name      = "${var.dc_2_pgstandby_name}"
  instance_count     = "${var.dc_2_pgstandby_count}"
  instance_zone      = "${var.dc_2_zone}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 4000
  instance_disk_type = "pd-ssd"
  instance_type      = "n1-standard-96"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "postgresql"
  ]
}

# Add an apigee-vm instance
module "apigee-dp" {
  source             = "../modules/internal-instance"
  instance_name      = "${var.dev_portal_name}"
  instance_count     = "${var.dev_portal_count}"
  instance_zone      = "${var.dc_1_zone}"
  instance_network   = "${google_compute_network.apigeenet.self_link}"
  instance_disk_size = 250
  instance_type      = "n1-standard-2"
  instance_tags = [
    "apigeenet-allow-ssh",
    "apigeenet-allow-icmp",
    "apigeenet-allow-mgmt-ui",
    "apigeenet-allow-local",
    "postgresql"
  ]
}

