# V2
sudo ETCDCTL_API=2 /opt/etcd/etcdctl \
  --endpoints https://$(hostname -i):2379 \
  --key-file /etc/etcd/certs/etcd.key \
  --cert-file /etc/etcd/certs/etcd.crt \
  --ca-file /etc/etcd/certs/dcos-ca.crt \
  cluster-health 

sudo ETCDCTL_API=2 /opt/etcd/etcdctl \
  --endpoints https://localhost:2379 \
  --key-file /etc/etcd/certs/etcd.key \
  --cert-file /etc/etcd/certs/etcd.crt \
  --ca-file /etc/etcd/certs/dcos-ca.crt \
  cluster-health 
