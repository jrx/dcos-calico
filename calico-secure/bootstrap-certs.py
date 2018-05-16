#!/opt/mesosphere/bin/python

import sys
sys.path.append('/opt/mesosphere/lib/python3.6/site-packages')

from dcos_internal_utils import bootstrap

if len(sys.argv) == 1:
    print("Usage: ./bootstrap-certs.py <CN> <PATH> | ./bootstrap-certs.py etcd /var/lib/dcos/etcd/certs")
    sys.exit(1)

b = bootstrap.Bootstrapper(bootstrap.parse_args())
b.read_agent_secrets()

cn = sys.argv[1]
location = sys.argv[2]

keyfile = location + '/' + cn + '.key'
crtfile = location + '/' + cn + '.crt'

b.ensure_key_certificate(cn, keyfile, crtfile, service_account='dcos_bootstrap_agent')