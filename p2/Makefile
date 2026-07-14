export PATH := $(CURDIR):$(PATH)

rebuild :
	vagrant destroy -f
	vagrant up --provision # rebuild the VM
	vagrant ssh -c "sudo cat /var/lib/rancher/k3s/server/node-token" > node-token

destroy:
	vagrant destroy -f

restart:
	vagrant up --provision
