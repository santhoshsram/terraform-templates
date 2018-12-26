/*********************************
 * Input Variables               *
 *********************************/
variable "image" {
   type = "string"
}

variable "flavor" {
   type = "string"
}

variable "floating_ip_pool" {
   type = "string"
}

variable "public_net_id" {
   type = "string"
}

variable "dns_server1" {
   type = "string"
   default = "8.8.8.8"
}

variable "dns_server2" {
   type = "string"
   default = "8.8.4.4"
}

variable "ssh_key_file" {
   type = "string"
   default = "~/.ssh/id_rsa" 
}

variable "ssh_user_name" {
   type = "string"
   default = "ubuntu" 
}

variable "master_count" {
   type = "string"
   default = "3"
}

variable "slave_count" {
   type = "string"
   default = "3"
}
