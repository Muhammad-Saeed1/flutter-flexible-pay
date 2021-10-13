import Flutter
import UIKit
import Foundation
import PassKit
import Stripe


typealias AuthorizationCompletion = (_ payment: NSDictionary) -> Void
typealias AuthorizationViewControllerDidFinish = (_ error : NSDictionary) -> Void
typealias CompletionHandler = (PKPaymentAuthorizationResult) -> Void


public class SwiftFlutterFlexiblePayPlugin: NSObject, FlutterPlugin, PKPaymentAuthorizationViewControllerDelegate {
    
    
    var authorizationCompletion : AuthorizationCompletion!
    var authorizationViewControllerDidFinish : AuthorizationViewControllerDidFinish!
    var pkrequest = PKPaymentRequest()
    var flutterResult: FlutterResult!;
    var completionHandler: CompletionHandler!
    
    var countryCode: String!
    var currencyCode: String!
    var merchantIdentifier: String!
    var merchantName: String!
    var supportedNetworks: [String]!
    var merchantCapabilities: [String]!
    var stripePublishableKey: String!
    var stripeVersion: String!
    var gateway: String!
    var requiredShippingContactFields: [String]!
    var requiredBillingContactFields: [String]!
    var errorDefinition : NSMutableDictionary = [
        "error": "Payment sheet closed",
        "description": "User closed apple pay",
        "status": "RESULT_CANCELED"
    ]
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_flexible_pay", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterFlexiblePayPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "request_apple_payment" {
            
            flutterResult = result;
            let parameters = NSMutableDictionary()
            var payments: [PKPaymentNetwork] = []
            var items = [PKPaymentSummaryItem]()
            var capabilities = [PKMerchantCapability]()
            var shippingContactFields = Set<String>()
            var billingContactFields = Set<String>()
            var totalPrice:Double = 0.0
            let arguments = call.arguments as! NSDictionary
            
            // Get paymentitems as a dictionary from arguments. Halt if null
            guard let paymentItem = arguments["paymentItem"] as? NSDictionary else {return}
            
            // Sets Product label and amount from payment item. Halt if null
            guard let label = paymentItem["label"] as? String else {return}
            guard let price = (paymentItem["amount"] as? NSString)?.doubleValue else {return}
            
            // Get supported Networks. Halt if null
            guard let paymentNeworks = supportedNetworks else {return}
            
            let shippingContactCollection = requiredShippingContactFields
            let billingContactCollection = requiredShippingContactFields
            
            // Get payment capabilities. Halt if null
            guard let paymentCapabilities = merchantCapabilities else {return}
            
            // Try to use the product country code, if null, use the config value
            guard let countryCode = countryCode ?? paymentItem["countryCode"] else {return}
            
            // Try to use the product currency code, if null, use the config value
            guard let currencyCode = currencyCode ?? paymentItem["currencyCode"] else {return}
            
            // Get stipe publish key. Halt if null
            guard let stripePublishedKey = stripePublishableKey else {return}
            // Get merchant IDentifier. Halt if null
            guard let merchantIdentifier = merchantIdentifier else {return}
            // Get merchant Name. Halt if null
            guard let merchantName = merchantName else {return}
            // Get transaction status passed from client. Halt if null
            guard let isPending = arguments["isPending"] as? Bool else {return}
            
            // Sets transaction status
            let type = isPending ? PKPaymentSummaryItemType.pending : PKPaymentSummaryItemType.final;
            
            // Add the total price
            totalPrice += price
            
            // Add item to chargeable
            items.append(PKPaymentSummaryItem(label: label, amount: NSDecimalNumber(floatLiteral: price), type: type))
            
            Stripe.setDefaultPublishableKey(stripePublishedKey)
            
            // Sets the item total
            let total = PKPaymentSummaryItem(
                label: merchantName,
                amount: NSDecimalNumber(floatLiteral:totalPrice),
                type: type)
            
            items.append(total)
            
            
            // Set's the payment networks for payment [e.g masterCard, amex, discover e.t.c]
            paymentNeworks.forEach {
                if let paymentType = PaymentSystem(rawValue: $0) {
                    payments.append(paymentType.paymentNetwork)
                }
            }
            
            // Set's merchants capabilities for the transactions [e.g 3DS, credit, debit]
            paymentCapabilities.forEach {
                if let paymentCap = PaymentCapability(rawValue: $0) {
                    capabilities.append(paymentCap.PaymentCapability)
                }
            }
            
            // If no payment configuration was found, Halt process
            if (payments.isEmpty) {
                assertionFailure("No payment type defined!")
                return
            }
            
            
            // Check and set required shipping contact fields
            shippingContactCollection?.forEach {
                if let field = ContactBillingField(rawValue: $0) {
                    shippingContactFields.insert(field.ContactBillingField.rawValue)
                }
            }
            
            
            // Check and set required billing contact fields
            billingContactCollection?.forEach {
                if let field = ContactBillingField(rawValue: $0) {
                    billingContactFields.insert(field.ContactBillingField.rawValue)
                }
            }
            
            
            // Assign [paymentNetworks]
            parameters["paymentNetworks"] = payments
            parameters["requiredShippingContactFields"] = shippingContactFields as Set
            parameters["requiredBillingContactFields"] = billingContactFields as Set
            
            parameters["merchantCapabilities"] = capabilities // optional
            parameters["merchantIdentifier"] = merchantIdentifier
            parameters["countryCode"] = countryCode
            parameters["currencyCode"] = currencyCode
            parameters["paymentSummaryItems"] = items
            
            makePaymentRequest(parameters: parameters,  authCompletion: authorizationCompletion, authControllerCompletion: authorizationViewControllerDidFinish)
            
        } else if call.method == "can_make_apple_payments" {
            // check if payment is available on device
            let isAvailable = NSMutableDictionary()
            isAvailable["isAvailable"] = checkCanMakeApplePayments();
            return result(isAvailable)
            
        } else if call.method == "closeApplePaySheetWithSuccess" {
            // Success callback when payment is successful
            closeApplePaySheetWithSuccess()
            
        } else if call.method == "set_apple_configurations" {
            // Sets configurations of values parsed from decodes json apple pay file
            let arguments = call.arguments as! NSDictionary
            setAppleConfigurations(parameters: arguments)
            
        } else if call.method == "closeApplePaySheetWithError" {
            // Error callback when payment fails
            closeApplePaySheetWithError()
        } else {
            // Incoming method was never defined, so return error : basically it's developer's error
            let nullError = NSMutableDictionary()
            nullError["error"] = "Flutter method not implemented on iOS"
            nullError["status"] = "DEVELOPER_ERROR"
            nullError["description"] = "Error"
            result(nullError)
        }
    }
    
    
    func authorizationCompletion(_ payment: NSDictionary) {
        //success
        flutterResult(payment)
    }
    
    func authorizationViewControllerDidFinish(_ error : NSDictionary) {
        //error
        flutterResult(error)
    }
    
    
    enum ContactBillingField :  String {
        case emailAddress
        case name
        case phoneNumber
        case postalAddress
        
        var ContactBillingField : PKContactField {
            
            switch self {
            case .emailAddress: return PKContactField.emailAddress
            case .name: return PKContactField.name
            case .phoneNumber: return PKContactField.phoneNumber
            case .postalAddress: return PKContactField.postalAddress
            }
        }
    }
    
    
    enum PaymentCapability : String {
        case threeDS
        case debit
        case credit
        
        var PaymentCapability : PKMerchantCapability {
            switch self {
            case .threeDS: return PKMerchantCapability.capability3DS
            case .credit: return PKMerchantCapability.capabilityCredit
            case .debit: return PKMerchantCapability.capabilityDebit
            }
        }
    }
    
    
    enum PaymentSystem: String {
        case visa
        case masterCard
        case amex
        case quicPay
        case chinaUnionPay
        case discover
        case interac
        case privateLabel
        
        var paymentNetwork: PKPaymentNetwork {
            
            switch self {
            case .masterCard: return PKPaymentNetwork.masterCard
            case .visa: return PKPaymentNetwork.visa
            case .amex: return PKPaymentNetwork.amex
            case .quicPay: return PKPaymentNetwork.quicPay
            case .chinaUnionPay: return PKPaymentNetwork.chinaUnionPay
            case .discover: return PKPaymentNetwork.discover
            case .interac: return PKPaymentNetwork.interac
            case .privateLabel: return PKPaymentNetwork.privateLabel
            }
        }
    }
    
    
    func makePaymentRequest(parameters: NSDictionary, authCompletion: @escaping AuthorizationCompletion, authControllerCompletion: @escaping AuthorizationViewControllerDidFinish) {
        guard let paymentNetworks               = parameters["paymentNetworks"]                 as? [PKPaymentNetwork] else {return}
        guard let requiredShippingContactFields = parameters["requiredShippingContactFields"]   as? Set<PKContactField> else {return}
        let merchantCapabilities : PKMerchantCapability = parameters["merchantCapabilities"]    as? PKMerchantCapability ?? .capability3DS
        
        guard let merchantIdentifier            = parameters["merchantIdentifier"]              as? String else {return}
        guard let countryCode                   = parameters["countryCode"]                     as? String else {return}
        guard let currencyCode                  = parameters["currencyCode"]                    as? String else {return}
        
        guard let paymentSummaryItems           = parameters["paymentSummaryItems"]             as? [PKPaymentSummaryItem] else {return}
        
        authorizationCompletion = authCompletion
        authorizationViewControllerDidFinish = authControllerCompletion
        
        // Cards that should be accepted
        if PKPaymentAuthorizationViewController.canMakePayments(usingNetworks: paymentNetworks) {
            
            pkrequest.merchantIdentifier = merchantIdentifier
            pkrequest.countryCode = countryCode
            pkrequest.currencyCode = currencyCode
            pkrequest.supportedNetworks = paymentNetworks
            pkrequest.requiredShippingContactFields = requiredShippingContactFields
            // This is based on using Stripe
            pkrequest.merchantCapabilities = merchantCapabilities
            
            pkrequest.paymentSummaryItems = paymentSummaryItems
            
            let authorizationViewController = PKPaymentAuthorizationViewController(paymentRequest: pkrequest)
            
            if let viewController = authorizationViewController {
                viewController.delegate = self
                guard let currentViewController = UIApplication.shared.keyWindow?.topMostViewController() else {
                    return
                }
                currentViewController.present(viewController, animated: true)
            }
        } else {
            let nullError = NSMutableDictionary()
            nullError["error"] = "No card added yet"
            nullError["status"] = "ERROR"
            nullError["description"] = "Error"
            
            authControllerCompletion(nullError)
        }
        
        return
    }
    
    
    // it's up to you to produce here the error response object with error messages and pointing
    func responsePrepared(with error: Error?) -> PKPaymentAuthorizationResult{
        
        // Define general error
        var errorBag : NSError = NSError.init(
            domain: PKPaymentErrorDomain,
            code: PKPaymentError.unknownError.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "An unknown error occurred",
                PKPaymentErrorKey.contactFieldUserInfoKey.rawValue: PKContactField.phoneNumber
            ])
        
        // Change error definition
        errorDefinition["error"] = "An unknown error occurred"
        errorDefinition["status"] = "ERROR"
        errorDefinition["description"] = "An unknown error occurred"
        
        
        // It's API key error
        if (error?.errorCode == 50) {
            
            errorBag = NSError.init(
                domain: PKPaymentErrorDomain,
                code: 50,
                userInfo: [
                    NSLocalizedDescriptionKey: error?.localizedDescription as Any,
                ])
            
            // Change error definition
            errorDefinition["error"] = error?.localizedDescription ?? "Invalid API Key"
            errorDefinition["status"] = "ERROR"
            errorDefinition["description"] = error?.localizedDescription ?? "Invalid API Key"
        }
        
        // It's Network Timeout error
        if (error?.errorCode == -1001) {
            
            errorBag = NSError.init(
                domain: PKPaymentErrorDomain,
                code: -1001,
                userInfo: [
                    NSLocalizedDescriptionKey: error?.localizedDescription as Any,
                ])
            
            // Change error definition
            errorDefinition["error"] = error?.localizedDescription ?? "Network Error"
            errorDefinition["status"] = "ERROR"
            errorDefinition["description"] = error?.localizedDescription ?? "Network Error"
        }

        return PKPaymentAuthorizationResult(status: .failure, errors: [errorBag])
    }
    
    
    public func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        
        STPAPIClient.shared().createToken(with: payment) { (stripeToken, error) in
            guard error == nil,
                  let stripeToken = stripeToken else {
                      // There was a failure, so prepare the error
                      completion(self.responsePrepared(with: error))
                      return
                  }
            
            
            // Everything was successful
            
            let tokenHolder: NSDictionary = [
                "token" : stripeToken.tokenId
            ]
            
            let successResponse: NSDictionary = [
                "status" : "SUCCESS",
                "description" : "Token obtained successfully",
                "result" : tokenHolder
            ]
            
            self.authorizationCompletion(successResponse)
            self.completionHandler = completion
            // Gently close sheet with success
            self.closeApplePaySheetWithSuccess()
        }
        
    }
    
    
    // Check if user can make payments
    public func checkCanMakeApplePayments() -> Bool {
        return PKPaymentAuthorizationViewController.canMakePayments()
    }
    
    
    // Set basic parameters from parsed json profile file
    public func setAppleConfigurations(parameters : NSDictionary) {
        currencyCode = parameters["currencyCode"] as? String
        countryCode = parameters["countryCode"] as? String
        merchantIdentifier = parameters["merchantIdentifier"] as? String
        merchantName = parameters["displayName"] as? String
        merchantCapabilities = parameters["merchantCapabilities"] as? [String]
        supportedNetworks = parameters["supportedNetworks"] as? [String]
        gateway = parameters["gateway"] as? String
        requiredShippingContactFields = parameters["requiredShippingContactFields"] as? [String]
        requiredBillingContactFields = parameters["requiredBillingContactFields"] as? [String]
        
        if gateway != nil {
            if gateway == "stripe" {
                stripePublishableKey = parameters["stripe:publishableKey"] as? String
                stripeVersion = parameters["stripe:version"] as? String
            }
        }
    }
    
    
    public func closeApplePaySheetWithSuccess() {
        if (self.completionHandler != nil) {
            self.completionHandler(PKPaymentAuthorizationResult(status: .success, errors: nil))
        }
    }
    
    public func closeApplePaySheetWithError() {
        if (self.completionHandler != nil) {
            self.completionHandler(PKPaymentAuthorizationResult(status: .failure, errors: nil))
        }
    }
    
    
    public func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        
        // Dismiss the Apple Pay UI
        guard let currentViewController = UIApplication.shared.keyWindow?.topMostViewController() else {
            return
        }
        
        
        currentViewController.dismiss(animated: true, completion: nil)
        
        let error : NSDictionary = [
            "error" : errorDefinition["error"] as Any,
            "status": errorDefinition["status"] as Any,
            "description" : errorDefinition["description"] as Any
        ]
        
        authorizationViewControllerDidFinish(error as NSDictionary)
    }
    
    func makePaymentSummaryItems(itemsParameters: Array<Dictionary <String, Any>>) -> [PKPaymentSummaryItem]? {
        var items = [PKPaymentSummaryItem]()
        var totalPrice:Decimal = 0.0
        
        for dictionary in itemsParameters {
            
            guard let label = dictionary["label"] as? String else {return nil}
            guard let amount = dictionary["amount"] as? NSDecimalNumber else {return nil}
            guard let type = dictionary["type"] as? PKPaymentSummaryItemType else {return nil}
            
            totalPrice += amount.decimalValue
            
            items.append(PKPaymentSummaryItem(label: label, amount: amount, type: type))
        }
        
        let total = PKPaymentSummaryItem(label: "Total", amount: NSDecimalNumber(decimal:totalPrice), type: .final)
        items.append(total)
        
        return items
    }
}

// View controllers
extension UIWindow {
    func topMostViewController() -> UIViewController? {
        guard let rootViewController = self.rootViewController else {
            return nil
        }
        return topViewController(for: rootViewController)
    }
    
    func topViewController(for rootViewController: UIViewController?) -> UIViewController? {
        guard let rootViewController = rootViewController else {
            return nil
        }
        guard let presentedViewController = rootViewController.presentedViewController else {
            return rootViewController
        }
        switch presentedViewController {
        case is UINavigationController:
            let navigationController = presentedViewController as! UINavigationController
            return topViewController(for: navigationController.viewControllers.last)
        case is UITabBarController:
            let tabBarController = presentedViewController as! UITabBarController
            return topViewController(for: tabBarController.selectedViewController)
        default:
            return topViewController(for: presentedViewController)
        }
    }
}

extension Error {
    var errorCode:Int? {
        return (self as NSError).code
    }
}
