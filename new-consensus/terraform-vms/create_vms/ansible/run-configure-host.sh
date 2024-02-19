#export ANSIBLE_ROLES_PATH=$ANSIBLE_ROLES_PATH:../../../../TON-Deployment/ansible/roles
cp -fv host_configuration.yml ../../../../TON-Deployment/ansible
#cp -fv inventory.ini ../../../../TON-Deployment/ansible
cp -fv ../../../keys/vm/id_ed25519 ../../../../TON-Deployment/ansible
#cp -fv ansible.cfg ../../../../TON-Deployment/ansible
cd ../../../../TON-Deployment/ansible
#ansible-playbook --private-key id_ed25519 -i inventory.ini host_configuration.yml
ansible-playbook --private-key id_ed25519 host_configuration.yml

