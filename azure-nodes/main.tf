# Input variables
/*
   Refer to the below URL to find out how to create
      * tenant-id
      * client-id
      * subscription-id
      * client-secret
   specifically the section "Creating a Service Principal in the Azure Portal".

   https://www.terraform.io/docs/providers/azurerm/authenticating_via_service_principal.html
*/
variable "tenant-id" {
   description = "The tenant id to use for creating the resources"
}

variable "client-id" {
   description = "The client id to use for creating the resources"
}

variable "subscription-id" {
   description = "The subscription id to use for creating the resources"
}

variable "client-secret" {
   description = "The client secret to use for creating the resources"
}

variable "location" {
   description = "The location/region where the resources need to be created."
   default     = "West US 2"
}

variable "node-count" {
   description = "Number of nodes to be created."
   default     = 3
}

variable "res-grp-name" {
   description = "Name to assign to resource group that will be created. The same name should not already exist."
}

variable "public-key-file" {
   description = "Full path to the ssh public key file."
   default     = "../cloud-vm.key.pub"
}

variable "data-disk-size-gb" {
   description = "Size of the data disk (in GB) to be attached to the cluster nodes."
   default     = 50
}

variable "img-name" {
   description = "Name of the image from which cluster nodes should be created. The image should be Centos 7.3 based and should have passwordless sudo enabled for user centos."
   default     = "ao-node-img-centos72-no-sudo-pwd"
}

variable img-res-grp {
   description = "Name of the resource group in which the image is located."
   default     = "apporbit"
}

variable "vm-size" {
   description = "The VM size to use for the nodes"
   default     = "Standard_A4_v2"
}

variable "ao-host-ip" {
   description = "IP address of the AO host"
}

# AzureRM Provider Configuration
provider "azurerm" {
   version           = "~> 1.0"
   subscription_id   = "${var.subscription-id}"
   client_id         = "${var.client-id}"
   client_secret     = "${var.client-secret}"
   tenant_id         = "${var.tenant-id}"
}

# Create a reference to an existing resource group where the image is present
data "azurerm_resource_group" "ao-img-rg" {
  name = "${var.img-res-grp}"
}

# Create a reference to the image
data "azurerm_image" "ao-node-img" {
  name                = "${var.img-name}"
  resource_group_name = "${data.azurerm_resource_group.ao-img-rg.name}"
}

# Create new Resource Group
resource "azurerm_resource_group" "apporbit-rg" {
   name     = "${var.res-grp-name}"
   location = "${var.location}"
}

# Create a new virtual network
resource "azurerm_virtual_network" "ao-cluster-net" {
   name                 = "ao-cluster-net"
   address_space        = ["10.0.0.0/16"]
   location             = "${var.location}"
   resource_group_name  = "${azurerm_resource_group.apporbit-rg.name}"
}

# Create a new subnet in the virtual network. Virtual Machines will be
# connected to this subnet
resource "azurerm_subnet" "ao-cluster-subnet" {
   name                 = "ao-cluster-subnet"
   resource_group_name  = "${azurerm_resource_group.apporbit-rg.name}"
   virtual_network_name = "${azurerm_virtual_network.ao-cluster-net.name}"
   address_prefix       = "10.0.1.0/24"
}

# Create new floating (public) IPs
resource "azurerm_public_ip" "ao-node-fips" {
   count                         = "${var.node-count}"
	name                          = "ao-node-fip-${count.index}"
   location                      = "${var.location}"
	resource_group_name           = "${azurerm_resource_group.apporbit-rg.name}"
	public_ip_address_allocation  = "dynamic"
}

# Create a new security group.
# This security group is pretty lame! It opens up all th ports on the nodes'
# public IP. But today our deployment architecture mandates this. Because
# ephemeral ports are created for app on the node public IPs, we do not know
# apriori what those ports are going to be and if we open only a set of well
# known ports then apps deployed on appOrbit will be inaccessible. The right
# solution is to not expose the app endpoints on the node IPs.
resource "azurerm_network_security_group" "ao-cluster-sg" {
   name                 = "ao-cluster-sg"
   location             = "${var.location}"
   resource_group_name  = "${azurerm_resource_group.apporbit-rg.name}"

   security_rule {
      name                       = "All"
      priority                   = 1001
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "1-65535"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
   }
/*
   security_rule {
      name                       = "SSH"
      description                = "Allow SSH AO Host"
      priority                   = 1001
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "22"
      destination_port_range     = "22"
      source_address_prefix      = "${var.ao-host-ip}/32"
      destination_address_prefix = "*"
   }
*/
}

# Create new NICs to be attached to the Virtual Machines
resource "azurerm_network_interface" "ao-node-nics" {
   count                      = "${var.node-count}"
   name                       = "ao-node-nic-${count.index}"
   location                   = "${var.location}"
   resource_group_name        = "${azurerm_resource_group.apporbit-rg.name}"
	network_security_group_id  = "${azurerm_network_security_group.ao-cluster-sg.id}"

   ip_configuration {
      name                          = "ao-node-ip-config"
      subnet_id                     = "${azurerm_subnet.ao-cluster-subnet.id}"
      private_ip_address_allocation = "dynamic"
      public_ip_address_id          = "${element(azurerm_public_ip.ao-node-fips.*.id, count.index)}"
   }
}

# Create new managed disks. These disks will be attached to the cluster nodes
# as data disks.
resource "azurerm_managed_disk" "ao-data-disks" {
   count                = "${var.node-count}"
   name                 = "ao-data-disk-${count.index}"
   location             = "${var.location}"
   resource_group_name  = "${azurerm_resource_group.apporbit-rg.name}"
   storage_account_type = "Standard_LRS"
   create_option        = "Empty"
   disk_size_gb         = "${var.data-disk-size-gb}"
}

resource "azurerm_virtual_machine" "ao-nodes" {
   count                   = "${var.node-count}"
   name                    = "ao-node-${count.index}"
   location                = "${var.location}"
   resource_group_name     = "${azurerm_resource_group.apporbit-rg.name}"
   network_interface_ids   = ["${element(azurerm_network_interface.ao-node-nics.*.id, count.index)}"]
   vm_size                 = "${var.vm-size}"

   # Delete the OS disk automatically when deleting the VM
   delete_os_disk_on_termination = true

   # Do not delete the data disks automatically when deleting the VM
   # Since the data disks are managed disks terraform will delete them as part
   # of 'terraform destroy'.
   # delete_data_disks_on_termination = true

   storage_image_reference {
      id        = "${data.azurerm_image.ao-node-img.id}"
   }

   storage_os_disk {
      name              = "ao-node-os-disk-${count.index}"
      caching           = "ReadWrite"
      create_option     = "FromImage"
      managed_disk_type = "Standard_LRS"
   }

   storage_data_disk {
      name              = "${element(azurerm_managed_disk.ao-data-disks.*.name, count.index)}"
      managed_disk_id   = "${element(azurerm_managed_disk.ao-data-disks.*.id, count.index)}"
      create_option     = "Attach"
      lun               = 0
      disk_size_gb      = "${element(azurerm_managed_disk.ao-data-disks.*.disk_size_gb, count.index)}"
   }

   os_profile {
      computer_name  = "ao-node-${count.index}"
      # Make sure the image is configured with passwordless sudo for the below
      # users. If not, creating an appOrbit cluster on the nodes will crash and
      # burn.
      admin_username = "centos"
      admin_password = "app0rb!t"
   }

   os_profile_linux_config {
      disable_password_authentication = false
      ssh_keys {
         path     = "/home/centos/.ssh/authorized_keys"
         key_data = "${file("${var.public-key-file}")}"
      }
   }

   tags {
      createdby = "terraform"
   }
}

# Create a reference to the public IPs. We have to do this so that we will
# block on this until the public IPs are actually allocated. They are allocated
# only after the VM to which they are assigned completely power up. We use
# depends_on here to make sure this reference is created after the VMs are up.
# We need this reference so that the node-ips output variable can always show
# the public IPs appropriately. If we don't have this terraform sometime exits
# successfully before the public IPs are allocated and in such cases the
# node-ips output variable come up empty.
data "azurerm_public_ip" "datasrc-fips" {
   count                = "${var.node-count}"
   name                 = "${element(azurerm_public_ip.ao-node-fips.*.name, count.index)}"
   resource_group_name  = "${azurerm_resource_group.apporbit-rg.name}"
   depends_on           = ["azurerm_virtual_machine.ao-nodes"]
}

# Display the public IPs of the nodes created
output "ao-node-ips" {
   value = ["${data.azurerm_public_ip.datasrc-fips.*.ip_address}"]
}
