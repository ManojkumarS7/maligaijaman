
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'orderSuccess_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'payment_selectionPage.dart';
import 'package:maligaijaman/apiconstants.dart';

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> selectedAddress;

  PaymentPage({
    Key? key,
    required this.selectedAddress,
  }) : super(key: key);

  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _storage = const FlutterSecureStorage();
  final TextEditingController _couponController = TextEditingController();

  List<dynamic> _productDetails = [];
  double _totalAmount = 0.0;
  double _discount = 0.0;
  double _finalAmount = 0.0;
  String? _jwt;
  String? _secretKey;
  String? _userid;
  String? _vendorId;
  bool _isFromCart = false;
  bool _couponApplied = false;
  String _appliedCouponCode = '';

  // Available coupon codes with their discount percentages
  final Map<String, double> _availableCoupons = {
    'FLAT50': 20.0,
    'FIRSTORDER50': 50.0,
    'WELCOME15': 15.0,
    'FIRST25': 25.0,
    'SUPER50' : 15.0
  };

  @override
  void initState() {
    super.initState();

    final fullAddress =
        '${widget.selectedAddress['address_line1']}, ${widget.selectedAddress['address_line2']}, ${widget.selectedAddress['city']}, ${widget.selectedAddress['state']}, ${widget.selectedAddress['pincode']}';

    _storage.write(key: 'address', value: fullAddress);
    _fetchProductDetails();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _fetchProductDetails() async {
    try {
      final buttonId = await _storage.read(key: 'button_id');
      print('Fetched Button ID: $buttonId');

      _jwt = await _storage.read(key: 'jwt');
      _secretKey = await _storage.read(key: 'key');
      _userid = await _storage.read(key: 'user_id');

      if (buttonId == '1' || buttonId == '01') {
        _isFromCart = false;
        await _fetchSingleProductFromStorage();
      } else if (buttonId == '2' || buttonId == '02') {
        _isFromCart = true;
        await _fetchCartProductsFromAPI();
      } else {
        print('Unknown button ID: $buttonId');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to determine product fetch method')),
        );
      }
    } catch (e) {
      print("Error fetching product details: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading product details: $e")),
      );
    }
  }

  Future<void> _fetchSingleProductFromStorage() async {
    try {
      final productId = await _storage.read(key: 'product_id');
      final productName = await _storage.read(key: 'product_name');
      final productPrice = await _storage.read(key: 'product_price');
      final productQuantity = await _storage.read(key: 'product_quantity');
      final productImage = await _storage.read(key: 'product_image');
      _vendorId = await _storage.read(key: 'vendor_id');

      print('Fetched Product Details:');
      print('ID: $productId');
      print('Name: $productName');
      print('Price: $productPrice');
      print('Quantity: $productQuantity');
      print('Image: $productImage');
      print('Vendor ID: $_vendorId');

      if (productId != null && productName != null && productPrice != null) {
        setState(() {
          _productDetails = [
            {
              'id': productId,
              'Product_name': productName,
              'product_price': productPrice,
              'Product_qty': productQuantity ?? '1',
              'img_path': productImage,
              'vendor_id': _vendorId,
            }
          ];

          _totalAmount = double.parse(productPrice) *
              double.parse(productQuantity ?? '1');
          _finalAmount = _totalAmount;

          print('Total Amount: $_totalAmount');
          print('Product Details Set: $_productDetails');
        });
      } else {
        print('One or more product details are null');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load product details')),
        );
      }
    } catch (e) {
      print('Error in _fetchSingleProductFromStorage: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading product details: $e')),
      );
    }
  }

  Future<void> _fetchCartProductsFromAPI() async {
    if (_jwt == null || _secretKey == null) {
      throw Exception('Authentication tokens not found');
    }

    final url = Uri.parse(
        "${Appconfig.baseurl}api/cart.php?jwt=$_jwt&secretkey=$_secretKey");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> cartItems = json.decode(responseBody);

        if (cartItems.isNotEmpty && cartItems[0].containsKey('vendor_id')) {
          _vendorId = cartItems[0]['vendor_id']?.toString();
          print('Vendor ID from cart: $_vendorId');
        } else {
          _vendorId = await _storage.read(key: 'vendor_id');
          print('Vendor ID from storage: $_vendorId');
        }

        setState(() {
          _productDetails = cartItems;

          _totalAmount = cartItems.fold(0.0, (total, item) {
            final price = double.tryParse(
                item['product_price']?.toString() ?? '0.0') ??
                0.0;
            final quantity =
                int.tryParse(item['Product_qty']?.toString() ?? '1') ?? 1;
            return total + (price * quantity);
          });
          _finalAmount = _totalAmount;
        });
      } else {
        throw Exception("Failed to load cart items: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching cart items: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading cart items: $e")),
      );
    }
  }

  void _applyCoupon(String couponCode) {
    final code = couponCode.toUpperCase().trim();

    if (_availableCoupons.containsKey(code)) {
      final discountPercentage = _availableCoupons[code]!;
      setState(() {
        _discount = (_totalAmount * discountPercentage) / 100;
        _finalAmount = _totalAmount - _discount;
        _couponApplied = true;
        _appliedCouponCode = code;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coupon applied! You saved ₹${_discount.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid coupon code'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _removeCoupon() {
    setState(() {
      _discount = 0.0;
      _finalAmount = _totalAmount;
      _couponApplied = false;
      _appliedCouponCode = '';
      _couponController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coupon removed'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildAvailableCoupons() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Coupons',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
          SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _availableCoupons.entries.map((entry) {
                return GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: entry.key));
                    _couponController.text = entry.key;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Coupon code copied! Tap "Apply" to use it.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: 12),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.content_copy,
                              color: Colors.white,
                              size: 14,
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Save ${entry.value.toInt()}%',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer, color: Color(0xFF2E7D32)),
              SizedBox(width: 8),
              Text(
                'Apply Coupon Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (!_couponApplied) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    decoration: InputDecoration(
                      hintText: 'Enter coupon code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_couponController.text.isNotEmpty) {
                      _applyCoupon(_couponController.text);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Apply'),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coupon Applied: $_appliedCouponCode',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                        Text(
                          'You saved ₹${_discount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red),
                    onPressed: _removeCoupon,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return Expanded(
      child: ListView.builder(
        itemCount: _productDetails.length,
        itemBuilder: (context, index) {
          final product = _productDetails[index];
          final itemTotal = (double.parse(product['product_price'] ?? '0') *
              int.parse(product['Product_qty'] ?? '1'));

          return Container(
            margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: EdgeInsets.all(12),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product['img_path'] != null
                    ? Image.network(
                  product['img_path'],
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 70,
                      height: 70,
                      color: Colors.grey[200],
                      child: Icon(Icons.image_not_supported,
                          color: Colors.grey),
                    );
                  },
                )
                    : Container(
                  width: 70,
                  height: 70,
                  color: Colors.grey[200],
                  child: Icon(Icons.shopping_bag, color: Colors.grey),
                ),
              ),
              title: Text(
                product['Product_name'] ?? 'Product Name',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Text(
                      '₹${product['product_price'] ?? 'N/A'}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(' × ${product['Product_qty'] ?? '1'}',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
              trailing: Text(
                '₹${itemTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceDetails() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal:', style: TextStyle(fontSize: 15)),
              Text('₹${_totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 15)),
            ],
          ),
          if (_couponApplied) ...[
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Discount:', style: TextStyle(fontSize: 15, color: Colors.green)),
                Text('- ₹${_discount.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 15, color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          Divider(height: 24, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '₹${_finalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          if (_couponApplied)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'You saved ₹${_discount.toStringAsFixed(2)}!',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Order Summary"),
        backgroundColor: Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Color(0xFF2E7D32), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Delivery Address',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '${widget.selectedAddress['address_line1']}, ${widget.selectedAddress['address_line2']}, ${widget.selectedAddress['city']}, ${widget.selectedAddress['state']}, ${widget.selectedAddress['pincode']}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(
              'Your Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildProductList(),
          _buildAvailableCoupons(),
          _buildCouponSection(),
          _buildPriceDetails(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentOptionsPage(
                      selectedAddress: widget.selectedAddress,
                      productDetails: _productDetails,
                      totalAmount: _finalAmount, // Pass final amount after discount
                      isFromCart: _isFromCart,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Proceed to Payment",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
