# flutter_flexible_pay
[![pub](https://img.shields.io/pub/v/flutter_flexible_pay.svg)](https://pub.dev/packages/flutter_flexible_pay)

Make payments via Google approved merchants across the globe. Supports IOS & Android [Payment Request API](https://developers.google.com/pay/api/android/overview).

## Usage

### AndroidManifest
```xml
<meta-data
    android:name="com.google.android.gms.wallet.api.enabled"
    android:value="true" />
```

### Load the payment configurations like so;
```dart

  import 'package:flutter_flexible_pay/flutter_flexible_pay.dart';

  /// This example file was used to implement stripe payment
  /// For other payment, remove "stripe:*" key occurrences and replace with "gatewayMerchantId"
  /// See project example to see the contents of payment_profile_google_pay.json
  /// *IOS support will be added soonest*
  Future<void> loadConfiguration() async {
    final String response =
    await rootBundle.loadString('assets/configurations/payment_profile_google_pay.json');
    final data = await json.decode(response);
    // Set the payment profile and configurations
    FlutterFlexiblePay.setPaymentConfig(data);
  }

  @override
  void initState() {
    super.initState();
    loadConfiguration();
  }
```

### Make Payments like so;
```dart
  
  _makePayment(dynamic product) async {
      var environment = 'test'; // or 'production'
      if (!(await FlutterFlexiblePay.isAvailable(environment))) {
        _showToast(scaffoldContext, "Google Pay Not Available!");
      } else {
  
        PaymentItem product = PaymentItem(
            countryCode: "US",
            currencyCode: "USD",
            amount: product["amount"], // string
            label: product["name"], // the product name or label
        );
  
        FlutterFlexiblePay.makePayment(product).then((Result result) {
          if (result.status == ResultStatus.success) {
            _showToast(scaffoldContext, 'Success');
          }
        }).catchError((dynamic error) {
          _showToast(scaffoldContext, error.toString());
        });
      }
    }
  
```
### Doc for creating custom payment data:
This goes into your .json file
[Google Pay](https://developers.google.com/pay/api/android/guides/tutorial)