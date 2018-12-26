# Input Variables

variable "access-key" {
   description = "The access key for the AWS account"
}

variable "secret-key" {
   description = "The secret key for the AWS account"
}

variable "region" {
   description = "The region where the resources need to be created."
   default     = "us-west-2"
}

variable "availability-zone" {
   description = "The availability zone where the resources need to be created. This needs to be in the region specified. If not, bad things will happen."
   default     = "us-west-2a"
}

variable "ami-name" {
   description = "Name of the image from which cluster nodes should be created. The image should be Centos 7.3 based and should have passwordless sudo enabled for user centos."
   default     = "centos73-apporbit"
}

variable "instance-type" {
   description = "The instance type to use for the nodes"
   default     = "t2.large"
}

variable "node-count" {
   description = "Number of nodes to be created."
   default     = 1
}

variable "public-key-file" {
   description = "Full path to the ssh public key file."
}

variable "subnet-id" {
   description = "ID (not name) of the subnet to which the nodes should be connected"
}

variable "ao-host-ip" {
   description = "IP address of the AO host"
}

variable "data-vol-size-gb" {
   description = "Size of the data volumes (in GB) to be attached to the cluster nodes."
   default     = 50
}

# AWS Provider Configuration
provider "aws" {
   access_key  = "${var.access-key}"
   secret_key  = "${var.secret-key}"
   region      = "${var.region}"
}

# Create a reference to the image
data "aws_ami" "ao-node-ami" {
   most_recent = true

   filter {
      name     = "name"
      values   = ["${var.ami-name}"]
   }
}

# Create a reference to the subnet
data "aws_subnet" "ao-cluster-subnet" {
   id = "${var.subnet-id}"
}

# Create the key pair to use for the instance
resource "aws_key_pair" "ao-node-kp" {
   key_name    = "ao-node-key"
   public_key  = "${file("${var.public-key-file}")}"
}

# Create the security group for instances.
resource "aws_security_group" "ao-cluster-sg" {
   name        = "ao-cluster-sg"
   description = "Security group for cluster nodes"
   vpc_id      = "${data.aws_subnet.ao-cluster-subnet.vpc_id}"

   ingress {
      from_port   = 1
      to_port     = 65535
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      #cidr_blocks = ["${var.ao-host-ip}/32"]
   }

   egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
   }

   tags {
      owner       = "santhosh"
      client      = "terraform"
   }
}

# Create the volumes
resource "aws_ebs_volume" "ao-data-vols" {
   count             = "${var.node-count}"
   availability_zone = "${var.availability-zone}"
   size              = "${var.data-vol-size-gb}"
   type              = "gp2"

   tags {
      owner       = "santhosh"
      client      = "terraform"
   }
}

# Create the instances
resource "aws_instance" "ao-nodes" {
   count                         = "${var.node-count}"
   availability_zone             = "${var.availability-zone}"
   ami                           = "${data.aws_ami.ao-node-ami.id}"
   instance_type                 = "${var.instance-type}"
   key_name                      = "${aws_key_pair.ao-node-kp.key_name}"
   subnet_id                     = "${data.aws_subnet.ao-cluster-subnet.id}"
   vpc_security_group_ids        = ["${aws_security_group.ao-cluster-sg.id}"]
   associate_public_ip_address   = true

   tags {
      owner       = "santhosh"
      client      = "terraform"
   }
}

# Attach the volumes to the instances
resource "aws_volume_attachment" "ao-vol2node-attachments" {
   count          = "${var.node-count}"
   device_name    = "/dev/sdg"
   volume_id      = "${element(aws_ebs_volume.ao-data-vols.*.id, count.index)}"
   instance_id    = "${element(aws_instance.ao-nodes.*.id, count.index)}"
}

# Display the public IPs of the nodes created
output "ao-node-ips" {
   value = ["${aws_instance.ao-nodes.*.public_ip}"]
}
