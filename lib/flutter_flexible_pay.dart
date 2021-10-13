// ignore_for_file: constant_identifier_names

import "dart:io";
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';


/// Main plugin file [FlutterFlexiblePay].
class FlutterFlexiblePay {
  static const MethodChannel _channel = MethodChannel('flutter_flexible_pay');
  static bool isConfigSet = true;

  static Future<void> closeApplePaySheet({required bool isSuccess}) async {
    if (Platform.isIOS) {
      if(isSuccess) {
        await _channel.invokeMethod('closeApplePaySheetWithSuccess');
      }
      else {
        await _channel.invokeMethod('closeApplePaySheetWithError');
      }
    } else {
      throw Exception("Only called for apple payments");
    }
  }

  /// Accepts payments profiles as files json [assetsFile]
  static setPaymentConfig(Map<String, dynamic> assetsFile) async {
    try {

      Map<String, dynamic>? googleProfile;
      Map<String, dynamic>? appleProfile;

      /// Load google payment profile if it's set
      if ( assetsFile['google'] != null ) {
        String googleParsed = await rootBundle.loadString(assetsFile['google']);
        googleProfile = json.decode(googleParsed);
        if ( Platform.isAndroid) {
          await _channel.invokeMethod("set_configurations", googleProfile);
        }
      }

      /// Load Apple payment profile if it's set
      if ( assetsFile['apple'] != null ) {
        final String appleParsed = await rootBundle.loadString(assetsFile['apple']);
        appleProfile = json.decode(appleParsed);
        if ( Platform.isIOS ) {
          await _channel.invokeMethod("set_apple_configurations", appleProfile);
        }
      }

      /// If non is set, flag [isConfigSet = false]
      if ( googleProfile == null && appleProfile == null ) {
        isConfigSet = false;
      }

    } catch (error) {
      isConfigSet = false;
    }
  }

  /// Call the payment processor to process [data] dataType of [PaymentItem]
  static Future<Result> makePayment(PaymentItem data) async {

    bool isPending = false;

    if( !isConfigSet ) {
      final Map<String, dynamic> error = {
        "error" : 'Configs not set',
        "status" : ResultStatus.ERROR,
        "description" : "Sorry! Base configurations are not set. Ensure you have loaded the payment profiles"
      };

      return _parseResult(error);
    }

    if ( Platform.isAndroid) {
      /// Request Payment using Google Pay
      return _call("request_payment_custom_payment", data.toMap());

    } else {

      /// Request Payment using Apple Pay
      final Map<String, Object> args = {
        'paymentItem': data.toMap(),
        'isPending' : isPending
      };

      return _call("request_apple_payment", args);
    }
  }

  /// An async handler to parse the string method [methodName] and [data]
  static Future<Result> _call(String methodName, dynamic data) async {
    var result = await _channel.invokeMethod(methodName, data).then((dynamic data) => data);
    // Token was obtained successfully
    return _parseResult(result);
  }

  /// Check payment availability using [environment]
  static Future<bool> isAvailable(String environment) async {

    if (!Platform.isIOS && !Platform.isAndroid) {
      return false;
    }

    try {
      // Response holder
      Map map;

      if (Platform.isIOS) {
        map = await _channel.invokeMethod("can_make_apple_payments");
      } else {
        map = await _channel.invokeMethod("is_available", {"environment": environment});
      }
      return map['isAvailable'];

    } catch (error) {
      return false;
    }
  }

  /// Parse payment response in [map]
  static Result _parseResult(dynamic map) {
    var error = map['error'];
    var status = map['status'];
    var result = map['result'];
    var description = map["description"];

    error ??= "";

    if (result != null) {
      if(result is String) {
        result = json.decode(result);
      }
    }

    ResultStatus resultStatus;
    if (status != null) {
      resultStatus = parseStatus(status);
    } else if (result != null) {
      resultStatus = ResultStatus.SUCCESS;
    } else {
      resultStatus = ResultStatus.UNKNOWN;
    }
    /// if result is null, make an empty object instead
    result ??= {};

    /// return response as instance of [Result]
    return Result(error, result, resultStatus, description);
  }

  /// Parse payment status using [status]
  static ResultStatus parseStatus(String status) {
    switch (status) {
      case "SUCCESS":
        return ResultStatus.SUCCESS;
      case "ERROR":
        return ResultStatus.ERROR;
      case "RESULT_CANCELED":
        return ResultStatus.RESULT_CANCELED;
      case "RESULT_INTERNAL_ERROR":
        return ResultStatus.RESULT_INTERNAL_ERROR;
      case "DEVELOPER_ERROR":
        return ResultStatus.DEVELOPER_ERROR;
      case "RESULT_TIMEOUT":
        return ResultStatus.RESULT_TIMEOUT;
      case "RESULT_DEAD_CLIENT":
        return ResultStatus.RESULT_DEAD_CLIENT;
      default:
        return ResultStatus.UNKNOWN;
    }
  }
}



class PaymentItem {
  String currencyCode;
  String amount;
  String label;
  String countryCode;

  PaymentItem(
      {required this.currencyCode,
        required this.amount,
        required this.label,
        required this.countryCode});

  Map toMap() {
    Map args = {};
    args["amount"] = amount;
    args["currencyCode"] = currencyCode;
    args["label"] = label;
    args["countryCode"] = countryCode;

    if (!_validateAmount(amount)) {
      throw Exception("Wrong amount: $amount");
    }
    if (!_validateCurrencyCode(currencyCode)) {
      throw Exception("Wrong currency code: $currencyCode");
    }
    if (!_validateCurrencyCode(countryCode)) {
      throw Exception("Wrong country code: $countryCode");
    }
    return args;
  }
}

enum ResultStatus {
  SUCCESS,
  ERROR,
  RESULT_CANCELED,
  RESULT_INTERNAL_ERROR,
  DEVELOPER_ERROR,
  RESULT_TIMEOUT,
  RESULT_DEAD_CLIENT,
  UNKNOWN,
}

class Result {
  String error;
  String description;
  Map data;
  ResultStatus status;

  Result(this.error, this.data, this.status, this.description);
}

bool _validateAmount(dynamic amount) {
  return (amount?.toString() ?? "").isNotEmpty;
}

bool _validateCurrencyCode(dynamic currencyCode) {
  bool isNotEmpty = (currencyCode?.toString() ?? "").isNotEmpty;
  if (!isNotEmpty) {
    return false;
  }

  return true;
}

bool isEmpty(String value) {
  return value.isEmpty;
}
