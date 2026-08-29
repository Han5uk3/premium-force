# App Links hosting

Two files here have to be live on **premiumforcegroup.com** before App Links
work. Until they are, tapping a link opens the browser instead of the app —
that is the verification failing, not the app misbehaving.

| File | Must be reachable at |
| --- | --- |
| `assetlinks.json` | `https://premiumforcegroup.com/.well-known/assetlinks.json` |
| `apple-app-site-association` | `https://premiumforcegroup.com/.well-known/apple-app-site-association` |

Both also have to answer on `https://www.premiumforcegroup.com/...`, since the
app claims that host too.

## Serving rules

Both platforms are strict, and every one of these has broken a rollout before:

* **HTTPS only**, with a certificate that validates. No self-signed certs.
* **No redirects.** Not http→https, not apex→www. The fetcher does not follow
  them. Each host must serve the file directly.
* **`Content-Type: application/json`** on both files.
* **`apple-app-site-association` has no file extension.** Do not add `.json`.
  Some static hosts add one automatically — check the served URL, not the
  source file.
* **No authentication**, no IP allowlist, no bot/WAF challenge. Google's and
  Apple's fetchers are not browsers.

## Verifying after deploy

```bash
curl -sSI https://premiumforcegroup.com/.well-known/assetlinks.json | head -20
curl -sS  https://premiumforcegroup.com/.well-known/apple-app-site-association
```

Check the status is `200` (not `301`/`302`) and the content type is JSON.

Google's own validator:

```
https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://premiumforcegroup.com&relation=delegate_permission/common.handle_all_urls
```

## ⚠️ The fingerprint in `assetlinks.json` is the upload key

`BF:F5:5C:...:8D:4F` is the SHA-256 of `android/app/my-release-key.jks` — the
key this repo signs with locally.

**If the app is distributed through Google Play with Play App Signing, that is
not the key users' devices see.** Play re-signs the app with its own key, and
verification will fail against this file alone.

Get the real one from **Play Console → your app → Test and release → Setup →
App signing**, copy the SHA-256 under *App signing key certificate*, and add it
to the array:

```json
"sha256_cert_fingerprints": [
  "<Play app signing key SHA-256>",
  "BF:F5:5C:46:FF:58:C2:36:0A:B7:D5:39:10:D3:8F:F5:B0:25:4A:B6:BE:63:2A:62:68:70:ED:A1:1F:84:8D:4F"
]
```

Keeping both is correct and recommended: the Play key covers store installs,
the upload key covers locally-signed release builds you sideload for testing.

To re-read the local fingerprint at any time:

```bash
keytool -list -v -keystore android/app/my-release-key.jks -alias my-key-alias
```

## Testing before the files are live

Android, forcing the intent without verification:

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "https://premiumforcegroup.com/booking/<bookingId>" \
  com.brandbik.premiumforce
```

Check what Android thinks of the domain on a device:

```bash
adb shell pm get-app-links com.brandbik.premiumforce
```

`verified` is what you want. `none` or `failure` means the file is not being
served correctly yet.

iOS: with the entitlement in place, a debug build can be tested by pasting the
URL into Notes and long-pressing it. Apple caches the AASA aggressively — a
device may need the app reinstalled after the file changes.
