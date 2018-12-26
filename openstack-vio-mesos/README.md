A terraform template that uses the openstack provider to deploy a mesos cluster.


# Instructions

1. The template assumes [terraform](https://www.terraform.io/) is installed correctly.

2. The template picks up the following openstack specific environment variables to connect to the openstack cloud. Make sure that they are set appropriately. The easisest way is to log in to the Horizon dashboard, dowload the openrc file and execute it.
 ```
 OS_USERNAME
 OS_TENANT_NAME
 OS_PASSWORD
 OS_AUTH_URL
 ```

3. The template requires a bunch of mandatory input parameters. These can be provided by creating a terraform.tfvars file in this mesos-openstack/ folder and adding the inputs to this file. Below is a sample input file.
 ```
 $ cat terraform.tfvars
 image = "ubuntu-14.04-server-cloudimg-amd64"           # Name of the base image to use
 flavor = "m1.medium"                                   # Flavor to use for the master and slave nodes
 floating_ip_pool = "EXTNET"                            # Name of the external / public network
 public_net_id = "e7ef060a-5ff9-4148-8a38-993951ed9da9" # Id of the external / public network
 dns_server1 = "10.20.20.1"                             # Optional
 dns_server2 = "10.20.20.2"                             # Optional
 ssh_key_file = "ssh-keys/terraform.key"                # The private key part of the key pair to use for this deployment.
 ```

 Inspect the variables.tf to checkout other variables that can be configured. A couple of useful ones will be
 ```
 master_count
 slave_count
 ```
4. Important: The template assumes that the public key corresponding to the private is also in the same location as the private key and that it's name is the same as the private with a suffix .pub, for example the template will look for ssh-keys/terraform.key.pub.

 Keypairs can be easily created using the below command. Make sure that the keys are created without a passphrase.
 ```
 ssh-keygen -t rsa -f terraform.key
 ```
 This will create the corresponding terraform.key.pub in the same directory. Make sure that both keys (private and public) are in the same directory and follow the naming convention *<public-key-file-name>=<private-key-file-name>.pub*

5. Once the openstack environment variables, template input variables and the ssh keys are set appropriately, run
 ```
 terraform plan
 ```
 to make sure there are no errors.

6. Once terraform plan shows what terraform is going to do, run
 ```
 terraform apply
 ```

This should deploy the mesos-cluster.


