Prereq: In cloud environments (AWS), need to turn off source/dest IP check, or I think configure ipip:always in the pool config.

1 Install etcd on all masters

2 Install etcd proxy on all agents (Test etcd on all nodes)

3 Configure Docker daemon on all nodes to use etcd as cluster store

4 Install Calico node on all nodes

5 Install and configure calicoctl

6 Install Calico CNI stuff on all nodes

7 Test stuff

Directories:
/opt/etcd - etcd binaries
/etc/etcd/certs - etcd certs
/var/etcd/data - etcd data
/etc/docker - docker-etcd certs
/etc/calico/certs/node - calico node certs

/etc/etcd/etcd.env
/etc/calico/calico.env

/var/lib/dcos/calico/cni
/var/lib/dcos/calico/cni-config