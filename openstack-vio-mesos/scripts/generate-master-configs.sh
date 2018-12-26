#!/bin/bash

# Input Args: List of IP addresses separated by space.

#
# Create the ansible inventory file for masters
# We'll use inventory variables to assign zookeeper
# ids fo the master. (Ansible is neat like that!)
#
zk_id=1
echo "[masters]" > ~/ansible/inventory/masters
for master in "$@";
do
   echo "$master zk_id=$zk_id" >> ~/ansible/inventory/masters
   zk_id=$((zk_id+1))
done

#
# Create config for /etc/mesos/zk
#
zk="zk://"
for master in "$@";
do
   zk="${zk}${master}:2181,"
done

# Remove last trailing comma
# We'll use the config in zk for marathon config file too.
zk=${zk::-1}

# Write the config to the template file
echo "$zk/mesos" > ~/ansible/templates/master_etc_mesos_zk

#
# Create config for /etc/zookeeper/conf/zoo.cfg
#
zk_id=1
truncate -s 0 ~/ansible/templates/zoo_cfg_fragments/master_etc_zookeeper_conf_zoo_cfg_2
for master in "$@";
do
   echo "server.$zk_id=$master:2888:3888" >> ~/ansible/templates/zoo_cfg_fragments/master_etc_zookeeper_conf_zoo_cfg_2
   zk_id=$((zk_id+1))
done

#
# Create config for /etc/mesos-master/quorum
#
quorum="$((($#+1)/2))"
echo $quorum > ~/ansible/templates/master_etc_mesos_master_quorum

#
# Create config for /etc/marathon/conf/master
#
# No need to create a new file. We'll just re-use
# ~/ansible/templates/master_etc_mesos_zk

#
# Create config for /etc/marathon/conf/zk
#
echo "$zk/marathon" > ~/ansible/templates/master_etc_marathon_conf_zk
