# Provided by Mouhssine SAIDI COE free to use and distribute as is

# This terraform file is to automate the delphix engine 
# install and configuration it only focuses on Vcenter topology

#############################################
#                                           #
#       Customer variable to define         #
#                                           #
#############################################

variable "project_dir" {
    default = "/home/delphix/delphix_factory"
    description = "Factory project dir containing scripts"
}

variable "esx_ip" {
    default = "172.24.0.33"
    description = "Esx deployment targets list comma separated"
}

variable "esx_user" {
    default = "root"
    description = "Privileged user to connect to ESX server"
}

variable "esx_password" {
    default = "hpinvent"
    description = "ESX user password"
}

#Provide one or more data datastores name
variable "delphix_data_datastores" {
    default = "DELPHIX_DS_KAM-01,DELPHIX_DS_KAM-02,DELPHIX_DS_KAM-03"
    description = "Existing datastore to host the delphix os vmdk"
}

#Notice indicated vmdk will be created under the list of datastores provided befor (you shou at leat have one or the same number as vmks files)
variable "delphix_data_vmdks" {
    default = "Delphix_Engine/Delphix_Engine-000001.vmdk,Delphix_Engine/Delphix_Engine-000002.vmdk,Delphix_Engine/Delphix_Engine-000003.vmdk"
    description = "Path to delphix engine vmdks, exclude datastore name in path"
}

variable "delphixos_datastore" {
# use commande "govc ls datastore" to get datastores list
    default = "DELPHIX_DS_OS"
    description = "Existing datastore to host the delphix os vmdk "
}

variable "data_vmdk_size" {
    default = "100GB"
    description = "Delphix data vmdk file size to create"
}

variable "delphix_ova_path" {
    default = "/u02/Prime_target_2.3.1_Partner.ova"
    description = "The path under local system to delphix's engine OVA"
}

variable "delphix_vm_path" {
# use commande "govc ls vm" to get datastores list
    default = "/ha-datacenter/vm/Delphix_5.0.5.3"
    description = "The path to the engine VM"
}

variable "engine_ip" {
    default = "172.25.0.110"
    description = "Engine IP address to set"
}

variable "sysadmin_pass" {
    default = "ITSOverl@p1"
    description = "Password to set to sysadmin user"
}

variable "delphixadmin_pass" {
    default = "ITSOverl@p"
    description = "Password to set to delphix_admin user"
}

variable "default_gw" {
    default =  "172.25.255.254"
    description = "The engine vm default gateway"
}

variable "dns" {
    default = "172.24.0.45,172.24.0.41"
    description = "dns server list comma separated"
}

###################################################
#                                                 #
#     Static default variable (do not change)     #  
#                                                 #
###################################################
variable "sysadmin_old" {
    default = "sysadmin"
    description = "Initial sysadmin user password"
}

variable "delphixadmin_old" {
    default = "delphix"
    description = "Initial delphix_admin user password"
}

###################################################
#                                                 #
#        RESOURCE SECTION START'S HERE            #
#                                                 #
###################################################


# Call govc to load the ova engine to your ESX

resource "null_resource" "OVA-LOAD" {
   provisioner "local-exec" {
    #This provisioner load the engine ova to a given ESX
     command=" echo \"Step 1: Invok govc to deploy the ova image\n\";export GOVC_URL=${var.esx_ip}; export GOVC_USERNAME=${var.esx_user}; export GOVC_PASSWORD=${var.esx_password}; export GOVC_DATASTORE=${var.delphixos_datastore} ;export GOVC_INSECURE=1; /usr/local/bin/govc import.ova ${var.delphix_ova_path}"
  }
}

# Call govc to create vmdk disks for the engine VM

resource "null_resource" "CREATE-DATA-DISKS" {
      count = "${length(split(",", var.delphix_data_datastores))}"
   provisioner "local-exec" {
    #This provisioner is to create delphix data vmdks
      command="echo \"Step 2 :About to attach data disks to the engine vm\n\";  export GOVC_URL=${var.esx_ip}; export GOVC_USERNAME=${var.esx_user}; export GOVC_PASSWORD=${var.esx_password}; export GOVC_DATASTORE=${element(split(",", var.delphix_data_datastores), count.index)};export GOVC_VM=${var.delphix_vm_path}; export GOVC_INSECURE=1; /usr/local/bin/govc vm.disk.create -name=${element(split(",", var.delphix_data_vmdks), count.index)} -size={var.data_vmdk_size}"
  }
     depends_on = ["null_resource.OVA-LOAD"]
}

# Call govc to attach vmdk disks to the engine VM

resource "null_resource" "ATTACH-DATA-DISKS" {
      count = "${length(split(",", var.delphix_data_datastores))}"
   provisioner "local-exec" {
    #This provisioner is to attach data vmdk disks to engine vm
      command="echo \"Step 2 :About to attach data disks to the engine vm\n\"; export GOVC_URL=${var.esx_ip}; export GOVC_USERNAME=${var.esx_user}; export GOVC_PASSWORD=${var.esx_password}; export GOVC_DATASTORE=${element(split(",", var.delphix_data_datastores), count.index)};export GOVC_VM=${var.delphix_vm_path} ;export GOVC_INSECURE=1; /usr/local/bin/govc vm.disk.attach -disk ${element(split(",", var.delphix_data_vmdks), count.index)}"
  }
     depends_on = ["null_resource.CREATE-DATA-DISKS"]
}

# Call govc to power on the engine VM

resource "null_resource" "POWER-ON-ENGINE" {
   provisioner "local-exec" {
    #This provisioner is to start vm
      command="echo \"Step 2 :About to start the engine vm\n\"; export GOVC_URL=${var.esx_ip}; export GOVC_USERNAME=${var.esx_user}; export GOVC_PASSWORD=${var.esx_password} ;export GOVC_INSECURE=1; /usr/local/bin/govc vm.power -on ${var.delphix_vm_path}"
  }
     depends_on = ["null_resource.ADD-DATA-DISKS"]
}

# Call engine_network_assignment.py script to configure the engine network

resource "null_resource" "ENGINE-NETWORK-ASSIGNEMENT" {
   provisioner "local-exec" {
    #This provisioner is to undo the workaround
     command="echo \"Step 3 :About to assigne network configuration to the engine\n\"; python ${var.project_dir}/engine_network_assignment.py -e $(export GOVC_URL=172.24.0.31; export GOVC_USERNAME=root; export GOVC_PASSWORD=hpinvent; export GOVC_INSECURE=1; /usr/local/bin/govc vm.ip /ha-datacenter/vm/Delphix_Source) -n ${var.engine_ip}/16 -p ${var.sysadmin_old} -g ${var.default_gw} -d ${var.dns}"
  }
     depends_on = ["null_resource.POWER-ON-ENGINE"]
}

# Call engine_setup.py to configure the sysadmin user and domain0

resource "null_resource" "ENGINE-DOMAIN-AND-SYSADMIN-USER-SETUP" {
   provisioner "local-exec" {
    #This provisioner is to configure sysadmin and set domain0
     command="echo \"Step 4: About to ser the domain and sysadmin user\n\"; python ${var.project_dir}/engine_setup.py -e ${var.engine_ip} -o ${var.sysadmin_old} -p ${var.sysadmin_pass}"
  }
     depends_on = ["null_resource.ENGINE-NETWORK-ASSIGNEMENT"]
}

# Call delphix_admin_setup.py to configure the delphix_admin user
resource "null_resource" "DELPHIX-ADMIN-USER-SETUP" {
   provisioner "local-exec" {
    #This provisioner is to configure delphix_admin account
     command="echo \"Step 5: About to set delphix_admin user\n\"; python  ${var.project_dir}/delphix_admin_setup.py -e ${var.engine_ip} -o ${var.delphixadmin_old} -p ${var.delphixadmin_pass}"
  }
     depends_on = ["null_resource.ENGINE-DOMAIN-AND-SYSADMIN-USER-SETUP"]
}


  output "DELPHIX_ENGINE" {
    value = ["Delphix Engine - Public IP: ${var.engine_ip}\n    Access via http://${var.engine_ip}\n    Username: delphix_admin Password: ${var.delphixadmin_pass}"]
}