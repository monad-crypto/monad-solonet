#!/usr/bin/bash

set -e

cat >/host/etc/sysctl.d/99-monad.conf <<'EOF'
vm.nr_hugepages = 2048
net.core.rmem_max = 62500000
net.core.rmem_default = 62500000
net.core.wmem_max = 62500000
net.core.wmem_default = 62500000
net.ipv4.tcp_rmem = 4096 62500000 62500000
net.ipv4.tcp_wmem = 4096 62500000 62500000
EOF

chroot /host sysctl --system
