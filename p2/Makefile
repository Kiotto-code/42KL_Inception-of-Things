export PATH := $(CURDIR):$(PATH)

HOSTS_FILE := /etc/hosts

hosts:
	@grep -q "192.168.56.110 app1.com" $(HOSTS_FILE) || \
		echo "192.168.56.110    app1.com" | sudo tee -a $(HOSTS_FILE)
	@grep -q "192.168.56.110 app2.com" $(HOSTS_FILE) || \
		echo "192.168.56.110    app2.com" | sudo tee -a $(HOSTS_FILE)

rebuild :
	vagrant destroy -f
	vagrant up --provision # rebuild the VM
	vagrant ssh -c "sudo cat /var/lib/rancher/k3s/server/node-token" > node-token

destroy:
	vagrant destroy -f

restart:
	vagrant up --provision
