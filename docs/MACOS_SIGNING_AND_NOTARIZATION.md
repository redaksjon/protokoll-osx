# macOS release: Developer ID signing, notarization & GitHub Actions secrets

This document describes how to configure **Apple Developer ID** code signing and **notarization** for the **Protokoll** macOS app when building in **GitHub Actions** (`.github/workflows/release.yml`).

Use it as a checklist when storing values in a password manager, internal wiki, or team “secrets runbook.” **Do not commit real passwords, `.p12` files, or API keys to git.**

---

## What the release workflow does (order matters)

1. Build with SwiftPM (`swift build -c release`).
2. Assemble `Protokoll.app` (bundle id `com.redaksjon.protokoll`).
3. Import your **Developer ID Application** identity from a **`.p12`** into a temporary keychain on the runner.
4. **Sign** with hardened runtime: `codesign --options runtime`.
5. Verify signature with **`codesign --verify`** (no `spctl` here — see troubleshooting).
6. **Notarize** with `notarytool submit` … `--wait`.
7. **Staple** with `stapler staple`, validate, then run **`spctl --assess`** (only sensible *after* notarization + staple).
8. Zip the app, checksum, attach to the GitHub Release.

Distribution channel: **outside the Mac App Store** (Developer ID + notarization), e.g. GitHub Releases.

---

## Prerequisites

- **Apple Developer Program** membership (paid).
- A **Developer ID Application** certificate installed on a Mac you control (with the **private key** present in Keychain).
- **Not** “Apple Distribution” (that’s for App Store builds). For direct download you need **Developer ID Application**.

---

## GitHub repository secrets (exact names)

Configure these in: **GitHub → repository → Settings → Secrets and variables → Actions**.

| Secret name | Required | Purpose |
|-------------|----------|---------|
| `DEVELOPER_ID_CERT_BASE64` | **Yes** | Base64-encoded `.p12` containing **certificate + private key** |
| `DEVELOPER_ID_CERT_PASSWORD` | **Yes** | Password you set when exporting the `.p12` |
| `APPLE_TEAM_ID` | **Yes** | 10-character Team ID (used for identity matching and `notarytool`) |
| `APPLE_ID` | **Yes** | Apple ID email used for notarization (`notarytool --apple-id`) |
| `APPLE_APP_PASSWORD` | **Yes** | App-specific password for that Apple ID (not your normal Apple ID password) |
| `CODESIGN_IDENTITY` | No | Full identity string; only if auto-detection by team ID is wrong |

The workflow reads these in `.github/workflows/release.yml` — if you rename secrets, update the workflow.

---

## Step 1: Ensure you have “Developer ID Application” + private key

1. On a Mac, open **Keychain Access**.
2. Select the **login** keychain, category **Certificates**.
3. Find **`Developer ID Application: Your Name or Org (TEAM_ID)`**.
4. **Expand** the row. You must see a **private key** nested under that certificate.

If there is **no private key**, you cannot sign on CI. You need to create or import the certificate on a machine where you control the key, or revoke/reissue per Apple’s docs.

---

## Step 2: Export a `.p12` that includes the private key

This is the most common failure point: exporting **only the certificate** produces a `.p12` that imports but shows **0 valid code-signing identities** on the runner.

1. In Keychain Access, under **Certificates**, locate **Developer ID Application: …**
2. Confirm the **private key** is present (expanded under the cert).
3. Right-click the **private key** (or the certificate that includes the key) → **Export …**
4. Choose format **Personal Information Exchange (.p12)**.
5. Set a **strong password** — you will store it as `DEVELOPER_ID_CERT_PASSWORD`.

**Important:** Do **not** use “Apple Distribution” or Mac App Store provisioning profiles for this flow; the workflow expects a **Developer ID Application** identity.

---

## Step 3: Base64-encode the `.p12` for `DEVELOPER_ID_CERT_BASE64`

On macOS (Terminal):

```bash
base64 -i /path/to/DeveloperID.p12 | pbcopy
```

Then paste into the GitHub secret **as a single line** (no extra newlines before/after). If the secret is truncated or corrupted, the decoded file on the runner will be empty or invalid.

**Sanity check locally** (optional):

```bash
printf '%s' "$(pbpaste)" | base64 -D > /tmp/test.p12
ls -la /tmp/test.p12   # should be non-zero size
```

---

## Step 4: `APPLE_TEAM_ID`

Your 10-character Team ID appears:

- In the **Membership** section of [Apple Developer Account](https://developer.apple.com/account), or
- In **Xcode → Settings → Accounts** when you select your team, or
- In parentheses in the identity string, e.g. `Developer ID Application: Discursive (XXXXXXXXXX)` → `XXXXXXXXXX`.

Store **only** the ID (no spaces). The workflow trims whitespace.

---

## Step 5: Notarization — `APPLE_ID` and `APPLE_APP_PASSWORD`

`notarytool` uses:

- **`APPLE_ID`**: Your Apple ID **email**.
- **`APPLE_APP_PASSWORD`**: An **app-specific password** (generated at [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → **App-Specific Passwords**).

**Do not** use your normal Apple ID account password.

`APPLE_TEAM_ID` is passed to `notarytool` as `--team-id` and must match the team that owns the Developer ID certificate used to sign.

---

## Step 6 (optional): `CODESIGN_IDENTITY`

Usually **omit** this secret. The workflow picks the **Developer ID Application** identity from the imported `.p12`, preferring one whose line contains your `APPLE_TEAM_ID`.

If you must pin the identity, set `CODESIGN_IDENTITY` to the **exact** string between quotes from:

```bash
security find-identity -v -p codesigning
```

Example shape (illustrative only):

```text
Developer ID Application: Your Company Name (XXXXXXXXXX)
```

The workflow **verifies** that this string appears in `security find-identity` output **after** import. If the `.p12` has no private key, setting `CODESIGN_IDENTITY` will **not** fix signing.

---

## Local dry run (optional, on your Mac)

After `./create-app.sh` or equivalent `Protokoll.app`:

```bash
# List signing identities
security find-identity -v -p codesigning

# Sign (replace with your identity line)
codesign --force --deep --options runtime \
  --sign "Developer ID Application: … (TEAM_ID)" \
  Protokoll.app

codesign --verify --deep --strict --verbose=2 Protokoll.app
```

**Before notarization**, `spctl --assess --type execute Protokoll.app` may report **`Unnotarized Developer ID`** — that is **expected**. After `notarytool` + `stapler staple`, run `spctl` again; it should pass for a correctly stapled build.

Example notarize + staple (local):

```bash
ditto -c -k --keepParent Protokoll.app Protokoll-notarize.zip
xcrun notarytool submit Protokoll-notarize.zip \
  --apple-id "you@example.com" \
  --password "app-specific-password" \
  --team-id "XXXXXXXXXX" \
  --wait
xcrun stapler staple Protokoll.app
xcrun stapler validate Protokoll.app
spctl --assess --type execute --verbose=4 Protokoll.app
```

---

## Troubleshooting (from real CI runs)

### “0 valid identities” / import succeeds but no Developer ID line

- The `.p12` almost certainly lacks the **private key**. Re-export from Keychain including the key (see Step 2).
- Wrong **`.p12` password** → import can fail or behave oddly; confirm `DEVELOPER_ID_CERT_PASSWORD`.
- Wrong cert type (**Apple Distribution** vs **Developer ID Application**).

### `codesign`: “The specified item could not be found in the keychain”

- Often caused by setting **`CODESIGN_IDENTITY`** while the keychain has **no** matching imported identity. Fix the `.p12` or remove `CODESIGN_IDENTITY`.

### `spctl`: `rejected` / `source=Unnotarized Developer ID` **right after signing**

- **Expected** if you run **`spctl` before** `notarytool` + **stapler**. The workflow intentionally runs **`spctl` only after staple**; do not add a pre-notarize `spctl` gate.

### Empty decoded `.p12` on the runner

- Regenerate `DEVELOPER_ID_CERT_BASE64` with `base64 -i … | pbcopy`, one line, no edits.
- Avoid wrapping the secret in quotes or adding newlines in the GitHub UI.

### `workflow_dispatch` and version strings

- The workflow uses `github.event.release.tag_name` for `CFBundleShortVersionString`. For **manual** runs without a release, that value may be empty unless you adjust the workflow — prefer testing via a **draft/published release** with a tag when validating versioning.

---

## Security notes

- Rotate the **app-specific password** if it may have leaked.
- Treat the `.p12` and its password as **high sensitivity** (anyone with them can sign as your Developer ID until revoked).
- Prefer **narrow** access to GitHub Actions secrets and enable **branch protection** on default branches.

---

## Reference

- Workflow: `.github/workflows/release.yml`
- Local app bundle helper: `create-app.sh`

---

*Last aligned with workflow behavior: 2026-03 — Developer ID sign → notarize → staple → `spctl`.*
