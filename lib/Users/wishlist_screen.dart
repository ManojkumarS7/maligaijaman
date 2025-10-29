import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'adress_Viewpage.dart';
import 'package:maligaijaman/main.dart';
import 'productdetail_page.dart';
import '../main.dart';
import 'cart_page.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'home_page.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({Key? key}) : super(key: key);

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _storage = const FlutterSecureStorage();
  List<dynamic>? currentCartItems;
  String? _jwt;
  String? _secretKey;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  final int buttonId = 02;

  int _selectedIndex = 0;

  // New Color scheme
  final Color primaryGreen = const Color.fromRGBO(85, 139, 47, 1); // header green
  final Color darkGreen = const Color.fromRGBO(27, 94, 32, 1); // button green
  final Color goldColor = const Color(0xFFFFC107); // price highlight
  final Color textColor = Colors.grey.shade800;

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

  Future<void> fetchCartItemsAndUpdateUI() async {
    try {
      final items = await fetchCartItems();
      setState(() {
        currentCartItems = items;
      });
    } catch (e) {
      print("Error fetching wishlist items: $e");
    }
  }

  Future<List<dynamic>> fetchCartItems() async {
    _jwt = await _storage.read(key: 'jwt');
    _secretKey = await _storage.read(key: 'key');
    if (_jwt == null || _secretKey == null) {
      throw Exception('Authentication tokens not found');
    }

    final url = Uri.parse(
        "https://maligaijaman.rdegi.com/api/wishlist.php?jwt=$_jwt&secretkey=$_secretKey");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> cartItems = json.decode(responseBody);
        return cartItems;
      } else {
        throw Exception("Failed to load wishlist items: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch wishlist items: $e");
    }
  }

  Future<void> removeFromWishlist(String productId) async {
    setState(() => _isLoading = true);
    try {
      setState(() {
        currentCartItems?.removeWhere((item) => item['id'] == productId);
      });

      _jwt = await _storage.read(key: 'jwt');
      _secretKey = await _storage.read(key: 'key');

      final url =
      Uri.parse('https://maligaijaman.rdegi.com/api/delete_wishlist.php');
      final Map<String, String> requestBody = {
        'id': productId,
        'jwt': _jwt!,
        'secretkey': _secretKey!,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product removed from wishlist!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          fetchCartItemsAndUpdateUI();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ??
                  'Failed to remove from wishlist'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        fetchCartItemsAndUpdateUI();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      fetchCartItemsAndUpdateUI();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildLoginMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 24),
          Text(
            'Please login to view wishlist',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: darkGreen,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              'Login',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCartMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 24),
          Text(
            'Your wishlist is empty',
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Save items you love to your wishlist',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
            label: Text(
              'Continue Shopping',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: darkGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final productId = product['id'];
    final name = product['Product_name'] ?? 'Unnamed Product';
    final imageUrl = product['img_path'] ?? '';
    final unitPrice = double.tryParse(
        product['product_price']?.toString() ?? '0.0') ??
        0.0;
    final originalUnitPrice = double.tryParse(
        product['original_price']?.toString() ??
            unitPrice.toString()) ??
        unitPrice;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutScreen(
              productId: productId,
              productName: name,
              productPrice: unitPrice,
              description: product['description'] ?? 'No description',
              imageUrl: imageUrl,
              quantity: 1,
            ),
          ),
        );
      },
      child: Card(
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + Remove Icon
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported,
                          size: 40, color: Colors.grey),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => removeFromWishlist(productId),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                        child: Icon(Icons.favorite, color: darkGreen, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Product Details
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('₹${unitPrice.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: goldColor)),
                      const SizedBox(width: 6),
                      if (originalUnitPrice > unitPrice)
                        Text('₹${originalUnitPrice.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        title: const Text("My Wishlist",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: !_isLoggedIn
          ? _buildLoginMessage()
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentCartItems == null || currentCartItems!.isEmpty
          ? _buildEmptyCartMessage()
          : GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: currentCartItems!.length,
        itemBuilder: (context, index) {
          return _buildProductCard(currentCartItems![index]);
        },
      ),
    );
  }
}
