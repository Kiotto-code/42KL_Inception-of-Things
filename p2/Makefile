# export PATH := $(CURDIR):$(PATH)

# HOSTS_FILE := /etc/hosts

# hosts:
# 	@grep -q "192.168.56.110 app1.com" $(HOSTS_FILE) || \
# 		echo "192.168.56.110    app1.com" | sudo tee -a $(HOSTS_FILE)
# 	@grep -q "192.168.56.110 app2.com" $(HOSTS_FILE) || \
# 		echo "192.168.56.110    app2.com" | sudo tee -a $(HOSTS_FILE)

# rebuild:
# 	cp .vagrant/machines/yichanS/virtualbox/private_key /tmp/yichanS_key
# 	chmod 600 /tmp/yichanS_key
# 	ssh -o StrictHostKeyChecking=no -i /tmp/yichanS_key -p $$(vagrant port yichanS --guest 22) vagrant@127.0.0.1 "sudo cat /var/lib/rancher/k3s/server/node-token" > node-token
# # 	rm /tmp/yichanS_key

login:
	cp .vagrant/machines/yichanS/virtualbox/private_key /tmp/yichanS_key
	chmod 600 /tmp/yichanS_key
	ssh -o StrictHostKeyChecking=no -i /tmp/yichanS_key -p $$(vagrant port yichanS --guest 22) vagrant@127.0.0.1

destroy:
	vagrant destroy -f

restart:
	vagrant destroy -f
	vagrant up --provision