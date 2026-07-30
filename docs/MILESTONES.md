# UrgeLock milestones

Living roadmap of **done** vs **still todo**.  
GitHub: [milestones](https://github.com/yb-sid/UrgeLock/milestones) · [issues](https://github.com/yb-sid/UrgeLock/issues)

---

## Status legend

| Status | Meaning |
|--------|---------|
| ✅ Done | Shipped in repo |
| 🔲 Todo | Not started or incomplete |
| 🔜 Next | Priority after current focus |

---

## M0 — Usable V1 shell ✅ (shipped ~0.1.x)

Baseline you can run daily.

| Item | Status |
|------|--------|
| Menu bar app (Swift / AppKit) | ✅ |
| Master password + recovery (Keychain) | ✅ |
| CleanBrowsing Adult DNS protection | ✅ |
| Optional `/etc/hosts` extra blocklist | ✅ |
| **Block extra site…** after install (Application Support) | ✅ |
| Allowlist (hosts only; remove needs password) | ✅ |
| Pause = password + cooldown + auto re-arm | ✅ |
| Quit needs password | ✅ |
| Makefile build + `~/Applications` install | ✅ |
| Block common browser DoH endpoints via hosts | ✅ |
| Open-source repo + threat model notes | ✅ |

---

## M1 — Daily reliability 🔜

Make protection survive reboots and less confusing.

| # | Item | Why |
|---|------|-----|
| M1.1 | Launch at login (Login Item / SMAppService) | App present after reboot |
| M1.2 | On launch: re-assert DNS if status is `on` | Survive sleep / network change |
| M1.3 | Auto-apply hosts after “Block extra site…” when hosts mode on | No forgotten re-apply |
| M1.4 | Pause also clears/restores hosts consistently | Pause means “actually open” |
| M1.5 | Detect browser Secure DNS / DoH and warn | Common bypass |
| M1.6 | Simple settings window (not only dialogs) | Usability |
| M1.7 | Status: last error + “DNS looks wrong” indicator | Self-diagnose |

**Exit criteria:** reboot Mac → still protected without opening anything manually; add a site → blocked without hunting menu items.

---

## M2 — Stronger block engine

Fewer leaks; clearer UX when blocked.

| # | Item | Why |
|---|------|-----|
| M2.1 | Larger curated / updatable domain lists | Escort, cams, mirrors |
| M2.2 | Subdomain policy (`*.example.com` or strip to eTLD+1) | CDN / m. leaks |
| M2.3 | Local DNS proxy (or Network Extension DNS) | Own allowlist that truly overrides filter |
| M2.4 | Re-apply DNS if user changes System Settings | Anti-bypass |
| M2.5 | Optional SafeSearch / restricted YouTube hints | Search surface |
| M2.6 | Consistent block UX (prefer sinkhole page vs grey DNS) | Less confusion |
| M2.7 | VPN / Tailscale “protection degraded” warning | Honest status |

**Exit criteria:** personal allowlist can unblock a false positive without turning all protection off; flipping system DNS gets corrected or clearly warned.

---

## M3 — Strict self-control

Harder in the moment; still not malware.

| # | Item | Why |
|---|------|-----|
| M3.1 | Strict profiles (30m / 1h / 4h / until tomorrow) | Match user intent |
| M3.2 | Delayed de-escalate (wait to *lower* strictness) | No rage soft-mode |
| M3.3 | Optional accountability notify (email/webhook on pause/uninstall attempt) | Social lock-in |
| M3.4 | Watchdog helper process (UI ≠ filter) | Force-quit UI ≠ kill filter |
| M3.5 | Recovery-phrase-gated “turn off forever” | Intentional exit only |
| M3.6 | Documented “hard mode” (config profile / Screen Time notes) | Power users |

**Exit criteria:** no instant full disable path without long delay + password (+ optional accountability).

---

## M4 — Ship to others

Open-source distribution people can trust.

| # | Item | Why |
|---|------|-----|
| M4.1 | Notarized Developer ID `.app` / DMG | Gatekeeper |
| M4.2 | GitHub Actions build + Releases | Prebuilt downloads |
| M4.3 | GitHub Pages landing (install, threat model, screenshots) | Marketing / help others |
| M4.4 | Auto-update (Sparkle or release check) | Stay current |
| M4.5 | SECURITY.md + privacy (no content logging) | Trust |
| M4.6 | Versioned changelog | Users know what changed |

**Exit criteria:** stranger can download DMG from GitHub, install, and understand limits in 5 minutes.

---

## M5 — Final / hard mode (long-term)

| # | Item | Why |
|---|------|-----|
| M5.1 | Full Network Extension (filter / DNS proxy) | System-level |
| M5.2 | Optional local heuristics (careful, privacy-first) | Beyond domain lists |
| M5.3 | Multi-user / system-wide install story | Shared Macs |
| M5.4 | Firefox Android or companion mobile story (docs or separate app) | Phone hole |
| M5.5 | Rename / branding pass if desired | Attention vs professionalism |

**Exit criteria:** matches earlier “final version” design doc intent; still open and auditable.

---

## Explicit non-goals (for now)

- Impossible to uninstall without wiping the Mac  
- Spying on or uploading page content by default  
- App Store as primary distribution (entitlements fight hard locks)  
- Replacing therapy / recovery programs  

---

## Suggested order of work

```
M1 (reliability) → M2.1–M2.2 (lists) → M4.1–M4.2 (DMG)
        ↓
   M2.3–M2.4 (engine) → M3 (strict) → M5
```

---

## How to use this doc

- Check a box / move a row to ✅ when shipping a PR  
- Open a GitHub issue per row when starting work (`M1.1 …`)  
- Don’t expand scope mid-milestone without updating this file  

## GitHub milestone numbers

- **M0 — Usable V1 shell** → milestone `1` — https://github.com/yb-sid/UrgeLock/milestone/1
- **M1 — Daily reliability** → milestone `2` — https://github.com/yb-sid/UrgeLock/milestone/2
- **M2 — Stronger block engine** → milestone `3` — https://github.com/yb-sid/UrgeLock/milestone/3
- **M3 — Strict self-control** → milestone `4` — https://github.com/yb-sid/UrgeLock/milestone/4
- **M4 — Ship to others** → milestone `5` — https://github.com/yb-sid/UrgeLock/milestone/5
- **M5 — Final / hard mode** → milestone `6` — https://github.com/yb-sid/UrgeLock/milestone/6

Tracking issue: https://github.com/yb-sid/UrgeLock/issues/1
