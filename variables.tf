#----------------- AVIATRIX -----------------
variable "avx_controller_admin_password" {
  type        = string
  description = "[sensitive.auto.tfvars] - aviatrix controller admin password"
}
variable "controller_ip" {
  type        = string
  description = "[terraform.auto.tfvars] - aviatrix controller "
}
variable "aws_region" {
  type        = string
  description = "AWS Region"
  default     = "eu-west-2"
}

variable "azure_region" {
  type = string
  default = "West Europe"
}

variable "ssh_key" {
  type        = string
  description = "SSH key for the ubuntu VMs"

}

variable "aws_ssh_key" {
  type        = string
  description = "SSH key for the ubuntu VMs"

}

variable "pre_shared_key" {
  type    = string
  default = "some_key"
}

variable "avx_ctrl_account_azure" {
  type = string
}

variable "avx_ctrl_account_aws" {
  type = string
}

variable "avx_ctrl_account_alicloud" {
  type = string
}


variable "palo_username" {
  type = string
}

variable "palo_password" {
  type = string
}


variable "palo_bootstrap_storage_name_1" {
  type = string
}

variable "palo_file_share_folder_1" {
  type = string
}
variable "azure_storage_access_key_1" {
  type = string
}
