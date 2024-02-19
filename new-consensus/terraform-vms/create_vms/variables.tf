variable "libvirt_disk_path" {
  description = "path for libvirt pool"
  default     = "/var/lib/kvm/ever-node-pool"
}

variable "ubuntu_20_img_url" {
  description = "ubuntu 20.04 image"
  default     = "https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"

}

variable "vm_hostname" {
  description = "vm hostname"
  default     = "ever-d-node"
}

variable "ssh_username" {
  description = "the ssh user to use"
  default     = "ruser"
}

variable "ssh_private_key" {
  description = "the private key to use"
  default     = "../../keys/vm/id_ed25519"
}

variable "nodes_count" {
  description = "number of nodes"
  default     = 3
}
