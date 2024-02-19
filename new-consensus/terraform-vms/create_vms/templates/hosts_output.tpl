smft_vm_validators:
  hosts:
%{ for hostname, value in hostnames ~}
    ${value}:
      HOSTNAME: ${hostname}
%{ endfor ~}
  vars:
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -W %h:%p -p 2223 -q ruser@leonid.node.dev.tonlabs.io"'
    ROLE: network
    CLEAN_MODE: simple
