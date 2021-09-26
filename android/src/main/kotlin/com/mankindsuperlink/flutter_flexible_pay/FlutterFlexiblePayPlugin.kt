package com.mankindsuperlink.flutter_flexible_pay

import android.app.Activity
import android.content.Intent
import android.text.TextUtils
import android.util.Log
import androidx.annotation.NonNull
import com.google.android.gms.common.api.Status
import com.google.android.gms.wallet.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject
import java.util.*

/** FlutterFlexiblePayPlugin */
class FlutterFlexiblePayPlugin: FlutterPlugin, MethodCallHandler, PluginRegistry.ActivityResultListener, ActivityAware{
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  private val channelName = "flutter_flexible_pay"
  private val methodRequestCustomPayment = "request_payment_custom_payment"
  private val methodIsAvailable = "is_available"
  private val keyMethod = "method_name"
  private val methodSetConfigurations = "set_configurations"
  private lateinit var paymentsJson: JSONObject
  private var mLastResult: Result? = null
  private var mLastMethodCall: MethodCall? = null

  /**
   * Arbitrarily-picked constant integer you define to track a request for payment data activity.
   *
   * @value #loadPaymentDataRequestCode
   */
  private val loadPaymentDataRequestCode = 991

  /**
   * A client for interacting with the Google Pay API.
   *
   * @see [PaymentsClient](https://developers.google.com/android/reference/com/google/android/gms/wallet/PaymentsClient)
   */
  private var mPaymentsClient: PaymentsClient? = null
  private lateinit var mActivity: Activity

  private fun client(): PaymentsClient? {
    if (mPaymentsClient == null) {
      val environment = mLastMethodCall!!.argument<CharArray>("environment").toString()
      mPaymentsClient = PaymentsUtil.createPaymentsClient(mActivity, environment)
    }
    return mPaymentsClient
  }


  /**
   * PaymentData response object contains the payment information, as well as any additional
   * requested information, such as billing and shipping address.
   *
   * @param paymentData A response object returned by Google after a payer approves payment.
   * @see [Payment
   * Data](https://developers.google.com/pay/api/android/reference/object.PaymentData)
   */
  private fun callToDartOnPaymentSuccess(paymentData: PaymentData) {
    val paymentInfo = paymentData.toJson()
    val data: MutableMap<String, Any> = HashMap()
    data["status"] = "SUCCESS"
    data["result"] = paymentInfo
    mLastResult!!.success(data)
  }

  private fun callToDartOnGooglePayIsAvailable(isAvailable: Boolean) {
    if (mLastResult != null) {
      val data: MutableMap<String, Any> = HashMap()
      data[keyMethod] = methodIsAvailable
      data["isAvailable"] = isAvailable
      mLastResult!!.success(data)
      mLastResult = null
    }
  }

  private fun callToDartOnError(status: Status?) {
    if (mLastResult != null) {
      val data: MutableMap<String, Any> = HashMap()
      if (status != null) {
        var statusMessage: Any = status.statusMessage
        if (TextUtils.isEmpty(statusMessage.toString())) {
          statusMessage = "payment error"
        }

        val statusCode: Any = when (status.statusCode) {
          8 -> "resultInternalError"
          10 -> "developerError"
          15 -> "resultTimeout"
          16 -> "resultCanceled"
          18 -> "resultDeadClient"
          else -> "unknown"
        }
        data["error"] = statusMessage
        data["status"] = statusCode
        data["description"] = status.toString()
      } else {
        data["error"] = "Wrong payment data"
        data["status"] = "unknown"
        data["description"] = "Payment finished without additional information"
      }
      mLastResult!!.success(data)
      mLastResult = null
    }
  }

  private fun callToDartOnCanceled() {
    if (mLastResult != null) {
      val data: MutableMap<String, Any> = HashMap()
      data["status"] = "RESULT_CANCELED"
      data["description"] = "Canceled by user"
      mLastResult!!.success(data)
      mLastResult = null
    }
  }


  // Load default configurations specified
  // This is a json file that contains google pay configurations
  // as indicated in the guidelines
  private fun prepareConfigurations() {
    try {
      paymentsJson = JSONObject(mLastMethodCall!!.arguments as Map<*, *>)
    } catch (e: Exception) {
      e.message?.let { Log.d("Config Error:", it) }
    }
  }


  private fun requestPaymentCustom() {
    try {

      // Get inputs for product
      val amount = mLastMethodCall!!.argument<String>("amount")
      val currencyCode = mLastMethodCall!!.argument<String>("currencyCode")
      val countryCode = mLastMethodCall!!.argument<String>("countryCode")
      val label = mLastMethodCall!!.argument<String>("label")

      // Parse existing transaction information and update
      val transactionInfo = paymentsJson.getJSONObject("transactionInfo")

      transactionInfo.apply {
        put("totalPrice", amount)
        put("totalPriceStatus", "FINAL")
        put("totalPriceLabel", label)
        put("currencyCode", currencyCode)
        put("countryCode", countryCode)
      }

      // Object payment request token using payment configuration
      val request = PaymentDataRequest.fromJson(paymentsJson.toString())
      this.makePayment(request)

    } catch (e: Exception) {
      // Log if there is error
      Log.d("Error", e.message!!)
    }
  }

  private fun makePayment(request: PaymentDataRequest?) {
    // Since loadPaymentData may show the UI asking the user to select a payment method, we use
    // AutoResolveHelper to wait for the user interacting with it. Once completed,
    // onActivityResult will be called with the result.
    if (request != null) {
      val task = client()!!.loadPaymentData(request)
      AutoResolveHelper.resolveTask(task, mActivity, loadPaymentDataRequestCode)
    }
  }

  /**
   * Determine the viewer's ability to pay with a payment method supported by your app and display a
   * Google Pay payment button.
   */
  private fun checkIsGooglePayAvailable() {
    val request = IsReadyToPayRequest.fromJson(PaymentsUtil.isReadyToPayRequest(paymentsJson).toString())
    // The call to isReadyToPay is asynchronous and returns a Task. We need to provide an
    // OnCompleteListener to be triggered when the result of the call is known.
    val task = client()!!.isReadyToPay(request)
    task.addOnCompleteListener(mActivity
    ) { task ->
      if (task.isSuccessful) {
        callToDartOnGooglePayIsAvailable(true)
      } else {
        callToDartOnGooglePayIsAvailable(false)
        Log.w("isReadyToPay failed", task.exception)
      }
    }
  }


  // On attached to device engine, register plugin to device
  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, channelName)
    channel.setMethodCallHandler(this)
  }

  // Once the activity is attached, bind plugin activity to main activity
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    mActivity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    // do nothing
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    mActivity = binding.activity
  }

  override fun onDetachedFromActivity() {
    //do nothing
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    mLastMethodCall = call
    mLastResult = result
    when (call.method) {
      methodIsAvailable -> this.checkIsGooglePayAvailable()
      methodRequestCustomPayment -> this.requestPaymentCustom()
      methodSetConfigurations -> this.prepareConfigurations()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  /**
   * Handle a resolved activity from the Google Pay payment sheet.
   *
   * @param requestCode Request code originally supplied to AutoResolveHelper in requestPayment().
   * @param resultCode  Result code returned by the Google Pay API.
   * @param data        Intent from the Google Pay API containing payment or error data.
   * @see <a href="https://developer.android.com/training/basics/intents/result">Getting a result
   * from an Activity</a>
   */
  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent): Boolean {
    if (requestCode == loadPaymentDataRequestCode) {
      when (resultCode) {
        Activity.RESULT_OK -> {
          val paymentData = PaymentData.getFromIntent(data)
          if (paymentData != null) {
            callToDartOnPaymentSuccess(paymentData)
          }
          return true
        }
        Activity.RESULT_CANCELED -> {
          callToDartOnCanceled()
          return true
        }
        AutoResolveHelper.RESULT_ERROR -> {
          val status = AutoResolveHelper.getStatusFromIntent(data)
          this.callToDartOnError(status)
          return true
        }
      }
    }
    return false
  }
}
