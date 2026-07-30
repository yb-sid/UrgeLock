# UrgeLock

**Open-source, system-wide adult-content shield for macOS.**

Menu bar app. Password-locked. Hard to turn off in the heat of the moment. Not App Store — ship a DMG from GitHub Releases.

## What V1 does

- Menu bar status: protected / pausing / off
- Master password (Keychain) + recovery phrase at setup
- **Protection ON**: points your Mac’s DNS at [CleanBrowsing Adult Filter](https://cleanbrowsing.org/) (blocks adult domains for *all* browsers)
- Optional **extra local blocklist** domains (hosts-based, applied with admin once)
- **Block extra site…** in the menu after install — saved to Application Support; apply hosts to enforce
- **Allowlist**: add freely; remove requires password
- **Pause**: password + cooldown delay (default 30 minutes) before protection drops
- **Quit app**: requires password (does not auto-disable DNS until you pause/disable)

## Threat model (honest)

| Attack | V1 |
|--------|----|
| Open porn in any browser | Usually blocked (DNS filter) |
| Switch browsers | Still blocked |
| Instant “just this once” | Password + long cooldown |
| Change DNS in System Settings | Can bypass — final version hardens this |
| Delete the app as admin | Protection can be removed |

## Build

Requires macOS + Xcode Command Line Tools (`xcode-select --install`).

```bash
make app          # builds build/UrgeLock.app
make run          # build and open
make install      # copy to ~/Applications
```

## Usage

1. `make run` or open `UrgeLock.app`
2. Set a master password + save recovery phrase
3. Click **Enable protection**
4. Approve admin prompts if asked (hosts/DNS helpers)

## License

MIT — see [LICENSE](LICENSE).
