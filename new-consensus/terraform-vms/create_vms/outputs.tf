output "ip" {
  value = libvirt_domain.domain-ever-node[*].network_interface[0].addresses[0]
}
