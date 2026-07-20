```
 GET / HTTP/1.1
 Host: app2.com
```
or
```
curl -H "Host:app2.com" 192.168.56.110
```

Check whether app2 load balancing is working
```
kubectl get pods -l app=app-two
for i in {1..10}; do curl -s -H "Host: app2.com" 192.168.56.110; echo; done
for i in {1..10}; do curl -s -H "Host: app2.com" 192.168.56.110 | grep -oP '(?<=<td>).*?(?=</td>)'; echo "---"; done
```


DNS routing for your virtual machine
```
--natdnshostresolver1 "on": Tells the virtual machine to use your host computer's (your laptop's) DNS system to resolve website names, rather than trying to look them up independently.
--natdnsproxy1 "on": Forces all DNS requests made by the VM to proxy directly through your host machine's active network connection.
```

The K3s Killall Script (Wipe containers & network)
```
vagrant ssh -c "sudo /usr/local/bin/k3s-killall.sh"\
```

By default, VirtualBox does not pass hardware virtualization through to its guest operating systems. You have to explicitly tell your parent hypervisor to allow it.
```
bcdedit /set hypervisorlaunchtype off
cd "C:\Program Files\Oracle\VirtualBox"
VBoxManage modifyvm "IOT" --nested-hw-virt on
```