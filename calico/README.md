## Installation of Calico

## etcd

Install etcd manually on dedicated nodes using an HA cluster:  
https://docs.projectcalico.org/v2.6/getting-started/mesos/installation/prerequisites  (Step: 1)

For simplicity I'm starting a single etcd instance with Docker on my Bootstrap Machine:

```
export ETCD_IP=172.31.5.132
export ETCD_PORT=2379
```

```
docker run --detach \
  --net=host \
  --name etcd quay.io/coreos/etcd:v3.1.10 \
  etcd --advertise-client-urls "http://$ETCD_IP:$ETCD_PORT" \
  --listen-client-urls "http://$ETCD_IP:$ETCD_PORT,http://127.0.0.1:$ETCD_PORT"
```

The recommendation is to setup an HA cluster: https://coreos.com/etcd/docs/latest/v2/clustering.html#static

## Calico CNI


**The following steps needs to be done on each cluster node - Masters and Agents:**


If your cluster is running in AWS, you need to disable the Source/Destination Checks on all of your nodes. To do so log into the AWS EC2 interface, right click on each of the instances that are used as private nodes and select Networking / Change Source/Dest. Check, [Yes, Disable]

Install calico manually by starting the Calico Node via Docker:

```
sudo docker rm /calico-node -f | true && sudo docker run -d --restart=always --net=host --privileged --name=calico-node -e FELIX_IGNORELOOSERPF=true -v /lib/modules:/lib/modules -v /var/log/calico:/var/log/calico -v /var/run/calico:/var/run/calico -v /run/docker/plugins:/run/docker/plugins -v /var/run/docker.sock:/var/run/docker.sock -e CALICO_LIBNETWORK_ENABLED=true -e IP=$(/opt/mesosphere/bin/detect_ip) -e HOSTNAME=$(hostname) -e ETCD_ENDPOINTS=http://172.31.5.132:2379 -e ETCD_SCHEME=http quay.io/calico/node:v2.6.2
```

**The following steps needs to be done only on Agents:**

Download and install the binaries for the Calico CNI plugin:

```
curl -L https://github.com/projectcalico/cni-plugin/releases/download/v1.5.5/calico -o /opt/mesosphere/active/cni/calico
curl -L https://github.com/projectcalico/cni-plugin/releases/download/v1.5.5/calico-ipam -o /opt/mesosphere/active/cni/calico-ipam
chmod +x /opt/mesosphere/active/cni/calico /opt/mesosphere/active/cni/calico-ipam
```

Configure Calico CNI module to point to your ETCD store:

```
vi /opt/mesosphere/etc/dcos/network/cni/calico.cni
```

```
{
    "name": "calico",
    "type": "calico",
    "etcd_endpoints": "http://172.31.5.132:2379",
    "ipam": {
        "type": "calico-ipam"
    }
}
```

Restart the Agent:

```
systemctl restart dcos-mesos-slave
```

or

```
systemctl restart dcos-mesos-slave-public
```

## Calico Config

On the Bootstrap Node

```
sudo curl -L https://github.com/projectcalico/calicoctl/releases/download/v1.6.1/calicoctl -o /usr/bin/calicoctl
sudo chmod +x /usr/bin/calicoctl
```

We also enable IPIP to be able to connect to Nodes across different AWS AZs:

```
calicoctl apply -f - <<EOF
- apiVersion: v1
  kind: ipPool
  metadata:
    cidr: 192.168.0.0/16
  spec:
    ipip:
      enabled: true
      mode: cross-subnet
    nat-outgoing: true
- apiVersion: v1
  kind: ipPool
  metadata:
    cidr: fd80:24e2:f998:72d6::/64
  spec: {}
EOF
```
