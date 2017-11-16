# spark-cni

## Overview
DC/OS 1.10 adds support for CNI plugins (Marked as Preview) and Data Services (based on the DC/OS SDK) are able to use this CNI-Based virtual networks: https://docs.mesosphere.com/1.10/networking/virtual-networks/cni-plugins/)

If you want use Calico, you can start out testing the community supported packages of etcd and calico. The guide for that is: https://docs.projectcalico.org/v2.6/getting-started/mesos/installation/dc-os/framework I tested these packages, but they were failing to deploy in DC/OS Strict mode and are created for demo purposes anyway.

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

## Example Configs

```
{
  "id": "/nginx-ucr-dcos",
  "instances": 1,
  "container": {
    "type": "MESOS",
    "volumes": [],
    "docker": {
      "image": "sdelrio/docker-minimal-nginx"
    },
    "portMappings": []
  },
  "cpus": 0.1,
  "mem": 128,
  "requirePorts": false,
  "networks": [
    {
      "name": "dcos",
      "mode": "container"
    }
  ],
  "healthChecks": [],
  "fetch": [],
  "constraints": []
}
```


```
{
  "id": "/nginx-ucr-calico",
  "instances": 1,
  "container": {
    "type": "MESOS",
    "volumes": [],
    "docker": {
      "image": "sdelrio/docker-minimal-nginx"
    },
    "portMappings": []
  },
  "cpus": 0.1,
  "mem": 128,
  "requirePorts": false,
  "networks": [
    {
      "name": "calico",
      "mode": "container"
    }
  ],
  "healthChecks": [],
  "fetch": [],
  "constraints": []
}
```

```
dcos task exec nginx-ucr-calico ping -c 3 nginx-ucr-calico.marathon.containerip.dcos.thisdcos.directory
```

## Calico Config

On the Bootstrap Node

```
sudo curl -L https://github.com/projectcalico/calicoctl/releases/download/v1.6.1/calicoctl -o /usr/bin/calicoctl
sudo chmod +x /usr/bin/calicoctl
```


The default profile doesn't allow the Host to connect to Calico IP addresses. But in order for starting a Spark Job, it must be able to talk to Mesos Masters:

```
calicoctl apply -f - <<EOF
- apiVersion: v1
  kind: profile
  metadata:
    name: calico
  spec:
    egress:
    - action: allow
      destination: {}
      source: {}
    ingress:
    - action: allow
      destination: {}
      source: {}
EOF
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


## Spark Streaming Job with CNI

- For this demo install Kafka in Strict Mode

```
dcos security org service-accounts keypair kafka-private-key.pem kafka-public-key.pem
dcos security org service-accounts create -p kafka-public-key.pem -d "Kafka service account" kafka-principal
dcos security secrets create-sa-secret --strict kafka-private-key.pem kafka-principal kafka/secret
```

- Create permissions for Kafka

```
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:framework:role:kafka-role \
-d '{"description":"Controls the ability of kafka-role to register as a framework with the Mesos master"}' \
-H 'Content-Type: application/json'
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:reservation:role:kafka-role \
-d '{"description":"Controls the ability of kafka-role to reserve resources"}' \
-H 'Content-Type: application/json'
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:volume:role:kafka-role \
-d '{"description":"Controls the ability of kafka-role to access volumes"}' \
-H 'Content-Type: application/json'
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:reservation:principal:kafka-principal \
-d '{"description":"Controls the ability of kafka-principal to reserve resources"}' \
-H 'Content-Type: application/json'
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:volume:principal:kafka-principal \
-d '{"description":"Controls the ability of kafka-principal to access volumes"}' \
-H 'Content-Type: application/json'  
```

- Grant Permissions to Kafka

```
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:framework:role:kafka-role/users/kafka-principal/create
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:reservation:role:kafka-role/users/kafka-principal/create
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:volume:role:kafka-role/users/kafka-principal/create
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:task:user:nobody/users/kafka-principal/create
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:reservation:principal:kafka-principal/users/kafka-principal/delete
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:volume:principal:kafka-principal/users/kafka-principal/delete
```

## Install Kafka

**config.json**

```
{
  "service": {
    "name": "kafka",
    "user": "nobody",
    "service_account": "kafka-principal",
    "service_account_secret": "kafka/secret",
    "virtual_network_enabled": true,
    "virtual_network_name": "calico",
    "virtual_network_plugin_labels": "app:backend,group:development"
  }
}
```

```
dcos package install --options=config.json kafka
```

- Check that Kafka brokers are using the Calico IP addresses

```
dcos kafka endpoints broker
{
  "address": [
    "192.168.177.0:1025",
    "192.168.133.64:1025",
    "192.168.186.192:1025"
  ],
  "dns": [
    "kafka-0-broker.kafka.autoip.dcos.thisdcos.directory:1025",
    "kafka-1-broker.kafka.autoip.dcos.thisdcos.directory:1025",
    "kafka-2-broker.kafka.autoip.dcos.thisdcos.directory:1025"
  ],
  "vip": "broker.kafka.l4lb.thisdcos.directory:9092"
}
```

- Setup a topic

```
dcos kafka topic create mytopic --replication=2 --partitions=4
```

## Install Spark

- Setup service account and secret

```bash
dcos security org service-accounts keypair spark-private.pem spark-public.pem
dcos security org service-accounts create -p spark-public.pem -d "Spark service account" spark-principal
dcos security secrets create-sa-secret --strict spark-private.pem spark-principal spark/secret
```

- Create permissions for the Spark Service Account¬ (Note: Some of them already exist.)

```bash
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:agent:task:user:root \
-d '{"description":"Allows Linux user root to execute tasks"}' \
-H 'Content-Type: application/json'
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" "$(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:framework:role:*" \
-d '{"description":"Allows a framework to register with the Mesos master using the Mesos default role"}' \
-H 'Content-Type: application/json'
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" "$(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:task:app_id:%252Fspark" \
-d '{"description":"Allow to read the task state"}' \
-H 'Content-Type: application/json'
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:task:user:nobody \
-d '{"description":"Allows Linux user nobody to execute tasks"}' \
-H 'Content-Type: application/json'
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:task:user:root \
-d '{"description":"Allows Linux user root to execute tasks"}' \
-H 'Content-Type: application/json'
```

- Grant permissions to the Spark Service Account

```bash
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:agent:task:user:root/users/spark-principal/create
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" "$(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:framework:role:*/users/spark-principal/create"
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" "$(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:task:app_id:%252Fspark/users/spark-principal/create"
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:task:user:nobody/users/spark-principal/create
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:task:user:root/users/spark-principal/create
```

- Grant permissions to Marathon in order to the Spark the dispatcher in root

```
# Grant permissions to Marathon
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:task:user:root/users/dcos_marathon/create
```

- Create a file **config.json** and set the Spark principal and secret

```json
{
  "service": {
    "name": "spark",
    "service_account": "spark-principal",
    "service_account_secret": "spark/secret",
    "user": "root"
  }
}
```

- Install Spark using the config.json file

```
dcos package install --options=config.json spark
```

## Run Spark Streaming Job

```
dcos spark run --verbose --submit-args="--supervise --conf spark.mesos.network.name=calico --conf spark.mesos.network.labels=app:backend,group:development --conf spark.mesos.containerizer=mesos --conf spark.cores.max=6 --conf spark.mesos.executor.docker.image=janr/spark-streaming-kafka:v2 --conf spark.mesos.executor.docker.forcePullImage=true --conf spark.mesos.principal=spark-principal --conf spark.mesos.driverEnv.LIBPROCESS_SSL_CA_DIR=.ssl/ --conf spark.mesos.driverEnv.LIBPROCESS_SSL_CA_FILE=.ssl/ca.crt --conf spark.mesos.driverEnv.LIBPROCESS_SSL_CERT_FILE=.ssl/scheduler.crt --conf spark.mesos.driverEnv.LIBPROCESS_SSL_KEY_FILE=.ssl/scheduler.key --conf spark.mesos.driverEnv.MESOS_MODULES=file:///opt/mesosphere/etc/mesos-scheduler-modules/dcos_authenticatee_module.json --conf spark.mesos.driverEnv.MESOS_AUTHENTICATEE=com_mesosphere_dcos_ClassicRPCAuthenticatee https://gist.githubusercontent.com/jrx/56e72ada489bf36646525c34fdaa7d63/raw/90df6046886e7c50fb18ea258a7be343727e944c/streamingWordCount-CNI.py"
```
