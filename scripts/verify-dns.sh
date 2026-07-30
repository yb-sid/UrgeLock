#!/bin/zsh
# Show current DNS per service — useful to confirm UrgeLock armed.
echo "=== network services DNS ==="
networksetup -listallnetworkservices | tail -n +2 | while read -r svc; do
  [[ "$svc" == \** ]] && continue
  echo "--- $svc ---"
  networksetup -getdnsservers "$svc"
done
echo
echo "Expect CleanBrowsing Adult when protected: 185.228.168.10 / 185.228.169.11"
