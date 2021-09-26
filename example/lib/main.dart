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
    final String response = await rootBundle
        .loadString('assets/configurations/payment_profile_google_pay.json');
    final data = await json.decode(response);
    // Set the payment profile and configurations
    FlutterFlexiblePay.setPaymentConfig(data);
  }

  @override
  void initState() {
    super.initState();
    preparePaymentConfig();
  }

  _makeStripePayment() async {
    var environment = 'test'; // or 'production'
    if (!(await FlutterFlexiblePay.isAvailable(environment))) {
      _showToast(scaffoldContext, "Google Pay Not Available!");
    } else {
      PaymentItem product = PaymentItem(
        countryCode: "US",
        currencyCode: "USD",
        amount: "0.10",
        label: "Shirt",
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
