import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_flexible_pay/flutter_flexible_pay.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late BuildContext scaffoldContext;

  /// This example file was used to implement stripe payment
  /// For other payment, remove "stripe:*" key occurrences and replace with "gatewayMerchantId"
  Future<void> preparePaymentConfig() async {

    Map<String, dynamic> profiles = {
    'google': 'assets/configurations/payment_profile_google_pay.json',
    'apple': 'assets/configurations/payment_profile_apple_pay.json',
    };
    FlutterFlexiblePay.setPaymentConfig(profiles);
  }

  @override
  void initState() {
    super.initState();
    preparePaymentConfig();
  }

  _makeStripePayment() async {
    var environment = 'test'; // or 'production'
    if (!(await FlutterFlexiblePay.isAvailable(environment))) {
      _showToast(scaffoldContext, "Google or Apple Pay Not Available on this device!");
    } else {
      PaymentItem product = PaymentItem(
        countryCode: "US",
        currencyCode: "USD",
        amount: "0.80",
        label: "Shirt",
      );

      /// Make payment using async [FlutterFlexiblePay]
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Flutter Flexible Pay'),
          ),
          body: Builder(builder: (context) {
            scaffoldContext = context;
            return Center(
                child: Column(
              children: <Widget>[
                TextButton(
                  onPressed: _makeStripePayment,
                  child: const Text('Make payment'),
                ),
              ],
            ));
          })),
    );
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () {},
      ),
    ));
  }
}
