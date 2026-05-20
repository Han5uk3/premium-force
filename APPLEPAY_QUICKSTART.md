# Apple Pay Certificate Generation - Quick Reference

**App Bundle ID**: `com.brandbik.premiumforce`  
**Merchant ID**: `merchant.com.premiumforce.main`

---

## ⚡ Quick Command Reference

### 1️⃣ Generate Private Key & CSR (Terminal)

```bash
# Navigate to certificates directory
cd "/Users/brandbik/Flutter/premium-force/premium force apple pay merchant"

# Generate ECC 256-bit private key (required by Apple Pay)
openssl ecparam -genkey -name prime256v1 -out apple_pay_private.key

# Generate Certificate Signing Request
openssl req -new \
  -key apple_pay_private.key \
  -out ApplePay-PremiumForce.csr \
  -subj "/emailAddress=muhammed.fadhil2@icloud.com/CN=Apple Pay - Premium Force/O=Brandbik/C=SA"

# Verify CSR was created
ls -la
```

**Output files**:
- ✅ `apple_pay_private.key` (keep safe!)
- ✅ `ApplePay-PremiumForce.csr` (upload to Apple)

---

### 2️⃣ In Apple Developer Account

1. Go: https://developer.apple.com/account
2. `Certificates, Identifiers & Profiles` → `Identifiers` → `+` 
3. Select `Merchant IDs` → Register ID: `merchant.com.premiumforce.main`
4. Go: `Certificates` → `+`
5. Create **Payment Processing Certificate** (upload CSR, download `.cer`)
6. Create **Merchant Identity Certificate** (upload same CSR, download `.cer`)

**Downloaded files**:
- 📥 Save to: `/Users/brandbik/Flutter/premium-force/premium force apple pay merchant/`
- 📥 `apple_pay_payment_processing.cer`
- 📥 `apple_pay_merchant_identity.cer`

---

### 3️⃣ Convert CER to PEM

```bash
cd "/Users/brandbik/Flutter/premium-force/premium force apple pay merchant"

# Payment Processing Certificate
openssl x509 -inform DER -in apple_pay_payment_processing.cer \
  -out apple_pay_payment_processing.pem

# Merchant Identity Certificate
openssl x509 -inform DER -in apple_pay_merchant_identity.cer \
  -out apple_pay_merchant_identity.pem
```

**Output files**:
- ✅ `apple_pay_payment_processing.pem`
- ✅ `apple_pay_merchant_identity.pem`

---

### 4️⃣ Convert to P12 (with password protection)

```bash
cd "/Users/brandbik/Flutter/premium-force/premium force apple pay merchant"

# Payment Processing P12
openssl pkcs12 -export \
  -in apple_pay_payment_processing.pem \
  -inkey apple_pay_private.key \
  -out apple_pay_payment_processing.p12 \
  -name "Apple Pay Payment Processing" \
  -passout pass:YourSecurePassword123

# Merchant Identity P12 (for backend)
openssl pkcs12 -export \
  -in apple_pay_merchant_identity.pem \
  -inkey apple_pay_private.key \
  -out apple_pay_merchant_identity.p12 \
  -name "Apple Pay Merchant Identity" \
  -passout pass:YourSecurePassword123
```

**Replace `YourSecurePassword123`** with your actual password!

---

### 5️⃣ Verify All Files

```bash
ls -lah "/Users/brandbik/Flutter/premium-force/premium force apple pay merchant/"

# Should see 8 files:
# ✓ ApplePay-PremiumForce.csr
# ✓ apple_pay_private.key
# ✓ apple_pay_payment_processing.cer
# ✓ apple_pay_payment_processing.pem
# ✓ apple_pay_payment_processing.p12
# ✓ apple_pay_merchant_identity.cer
# ✓ apple_pay_merchant_identity.pem
# ✓ apple_pay_merchant_identity.p12
```

---

### 6️⃣ Verify Certificate Details

```bash
# Check Payment Processing certificate expiry
openssl x509 -in apple_pay_payment_processing.pem -text -noout | grep -A 2 "Validity"

# Check Merchant Identity certificate expiry
openssl x509 -in apple_pay_merchant_identity.pem -text -noout | grep -A 2 "Validity"

# Check P12 contents
openssl pkcs12 -in apple_pay_payment_processing.p12 -noout -info -passin pass:YourSecurePassword123
```

---

## 📦 File Destination

**For iOS App** (add to Xcode):
- `apple_pay_payment_processing.p12` → Xcode Build Resources

**For Backend Server** (keep secure):
- `apple_pay_merchant_identity.p12` → Backend certificate store
- `apple_pay_merchant_identity.pem` → For decryption/verification

---

## ⚠️ Security Notes

- 🔐 **Private key** (`apple_pay_private.key`) - Never share, never commit to Git
- 🔐 **P12 files** - Password protected, keep in secure location
- 🔐 **Backend P12** - Store securely on server, use environment variables for passwords
- 🔐 **Add to `.gitignore`**:
  ```
  certificates/
  *.key
  *.p12
  *.cer
  *.pem
  ```

---

## 🔄 Full One-Liner Scripts

### Generate everything in one go:
```bash
mkdir -p "/Users/brandbik/Flutter/premium-force/premium force apple pay merchant" && \
cd "/Users/brandbik/Flutter/premium-force/premium force apple pay merchant" && \
openssl ecparam -genkey -name prime256v1 -out apple_pay_private.key && \
openssl req -new -key apple_pay_private.key -out ApplePay-PremiumForce.csr \
  -subj "/emailAddress=muhammed.fadhil2@icloud.com/CN=Apple Pay - Premium Force/O=Brandbik/C=SA"

echo "✅ Generated:"
echo "  - apple_pay_private.key (ECC 256-bit)"
echo "  - ApplePay-PremiumForce.csr"
echo ""
echo "📋 Next: Upload CSR to Apple Developer Account"
```

---

## 📅 Timeline

1. **Today**: Generate CSR (3 minutes)
2. **Apple Developer**: Register Merchant ID & upload CSR (5 minutes)
3. **Apple Developer**: Download certificates (instant)
4. **Your Mac**: Convert to PEM/P12 (2 minutes)
5. **Xcode**: Configure Apple Pay capability (5 minutes)
6. **Backend**: Deploy merchant identity certificate (varies)

**Total setup time**: ~20 minutes

---

## ❓ Troubleshooting

```bash
# CSR file doesn't look right?
openssl req -in ApplePay-PremiumForce.csr -text -noout

# Private key validation
openssl rsa -in apple_pay_private.key -check

# P12 file validation
openssl pkcs12 -in apple_pay_payment_processing.p12 -noout -passin pass:YourPassword

# Check certificate chain
openssl verify apple_pay_payment_processing.pem
```

---

## 📞 Support

- **Apple Developer Docs**: https://developer.apple.com/apple-pay/
- **OpenSSL Guide**: https://www.openssl.org/docs/
- **Certificate Issues**: Check Apple Developer Account notifications

---

**Reference**: Full guide in `APPLEPAY_SETUP.md`
