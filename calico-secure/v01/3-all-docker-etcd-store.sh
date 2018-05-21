# Certs
sudo ./bootstrap-certs.py docker-etcd /etc/docker/
sudo curl -L http://master.mesos/ca/dcos-ca.crt -o /etc/docker/dcos-ca.crt

sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "storage-driver": "overlay",
    "cluster-store": "etcd://127.0.0.1:2379",
    "cluster-store-opts": {
        "kv.cacertfile": "/etc/docker/dcos-ca.crt",
        "kv.certfile": "/etc/docker/docker-etcd.crt",
        "kv.keyfile": "/etc/docker/docker-etcd.key"
    }
}
EOF

# or, if overlay is configured in the systemd unit for docker:
sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "cluster-store": "etcd://127.0.0.1:2379",
    "cluster-store-opts": {
        "kv.cacertfile": "/etc/docker/dcos-ca.crt",
        "kv.certfile": "/etc/docker/docker-etcd.crt",
        "kv.keyfile": "/etc/docker/docker-etcd.key"
    }
}
EOF

sudo systemctl restart docker
