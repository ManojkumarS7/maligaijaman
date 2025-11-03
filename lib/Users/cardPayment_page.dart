import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:maligaijaman/Users/orderSuccess_page.dart';
import 'package:maligaijaman/apiconstants.dart';

class CardPaymentScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedAddress;
  final List<dynamic>? productDetails;
  final double? totalAmount;
  final bool? isFromCart;

  const CardPaymentScreen({
    Key? key,
    this.selectedAddress,
    this.productDetails,
    this.totalAmount,
    this.isFromCart,
  }) : super(key: key);

  @override
  _CardPaymentScreenState createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();

  // Controllers
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  // State variables
  bool _isProcessing = false;
  String _cardType = 'unknown';
  String? _jwt;
  String? _secretKey;
  String? _userid;
  String? _vendorId;
  String? _address;

  @override
  void initState() {
    super.initState();
    _loadAuthData();
    _cardNumberController.addListener(_detectCardType);
  }

  Future<void> _loadAuthData() async {
    _jwt = await _storage.read(key: 'jwt');
    _secretKey = await _storage.read(key: 'key');
    _userid = await _storage.read(key: 'user_id');
    _vendorId = await _storage.read(key: 'vendor_id');
    _address = await _storage.read(key: 'address');
  }

  void _detectCardType() {
    String cardNumber = _cardNumberController.text.replaceAll(' ', '');
    setState(() {
      if (cardNumber.startsWith('4')) {
        _cardType = 'visa';
      } else if (cardNumber.startsWith(RegExp(r'5[1-5]'))) {
        _cardType = 'mastercard';
      } else if (cardNumber.startsWith(RegExp(r'3[47]'))) {
        _cardType = 'amex';
      } else if (cardNumber.startsWith('6')) {
        _cardType = 'rupay';
      } else {
        _cardType = 'unknown';
      }
    });
  }

  String? _validateCardNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Card number is required';
    }
    String cardNumber = value.replaceAll(' ', '');
    if (cardNumber.length < 13 || cardNumber.length > 19) {
      return 'Invalid card number';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(cardNumber)) {
      return 'Card number must contain only digits';
    }
    return null;
  }

  String? _validateCardHolder(String? value) {
    if (value == null || value.isEmpty) {
      return 'Cardholder name is required';
    }
    if (value.length < 3) {
      return 'Name is too short';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    if (value == null || value.isEmpty) {
      return 'Expiry date is required';
    }
    if (!RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$').hasMatch(value)) {
      return 'Invalid format (MM/YY)';
    }

    List<String> parts = value.split('/');
    int month = int.parse(parts[0]);
    int year = int.parse('20${parts[1]}');

    DateTime now = DateTime.now();
    DateTime cardDate = DateTime(year, month);

    if (cardDate.isBefore(DateTime(now.year, now.month))) {
      return 'Card has expired';
    }

    return null;
  }

  String? _validateCVV(String? value) {
    if (value == null || value.isEmpty) {
      return 'CVV is required';
    }
    if (value.length < 3 || value.length > 4) {
      return 'Invalid CVV';
    }
    return null;
  }

  Future<void> _conditionalClearCart() async {
    if (widget.isFromCart == true) {
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

    if (widget.productDetails == null || widget.productDetails!.isEmpty) {
      print("No products to confirm");
      return;
    }

    try {
      if (widget.isFromCart == true) {
        final url = Uri.parse(
            "${Appconfig.baseurl}api/addcart_confirm.php");

        var request = http.MultipartRequest('POST', url);
        request.fields['user_id'] = _userid ?? '';
        request.fields['addrerss'] = _address ?? '';

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          print("Cart order successfully confirmed");
        } else {
          throw Exception("Cart order confirmation failed");
        }
      } else {
        final url = Uri.parse(
            "${Appconfig.baseurl}api/conformorderinsert.php");

        for (var product in widget.productDetails!) {
          var request = http.MultipartRequest('POST', url);
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

          var streamedResponse = await request.send();
          var response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode != 200) {
            throw Exception("Direct order confirmation failed");
          }
        }
      }
    } catch (e) {
      print("Error confirming order: $e");
      rethrow;
    }
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Simulate payment processing
      await Future.delayed(Duration(seconds: 2));

      // Confirm order
      await _confirmOrder();
      await _conditionalClearCart();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Successful!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => OrderSuccessPage()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Widget _buildCardTypeIcon() {
    IconData icon;
    Color color;

    switch (_cardType) {
      case 'visa':
        icon = Icons.credit_card;
        color = Color(0xFF1A1F71);
        break;
      case 'mastercard':
        icon = Icons.credit_card;
        color = Color(0xFFEB001B);
        break;
      case 'amex':
        icon = Icons.credit_card;
        color = Color(0xFF006FCF);
        break;
      case 'rupay':
        icon = Icons.credit_card;
        color = Color(0xFF097939);
        break;
      default:
        icon = Icons.credit_card;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 32);
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Card Payment'),
        backgroundColor: Color(0xFF2E7D32),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Amount Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Amount to Pay',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '₹${widget.totalAmount?.toStringAsFixed(2) ?? "0.00"}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Payment Form
            Padding(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Number
                    Text(
                      'Card Number',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _cardNumberController,
                      keyboardType: TextInputType.number,
                      maxLength: 19,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _CardNumberFormatter(),
                      ],
                      decoration: InputDecoration(
                        hintText: '1234 5678 9012 3456',
                        prefixIcon: Padding(
                          padding: EdgeInsets.all(12),
                          child: _buildCardTypeIcon(),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF2E7D32), width: 2),
                        ),
                        counterText: '',
                      ),
                      validator: _validateCardNumber,
                    ),
                    SizedBox(height: 20),

                    // Card Holder Name
                    Text(
                      'Cardholder Name',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _cardHolderController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'JOHN DOE',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF2E7D32), width: 2),
                        ),
                      ),
                      validator: _validateCardHolder,
                    ),
                    SizedBox(height: 20),

                    // Expiry and CVV Row
                    Row(
                      children: [
                        // Expiry Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expiry Date',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: _expiryController,
                                keyboardType: TextInputType.number,
                                maxLength: 5,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  _ExpiryDateFormatter(),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'MM/YY',
                                  prefixIcon: Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Color(0xFF2E7D32), width: 2),
                                  ),
                                  counterText: '',
                                ),
                                validator: _validateExpiry,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),

                        // CVV
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CVV',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: _cvvController,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                obscureText: true,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  hintText: '123',
                                  prefixIcon: Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Color(0xFF2E7D32), width: 2),
                                  ),
                                  counterText: '',
                                ),
                                validator: _validateCVV,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Security Info
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.security, color: Colors.blue[700], size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your card details are encrypted and secure',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),

                    // Pay Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _processPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2E7D32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isProcessing
                            ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : Text(
                          'Pay ₹${widget.totalAmount?.toStringAsFixed(2) ?? "0.00"}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Card Number Formatter
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    String text = newValue.text.replaceAll(' ', '');
    String formatted = '';

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += ' ';
      }
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// Expiry Date Formatter
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    String text = newValue.text.replaceAll('/', '');
    String formatted = '';

    for (int i = 0; i < text.length && i < 4; i++) {
      if (i == 2) {
        formatted += '/';
      }
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}