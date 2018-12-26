/*********************************
 * Output Variables              *
 *********************************/
output "config_server_ip" {
   value = "${openstack_compute_instance_v2.config_server.network.0.floating_ip}"
}

output "mesos_master_ips" {
   value = "${join(", ", openstack_compute_instance_v2.mesos_masters.*.network.0.fixed_ip_v4)}"
}
