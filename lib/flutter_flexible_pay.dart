import "dart:io";
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

class FlutterFlexiblePay {
  static const MethodChannel _channel = MethodChannel('flutter_flexible_pay');

  static setPaymentConfig (Map data) async {

    try {
      await _channel.invokeMethod("set_configurations", data);
    } catch (error) {
      // do nothing for now
    }
  }

  // Call the payment processor
  static Future<Result> makePayment(PaymentItem data) async {
    return _call("request_payment_custom_payment", data.toMap());
  }

  // Call handler to parse the string method Name
  static Future<Result> _call(String methodName, dynamic data) async {
    Result result = await _channel.invokeMethod(methodName, data).then((dynamic data) {
      return _parseResult(data);
    }).catchError((dynamic error) {
      return Result(error?.toString() ?? 'unknown error', {"error": null},
          ResultStatus.error, (error?.toString()) ?? "");
    });
    return result;
  }

// Check payment availability
  static Future<bool> isAvailable(String environment) async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      Map map = await _channel.invokeMethod("is_available", {"environment": environment});
      return map['isAvailable'];
    } catch (error) {
      return false;
    }
  }

  static Result _parseResult(dynamic map) {
    var error = map['error'];
    var status = map['status'];
    var result = map['result'];
    var description = map["description"];
    if (result != null) {
      result = json.decode(result);
    }
    ResultStatus resultStatus;
    if (error != null) {
      resultStatus = ResultStatus.error;
    } else if (status != null) {
      resultStatus = parseStatus(status);
    } else if (result != null) {
      resultStatus = ResultStatus.success;
    } else {
      resultStatus = ResultStatus.unknown;
    }
    return Result(error, result, resultStatus, description);
  }

  static ResultStatus parseStatus(String status) {
    switch (status) {
      case "success":
        return ResultStatus.success;
      case "error":
        return ResultStatus.error;
      case "resultCanceled":
        return ResultStatus.resultCanceled;
      case "resultInternalError":
        return ResultStatus.resultInternalError;
      case "developerError":
        return ResultStatus.developerError;
      case "resultTimeout":
        return ResultStatus.resultTimeout;
      case "resultDeadClient":
        return ResultStatus.resultDeadClient;
      default:
        return ResultStatus.unknown;
    }
  }
}


class PaymentItem {
  String currencyCode;
  String amount;
  String label;
  String countryCode;

  PaymentItem({
    required this.currencyCode,
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
  success,
  error,
  resultCanceled,
  resultInternalError,
  developerError,
  resultTimeout,
  resultDeadClient,
  unknown,
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

