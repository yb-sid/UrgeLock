# UrgeLock

**Open-source, system-wide adult-content shield for macOS.**

Menu bar app. Password-locked. Hard to weaken in the heat of the moment.  
Not App Store — build locally now; prebuilt DMG via GitHub Releases is on the roadmap.

**Version:** 0.1.3 (M0 usable shell)  
**Repo:** https://github.com/yb-sid/UrgeLock

---

## What it does

| Feature | Behavior |
|--------|----------|
| **CleanBrowsing Adult DNS** | Points all Mac traffic at [CleanBrowsing Adult Filter](https://cleanbrowsing.org/filters#adult) so most adult domains fail for every browser |
| **Extra blocklist (`/etc/hosts`)** | Built-in list + sites you add after install; needs Mac admin once to write |
| **Block browser Secure DNS (DoH)** | When hosts is applied, common DoH endpoints are blocked so Brave/Chrome cannot skip `/etc/hosts` |
| **Block extra site…** | Add domains from the menu (no rebuild). Stored in Application Support |
| **Allowlist** | Exclude false positives from *hosts* only (does **not** override CleanBrowsing adult DNS) |
| **Pause** | Master password + cooldown (default 30 min), then short pause, then auto re-arm |
| **Quit** | Requires password; does **not** automatically turn DNS/hosts off |

Menu bar status: **Protected** / **Cooldown** / **Paused** / **Off**.

---

## How protection works (simple)

```
Browser request
      │
      ├─► System DNS ── CleanBrowsing Adult ── many porn hosts blocked
      │
      └─► /etc/hosts ── your extras + built-in + DoH endpoints ── forced dead (0.0.0.0)
```

- **DNS only** — broad adult filter; your custom sites are *not* enforced until hosts is applied.  
- **DNS + hosts** — recommended: filter + personal list + DoH lock-down.

Some sites (e.g. obscure / escort) are **not** on CleanBrowsing. Add them with **Block extra site…**, then **Apply hosts**.

---

## Requirements

- macOS 13+
- [Xcode Command Line Tools](https://developer.apple.com/xcode/): `xcode-select --install`
- Admin password when applying `/etc/hosts` (optional but recommended)

No full Xcode app required for the Makefile build.

---

## Build & install

```bash
git clone https://github.com/yb-sid/UrgeLock.git
cd UrgeLock
make app          # → build/UrgeLock.app
make run          # build and open
make install      # → ~/Applications/UrgeLock.app
```

```bash
make clean        # remove build/
./scripts/verify-dns.sh   # show DNS per network service
```

---

## Usage

1. `make install` then open **UrgeLock** from `~/Applications` (or `make run`).
2. First launch: set a **master password** and save the **recovery phrase** offline.
3. Menu bar shield → **Enable protection + hosts blocklist…** (recommended).  
   - Enter your **Mac login/admin** password when asked to update hosts.  
   - DNS switches to CleanBrowsing Adult.
4. To pin a site that still loads: **Block extra site…** → paste domain (e.g. `clubcastings.com`) → apply hosts when prompted.
5. **Request pause** when you truly need temporary relief: password + wait (cooldown).

### Menu map

| Item | Password? |
|------|-----------|
| Enable protection (DNS only) | No |
| Enable protection + hosts / Apply hosts | Mac admin |
| Block extra site… | No |
| Remove blocked site… | Master password |
| Add to allowlist… | No |
| Remove from allowlist… | Master password |
| Request pause / change strictness / quit | Master password |

---

## Uninstall / cleanup

Protection can outlive the app (by design). Full cleanup:

```bash
killall UrgeLock 2>/dev/null
rm -rf ~/Applications/UrgeLock.app
rm -rf ~/Library/Application\ Support/UrgeLock
# Reset DNS (repeat for other services if needed)
networksetup -setdnsservers Wi-Fi Empty
# Remove hosts section: delete lines between "# BEGIN UrgeLock" and "# END UrgeLock" in /etc/hosts (admin)
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

Optional: Keychain Access → search `urgelock` → delete leftover items.

---

## Limitations (honest)

| Limitation | Notes |
|------------|--------|
| Not unremovable | Admin can delete app, change DNS, edit hosts |
| CleanBrowsing gaps | Some adult/escort domains need **your** hosts list |
| VPN / Tailscale | May bypass or confuse DNS; treated as degraded path later |
| Pause vs hosts | V1 pause mainly restores DNS; re-apply hosts after changes |
| No auto-start yet | Login item is milestone M1 |
| No notarized DMG yet | Milestone M4 |
| Mobile | Out of scope for now |

**Browser tip:** Prefer Secure DNS **off** in Brave/Chrome. UrgeLock blocks many DoH hosts when hosts mode is on, but browser settings still matter.

Full threat model: [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md).

---

## Project layout

```
UrgeLock/
  Sources/           Swift menu bar app
  Resources/
    Info.plist
    blocklists/
      extra-domains.txt    # built-in adult extras
      doh-endpoints.txt    # Secure DNS / DoH hosts to sinkhole
  scripts/           verify-dns, smoke helpers
  docs/              MILESTONES, threat model
  Makefile
```

Data at runtime: `~/Library/Application Support/UrgeLock/`  
(password hashes in Keychain under `app.urgelock.mac`).

---

## Roadmap

| Milestone | Focus | Status |
|-----------|--------|--------|
| **M0** | Usable V1 shell | Done (~0.1.x) |
| **M1** | Daily reliability (login item, re-assert DNS, auto hosts) | Next |
| **M2** | Stronger engine (lists, local DNS / Network Extension) | Planned |
| **M3** | Strict self-control (profiles, accountability) | Planned |
| **M4** | Ship to others (notarized DMG, Pages, CI) | Planned |
| **M5** | Final hard mode | Planned |

Details: [docs/MILESTONES.md](docs/MILESTONES.md) · tracking: [issue #1](https://github.com/yb-sid/UrgeLock/issues/1) · [milestones](https://github.com/yb-sid/UrgeLock/milestones)

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Keep commits focused; no secrets or signing certs in the repo.

---

## License

MIT — see [LICENSE](LICENSE).

**Disclaimer:** Self-control tool, not spyware and not a guarantee. You are responsible for how you use it on your machine.
