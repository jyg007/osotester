# OSO TESTER

Your way to IBM Hyper Protect Offline Signing Orchestrator.

## OSO Tester HOWTO 
 
### Define your HPVS using plugin smartcontract files
 
 ```
./create_front_contract.sh /tmp/frontend_plugin.yml 
./create_back_contract.sh /tmp/user-data
```

### Start up hpvs :

```
virsh start frontendplugintester
virsh start backendplugintester
```

### if needed

```
virsh start frontendplugintester --console
virsh start backendplugintester  --console
```

### Check Logs for hpvs errors !

`journactl -f`


### Test your plugin:

f,b and then 1 to 4 !

```
./osotester 

Choose an option:
f) front plugin status
b) back plugin status
1) FRONT - RETRIEVE tx for preconfirmation queue
2) ITERATION - INPUT BRIDGE upload
3) ITERATION - OUTPUT BRIDGE download
4) FRONT - UPLOAD tx from postconfirmation queue
0) Exit
```

## Additional info

### Enabling grep11 from OSO3 to OSO1

Modify your OSO3 IP address of this example
```
iptables -t nat -A PREROUTING -d 129.40.110.4 -p tcp --dport 9876  -j DNAT --to-destination 192.168.96.21:9876
iptables -t nat -A POSTROUTING -d 192.168.96.21 -p tcp --dport 9876  -j MASQUERADE
```
### hpcr version

copy the qcow2 hpcr image in install your hpcr in `/var/lib/libvirt/images/oso/hpcr.2.2.3.1`

`testerdata/domain_front.xml` and `testerdata/domain_back.xml` must be updated if you copy as another filename.
