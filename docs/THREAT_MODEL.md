# UrgeLock threat model (V1)

## Protects against
- Casual browsing of known adult sites in any browser (DNS filter)
- Impulse “just disable it” (password + cooldown)
- Accidental quit without password

## Does not protect against
- Changing DNS manually in System Settings
- Admin deleting the app / editing `/etc/hosts`
- Using a phone or another device
- VPNs that bypass system DNS
- Brand-new domains not on CleanBrowsing or our list

## Data
- Password hash in Keychain (never plaintext)
- State/allowlist in `~/Library/Application Support/UrgeLock/`
- No browsing history collection

## Browser Secure DNS (DoH)

Browsers may resolve names via HTTPS (Google/Cloudflare) and ignore system DNS and `/etc/hosts`.
V0.1.3+ sinkholes common DoH hostnames when hosts mode is applied. Users should still disable
Secure DNS in the browser for best results.
