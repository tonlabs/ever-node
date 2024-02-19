provider "libvirt" {
  uri = "qemu+ssh://ruser@leonid.node.dev.tonlabs.io:2223/system"
}

resource "libvirt_pool" "ever_node_disk_pool" {
  name = "ever_node_disk_pool"
  type = "dir"
  path = var.libvirt_disk_path
}

resource "libvirt_volume" "ever-node-qcow2-base" {
  name = "ubuntu_upstream"
  pool = libvirt_pool.ever_node_disk_pool.name
  source = var.ubuntu_20_img_url
  format = "qcow2"
}

resource "libvirt_volume" "ever-node-qcow2" {
  count = var.nodes_count
  name = format("ever-node-qcow2-%02d", count.index + 1)
  base_volume_id = libvirt_volume.ever-node-qcow2-base.id
  pool = libvirt_pool.ever_node_disk_pool.name
  size = 20000000000
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "commoninit.iso"
  user_data      = <<-EOF
    #cloud-config
    # vim: syntax=yaml
    # examples:
    # https://cloudinit.readthedocs.io/en/latest/topics/examples.html
    bootcmd:
      - echo 192.168.0.1 gw.homedns.xyz >> /etc/hosts
    runcmd:
     - [ ls, -l, / ]
     - [ sed, -i, 's/^#Port .*/Port 2223/', /etc/ssh/sshd_config ]
     - [ service, sshd, restart ]
     - [ sh, -xc, "echo $(date) ': hello world!'" ]
    ssh_pwauth: true
    disable_root: false
    chpasswd:
      list: |
         root:ton4ever
      expire: false
    users:
      - name: ruser
        sudo: ALL=(ALL) NOPASSWD:ALL
        groups: users, admin
        home: /home/ruser
        shell: /bin/bash
        lock_passwd: false
        ssh-authorized-keys:
          - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJdCrUGWRYUgpY5KEVfcBO9YXnNXQgKpQdylBLBOj6O8 Terraform        
          - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF6j9dLNIvZGTBswFX8/JtpIodP3S/paTRUquSoglpjR leonid.k@tonlabs.io
          - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDKXYhKJ4xfjvYi6PIbvYb7une9Q1o/USNTeDKX/L476RrS00Nx5SHVEFG7o8SN5zXoKGt9OXoDcQS7dN89aVN484Hn/fu+4wDQmASBL82DNdBhyIbkFsA1/oYLCpviguWG+eBsJyfJhGNMyb0YKmO6q5uvV6NPewPqIflXhhw/Fw== LK
    final_message: "The system is finally up, after $UPTIME seconds"  
  EOF

  network_config = <<-EOF
    version: 2
    ethernets:
      ens3:
        dhcp4: true
  EOF

  pool = libvirt_pool.ever_node_disk_pool.name
}

resource "libvirt_domain" "domain-ever-node" {
  count  = var.nodes_count
  name   = format("%s-%02d", var.vm_hostname, count.index + 1)
  memory = "4096"
  vcpu   = 4

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name   = "default"
    wait_for_lease = true
    hostname       = format("%s-%02d", var.vm_hostname, count.index + 1)
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = libvirt_volume.ever-node-qcow2[count.index].id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

resource "null_resource" "remote_provisioning" {
  count = var.nodes_count

  provisioner "remote-exec" {
    inline = [
      "echo 'Hello World'"
    ]

    connection {
      type                = "ssh"
      user                = var.ssh_username
      host                = libvirt_domain.domain-ever-node[count.index].network_interface[0].addresses[0]
      port                = 2223
      private_key         = file(var.ssh_private_key)
      bastion_host        = "leonid.node.dev.tonlabs.io"
      bastion_port        = 2223
      bastion_user        = "ruser"
      #bastion_private_key = file(var.ssh_private_key)
      #bastion_private_key = file("/home/ruser/.ssh/id_ed25519")
      agent               = true
      timeout             = "2m"
    }
  }
}

locals {
  hosts_file = templatefile("${path.module}/templates/hosts_output.tpl", {
      hostnames = {
        for instance in libvirt_domain.domain-ever-node:
        instance.name => instance.network_interface[0].addresses[0]
      }
    })
}

resource "null_resource" "ansible_host_provisioner" {
  depends_on = [null_resource.remote_provisioning]

  triggers = {
    hosts_file = local.hosts_file
    #always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOT
      # Save the hosts_file as an inventory file
      cat <<EOF > ../../ton-deployment/ansible/hosts/smft_vm_all.yaml
${local.hosts_file}
EOF

      # Copy initial scripts
      cp -fv ansible/host_configuration.yml ../../ton-deployment/ansible

      # Run ansible-playbook with the inventory file
      cd ../../ton-deployment/ansible
      ansible-playbook --private-key ../../keys/vm/id_ed25519 host_configuration.yml
    EOT
  }
}

resource "null_resource" "ansible_validators_deployer" {
  depends_on = [null_resource.ansible_host_provisioner]

  triggers = {
    hosts_file = local.hosts_file
    #always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOT
      # Save the hosts_file as an inventory file
      cat <<EOF > ../../ton-deployment/ansible/hosts/smft_vm_all.yaml
${local.hosts_file}
EOF

      # Run ansible-playbook with the inventory file
      cd ../../ton-deployment/ansible
      ansible-playbook \
        --private-key ../../keys/vm/id_ed25519 \
        -e @cluster_vars/smft_vm_validators.yaml \
        -e CLUSTER=smft_vm_validators \
        -e WORKSPACE=`cd .. && pwd` \
        -e GIT_COMMIT=`git rev-parse HEAD` \
        -e sdk_endpoint_prefix= \
        -e skip_unreacheble_mutex_check=false \
        -e long_rnode_init=false \
        deploy-cluster.playbook.yaml
    EOT
  }
}
