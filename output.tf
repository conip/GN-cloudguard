#---------------------------- spoke 1 -------------------------------
# output "spoke3_vm1" {
#     value = { "public_ip" = module.spoke3_vm1.vm.public_ip, "private_ip" = module.spoke3_vm1.vm.private_ip }
# }


output "aviatrix_firewall_instance" {
    value = module.firenet_1.aviatrix_firewall_instance
    sensitive = true
}