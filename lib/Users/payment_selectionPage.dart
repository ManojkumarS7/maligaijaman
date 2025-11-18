import 'package:flutter/material.dart';
import 'package:maligaijaman/Users/orderSuccess_page.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:easy_upi_payment/easy_upi_payment.dart';
import 'cardPayment_page.dart';
import 'package:maligaijaman/apiconstants.dart';
import 'package:maligaijaman/appcolors.dart';

class PaymentOptionsPage extends StatefulWidget {
  final Map<String, dynamic> selectedAddress;
  final List<dynamic> productDetails;
  final double totalAmount;
  final bool isFromCart;

  PaymentOptionsPage({
    Key? key,
    required this.selectedAddress,
    required this.productDetails,
    required this.totalAmount,
    required this.isFromCart,
  }) : super(key: key);

  @override
  _PaymentOptionsPageState createState() => _PaymentOptionsPageState();
}

class _PaymentOptionsPageState extends State<PaymentOptionsPage> {
  final _storage = const FlutterSecureStorage();
  late Razorpay _razorpay;
  String? _jwt;
  String? _secretKey;
  String? _userid;
  String? _vendorId;
  String? _address;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    _jwt = await _storage.read(key: 'jwt');
    _secretKey = await _storage.read(key: 'key');
    _userid = await _storage.read(key: 'user_id');
    _vendorId = await _storage.read(key: 'vendor_id');
    _address = await _storage.read(key: 'address');
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print("Payment Success");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Successful: ${response.paymentId}")),
    );

    // Submit order confirmation after successful payment
    await _confirmOrder();

    // Only clear cart if needed
    await _conditionalClearCart();

    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => OrderSuccessPage()),
            (route) => false
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print("Payment Error");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed: ${response.message}")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print("External Wallet");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("External Wallet Selected: ${response.walletName}")),
    );
  }

  Future<void> _conditionalClearCart() async {
    // Only clear cart if coming from cart page
    if (widget.isFromCart) {
      // Implement clear cart functionality if needed
      print("Cart cleared - came from cart page");
    } else {
      print("No need to clear cart - direct purchase");
    }
  }

  Future<void> _confirmOrder() async {
    if (_jwt == null || _secretKey == null) {
      print("Missing JWT or secret key");
      return;
    }

    if (widget.productDetails.isEmpty) {
      print("No products to confirm");
      return;
    }

    try {
      if (widget.isFromCart) {
        // If from cart, use the cart confirmation endpoint
        final url = Uri.parse(
            "${Appconfig.baseurl}api/addcart_confirm.php");

        var request = http.MultipartRequest('POST', url);

        request.fields['user_id'] = _userid ?? '';
        request.fields['addrerss'] = _address ?? '';

        print("Submitting cart order with userid: $_userid");

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          print("Cart order successfully confirmed");
          print("Response body: ${response.body}");
        } else {
          print("Failed to confirm cart order: ${response.statusCode}");
          print("Response body: ${response.body}");
          throw Exception("Cart order confirmation failed with status ${response.statusCode}");
        }
      } else {
        // Direct product purchase - use the original endpoint
        final url = Uri.parse(
            "${Appconfig.baseurl}api/conformorderinsert.php");

        // Direct product purchase - post each product individually
        for (var product in widget.productDetails) {
          var request = http.MultipartRequest('POST', url);

          // Add all required fields
          request.fields['jwt'] = _jwt!;
          request.fields['secretkey'] = _secretKey!;
          request.fields['user_id'] = _userid ?? '';
          request.fields['productid'] = product['id'].toString();
          request.fields['productname'] = product['Product_name'];
          request.fields['productprice'] = product['product_price'].toString();
          request.fields['price'] = product['product_price'].toString();
          request.fields['quantity'] = product['Product_qty'].toString();
          request.fields['qty'] = product['Product_qty'].toString();
          request.fields['vendor_id'] =
              product['vendor_id']?.toString() ?? _vendorId ?? '';
          request.fields['is_from_cart'] = '0';
          request.fields['address'] = _address ?? '';

          print("Submitting direct product order data: ${request.fields}");

          var streamedResponse = await request.send();
          var response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            print("Direct order successfully confirmed for ${product['Product_name']}");
            print("Response body: ${response.body}");
          } else {
            print("Failed to confirm direct order: ${response.statusCode}");
            print("Response body: ${response.body}");
            throw Exception("Direct order confirmation failed with status ${response.statusCode}");
          }
        }
      }
    } catch (e) {
      print("Error confirming order: $e");
    }
  }

  void _openCheckout() {
    // Prepare Razorpay options based on fetched products
    var options = {
      'key': 'rzp_live_8QVaxzxdOrEnkw',
      'amount': (widget.totalAmount * 100).toInt(), // Convert to paise
      'name': 'Maligaijamaan',
      'description': widget.productDetails.length == 1
          ? 'Purchase of ${widget.productDetails[0]['Product_name']}'
          : 'Multiple Product Purchase',
      'prefill': {
        'contact': '9876543210',
        'email': 'customer@example.com'
      },
      'theme': {
        'color': '#F37254'
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _startUpiPayment() async {
    try {
      String productDescription = widget.productDetails.length == 1
          ? 'Purchase of ${widget.productDetails[0]['Product_name']}'
          : 'Multiple Product Purchase';

      // Start UPI payment
      final res = await EasyUpiPaymentPlatform.instance.startPayment(
        EasyUpiPaymentModel(
          payeeVpa: 'dhonimanojvijay@okicici',
          payeeName: 'Maligaijamaan',
          amount: widget.totalAmount,
          description: productDescription,
        ),
      );

      print("UPI Payment Result: $res");

      // Check if payment was successful
      if (res == "Success") {
        print("UPI Payment Success");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("UPI Payment Successful!")),
        );

        // Submit order confirmation after successful payment
        await _confirmOrder();

        // Only clear cart if needed
        await _conditionalClearCart();

        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => OrderSuccessPage()),
                (route) => false
        );
      } else {
        print("UPI Payment Failed or Cancelled");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("UPI Payment Failed: ${res}")),
        );
      }
    } on EasyUpiPaymentException catch (e) {
      print("UPI Payment Error: ${e.message}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("UPI Payment Error: ${e.message}")),
      );
    } catch (e) {
      print("Generic UPI Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("UPI Payment Error: $e")),
      );
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("Payment Options",style: TextStyle(color: Colors.white),),
        backgroundColor: Appcolor.Appbarcolor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose Payment Method',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Amount to Pay: \₹${widget.totalAmount.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 30),

            // Cash on Delivery Option
            Card(
              elevation: 3,
              margin: EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () async {
                  // First confirm the order
                  await _confirmOrder();
                  await _conditionalClearCart();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Order Placed with Cash on Delivery")),
                  );
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => OrderSuccessPage()),
                          (route) => false
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.money, size: 32, color: Color(0xFF00677E)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cash on Delivery',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text('Pay when your order arrives'),
                          ],
                        ),
                      ),
                      // Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                ),
              ),
            ),

            // UPI Payment Option
            Card(
              elevation: 3,
              margin: EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: _startUpiPayment,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance, size: 32, color: Color(0xFF1976D2)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pay with UPI',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text('Google Pay, PhonePe, BHIM UPI'),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                ),
              ),
            ),
//Pay Razorpay
            Card(
              elevation: 3,
              margin: EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: _openCheckout,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.payments_outlined, size: 32, color: Color(0xFF00677E)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pay with Razorpay',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text('Multiple Payment Method'),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                ),
              ),
            ),
            // Card Payment Option
            Card(
              elevation: 3,
              margin: EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CardPaymentScreen(
                        selectedAddress: widget.selectedAddress,
                        productDetails: widget.productDetails,
                        totalAmount: widget.totalAmount,
                        isFromCart: widget.isFromCart,
                      ),
                    ),
                  );
                },                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.credit_card, size: 32, color: Color(0xFF00677E)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pay with Card',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text('Credit/Debit Card'),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
