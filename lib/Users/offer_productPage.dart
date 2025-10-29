import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'productdetail_page.dart';

class OfferPage extends StatefulWidget {
  final String offerId;
  final String offerName;
  final String offerPercentage;
  final String offerDescription;
  final String categoryId; // Optional - use if filtering by category

  const OfferPage({
    Key? key,
    required this.offerId,
    required this.offerName,
    required this.offerPercentage,
    required this.offerDescription,
    this.categoryId = '', // Default empty string if not provided
  }) : super(key: key);

  @override
  _OfferPageState createState() => _OfferPageState();

}

class _OfferPageState extends State<OfferPage> {
  List<dynamic> _products = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String? _jwt;
  String? _secretKey;
  final _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    fetchProducts();

  }

  Future<void> _loadCredentials() async {
    _jwt = await _storage.read(key: 'jwt');
    _secretKey = await _storage.read(key: 'key');
    setState(() {});
  }

  Future<void> fetchProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final url = Uri.parse(
          "https://maligaijaman.rdegi.com/api/productlist.php");
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Network request timed out. Please check your connection.');
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load products. Status code: ${response.statusCode}');
      }

      String responseBody = utf8.decode(response.bodyBytes);
      final List<dynamic> allProducts = json.decode(responseBody);

      // Filter valid products

      final validProducts = allProducts.where((product) =>

      product != null &&
          product['delete_flag'] == "0" &&
          product['status'] == "1" &&
          product['name'] != null &&
          (product['image_path'] != null || product['imgpath'] != null) &&
          product['price'] != null &&
          int.parse(product['stock'] ?? '0') > 0
      ).toList();

      // Filter by category if categoryId is provided
      List<dynamic> filteredProducts = validProducts;
      if (widget.categoryId.isNotEmpty) {
        filteredProducts = validProducts.where((product) =>
        product['category_id ']?.trim() == widget.categoryId.trim()
        ).toList();
      }

      setState(() {
        _products = filteredProducts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error loading products: $e";
      });
      print("Error fetching products: $e");
    }
  }

  Future<void> addToCart(String productId, String productName, double productPrice, int qty) async {
    if (_jwt == null || _secretKey == null) {
      await _loadCredentials();
    }

    if (_jwt == null || _secretKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to add items to cart'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final url = Uri.parse('https://maligaijaman.rdegi.com/api/cart_insert.php');
      final Map<String, dynamic> requestBody = {
        'secretkey': _secretKey,
        'jwt': _jwt,
        'productid': productId,
        'productname': productName,
        'productprice': productPrice.toString(),
        'qty': qty.toString(),
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
              content: Text('Product added to cart successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'Failed to add product to cart'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding to cart: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Calculate discounted price
  double calculateDiscountedPrice(String originalPrice, String percentage) {
    try {
      final double price = double.parse(originalPrice);
      final double discountPercentage = double.parse(percentage);
      final double discount = price * (discountPercentage / 100);
      return price - discount;
    } catch (e) {
      print("Error calculating discount: $e");
      return double.parse(originalPrice);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.offerName} - ${widget.offerPercentage}% OFF'),
        backgroundColor: Color(0xFFFFC107),
      ),
      body: Column(
        children: [
          // Offer Banner
          _buildOfferBanner(),

          // Products List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                ? Center(
                child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
                : _products.isEmpty
                ? const Center(
                child: Text('No products available for this offer'))
                : GridView.builder(
              padding: EdgeInsets.all(10),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                final originalPrice = double.parse(product['price'] ?? '0');
                final discountedPrice = calculateDiscountedPrice(
                    product['price'] ?? '0',
                    widget.offerPercentage
                );

                return _buildProductCard(
                    product,
                    originalPrice,
                    discountedPrice,
                    context
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.offerName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${widget.offerPercentage}% OFF',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.offerDescription,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
      dynamic product,
      double originalPrice,
      double discountedPrice,
      BuildContext context) {
    final imagePath = product['image_path'] ?? product['imgpath'] ?? '';
    final name = product['name'] ?? 'Unknown Product';
    final quantity = product['quantity'] ?? '1';
    final quantityType = product['quantity_type'] ?? 'pc';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () async {
          // Save the discount information to secure storage
          final storage = FlutterSecureStorage();
          await storage.write(
              key: 'applied_discount_percentage',
              value: widget.offerPercentage);

          // Navigate to product detail page
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => CheckoutScreen(
          //       productId: product['id'],
          //       // offerId: widget.offerId,
          //       productName: name,
          //       offerPercentage: widget.offerPercentage,
          //       offerDescription: widget.offerDescription,
          //       productPrice: originalPrice.toString(),
          //       discountedPrice: discountedPrice.toStringAsFixed(2),
          //     ),
          //   ),
          // );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                child: Image.network(
                  imagePath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: Center(child: Icon(Icons.image_not_supported, size: 50)),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Product Details
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$quantity $quantityType',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${discountedPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '₹$originalPrice',
                        style: TextStyle(
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Add to cart logic here
                         addToCart(
                           product['id'],
                          name,
                          discountedPrice,
                          quantity,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text('Add to Cart'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}