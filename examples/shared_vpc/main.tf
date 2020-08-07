/**
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
/**
 * https://github.com/terraform-google-modules/terraform-google-project-factory
 */

locals {
  subnet_01 = "${var.network_name}-subnet-01"
  subnet_02 = "${var.network_name}-subnet-02"
}

/******************************************
  Provider configuration
 *****************************************/
provider "google" {
  version = "~> 3.30"
}

provider "google-beta" {
  version = "~> 3.30"
}

provider "null" {
  version = "~> 2.1"
}

provider "random" {
  version = "~> 2.2"
}

/******************************************
  Host Project Creation
 *****************************************/
module "host-project" {
  source               = "../../"
  random_project_id    = true
  name                 = var.host_project_name
  org_id               = var.organization_id
  folder_id            = var.folder_id
  billing_account      = var.billing_account
  skip_gcloud_download = true
}

/******************************************
  Network Creation
 *****************************************/
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 2.1.0"

  project_id   = module.host-project.project_id
  network_name = var.network_name

  delete_default_internet_gateway_routes = true
  shared_vpc_host                        = true

  subnets = [
    {
      subnet_name   = local.subnet_01
      subnet_ip     = "10.10.10.0/24"
      subnet_region = "us-west1"
    },
    {
      subnet_name           = local.subnet_02
      subnet_ip             = "10.10.20.0/24"
      subnet_region         = "us-west1"
      subnet_private_access = true
      subnet_flow_logs      = true
    },
  ]

  secondary_ranges = {
    "${local.subnet_01}" = [
      {
        range_name    = "${local.subnet_01}-01"
        ip_cidr_range = "192.168.64.0/24"
      },
      {
        range_name    = "${local.subnet_01}-02"
        ip_cidr_range = "192.168.65.0/24"
      },
    ]

    "${local.subnet_02}" = [
      {
        range_name    = "${local.subnet_02}-01"
        ip_cidr_range = "192.168.66.0/24"
      },
    ]
  }
}

/******************************************
  Service Project Creation
 *****************************************/
module "service-project" {
  source = "../../modules/shared_vpc"

  name              = var.service_project_name
  random_project_id = "false"

  org_id             = var.organization_id
  folder_id          = var.folder_id
  billing_account    = var.billing_account
  shared_vpc_enabled = true

  shared_vpc         = module.vpc.project_id
  shared_vpc_subnets = module.vpc.subnets_self_links

  activate_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "dataproc.googleapis.com",
  ]

  disable_services_on_destroy = "false"
  skip_gcloud_download        = "true"
}

/******************************************
  Firewall rule
 *****************************************/

module "firewall" {
  source               = "../../modules/net-vpc-firewall"
  project_id           = module.host-project.project_id
  network              = module.vpc.network_name
  admin_ranges_enabled = true
  admin_ranges         = ["10.0.0.0/8"]
  custom_rules = {
    ntp-svc = {
      description          = "NTP service."
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = ["0.0.0.0/0"]
      targets              = ["ntp-svc"]
      use_service_accounts = false
      rules                = [{ protocol = "udp", ports = [123] }]
      extra_attributes     = {}
    }
  }
}

/******************************************
  External Static IP Address for Bastion
 *****************************************/

module "addresses" {
  source     = "../../modules/net-address"
  project_id = module.host-project.project_id
  external_addresses = {
    bastion-1      = "us-west1",
  }
}

/******************************************
  Bastion creation
     Ref: https://github.com/terraform-google-modules/cloud-foundation-fabric/tree/master/modules/compute-vm
 *****************************************/

module "bastion" {
  source     = "../../modules/compute-vm"
  project_id = module.service-project.project_id
  region     = "us-west1"
  name       = "bastion"
  network_interfaces = [{
    nat        = true,
    network    = module.vpc.network_self_link,
    subnetwork = module.vpc.subnets_self_links[0],
    addresses  = {
        internal = [""], 
        external = [module.addresses.external_addresses["bastion-1"].address]
    }
  }]
  boot_disk = {
    image        = "projects/centos-cloud/global/images/centos-7-v20200714"
    type         = "pd-ssd"
    size         = 20
  }
  service_account_create = false
  instance_count = 1
}