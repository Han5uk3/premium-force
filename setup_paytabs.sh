#!/bin/bash
# Flutter Paytabs Bridge Setup Automation Script
# This script automates the setup process for flutter_paytabs_bridge

set -e

echo "================================"
echo "Flutter Paytabs Bridge Setup"
echo "================================"
echo ""

# Step 1: Verify flutter_paytabs_bridge is in pubspec.yaml
echo "📋 Step 1: Verifying flutter_paytabs_bridge dependency..."
if grep -q "flutter_paytabs_bridge" pubspec.yaml; then
    echo "✅ flutter_paytabs_bridge found in pubspec.yaml"
else
    echo "❌ flutter_paytabs_bridge not found in pubspec.yaml"
    exit 1
fi
echo ""

# Step 2: Get dependencies
echo "📋 Step 2: Fetching dependencies..."
flutter pub get
echo "✅ Dependencies installed"
echo ""

# Step 3: Check iOS setup
echo "📋 Step 3: Checking iOS setup..."
if [ -f "ios/Podfile" ]; then
    echo "✅ iOS Podfile found"
    cd ios
    echo "   Installing pods..."
    pod install --repo-update 2>/dev/null || true
    cd ..
    echo "✅ iOS pods installed"
else
    echo "⚠️  iOS Podfile not found"
fi
echo ""

# Step 4: Check Android setup
echo "📋 Step 4: Checking Android setup..."
if [ -f "android/app/build.gradle.kts" ]; then
    echo "✅ Android build.gradle.kts found"
else
    echo "⚠️  Android build.gradle.kts not found"
fi
echo ""

# Step 5: Verify created files
echo "📋 Step 5: Verifying setup files..."
files=(
    "lib/services/payment_service.dart"
    "lib/models/payment_model.dart"
    "lib/providers/payment_provider.dart"
    "lib/utils/paytabs_config.dart"
    "lib/common_widgets/payment_example_screen.dart"
    "PAYTABS_SETUP.md"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - MISSING"
    fi
done
echo ""

# Step 6: Show next steps
echo "================================"
echo "✅ Setup Complete!"
echo "================================"
echo ""
echo "📝 Next Steps:"
echo ""
echo "1. Update your credentials in lib/utils/paytabs_config.dart:"
echo "   - SERVER_KEY"
echo "   - CLIENT_KEY"
echo "   - MERCHANT_EMAIL"
echo "   - MERCHANT_COUNTRY_CODE"
echo ""
echo "2. Add PaymentProvider to your main.dart:"
echo "   import 'package:premium_force_main/providers/payment_provider.dart';"
echo ""
echo "3. Initialize payment in main():"
echo "   await PaymentProvider().initializePayment();"
echo ""
echo "4. Use in your widgets:"
echo "   final paymentProvider = Provider.of<PaymentProvider>(context);"
echo "   await paymentProvider.processPayment(request: paymentRequest);"
echo ""
echo "📖 For detailed setup instructions, see PAYTABS_SETUP.md"
echo "💡 Example implementation in lib/common_widgets/payment_example_screen.dart"
echo ""
