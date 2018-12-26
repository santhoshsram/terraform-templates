/*********************************
 * Provider Configuration        *
 *********************************/
provider "openstack" {
/*
   The necessary input to configure OpenStack as the provider
   will be picked up from the following env vars. Make sure
   that they are set appropriately.
      OS_USERNAME
      OS_TENANT_NAME
      OS_PASSWORD
      OS_AUTH_URL
*/
}


/*********************************
 * Resources                     *
 *********************************/
resource "openstack_compute_secgroup_v2" "config_server_sg" {
   name = "config_server_sg"
   description = "Security group for the config server"
   rule {
      # Enable SSH
      from_port = 22
      to_port = 22
      ip_protocol = "tcp"
      cidr = "0.0.0.0/0"
   }
}

resource "openstack_compute_secgroup_v2" "mesos_masters_sg" {
   name = "mesos_masters_sg"
   description = "Security group for the mesos masters"
   rule {
      # Enable SSH
      from_port = 22
      to_port = 22
      ip_protocol = "tcp"
      cidr = "10.0.0.0/24"
   }
   rule {
      # Enable port 8080 to allow access to marathon
      from_port = 8080
      to_port = 8080
      ip_protocol = "tcp"
      cidr = "0.0.0.0/0"
   }
   rule {
      # Enable port 5050 to allow access to mesos-master
      from_port = 5050
      to_port = 5050
      ip_protocol = "tcp"
      cidr = "0.0.0.0/0"
   }
   rule {
      # Enable port 2181 to allow slaves to connect to master
      from_port = 2181
      to_port = 2181
      ip_protocol = "tcp"
      cidr = "10.0.0.0/24"
   }
   rule {
      # Enable port 2888 to allow zookeeper peer traffic
      from_port = 2888
      to_port = 2888
      ip_protocol = "tcp"
      cidr = "10.0.0.0/24"
   }
   rule {
      # Enable port 3888 for zookeeper leader election
      from_port = 3888
      to_port = 3888
      ip_protocol = "tcp"
      cidr = "10.0.0.0/24"
   }
}

resource "openstack_compute_secgroup_v2" "mesos_slaves_sg" {
   name = "mesos_slaves_sg"
   description = "Security group for the mesos slaves"
   rule {
      # Enable SSH
      from_port = 22
      to_port = 22
      ip_protocol = "tcp"
      cidr = "10.0.0.0/24"
   }
}

resource "openstack_networking_network_v2" "mesos_net" {
   name = "mesos_net"
   admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "mesos_subnet" {
   name = "mesos_subnet"
   network_id = "${openstack_networking_network_v2.mesos_net.id}"
   cidr = "10.0.0.0/24"
   dns_nameservers = ["${var.dns_server1}", "${var.dns_server2}"]
   ip_version = 4
}

resource "openstack_networking_router_v2" "mesos_gw_rtr" {
   name = "mesos_gw_rtr"
   external_gateway = "${var.public_net_id}"
}

resource "openstack_networking_router_interface_v2" "mesos_gw_intf" {
   router_id = "${openstack_networking_router_v2.mesos_gw_rtr.id}"
   subnet_id = "${openstack_networking_subnet_v2.mesos_subnet.id}"
}

resource "openstack_compute_floatingip_v2" "floatingip" {
   depends_on = ["openstack_networking_router_interface_v2.mesos_gw_intf"]
   pool = "${var.floating_ip_pool}"
}


resource "openstack_compute_keypair_v2" "keypair" {
   name = "Mesos-Key-Pair"
   public_key = "${file("${var.ssh_key_file}.pub")}"
}

resource "openstack_compute_instance_v2" "config_server" {
   name = "config_server"
   image_name = "${var.image}"
   flavor_name = "${var.flavor}"
   key_pair = "${openstack_compute_keypair_v2.keypair.name}"
   security_groups = ["${openstack_compute_secgroup_v2.config_server_sg.name}"]

   network {
      name = "${openstack_networking_network_v2.mesos_net.name}"
      floating_ip = "${openstack_compute_floatingip_v2.floatingip.address}"
   }
}

resource "openstack_compute_instance_v2" "mesos_masters" {
   count = "${var.master_count}"
   depends_on = ["openstack_compute_instance_v2.config_server"]
   name = "mesos_master_${count.index + 1}"
   image_name = "${var.image}"
   flavor_name = "${var.flavor}"
   key_pair = "${openstack_compute_keypair_v2.keypair.name}"
   security_groups = ["${openstack_compute_secgroup_v2.mesos_masters_sg.name}"]
   network {
      name = "${openstack_networking_network_v2.mesos_net.name}"
   }
}

resource "openstack_compute_instance_v2" "mesos_slaves" {
   count = "${var.master_count}"
   depends_on = ["openstack_compute_instance_v2.config_server"]
   name = "mesos_slave_${count.index + 1}"
   image_name = "${var.image}"
   flavor_name = "${var.flavor}"
   key_pair = "${openstack_compute_keypair_v2.keypair.name}"
   security_groups = ["${openstack_compute_secgroup_v2.mesos_slaves_sg.name}"]
   network {
      name = "${openstack_networking_network_v2.mesos_net.name}"
   }
}

resource "null_resource" "prep_config_server" {
   triggers {
      instance_ids = "${openstack_compute_instance_v2.config_server.id}"
   }
   connection {
      host = "${openstack_compute_instance_v2.config_server.network.0.floating_ip}"
      user = "${var.ssh_user_name}"
      private_key = "${file("${var.ssh_key_file}")}"
   }

   provisioner "local-exec" {
      # Tar all files to be uploaded to the config server
      command = "tar -cjf config-server-files.tar.bz2 ansible/ confs/ scripts/"
   }

   provisioner "file" {
      # Tar ball of all configs, playbooks & templates that
      # the config server needs
      source = "config-server-files.tar.bz2"
      destination = "~/config-server-files.tar.bz2"
   }

   provisioner "file" {
      # SSH private key. config server will need this to ssh
      # to the masters & slaves
      source = "${var.ssh_key_file}"
      destination = "~/.ssh/id_rsa"
   }

   provisioner "remote-exec" {
      inline = [
         "cd ~; tar -xjf config-server-files.tar.bz2",
         "rm ~/config-server-files.tar.bz2",
         "chmod +x ~/scripts/prep-config-server.sh",
         "chmod +x ~/scripts/generate-master-configs.sh",
         "chmod +x ~/scripts/generate-slave-configs.sh",
         "chmod 600 ~/.ssh/id_rsa",
         "ln -sf ~/confs/ansible.cfg ~/.ansible.cfg",
         "~/scripts/prep-config-server.sh"
      ]
   }

   provisioner "local-exec" {
      # Cleanup the tar ball that was copied to the config server
      command = "rm config-server-files.tar.bz2"
   }
}

resource "null_resource" "prep_mesos_masters" {
   depends_on = ["null_resource.prep_config_server"]
   triggers {
      instance_ids = "${join(", ", openstack_compute_instance_v2.mesos_masters.*.id)}"
   }

   connection {
      host = "${openstack_compute_instance_v2.config_server.network.0.floating_ip}"
      user = "${var.ssh_user_name}"
      private_key = "${file("${var.ssh_key_file}")}"
   }

   provisioner "remote-exec" {
      inline = [
         "~/scripts/generate-master-configs.sh ${join(" ", openstack_compute_instance_v2.mesos_masters.*.network.0.fixed_ip_v4)}",
         "ansible-playbook ~/ansible/playbooks/bootstrap-masters.yaml"
      ]
   }
}

resource "null_resource" "prep_mesos_slaves" {
   depends_on = ["null_resource.prep_config_server"]
   triggers {
      instance_ids = "${join(", ", concat(openstack_compute_instance_v2.mesos_masters.*.id, openstack_compute_instance_v2.mesos_slaves.*.id))}"
   }

   connection {
      host = "${openstack_compute_instance_v2.config_server.network.0.floating_ip}"
      user = "${var.ssh_user_name}"
      private_key = "${file("${var.ssh_key_file}")}"
   }

   provisioner "remote-exec" {
      inline = [
         "~/scripts/generate-slave-configs.sh ${join(" ", openstack_compute_instance_v2.mesos_slaves.*.network.0.fixed_ip_v4)}",
         "ansible-playbook ~/ansible/playbooks/bootstrap-slaves.yaml"
      ]
   }
}
