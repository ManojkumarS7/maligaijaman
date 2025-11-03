
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'adress_Viewpage.dart';
import 'productdetail_page.dart';
import '../main.dart';
import 'wishlist_screen.dart';
import 'profile_page.dart';
import 'home_page.dart';
import 'package:maligaijaman/apiconstants.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Map<String, int> _quantities = {};
  final Map<String, double> _prices = {};
  final _storage = const FlutterSecureStorage();
  List<dynamic>? currentCartItems;
  String? _jwt;
  String? _secretKey;
  bool _isLoading = false;
  bool _isUpdatingQuantity = false;
  bool _isLoggedIn = false;
  final int buttonId = 02;
  int _selectedIndex = 0;


  @override
  void initState() {
    super.initState();
    checkLoginStatus();
    fetchCartItemsAndUpdateUI();
  }

  Future<void> checkLoginStatus() async {
    _jwt = await _storage.read(key: 'jwt');
    _secretKey = await _storage.read(key: 'key');
    setState(() {
      _isLoggedIn = _jwt != null && _secretKey != null;
      _isLoading = false;
    });
  }

  /// **Store Button ID in Secure Storage**
  Future<void> _storeButtonId() async {
    await _storage.write(key: "button_id", value: buttonId.toString());
    print("Cart Button ID stored: $buttonId"); // Debugging purpose
  }

  Future<void> fetchCartItemsAndUpdateUI() async {
    try {
      final items = await fetchCartItems();
      setState(() {
        currentCartItems = items;
      });
    } catch (e) {
      print("Error fetching cart items: $e");
    }
  }

  Future<List<dynamic>> fetchCartItems() async {
    _jwt = await _storage.read(key: 'jwt');
    _secretKey = await _storage.read(key: 'key');
    if (_jwt == null || _secretKey == null) {
      throw Exception('Authentication tokens not found');
    }

    final url = Uri.parse(
        "${Appconfig.baseurl}api/cart.php?jwt=$_jwt&secretkey=$_secretKey");
    print(url);

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> cartItems = json.decode(responseBody);

        for (var item in cartItems) {
          final productId = item['id'];
          final quantity = int.tryParse(
              item['Product_qty']?.toString() ?? '1') ?? 1;
          final basePrice = double.tryParse(
              item['product_price']?.toString() ?? '0.0') ?? 0.0;

          _quantities[productId] = quantity;
          _prices[productId] = basePrice * quantity;
        }

        return cartItems;
      } else {
        throw Exception("Failed to load cart items: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching cart items: $e");
      throw Exception("Failed to fetch cart items: $e");
    }
  }

  Future<void> removeFromCart(String productId) async {
    setState(() => _isLoading = true);

    try {
      // Remove the item from the local state immediately
      setState(() {
        currentCartItems?.removeWhere((item) => item['id'] == productId);
        _quantities.remove(productId);
        _prices.remove(productId);
      });

      // Make the API call to remove the item from the server
      final url = Uri.parse(
          '${Appconfig.baseurl}api/deletecart.php');
      final Map<String, dynamic> requestBody = {
        'id': productId,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product removed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // If the API call fails, revert the local state
          setState(() {
            fetchCartItemsAndUpdateUI(); // Re-fetch the cart items
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  responseData['message'] ?? 'Failed to remove from cart'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // If the API call fails, revert the local state
        setState(() {
          fetchCartItemsAndUpdateUI(); // Re-fetch the cart items
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // If an error occurs, revert the local state
      setState(() {
        fetchCartItemsAndUpdateUI(); // Re-fetch the cart items
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing from cart: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> updateCartQuantity(String productId, int quantity) async {
    if (_jwt == null || _secretKey == null) {
      await checkLoginStatus();
      if (_jwt == null || _secretKey == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to update cart'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Don't allow quantity less than 1
    if (quantity < 1) {
      return;
    }

    setState(() => _isUpdatingQuantity = true);

    try {
      // Find the product in cart items
      final product = currentCartItems?.firstWhere(
            (item) => item['id'] == productId,
        orElse: () => null,
      );

      if (product == null) {
        throw Exception('Product not found in cart');
      }

      // Get the base price of the product
      final basePrice = double.tryParse(
          product['product_price']?.toString() ?? '0.0') ?? 0.0;

      // Calculate total price based on quantity
      final totalPrice = basePrice * quantity;

      // Update quantity in local state
      setState(() {
        _quantities[productId] = quantity;
        _prices[productId] = totalPrice;
      });

      // Prepare API call to update quantity on server
      final url = Uri.parse(
          '${Appconfig.baseurl}api/update_cart.php');
      final Map<String, dynamic> requestBody = {
        'secretkey': _secretKey,
        'jwt': _jwt,
        'id': productId,
        'qty': quantity.toString(),
        'price': basePrice.toString() // Send the base price, not total price
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quantity updated!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        } else {
          // Revert local state change if API call fails
          await fetchCartItemsAndUpdateUI();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  responseData['message'] ?? 'Failed to update quantity'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Revert local state change if API call fails
        await fetchCartItemsAndUpdateUI();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Revert local state change if exception occurs
      await fetchCartItemsAndUpdateUI();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating quantity: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUpdatingQuantity = false);
    }
  }


  void _increaseQuantity(String productId) {
    final currentQty = _quantities[productId] ?? 1;
    updateCartQuantity(productId, currentQty + 1);
  }

  void _decreaseQuantity(String productId) {
    final currentQty = _quantities[productId] ?? 1;
    if (currentQty > 1) {
      updateCartQuantity(productId, currentQty - 1);
    }
  }

  void _updatePrice(String productId) {
    final basePrice = _prices[productId]! / (_quantities[productId] ?? 1);
    _prices[productId] = basePrice * (_quantities[productId] ?? 1);
  }

  void _proceedToCheckout(List<dynamic> cartItems) async {
    await _storeButtonId();
    // Create a list to store all products
    List<Map<String, String>> productsData = [];

    // Loop through cart items and create product data for each
    for (var item in cartItems) {
      final productId = item['id'];
      final currentPrice = _prices[productId] ??
          (double.tryParse(item['product_price']?.toString() ?? '0.0') ?? 0.0);

      Map<String, String> productData = {
        'id': productId,
        'name': item['Product_name'] ?? '',
        'price': currentPrice.toString(),
        'image_url': item['img_path'] ?? '',
        'quantity': (_quantities[productId] ?? 1).toString(),
      };

      productsData.add(productData);

      // Print debug information
      print('Product stored:');
      print("ID: ${productData['id']}");
      print("Name: ${productData['name']}");
      print(
          "Price: \$${double.parse(productData['price']!).toStringAsFixed(2)}");
      print("Image URL: ${productData['image_url']}");
      print("Quantity: ${productData['quantity']}");
      print("------------------------");
    }

    // Store the entire products list
    final storage = const FlutterSecureStorage();
    await storage.write(
      key: 'checkout_products',
      value: json.encode(productsData),
    );

    // Store total amount
    final totalAmount = calculateTotal();
    await storage.write(
      key: 'checkout_total',
      value: totalAmount.toString(),
    );

    // Navigate to checkout screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressViewScreen(),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // Do nothing if same tab

    setState(() {
      _selectedIndex = index;
    });

    // Handle navigation based on the selected tab
    switch (index) {
      case 0:
      // Return to Home
        Navigator.pop(context);
        break;
      case 1:
      // Navigate to Cart
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CartScreen()),
        );
        break;
      case 2:
      // Navigate to Wishlist
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => WishlistScreen()),
        );
        break;
      case 3:
      // Navigate to Profile
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfileScreen()),
        );
        break;
    }
  }


  Widget _buildQuantityControl(String productId, String quantityType,
      double basePrice) {
    return Row(
      children: [
        _buildQuantityButton(
          icon: Icons.remove,
          onTap: _isUpdatingQuantity
              ? null
              : () => _decreaseQuantity(productId),
        ),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: _isUpdatingQuantity
              ? SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFFFC107),
            ),
          )
              : Text(
            '${_quantities[productId] ?? 1}',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold
            ),
          ),
        ),
        _buildQuantityButton(
          icon: Icons.add,
          onTap: _isUpdatingQuantity
              ? null
              : () => _increaseQuantity(productId),
        ),
        const SizedBox(width: 8),
        Text(quantityType, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildQuantityButton(
      {required IconData icon, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? Colors.grey : Colors.black,
        ),
      ),
    );
  }


  Widget _buildCartItem(Map<String, dynamic> item) {
    final productId = item['id'];
    final productName = item['Product_name'] ?? 'Unnamed Product';
    final imageUrl = item['img_path'] ?? '';
    final basePrice = double.tryParse(
        item['product_price']?.toString() ?? '0.0') ?? 0.0;
    final currentPrice = _prices[productId] ?? basePrice;
    final description = item['description'] ?? 'No description';
    final quantity = 1; // Replace if you have actual quantity data

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CheckoutScreen(
                  productId: productId,
                  productName: productName,
                  productPrice: currentPrice,
                  description: description,
                  imageUrl: imageUrl,
                  quantity: quantity,
                ),
          ),
        );
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported),
                          ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${currentPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFFFFC107),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildQuantityControl(
                          productId,
                          item['quantity_type'] ?? 'pcs',
                          basePrice,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(
                        Icons.delete_outline, color: Color(0xFF00677E)),
                    label: const Text(
                      'Remove',
                      style: TextStyle(color: Color(0xFF00677E)),
                    ),
                    onPressed: _isLoading ? null : () =>
                        removeFromCart(productId),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  double calculateTotal() {
    return _prices.values.fold(0, (sum, price) => sum + price);
  }

  Widget _buildEmptyCartMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 64,
              color: Color.fromRGBO(85, 139, 47, 1)),
          const SizedBox(height: 16),
          const Text(
            'No products',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MainScreen()),
                ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(27, 94, 32, 1),
              // dark green
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Continue Shopping',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutSection(List<dynamic> cartItems) {
    final total = calculateTotal();
    final itemCount = cartItems.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Items in cart',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  '$itemCount',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFC107), // gold highlight
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: total > 0
                    ? () => _proceedToCheckout(cartItems)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(27, 94, 32, 1),
                  // dark green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Proceed to Checkout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildLoginMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.login, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Please login to view cart',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100, // light background
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(85, 139, 47, 1), // primary green
        title: const Text(
          "Shopping Cart",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: !_isLoggedIn
          ? _buildLoginMessage()
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentCartItems == null || currentCartItems!.isEmpty
          ? _buildEmptyCartMessage()
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: currentCartItems!.length,
              itemBuilder: (context, index) {
                return _buildCartItem(currentCartItems![index]);
              },
            ),
          ),
          _buildCheckoutSection(currentCartItems!),
        ],
      ),
    );
  }
}