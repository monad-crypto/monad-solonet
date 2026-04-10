log "Checking system setup"
if is_privileged; then
  echo "✅ Container looks privileged (high capabilities)."
else
  echo "Container does not look privileged."
  echo "⚠️ Container is not privileged"
  echo "Please set --privileged"
fi

if is_1g_hugepages_cpu; then
  echo "✅ CPU supports 1GB huge pages"
else
  echo "❌ CPU does not support 1GB huge pages."
  echo "If running on Docker Desktop on Apple Silicon, start Docker inside a QEMU VM (Lima/Colima)."
  echo "See the documentation for setup instructions."
  exit 1
fi

SOFT=$(ulimit -Sn)
HARD=$(ulimit -Hn)
EXPECTED="16384"
if (("$SOFT" >= "$EXPECTED" && "$HARD" >= "$EXPECTED")); then
  echo "✅ NOFILE limits correctly set to 16384"
else
  echo "WARNING: soft limit expected 16384, got $SOFT"
  echo "WARNING: hard limit expected 16384, got $HARD"
  echo
  echo "⚠️ Please set --ulimit nofile=16384:16384"
fi

log "Kernel parameters"
echo
echo "Trying to set the kernel parameters..."
echo 4 >/sys/devices/system/node/node0/hugepages/hugepages-1048576kB/nr_hugepages
echo 2048 >/sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
sysctl vm.nr_hugepages="2048" || true
sysctl net.ipv4.tcp_rmem="4096 62500000 62500000" || true
sysctl net.ipv4.tcp_wmem="4096 62500000 62500000" || true
sysctl net.core.rmem_max="62500000" || true
sysctl net.core.rmem_default="62500000" || true
sysctl net.core.wmem_max="62500000" || true
sysctl net.core.wmem_default="62500000" || true

echo
echo "Checking values..."
check_sysctl vm.nr_hugepages "2048"
check_sysctl net.core.rmem_max "62500000"
check_sysctl net.core.rmem_default "62500000"
check_sysctl net.core.wmem_max "62500000"
check_sysctl net.core.wmem_default "62500000"
check_sysctl net.ipv4.tcp_rmem "4096 62500000 62500000"
check_sysctl net.ipv4.tcp_wmem "4096 62500000 62500000"
