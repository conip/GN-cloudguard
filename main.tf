module "mc_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "v2.0.1"

  cloud                       = "Azure"
  cidr                        = "10.1.0.0/23"
  region                      = var.azure_region
  account                     = var.avx_ctrl_account_azure
  bgp_ecmp                    = true
  enable_transit_firenet      = true
  local_as_number             = "65001"
  name                        = "${local.env_prefix}TRANSIT-1"
  enable_segmentation         = true
  learned_cidrs_approval_mode = "connection"
}

module "firenet_1" {
  source  = "terraform-aviatrix-modules/mc-firenet/aviatrix"
  version = "1.0.2"
egress_enabled = true
  transit_module           = module.mc_transit
  firewall_image           = "Palo Alto Networks VM-Series Flex Next-Generation Firewall Bundle 1"
  firewall_image_version   = "10.1.4"
  username                 = var.palo_username
  password                 = var.palo_password
  bootstrap_storage_name_1 = var.palo_bootstrap_storage_name_1
  storage_access_key_1     = var.azure_storage_access_key_1
  file_share_folder_1      = var.palo_file_share_folder_1
  bootstrap_storage_name_2 = var.palo_bootstrap_storage_name_1
  storage_access_key_2     = var.azure_storage_access_key_1
  file_share_folder_2      = var.palo_file_share_folder_1
  depends_on = [
    module.mc_transit
  ]
}


######  need to wait for FW to come up
#Aviatrix FireNet Vendor Integration Data Source
data "aviatrix_firenet_vendor_integration" "vi_palo1" {
  count       = length(module.firenet_1.aviatrix_firewall_instance)
  vpc_id      = module.firenet_1.aviatrix_firewall_instance[count.index].vpc_id
  instance_id = module.firenet_1.aviatrix_firewall_instance[count.index].instance_id
  vendor_type = "Palo Alto Networks VM-Series"
  #public_ip     = "10.11.12.13"
  username      = var.palo_username
  password      = var.palo_password
  firewall_name = module.firenet_1.aviatrix_firewall_instance[count.index].firewall_name
  save          = true
  depends_on = [
    module.firenet_1
  ]
}


module "az_spoke_1" {
  source     = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  name       = "${local.env_prefix}SPOKE-1"
  cloud      = "Azure"
  region     = "UK South"
  cidr       = "10.101.0.0/16"
  attached   = true
  account    = var.avx_ctrl_account_azure
  ha_gw      = false
  transit_gw = module.mc_transit.transit_gateway.gw_name
}

module "spoke_1_vm1" {
  source    = "git::https://github.com/conip/terraform-azure-instance-build-module.git"
  name      = "${local.env_prefix}spoke1-vm1"
  region    = "UK South"
  rg        = module.az_spoke_1.vpc.resource_group
  subnet_id = module.az_spoke_1.vpc.public_subnets[1].subnet_id
  ssh_key   = var.ssh_key
  public_ip = true
  depends_on = [
    module.az_spoke_1
  ]
}

resource "aviatrix_transit_external_device_conn" "azueuw1_tpg1_primary" {
  depends_on                    = [module.mc_transit]
  vpc_id                        = module.mc_transit.transit_gateway.vpc_id
  connection_name               = "Forti-vpn"
  gw_name                       = module.mc_transit.transit_gateway.gw_name #"transitGw"
  connection_type               = "bgp"
  tunnel_protocol               = "IPsec"
  bgp_local_as_num              = module.mc_transit.transit_gateway.local_as_number #"123"
  bgp_remote_as_num             = "65012"                                           
  remote_gateway_ip             = "20.223.25.113"                                   
  remote_tunnel_cidr            = "169.254.1.2/30,169.254.2.2/30"                   
  local_tunnel_cidr             = "169.254.1.1/30,169.254.2.1/30"
  custom_algorithms             = true
  phase_1_authentication        = "SHA-256"
  phase_2_authentication        = "HMAC-SHA-256"
  phase_1_dh_groups             = "5"
  phase_2_dh_groups             = "5"
  phase_1_encryption            = "AES-256-CBC"
  phase_2_encryption            = "AES-256-CBC"
  ha_enabled                    = false
  enable_ikev2                  = true
  pre_shared_key                = "secret$123" # !! move to Azure Vault
  phase1_remote_identifier      = ["10.115.0.4"]
  enable_learned_cidrs_approval = true
  approved_cidrs                = ["10.111.0.0/20", "10.115.2.0/24"]
}

################################################################################ step 0 - creating subnets for spoke GW
resource "azurerm_subnet" "avx_gw_subnet" {
  name                 = "GN-avx-gw-subnet"
  resource_group_name  = "GN-migration-TEST"
  virtual_network_name = "GN-FortiGate-VNET"
  address_prefixes     = ["10.115.15.0/25"]
}

resource "azurerm_subnet" "avx_gw_subnet_ha" {
  name                 = "GN-avx-gwha-subnet"
  resource_group_name  = "GN-migration-TEST"
  virtual_network_name = "GN-FortiGate-VNET"
  address_prefixes     = ["10.115.15.128/25"]
}

################################################################################ step 1 - deploying 2 new spoke GW

# resource "aviatrix_spoke_gateway" "spoke2_avx_gw" {
#   cloud_type                            = 8
#   account_name                          = var.avx_ctrl_account_azure
#   gw_name                               = "${local.env_prefix}migrated-AVX-spoke"
#   vpc_id                                = "GN-FortiGate-VNET:GN-migration-TEST:930d69e5-a2f9-4dca-a58e-5396ca01502e"
#   vpc_reg                               = "North Europe"
#   gw_size                               = "Standard_B1ms"
#   ha_gw_size                            = "Standard_B1ms"
#   subnet                                = "10.115.15.0/25"
#   ha_subnet                             = "10.115.15.128/25"
#   insane_mode                           = false
#   manage_transit_gateway_attachment     = false
#   single_az_ha                          = true
#   single_ip_snat                        = false
#   customized_spoke_vpc_routes           = ""
#   filtered_spoke_vpc_routes             = ""
#   included_advertised_spoke_routes      = ""
#   zone                                  = "az-1"
#   ha_zone                               = "az-2"
#   enable_private_vpc_default_route      = false
#   enable_skip_public_route_table_update = false
#   enable_auto_advertise_s2c_cidrs       = false
#   tunnel_detection_time                 = null
#   tags                                  = null
#   depends_on = [
#     azurerm_subnet.avx_gw_subnet,
#     azurerm_subnet.avx_gw_subnet_ha
#   ]
# }

# ################################################################################ step 2 - attaching SPOKE2 GW
# resource "aviatrix_spoke_transit_attachment" "spoke2_transit_attachment" {
#   spoke_gw_name   = aviatrix_spoke_gateway.spoke2_avx_gw.gw_name
#   transit_gw_name = module.mc_transit.transit_gateway.gw_name
# }

################################################################################ step 3 - creating subnet-groups


# resource "aviatrix_spoke_gateway_subnet_group" "GN-forti-DMZ" {
#   name    = "GN-forti-DMZ"
#   gw_name = aviatrix_spoke_gateway.spoke2_avx_gw.gw_name
#   subnets = [
#     "10.115.2.0/24~~GN-DMZSubnet",
#   ]
#   depends_on = [
#     aviatrix_spoke_gateway.spoke2_avx_gw
#   ]
# }

# resource "aviatrix_spoke_gateway_subnet_group" "GN-forti-DC" {
#   name    = "GN-forti-DC"
#   gw_name = aviatrix_spoke_gateway.spoke2_avx_gw.gw_name
#   subnets = [
#     "10.111.0.0/24~~DC_subnet"
#   ]
#   depends_on = [
#     aviatrix_spoke_gateway.spoke2_avx_gw
#   ]
# }

# resource "aviatrix_spoke_gateway_subnet_group" "GN-forti-mgmt" {
#   name    = "GN-forti-mgmt"
#   gw_name = aviatrix_spoke_gateway.spoke2_avx_gw.gw_name
#   subnets = [
#     "10.111.1.0/24~~mgmt_subnet"
#   ]
#   depends_on = [
#     aviatrix_spoke_gateway.spoke2_avx_gw
#   ]
# }


################################################################################ step 4 - creating inspection policy

# locals {
#   # SPOKE_SUBNET_GROUP: spoke_name ~~ sub_group_name
#   inspected_resources = toset(["SPOKE_SUBNET_GROUP:${aviatrix_spoke_gateway.spoke2_avx_gw.gw_name}~~GN-forti-DMZ",
#     "SPOKE_SUBNET_GROUP:${aviatrix_spoke_gateway.spoke2_avx_gw.gw_name}~~GN-forti-mgmt",
#     "SPOKE_SUBNET_GROUP:${aviatrix_spoke_gateway.spoke2_avx_gw.gw_name}~~GN-forti-DC"
#   ])
# }

# resource "aviatrix_transit_firenet_policy" "inspection_policy_cloudguard" {
#   for_each                     = local.inspected_resources
#   transit_firenet_gateway_name = module.mc_transit.transit_gateway.gw_name
#   inspected_resource_name      = each.value

#   depends_on = [
#     module.mc_transit,
#     aviatrix_spoke_gateway_subnet_group.GN-forti-DMZ,
#     aviatrix_spoke_gateway_subnet_group.GN-forti-mgmt,
#     aviatrix_spoke_gateway_subnet_group.GN-forti-DC
#   ]
# }


