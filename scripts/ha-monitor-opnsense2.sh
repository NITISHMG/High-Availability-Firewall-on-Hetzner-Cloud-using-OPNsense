cat > /usr/local/sbin/ha-monitor.sh << 'EOF'
#!/bin/sh

PEER_IP="10.20.1.1"
PEER_WAN="public_ip"
HETZNER_TOKEN="API-key"
FLOATING_IP_ID="123456789"
THIS_SERVER_ID="123456789"
LOG="/var/log/hetzner-failover.log"
LOCKFILE="/tmp/ha-monitor.lock"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') ha-monitor: $1" >> $LOG
}

# Prevent concurrent runs
if [ -f "$LOCKFILE" ]; then exit 0; fi
touch "$LOCKFILE"

# Check peer via LAN
if ping -c 3 -W 1 $PEER_IP > /dev/null 2>&1; then
  log "Peer alive - standby mode"
  rm -f "$LOCKFILE"
  exit 0
fi

# LAN ping failed - check WAN
if ping -c 3 -W 1 $PEER_WAN > /dev/null 2>&1; then
  log "Peer LAN down but WAN alive - split brain check"
  rm -f "$LOCKFILE"
  exit 0
fi

# Peer completely down - claim Floating IP
log "Peer DOWN - claiming Floating IP"
curl -s -X POST \
  -H "Authorization: Bearer $HETZNER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"server\": $THIS_SERVER_ID}" \
  "https://api.hetzner.cloud/v1/floating_ips/$FLOATING_IP_ID/actions/assign" >> $LOG 2>&1

rm -f "$LOCKFILE"
EOF
