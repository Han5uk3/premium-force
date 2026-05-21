# Apple Pay Setup Checklist

**Project**: Premium Force  
**Bundle ID**: `com.brandbik.premiumforce`  
**Merchant ID**: `merchant.com.premiumforce.main`

---

## ✅ PHASE 1: Certificate Generation (Local Machine)

### Step 1.1: Prepare your Mac
- [ ] Open Terminal
- [ ] Create certificates directory in the project:
  ```bash
  cd /Users/brandbik/Flutter/premium-force
  mkdir -p "premium force apple pay merchant"
  cd "premium force apple pay merchant"
  ```
- [ ] Verify OpenSSL is available:
  ```bash
  openssl version
  ```

### Step 1.2: Generate Private Key (ECC 256-bit)
- [ ] Run command:
  ```bash
  openssl ecparam -genkey -name prime256v1 -out apple_pay_private.key
  ```
- [ ] Verify file created: `ls -la apple_pay_private.key`
- [ ] ⚠️ **IMPORTANT**: Apple Pay requires ECC 256-bit, NOT RSA

### Step 1.3: Generate Certificate Signing Request (CSR)
- [ ] Run command:
  ```bash
  openssl req -new \
    -key apple_pay_private.key \
    -out ApplePay-PremiumForce.csr \
    -subj "/emailAddress=muhammed.fadhil2@icloud.com/CN=Apple Pay - Premium Force/O=Brandbik/C=SA"
  ```
- [ ] Verify file created: `ls -la ApplePay-PremiumForce.csr`
- [ ] **Save this file** - you'll upload it to Apple Developer

---

## ✅ PHASE 2: Apple Developer Account Setup

### Step 2.1: Create Merchant ID
- [ ] Go to [Apple Developer Account](https://developer.apple.com/account)
- [ ] Navigate to: `Certificates, Identifiers & Profiles` → `Identifiers`
- [ ] Click the **"+"** button
- [ ] Select **"Merchant IDs"**
- [ ] Enter:
  - **Description**: `Premium Force Merchant ID`
  - **Merchant ID**: `merchant.com.premiumforce.main`
- [ ] Click **"Register"**
- [ ] Confirm created successfully

### Step 2.2: Create Payment Processing Certificate
- [ ] Go to: `Certificates, Identifiers & Profiles` → `Certificates` → **"+"**
- [ ] Select: **"Apple Pay Payment Processing Certificate"**
- [ ] Choose your Merchant ID: `merchant.com.premiumforce.main`
- [ ] Upload the CSR: `ApplePay-PremiumForce.csr`
- [ ] Download certificate as: `apple_pay_payment_processing.cer`
- [ ] Save to: `/Users/brandbik/Flutter/premium-force/premium force apple pay merchant/`

### Step 2.3: Create Merchant Identity Certificate
- [ ] Go to: `Certificates, Identifiers & Profiles` → `Certificates` → **"+"**
- [ ] Select: **"Apple Pay Merchant Identity Certificate"**
- [ ] Choose your Merchant ID: `merchant.com.premiumforce.main`
- [ ] Upload the CSR: `ApplePay-PremiumForce.csr` (same file as before)
- [ ] Download certificate as: `apple_pay_merchant_identity.cer`
- [ ] Save to: `/Users/brandbik/Flutter/premium-force/premium force apple pay merchant/`

---

## ✅ PHASE 3: Convert Certificates (Local Machine)

### Step 3.1: Convert Payment Processing Certificate to PEM
- [ ] In Terminal, navigate to certificates directory:
  ```bash
  cd "/Users/brandbik/Flutter/premium-force/premium force apple pay merchant"
  ```
- [ ] Run conversion:
  ```bash
  openssl x509 -inform DER -in apple_pay_payment_processing.cer \
    -out apple_pay_payment_processing.pem
  ```
- [ ] Verify: `ls -la apple_pay_payment_processing.pem`

### Step 3.2: Convert Payment Processing Certificate to P12
- [ ] Run conversion (set your own password):
  ```bash
  openssl pkcs12 -export \
    -in apple_pay_payment_processing.pem \
    -inkey apple_pay_private.key \
    -out apple_pay_payment_processing.p12 \
    -name "Apple Pay Payment Processing" \
    -passout pass:CHANGE_THIS_PASSWORD_123
  ```
- [ ] Replace `CHANGE_THIS_PASSWORD_123` with strong password
- [ ] **Remember this password!** (you'll need it later)
- [ ] Verify: `ls -la apple_pay_payment_processing.p12`

### Step 3.3: Convert Merchant Identity Certificate to PEM
- [ ] Run conversion:
  ```bash
  openssl x509 -inform DER -in apple_pay_merchant_identity.cer \
    -out apple_pay_merchant_identity.pem
  ```
- [ ] Verify: `ls -la apple_pay_merchant_identity.pem`

### Step 3.4: Convert Merchant Identity Certificate to P12
- [ ] Run conversion (use same password):
  ```bash
  openssl pkcs12 -export \
    -in apple_pay_merchant_identity.pem \
    -inkey apple_pay_private.key \
    -out apple_pay_merchant_identity.p12 \
    -name "Apple Pay Merchant Identity" \
    -passout pass:CHANGE_THIS_PASSWORD_123
  ```
- [ ] Use the same password as Step 3.2
- [ ] Verify: `ls -la apple_pay_merchant_identity.p12`

### Step 3.5: Final Verification
- [ ] Run:
  ```bash
  ls -lah "/Users/brandbik/Flutter/premium-force/premium force apple pay merchant/"
  ```
- [ ] Should see 8 files:
  - ✅ `ApplePay-PremiumForce.csr`
  - ✅ `apple_pay_private.key`
  - ✅ `apple_pay_payment_processing.cer`
  - ✅ `apple_pay_payment_processing.pem`
  - ✅ `apple_pay_payment_processing.p12`
  - ✅ `apple_pay_merchant_identity.cer`
  - ✅ `apple_pay_merchant_identity.pem`
  - ✅ `apple_pay_merchant_identity.p12`

---

## ✅ PHASE 4: iOS App Configuration

### Step 4.1: Update Bundle Identifier (if needed)
- [ ] Open: `ios/Runner/Info.plist`
- [ ] Verify `CFBundleIdentifier` is: `com.brandbik.premiumforce`
- [ ] If not, update it

### Step 4.2: Enable Apple Pay in Xcode
- [ ] Open Xcode: `open ios/Runner.xcworkspace`
- [ ] Select **Runner** target
- [ ] Go to **Signing & Capabilities**
- [ ] Click **"+ Capability"**
- [ ] Search for: **"Apple Pay"**
- [ ] Add the **"Apple Pay"** capability
- [ ] In the dropdown, select your Merchant ID: `merchant.com.premiumforce.main` (different from bundle ID)

### Step 4.3: Verify Entitlements
- [ ] Check: `ios/Runner/Runner.entitlements`
- [ ] Should contain:
  ```xml
  <key>com.apple.developer.in-app-payments</key>
  <array>
    <string>merchant.com.premiumforce.main</string>
  </array>
  ```
- [ ] If missing, add it manually

### Step 4.4: Update Signing
- [ ] Close Xcode
- [ ] Run in Terminal:
  ```bash
  cd /Users/brandbik/Flutter/premium-force
  pod repo update
  cd ios && pod install && cd ..
  flutter clean
  flutter pub get
  ```

---

## ✅ PHASE 5: Flutter Implementation

### Step 5.1: Add Package
- [ ] Open: `pubspec.yaml`
- [ ] Add under `dependencies`:
  ```yaml
  pay: ^2.0.0
  ```
- [ ] Run:
  ```bash
  flutter pub get
  ```

### Step 5.2: Create Payment Service
- [ ] Create file: `lib/services/apple_pay_service.dart`
- [ ] Copy template from `APPLEPAY_SETUP.md`
- [ ] Update merchant ID if different

### Step 5.3: Integrate into App
- [ ] Update `lib/main.dart` to support Apple Pay
- [ ] Add UI button to trigger payments
- [ ] Test on simulator/device

### Step 5.4: Test Build
- [ ] Run:
  ```bash
  flutter run
  ```
- [ ] Or build for iOS:
  ```bash
  flutter build ios
  ```

---

## ✅ PHASE 6: Backend Server Setup

### Step 6.1: Deploy Merchant Identity Certificate
- [ ] Transfer `apple_pay_merchant_identity.p12` to backend server
- [ ] Store in secure location (e.g., `/etc/applepay/certs/`)
- [ ] Set appropriate permissions:
  ```bash
  chmod 600 /etc/applepay/certs/apple_pay_merchant_identity.p12
  ```

### Step 6.2: Configure Backend
- [ ] Create payment verification endpoint
- [ ] Implement token decryption using merchant certificate
- [ ] Implement signature verification
- [ ] Store P12 password securely (environment variable)

### Step 6.3: Test Decryption
- [ ] Verify backend can decrypt sample payment tokens
- [ ] Test with payment processor integration

---

## ✅ PHASE 7: Security & Maintenance

### Step 7.1: Git Safety
- [ ] Verify `.gitignore` contains:
  ```
  certificates/
  *.csr
  *.key
  *.p12
  *.cer
  *.pem
  ```
- [ ] Run:
  ```bash
  git status
  ```
- [ ] Ensure no certificate files are staged

### Step 7.2: Backup
- [ ] Backup certificates directory to secure location:
  ```bash
  tar -czf applepay_certs_backup_$(date +%Y%m%d).tar.gz \
    "/Users/brandbik/Flutter/premium-force/premium force apple pay merchant/"
  ```
- [ ] Store backup in password-protected location

### Step 7.3: Document Passwords
- [ ] Create secure password document (LastPass, 1Password, etc.)
- [ ] Store: P12 file password
- [ ] Store: Backend server access credentials

### Step 7.4: Certificate Expiration Tracking
- [ ] Check expiry dates:
  ```bash
  openssl x509 -in "/Users/brandbik/Flutter/premium-force/premium force apple pay merchant/apple_pay_payment_processing.pem" \
    -text -noout | grep "Not After"
  openssl x509 -in "/Users/brandbik/Flutter/premium-force/premium force apple pay merchant/apple_pay_merchant_identity.pem" \
    -text -noout | grep "Not After"
  ```
- [ ] Add calendar reminders to renew 30 days before expiry
- [ ] Payment Processing: expires in 3 years
- [ ] Merchant Identity: expires in 1 year

---

## ✅ PHASE 8: Testing

### Step 8.1: Simulator Testing
- [ ] Run on iOS simulator:
  ```bash
  flutter run
  ```
- [ ] Verify app launches without errors

### Step 8.2: Device Testing
- [ ] Run on physical iPhone with Apple Pay support
- [ ] Verify Apple Pay button appears
- [ ] Test payment flow (use test card if available)

### Step 8.3: Backend Testing
- [ ] Send test payment token to backend
- [ ] Verify decryption works
- [ ] Verify signature validation works
- [ ] Log all steps for debugging

### Step 8.4: Production Testing
- [ ] Test with payment processor (PayTabs, etc.)
- [ ] Verify transaction completion
- [ ] Verify receipts generated
- [ ] Monitor for errors

---

## 🎯 Summary

### Files Created
- [ ] `APPLEPAY_SETUP.md` - Comprehensive guide
- [ ] `APPLEPAY_QUICKSTART.md` - Quick reference
- [ ] `.gitignore` - Updated with certificate patterns
- [ ] `lib/services/apple_pay_service.dart` - Service implementation
- [ ] `lib/models/apple_pay_model.dart` - Data models

### Certificates Generated
- [ ] 8 certificate files in `/Users/brandbik/Flutter/premium-force/premium force apple pay merchant/`
- [ ] Private key secured
- [ ] P12 files password-protected
- [ ] Backup created

### Configuration Complete
- [ ] iOS app configured with Apple Pay capability
- [ ] Merchant ID registered with Apple
- [ ] Entitlements added
- [ ] Flutter package integrated
- [ ] Backend ready for token decryption

---

## 📞 Support & Troubleshooting

| Issue | Solution |
|-------|----------|
| OpenSSL not found | Install: `brew install openssl` |
| CSR upload fails | Verify CSR file format: `openssl req -in file.csr -text -noout` |
| Certificate not showing in Xcode | Run `pod install` again, restart Xcode |
| Apple Pay button not appearing | Check merchant ID matches bundle ID |
| Payment token invalid | Verify P12 certificate password is correct |
| Backend decryption fails | Check certificate chain and expiration |

---

## 📋 Documentation References

- `APPLEPAY_SETUP.md` - Full setup guide
- `APPLEPAY_QUICKSTART.md` - Command reference
- `.gitignore` - Git safety patterns
- [Apple Pay Developer Guide](https://developer.apple.com/apple-pay/)

---

**Status**: 📝 READY FOR IMPLEMENTATION

Start with **PHASE 1** and work through each phase systematically.
