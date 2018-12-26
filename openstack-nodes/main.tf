# Input variables
variable "node-count" {
   description = "Number of nodes to be created"
   default     = 3
}

variable "image-name" {
   description = "Name of the image to use for the AO nodes"
   default     = "Gemini-Systems-CentOS-73-1702"
}

variable "flavor-name" {
   description = "Flavor to use for the AO nodes"
}

variable "data-disk-size-gb" {
   description =  "Data disk size in GB"
   default     = 50
}

variable "ao-cluster-net-cidr" {
   description = "CIDR to be used for the AO cluster private network"
   default     = "11.0.0.0/24"
}

variable "ao-host-ip" {
   description = "IP address of the AO host"
}

variable "public-net-name" {
   description = "Name of the public network"
}

variable "public-net-id" {
   description = "UUID of the public network"
}

/*
variable "public-cidr" {
   description = "CIDR of the public network"
   default     = "209.205.217.128/27"
}
*/

variable "dns-server-1" {
   # Default is Google's public DNS server
   type     = "string"
   default  = "8.8.8.8"
}

variable "dns-server-2" {
   # Default is Google's public DNS server
   type     = "string"
   default  = "8.8.4.4"
}

variable "public-key-file" {
   description = "Full path to the ssh public key file."
}

# Provider Configuration
provider "openstack" {
/*
   The necessary input to configure OpenStack as the provider
   will be picked up from the following env vars. Make sure
   that they are set appropriately.
      OS_USERNAME
      OS_TENANT_NAME
      OS_PASSWORD
      OS_AUTH_URL

   Easiest way to set these up is
      1. Login to your openstack account through horizon dashboard
      2. Navigate to Compute -> Access & Security -> API Access
      3. Download the OpenStack RC File v2.0
      4. Source the downloaded file in your Shell
      5. Run terraform from the same shell
*/
}

resource "openstack_networking_secgroup_v2" "ao-cluster-sg" {
   name                 = "ao-cluster-sg"
   description          = "Security group to be associated with the AO nodes"
   delete_default_rules = true
}


resource "openstack_networking_secgroup_rule_v2" "allow-ipv4-egress" {
   # Allow all outgoing IPv4 connections
   direction   		= "egress"
   ethertype   		= "IPv4"
	security_group_id	= "${openstack_networking_secgroup_v2.ao-cluster-sg.id}"
}

resource "openstack_networking_secgroup_rule_v2" "allow-ipv6-egress" {
   # Allow all outgoing IPv6 connections
   direction   		= "egress"
   ethertype   		= "IPv6"
	security_group_id	= "${openstack_networking_secgroup_v2.ao-cluster-sg.id}"
}

resource "openstack_networking_secgroup_rule_v2" "allow-intra-sg-ipv4" {
   # Allow all incoming IPv4 connections originating from nodes within the security group
   direction   		= "ingress"
   ethertype   		= "IPv4"
	remote_group_id	= "${openstack_networking_secgroup_v2.ao-cluster-sg.id}"
	security_group_id	= "${openstack_networking_secgroup_v2.ao-cluster-sg.id}"
}

resource "openstack_networking_secgroup_rule_v2" "allow-intra-sg-ipv6" {
   # Allow all incoming IPv6 connections originating from nodes within the security group
   direction   		= "ingress"
   ethertype   		= "IPv6"
	remote_group_id	= "${openstack_networking_secgroup_v2.ao-cluster-sg.id}"
	security_group_id	= "${openstack_networking_secgroup_v2.ao-cluster-sg.id}"
}

resource "openstack_networking_secgroup_rule_v2" "allow-1to21-ingress" {
   # Allow incoming IPv4 connections for ports 1 - 21 from any source
   direction   		= "ingress"
   ethertype   		= "IPv4"
   protocol          = "tcp"
   port_range_min    = "1"
   port_range_max    = "21"
   remote_ip_prefix  = "0.0.0.0/0"
	security_group_id	= "${openstack_networking_secgroup_v2.ao-cluster-sg.id}"
}

resource "openstack_networking_secgroup_rule_v2" "allow-23to4000-ingress" {
   # Allow incoming IPv4 connections for ports 23 - 4000 from any source
   direction   		= "ingress"
   ethertype   		= "IPv4"
   protocol          = "tcp"
   port_range_min    = "23"
   port_range_max    = "4000"
   remote_ip_prefix  = "0.0.0.0/0"
	security_group_id	= "${openstack_networking_secgroup_v2.ao-cluster-sg.id}"
}

resource "openstack_networking_secgroup_rule_v2" "allow-4002to65535-ingress" {
   # Allow incoming IPv4 connections for ports 4002 - 65535 from any source
   direction   		= "ingress"
   ethertype   		= "IPv4"
   protocol          = "tcp"
   port_range_min    = "4002"
   port_range_max    = "65535"
   remote_ip_prefix  = "0.0.0.0/0"
	security_group_id	= "${openstack_networking_secgroup_v2.ao-cluster-sg.id}"
}

resource "openstack_networking_secgroup_rule_v2" "allow-ssh-frm-aohost" {
   # Allow incoming IPv4 ssh connections from AO host only
   direction   		= "ingress"
   ethertype   		= "IPv4"
   protocol          = "tcp"
   port_range_min    = "22"
   port_range_max    = "22"
   remote_ip_prefix  = "${var.ao-host-ip}/32"
	security_group_id	= "${openstack_networking_secgroup_v2.ao-cluster-sg.id}"
}

resource "openstack_networking_secgroup_rule_v2" "allow-4001-frm-aohost" {
   # Allow incoming IPv4 connections to port 4001 (etcd) from AO host only
   direction   		= "ingress"
   ethertype   		= "IPv4"
   protocol          = "tcp"
   port_range_min    = "4001"
   port_range_max    = "4001"
   remote_ip_prefix  = "${var.ao-host-ip}/32"
	security_group_id	= "${openstack_networking_secgroup_v2.ao-cluster-sg.id}"
}

resource "openstack_networking_secgroup_rule_v2" "allow-ping-frm-aohost" {
   # Allow ping from the AO host
   direction   		= "ingress"
   ethertype   		= "IPv4"
   protocol          = "icmp"
   remote_ip_prefix  = "${var.ao-host-ip}/32"
	security_group_id	= "${openstack_networking_secgroup_v2.ao-cluster-sg.id}"
}

resource "openstack_networking_secgroup_rule_v2" "allow-ping-frm-fip" {
   # Allow pings between cluster nodes over the external / public IP subnet"
#   depends_on        = ["${openstack_compute_floatingip_v2.fip}"]
   count             = "${var.node-count}"
   direction   		= "ingress"
   ethertype   		= "IPv4"
   protocol          = "icmp"
   remote_ip_prefix  = "${element(openstack_compute_floatingip_v2.fip.*.address, count.index)}/32"
	security_group_id	= "${openstack_networking_secgroup_v2.ao-cluster-sg.id}"
}

resource "openstack_networking_secgroup_rule_v2" "allow-all-frm-fip" {
   # Allow all incoming IPv4 connections from external / public IPs of the AO  nodes"
#   depends_on        = ["${openstack_compute_floatingip_v2.fip}"]
   count             = "${var.node-count}"
   direction   		= "ingress"
   ethertype   		= "IPv4"
   protocol          = "tcp"
   remote_ip_prefix  = "${element(openstack_compute_floatingip_v2.fip.*.address, count.index)}/32"
	security_group_id	= "${openstack_networking_secgroup_v2.ao-cluster-sg.id}"
}

resource "openstack_networking_network_v2" "ao-cluster-net" {
   # Private network for the AO cluster
   name           = "ao-cluster-net"
   admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "ao-cluster-subnet" {
   # IP subnet for the AO cluster's private network
   name              = "ao-cluster-subnet"
   network_id        = "${openstack_networking_network_v2.ao-cluster-net.id}"
   cidr              = "${var.ao-cluster-net-cidr}"
   dns_nameservers   = ["${var.dns-server-1}", "${var.dns-server-2}"]
   ip_version = 4
}

resource "openstack_networking_router_v2" "ao-cluster-uplink-rtr" {
   # Router to uplink the AO cluster private network to the public network
   name              = "ao-cluster-uplink-rtr"
   external_gateway  = "${var.public-net-id}"
}

resource "openstack_networking_router_interface_v2" "ao-cluster-net-gw-intf" {
   # Connect the AO cluster private network to the router
   router_id = "${openstack_networking_router_v2.ao-cluster-uplink-rtr.id}"
   subnet_id = "${openstack_networking_subnet_v2.ao-cluster-subnet.id}"
}

resource "openstack_compute_floatingip_v2" "fip" {
   # Externap / Public IPs for the ao nodes
   count       = "${var.node-count}"
   depends_on  = ["openstack_networking_router_interface_v2.ao-cluster-net-gw-intf"]
   pool        = "${var.public-net-name}"
}

resource "openstack_compute_keypair_v2" "ao-node-kp" {
   # SSH keypair to be added to the AO nodes
   name        = "ao-node-kp"
   public_key  = "${file("${var.public-key-file}")}"
}

data "openstack_images_image_v2" "ao-node-img" {
   # Image to use for the AO nodes
   name        = "${var.image-name}"
   most_recent = "true"
}

resource "openstack_blockstorage_volume_v2" "ao-data-disk" {
   name        = "ao-data-disk-${count.index}"
   description = "Volume to be added to the AO nodes as data disk"
   count       = "${var.node-count}"
   size        = "${var.data-disk-size-gb}"
}

resource "openstack_compute_instance_v2" "ao-node" {
   # AO cluster node
   name              = "ao-node-${count.index}"
   count             = "${var.node-count}"
   image_id          = "${data.openstack_images_image_v2.ao-node-img.id}"
   flavor_name       = "${var.flavor-name}"
   key_pair          = "${openstack_compute_keypair_v2.ao-node-kp.name}"
   security_groups   = ["${openstack_networking_secgroup_v2.ao-cluster-sg.name}"]

   network {
      name = "${openstack_networking_network_v2.ao-cluster-net.name}"
   }
}

resource "openstack_compute_floatingip_associate_v2" "fip_associate" {
   # Associate the external / public IPs with the AO nodes
   count       = "${var.node-count}"
   floating_ip = "${element(openstack_compute_floatingip_v2.fip.*.address, count.index)}"
   instance_id = "${element(openstack_compute_instance_v2.ao-node.*.id, count.index)}"
}

resource "openstack_compute_volume_attach_v2" "ao-node-disk-attachment" {
   # Attach the data disks to the AO nodes
   count       = "${var.node-count}"
   instance_id = "${element(openstack_compute_instance_v2.ao-node.*.id, count.index)}"
   volume_id   = "${element(openstack_blockstorage_volume_v2.ao-data-disk.*.id, count.index)}"
}


# Display the public IPs of the nodes created
output "ao-node-ips" {
   description =  "External IPs of AO nodes"
   value       = ["${openstack_compute_floatingip_v2.fip.*.address}"]
}
