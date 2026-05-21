# Apple Pay Certificate Setup

**App Bundle ID**: `com.brandbik.premiumforce`  
**Merchant ID**: `merchant.com.premiumforce.main`  
**Date**: May 20, 2026

---

## Step 1: Create a Certificate Signing Request (CSR)

### Option A: Using macOS Keychain Access (Recommended)

1. **Open Keychain Access** on your Mac:
   ```bash
   /Applications/Utilities/Keychain Access.app
   ```

2. **Go to**: `Keychain Access` → `Certificate Assistant` → `Request a Certificate from a Certificate Authority`

3. **Fill in the form**:
   - **User Email Address**: your-email@premiumforce.com
   - **Common Name**: Apple Pay - Premium Force
   - **Request is**: Select **"Saved to disk"**

4. **Click Continue** and save the CSR file:
   - **Filename**: `ApplePay-PremiumForce.certSigningRequest`
   - **Location**: Save to a secure folder

5. **Keep the private key** in Keychain (you'll need this later for P12 export)

### Option B: Using Terminal (Alternative)

```bash
# Generate ECC 256-bit private key (required by Apple Pay)
openssl ecparam -genkey -name prime256v1 -out apple_pay_private.key

# Generate CSR
openssl req -new \
  -key apple_pay_private.key \
  -out ApplePay-PremiumForce.csr \
  -subj "/emailAddress=your-email@premiumforce.com/CN=Apple Pay - Premium Force/O=Premium Force/C=AE"
```

**Files created**:
- `apple_pay_private.key` - Keep this safe! (ECC 256-bit)
- `ApplePay-PremiumForce.csr` - Upload to Apple Developer

---

## Step 2: Register Merchant ID in Apple Developer Account

1. **Go to**: [Apple Developer Account](https://developer.apple.com/account)

2. **Navigate to**: `Certificates, Identifiers & Profiles` → `Identifiers`

3. **Click the "+" button** to create a new identifier

4. **Select**: `Merchant IDs` and click **Continue**

5. **Fill in**:
   - **Description**: Premium Force Merchant ID
   - **Merchant ID**: `merchant.com.premiumforce.main`

6. **Click Register** and confirm

**Your Merchant ID**: `merchant.com.premiumforce.main`

---

## Step 3: Create Apple Pay Certificates

### 3.1 Create Payment Processing Certificate

1. **Go to**: `Certificates, Identifiers & Profiles` → `Certificates`

2. **Click "+"** to create a new certificate

3. **Select**: `Apple Pay Payment Processing Certificate` → **Continue**

4. **Choose your Merchant ID**: `merchant.com.premiumforce.main`

5. **Upload CSR**: Upload `ApplePay-PremiumForce.csr`

6. **Download**: Save as `apple_pay_payment_processing.cer`

### 3.2 Create Merchant Identity Certificate

1. **Repeat steps 1-2 above**

2. **Select**: `Apple Pay Merchant Identity Certificate` → **Continue**

3. **Choose your Merchant ID**: `merchant.com.premiumforce.main`

4. **Upload CSR**: Same CSR file as above

5. **Download**: Save as `apple_pay_merchant_identity.cer`

---

## Step 4: Convert Certificates to PEM and P12 Formats

### Prerequisites

```bash
# Install OpenSSL (usually pre-installed on macOS)
# If needed: brew install openssl
```

### 4.1 Convert Payment Processing Certificate

#### To PEM:
```bash
openssl x509 -inform DER -in apple_pay_payment_processing.cer \
  -out apple_pay_payment_processing.pem
```

#### To P12 (with private key):
```bash
openssl pkcs12 -export \
  -in apple_pay_payment_processing.pem \
  -inkey apple_pay_private.key \
  -out apple_pay_payment_processing.p12 \
  -name "Apple Pay Payment Processing" \
  -passout pass:YOUR_PASSWORD
```

**Replace `YOUR_PASSWORD`** with a secure password (you'll need it to import the certificate).

### 4.2 Convert Merchant Identity Certificate

#### To PEM:
```bash
openssl x509 -inform DER -in apple_pay_merchant_identity.cer \
  -out apple_pay_merchant_identity.pem
```

#### To P12 (with private key):
```bash
openssl pkcs12 -export \
  -in apple_pay_merchant_identity.pem \
  -inkey apple_pay_private.key \
  -out apple_pay_merchant_identity.p12 \
  -name "Apple Pay Merchant Identity" \
  -passout pass:YOUR_PASSWORD
```
