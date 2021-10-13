# flutter_flexible_pay
[![pub](https://img.shields.io/pub/v/flutter_flexible_pay.svg)](https://pub.dev/packages/flutter_flexible_pay)

Make Stripe payments via Google pay & Apple Pay across the globe with ease Supports IOS & Android [Payment Request API](https://developers.google.com/pay/api/android/overview).
Personally, I love simplicity!

![Simulator Screen Shot - iPhone 13 Pro Max - 1](https://user-images.githubusercontent.com/42380340/137212417-4ae5e23a-29a0-461f-914c-8877351f25f0.png)
![Simulator Screen Shot - iPhone 13 Pro Max - 2](https://user-images.githubusercontent.com/42380340/137212427-8018b03f-a8a2-4238-b2fc-fcefa20e2902.png)
![Simulator Screen Shot - iPhone 13 Pro Max - 3](https://user-images.githubusercontent.com/42380340/137212431-6ac9ef48-6588-4ed8-b6c7-141a91335ed0.png)
![Simulator Screen Shot - iPhone 13 Pro Max - 4](https://user-images.githubusercontent.com/42380340/137212434-40943a79-7ea2-44e9-a591-f4e34dab4e42.png)

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
  /// See project example to see the contents of payment_profile_google_pay.json &
  /// payment_profile_apple_pay.json in the example assets' folder
  Future<void> loadConfiguration() async {
   Map<String, dynamic> profiles = {
   'google': 'assets/configurations/payment_profile_google_pay.json',
   'apple': 'assets/configurations/payment_profile_apple_pay.json',
   };
   FlutterFlexiblePay.setPaymentConfig(profiles);
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
        _showToast(scaffoldContext, "Google or Apple Pay Not Available on this device!");
      } else {
  
        PaymentItem product = PaymentItem(
            countryCode: "US",
            currencyCode: "USD",
            amount: product["amount"], // string
            label: product["name"], // the product name or label
        );
  
        FlutterFlexiblePay.makePayment(product).then((Result result) {
           if (result.status == ResultStatus.SUCCESS) {
            _showToast(scaffoldContext, result.description);
          }
  
          if(result.status == ResultStatus.RESULT_CANCELED) {
            _showToast(scaffoldContext, result.error);
          }
  
          if(result.status == ResultStatus.ERROR) {
            _showToast(scaffoldContext, result.error);
          }
  
          if(result.status == ResultStatus.UNKNOWN) {
            _showToast(scaffoldContext, 'Unknown Error');
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