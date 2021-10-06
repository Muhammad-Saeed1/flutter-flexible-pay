// ignore_for_file: constant_identifier_names

import "dart:io";
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';


/// Main plugin file [FlutterFlexiblePay].
class FlutterFlexiblePay {
  static const MethodChannel _channel = MethodChannel('flutter_flexible_pay');

  /// Accepts parsed json file as [data]
  static setPaymentConfig(Map data) async {
    try {
      await _channel.invokeMethod("set_configurations", data);
    } catch (error) {
      // do nothing for now
    }
  }

  /// Call the payment processor to process [data] dataType of [PaymentItem]
  static Future<Result> makePayment(PaymentItem data) async {
    return _call("request_payment_custom_payment", data.toMap());
  }

  /// An async handler to parse the string method [methodName] and [data]
  static Future<Result> _call(String methodName, dynamic data) async {
    var result = await _channel.invokeMethod(methodName, data).then((dynamic data) => data);
    return _parseResult(result);
  }

  /// Check payment availability using [environment]
  static Future<bool> isAvailable(String environment) async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      Map map = await _channel
          .invokeMethod("is_available", {"environment": environment});
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
    if (result != null) {
      result = json.decode(result);
    }

    ResultStatus resultStatus;
    if (status != null) {
      resultStatus = parseStatus(status);
    } else if (error != null) {
      resultStatus =  ResultStatus.ERROR;
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
