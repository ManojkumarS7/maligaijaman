import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maligaijaman/Users/login_page.dart';
import 'productdetail_page.dart';
import '../main.dart';
import 'cart_page.dart';
import 'wishlist_screen.dart';
import 'profile_page.dart';
import 'home_page.dart';
import 'package:maligaijaman/apiconstants.dart';

class ProductListScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const ProductListScreen({
    Key? key,
    required this.categoryId,
    required this.categoryName,
  }) : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class Product {
  final String name;
  final double price;
  final double originalPrice;
  final String imageUrl;
  final String id;
  final String supplier;

  Product({
    required this.name,
    required this.price,
    required this.originalPrice,
    required this.imageUrl,
    required this.id,
    required this.supplier,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      originalPrice: double.tryParse(json['original_price']?.toString() ?? json['price'].toString()) ?? 0.0,
      imageUrl: json['image_url'] ?? '',
      supplier: json['supplier'] ?? 'Tradly',
    );
  }
}




class _ProductListScreenState extends State<ProductListScreen> {
  final _storage = const FlutterSecureStorage();
  String? _jwt;
  String? _secretKey;
  List<dynamic> _allProducts = [];
  List<dynamic> _filteredProducts = [];
  final Map<String, int> _quantities = {};
  final Map<String, double> _prices = {};
  // final Map<String, int> _quantities = {};
  final Map<String, bool> _wishlist = {};
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  String _sortCriteria = "Default";
  bool _sortAscending = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _searchController.addListener(_filterProducts);
    _loadProducts();
    _loadWishlistData();
  }

  Future<void> _loadCredentials() async {
    _jwt = await _storage.read(key: 'jwt');
    _secretKey = await _storage.read(key: 'key');
    setState(() {});
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final products = await fetchProducts(widget.categoryId);

      // Initialize quantities and wishlist status
      for (var product in products) {
        final productId = product['id'];
        _quantities[productId] = 1;
        _wishlist[productId] = false;
      }

      setState(() {
        _allProducts = products;
        _filteredProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<dynamic>> fetchProducts(String categoryId) async {
    final url = Uri.parse("${Appconfig.baseurl}api/productlist.php");
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> products = json.decode(responseBody);

        final filteredProducts = products.where((product) {
          final productCategoryId = product['category_id ']?.toString().trim() ?? '';
          final deleteFlag = product['delete_flag']?.toString() ?? '1';
          return productCategoryId == categoryId.trim() && deleteFlag == '0';
        }).toList();

        return filteredProducts;
      } else {
        throw Exception("Failed to load products with status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
      throw Exception("Failed to fetch products: $e");
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
          backgroundColor: Colors.orange,

        ),
      );
      return; // Exit the function early
    }
    try {
      final url = Uri.parse('${Appconfig.baseurl}api/cart_insert.php');
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

  Future<void> _loadWishlistData() async {
    if (_jwt == null || _secretKey == null) {
      await _loadCredentials();
    }

    if (_jwt == null || _secretKey == null) {
      return; // User not logged in
    }

    try {
      final url = Uri.parse('${Appconfig.baseurl}api/get_wishlist.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'jwt': _jwt!, 'secretkey': _secretKey!},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success' && responseData['data'] != null) {
          setState(() {
            // Reset all wishlist items
            _wishlist.clear();

            // Set wishlist status for items in the response
            for (var item in responseData['data']) {
              _wishlist[item['productid']] = true;
            }
          });
        }
      }
    } catch (e) {
      print('Error loading wishlist: $e');
    }
  }



  Future<void> _toggleWishlist(String productId) async {
    if (_jwt == null || _secretKey == null) {
      await _loadCredentials();
    }

    if (_jwt == null || _secretKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to manage wishlist'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final product = _allProducts.firstWhere((p) => p['id'] == productId, orElse: () => null);
    if (product == null) return;

    final isCurrentlyWishlisted = _wishlist[productId] ?? false;

    // Optimistically update UI
    setState(() {
      _wishlist[productId] = !isCurrentlyWishlisted;
    });

    try {
      final url = Uri.parse(isCurrentlyWishlisted
          ? '${Appconfig.baseurl}api/delete_wishlist.php'
          : '${Appconfig.baseurl}api/wishlist_insert.php');

      final Map<String, dynamic> requestBody;

      if (isCurrentlyWishlisted) {
        // For removal, we only need productid
        requestBody = {
          'jwt': _jwt!,
          'secretkey': _secretKey!,
          'productid': productId,
        };
      } else {
        // For adding, we need all product details
        final String productName = product['name'] ?? '';
        final double productPrice = double.tryParse(product['price']?.toString() ?? '0.0') ?? 0.0;

        requestBody = {
          'jwt': _jwt!,
          'secretkey': _secretKey!,
          'productid': productId,
          'productname': productName,
          'productprice': productPrice.toString(),
        };
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isCurrentlyWishlisted
                  ? 'Removed from wishlist'
                  : 'Added to wishlist'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          // Revert UI change if server update failed
          setState(() {
            _wishlist[productId] = isCurrentlyWishlisted;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'Failed to update wishlist'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Revert UI change if request failed
        setState(() {
          _wishlist[productId] = isCurrentlyWishlisted;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Revert UI change if exception occurred
      setState(() {
        _wishlist[productId] = isCurrentlyWishlisted;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating wishlist: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _increaseQuantity(String productId) {
    setState(() {
      _quantities[productId] = (_quantities[productId] ?? 1) + 1;
    });
  }

  void _decreaseQuantity(String productId) {
    if ((_quantities[productId] ?? 1) > 1) {
      setState(() {
        _quantities[productId] = (_quantities[productId] ?? 1) - 1;
      });
    }
  }

  void _updatePrice(String productId, double basePrice) {
    setState(() {
      _prices[productId] = basePrice * _quantities[productId]!;
    });
  }

  void _sortProducts(String criteria, bool ascending) {
    setState(() {
      _sortCriteria = criteria;
      _sortAscending = ascending;

      switch (criteria) {
        case "Price":
          _filteredProducts.sort((a, b) {
            double priceA = double.tryParse(a['price']?.toString() ?? '0.0') ?? 0.0;
            double priceB = double.tryParse(b['price']?.toString() ?? '0.0') ?? 0.0;
            return ascending ? priceA.compareTo(priceB) : priceB.compareTo(priceA);
          });
          break;
        case "Name":
          _filteredProducts.sort((a, b) {
            String nameA = a['name']?.toString() ?? '';
            String nameB = b['name']?.toString() ?? '';
            return ascending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
          });
          break;
        case "Default":
        // Reset to original order (you might need to keep a copy of the original order)
          _filteredProducts = List.from(_allProducts);
          _filterProducts(); // Apply any existing search filters
          break;
      }
    });
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((product) {
          final name = product['name']?.toString().toLowerCase() ?? '';
          return name.contains(query);
        }).toList();
      }
    });
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


// Replace your sort button with this implementation:
  Widget _buildSortButton() {
    return PopupMenuButton<Map<String, dynamic>>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      offset: const Offset(0, 40),
      onSelected: (Map<String, dynamic> value) {
        _sortProducts(value['criteria'], value['ascending']);
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<Map<String, dynamic>>(
          value: {'criteria': 'Default', 'ascending': true},
          child: Row(
            children: [
              const Icon(Icons.restore, size: 18),
              const SizedBox(width: 8),
              const Text('Default'),
              const Spacer(),
              if (_sortCriteria == 'Default')
                const Icon(Icons.check, color: Color.fromRGBO(85, 139, 47, 1), size: 18),
            ],
          ),
        ),
        PopupMenuItem<Map<String, dynamic>>(
          value: {'criteria': 'Price', 'ascending': true},
          child: Row(
            children: [
              const Icon(Icons.arrow_upward, size: 18),
              const SizedBox(width: 8),
              const Text('Price: Low to High'),
              const Spacer(),
              if (_sortCriteria == 'Price' && _sortAscending)
                const Icon(Icons.check, color: Color.fromRGBO(85, 139, 47, 1), size: 18),
            ],
          ),
        ),
        PopupMenuItem<Map<String, dynamic>>(
          value: {'criteria': 'Price', 'ascending': false},
          child: Row(
            children: [
              const Icon(Icons.arrow_downward, size: 18),
              const SizedBox(width: 8),
              const Text('Price: High to Low'),
              const Spacer(),
              if (_sortCriteria == 'Price' && !_sortAscending)
                const Icon(Icons.check, color: Color.fromRGBO(85, 139, 47, 1), size: 18),
            ],
          ),
        ),
        PopupMenuItem<Map<String, dynamic>>(
          value: {'criteria': 'Name', 'ascending': true},
          child: Row(
            children: [
              const Icon(Icons.sort_by_alpha, size: 18),
              const SizedBox(width: 8),
              const Text('Name: A to Z'),
              const Spacer(),
              if (_sortCriteria == 'Name' && _sortAscending)
                const Icon(Icons.check, color: Color.fromRGBO(85, 139, 47, 1), size: 18),
            ],
          ),
        ),
        PopupMenuItem<Map<String, dynamic>>(
          value: {'criteria': 'Name', 'ascending': false},
          child: Row(
            children: [
              Transform.rotate(
                angle: 3.14159, // 180 degrees in radians
                child: const Icon(Icons.sort_by_alpha, size: 18),
              ),
              const SizedBox(width: 8),
              const Text('Name: Z to A'),
              const Spacer(),
              if (_sortCriteria == 'Name' && !_sortAscending)
                const Icon(Icons.check, color: Color.fromRGBO(85, 139, 47, 1), size: 18),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 16),
            SizedBox(width: 4),
            Text('Sort'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.categoryName,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromRGBO(85, 139, 47, 1), // Yellow background color
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar and sort button
          Container(
            color: const Color.fromRGBO(85, 139, 47, 1),
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Row(
              children: [
                // Search bar
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search products',
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Sort button with dropdown
                _buildSortButton(),
              ],
            ),
          ),

          // Product grid (unchanged)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text('Error: $_error'))
                : _filteredProducts.isEmpty
                ? const Center(child: Text("No products found."))
                : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.68,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                return _buildProductCard(product);
              },
            ),
          ),
        ],
      ),

    );

  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final productId = product['id'];
    final vendor_id = product['vendor_id'];
    final name = product['name'] ?? 'Unnamed Product';
    final vendorName = product['store_name'] ?? 'Unknown Vendor';

    // Parse stock as integer and handle different formats
    int stockValue = 0;
    if (product['stock'] != null) {
      if (product['stock'] is int) {
        stockValue = product['stock'];
      } else if (product['stock'] is String) {
        stockValue = int.tryParse(product['stock']) ?? 0;
      }
    }

    final bool isOutOfStock = stockValue <= 0;
    final String stockDisplay = isOutOfStock ? 'Out of Stock' : '$stockValue left';

    // DEBUG: Print all product data to see what we're getting
    print('=== PRODUCT DEBUG INFO ===');
    print('Product ID: $productId');
    print('Product Name: $name');
    print('Raw image_path: ${product['image_path']}');
    print('Image_path type: ${product['image_path'].runtimeType}');
    print('Full product data: $product');
    print('========================');

    // Get the raw image path exactly as it comes from the API
    final rawImagePath = product['image_path'];
    String imageUrl = '';

    if (rawImagePath != null && rawImagePath.toString().isNotEmpty) {
      imageUrl = rawImagePath.toString();
      print('Processed imageUrl: $imageUrl');
    } else {
      print('WARNING: image_path is null or empty');
    }

    final unitPrice = double.tryParse(product['price']?.toString() ?? '0.0') ?? 0.0;
    final originalUnitPrice = unitPrice + 10;
    final quantity = _quantities[productId] ?? 1;
    final isWishlisted = _wishlist[productId] ?? false;

    final totalPrice = unitPrice * quantity;
    final totalOriginalPrice = originalUnitPrice * quantity;

    // Calculate discount percentage
    final discountPercent = ((originalUnitPrice - unitPrice) / originalUnitPrice * 100).round();

    // Check if quantity can be increased (stock limit check)
    final bool canIncreaseQuantity = !isOutOfStock && quantity < stockValue;

    return GestureDetector(
      onTap: () {
        // Only navigate to checkout if item is in stock
        if (!isOutOfStock) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                body: CheckoutScreen(
                  productId: productId,
                  productName: name,
                  productPrice: unitPrice,
                  quantity: quantity,
                  imageUrl: imageUrl,
                ),
                bottomNavigationBar: BottomNavigationBar(
                  items: const <BottomNavigationBarItem>[
                    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                    BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
                    BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Wishlist'),
                    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
                  ],
                  currentIndex: 1,
                  selectedItemColor: const Color.fromRGBO(85, 139, 47, 1),
                  unselectedItemColor: Colors.grey,
                  onTap: (index) {
                    if (index == 1) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MainScreen(initialIndex: index),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(85, 139, 47, 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image with badges and wishlist
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: ColorFiltered(
                    colorFilter: isOutOfStock
                        ? const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0, 0, 0, 1, 0,
                    ])
                        : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                    child: _buildImageWidget(imageUrl),
                  ),
                ),

                // Out of stock overlay
                if (isOutOfStock)
                  Positioned.fill(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.white.withOpacity(0.9),
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Discount badge (top left)
                if (!isOutOfStock && discountPercent > 0)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color.fromRGBO(85, 139, 47, 1), Color.fromRGBO(105, 159, 67, 1)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromRGBO(85, 139, 47, 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$discountPercent% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),

                // Wishlist button (top right)
                Positioned(
                  top: 10,
                  right: 10,
                  child: InkWell(
                    onTap: () => _toggleWishlist(productId),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isWishlisted ? Icons.favorite : Icons.favorite_border,
                        color: isWishlisted ? Colors.red.shade600 : Colors.grey.shade600,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Product details section - More compact
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3436),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Vendor info with icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(85, 139, 47, 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.store,
                          size: 10,
                          color: Color.fromRGBO(85, 139, 47, 1),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          vendorName,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Price section with stock
                  Row(
                    children: [
                      // Current price
                      Text(
                        '₹${totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color.fromRGBO(85, 139, 47, 1),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Original price
                      Text(
                        '₹${totalOriginalPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const Spacer(),
                      // Stock indicator
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? Colors.red.shade500
                              : (stockValue < 10 ? Colors.orange.shade500 : const Color.fromRGBO(85, 139, 47, 1)),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        stockDisplay,
                        style: TextStyle(
                          fontSize: 9,
                          color: isOutOfStock
                              ? Colors.red.shade700
                              : (stockValue < 10 ? Colors.orange.shade700 : Colors.grey.shade600),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Unit price
                  Text(
                    '₹${unitPrice.toStringAsFixed(0)}/unit',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Action row - Quantity and Add to Cart
                  Row(
                    children: [
                      // Quantity controls
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isOutOfStock
                                ? Colors.grey.shade300
                                : const Color.fromRGBO(85, 139, 47, 0.3),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            _buildQuantityButton(
                              icon: Icons.remove,
                              onTap: isOutOfStock
                                  ? null
                                  : () {
                                if (quantity > 1) {
                                  setState(() {
                                    _quantities[productId] = quantity - 1;
                                  });
                                }
                              },
                              size: 22,
                              isDisabled: isOutOfStock,
                            ),
                            Container(
                              width: 24,
                              alignment: Alignment.center,
                              child: Text(
                                '$quantity',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isOutOfStock ? Colors.grey.shade400 : const Color(0xFF2D3436),
                                ),
                              ),
                            ),
                            _buildQuantityButton(
                              icon: Icons.add,
                              onTap: canIncreaseQuantity
                                  ? () {
                                setState(() {
                                  _quantities[productId] = quantity + 1;
                                });
                              }
                                  : null,
                              size: 22,
                              isDisabled: !canIncreaseQuantity,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Add to cart button
                      Expanded(
                        child: SizedBox(
                          height: 30,
                          child: ElevatedButton(
                            onPressed: isOutOfStock
                                ? null
                                : () => addToCart(
                              productId,
                              name,
                              unitPrice,
                              quantity,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isOutOfStock
                                  ? Colors.grey.shade300
                                  : const Color.fromRGBO(85, 139, 47, 1),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade500,
                            ),
                            child: Text(
                              isOutOfStock ? 'Unavailable' : 'Add to Cart',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 8,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
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

// Separate method to handle image loading with extensive debugging
  Widget _buildImageWidget(String imageUrl) {
    print('_buildImageWidget called with URL: $imageUrl');

    if (imageUrl.isEmpty) {
      print('Empty URL - showing placeholder');
      return Container(
        height: 100,
        width: double.infinity,
        color: Colors.grey[200],
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 40),
            Text('No Image URL', style: TextStyle(fontSize: 10)),
          ],
        ),
      );
    }

    return Image.network(
      imageUrl,
      height: 100,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          print('Image loaded successfully: $imageUrl');
          return child;
        }

        print('Loading image: ${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes}');
        return Container(
          height: 100,
          width: double.infinity,
          color: Colors.grey[200],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  color: const Color.fromRGBO(85, 139, 47, 1),
                ),
                const SizedBox(height: 4),
                const Text('Loading...', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('=== IMAGE ERROR ===');
        print('URL: $imageUrl');
        print('Error: $error');
        print('StackTrace: $stackTrace');
        print('==================');

        return Container(
          height: 100,
          width: double.infinity,
          color: Colors.red[100],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 40, color: Colors.red),
              const SizedBox(height: 4),
              Text(
                'Failed to load',
                style: TextStyle(fontSize: 10, color: Colors.red[700]),
              ),
              Text(
                imageUrl.length > 30 ? '${imageUrl.substring(0, 30)}...' : imageUrl,
                style: TextStyle(fontSize: 8, color: Colors.red[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }



// Modified quantity button to handle disabled state
  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onTap,
    required double size,
    bool isDisabled = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDisabled ? Colors.grey[200] : const Color(0xFFFFC107).withOpacity(0.2),
        ),
        child: Icon(
          icon,
          size: size * 0.6,
          color: isDisabled ? Colors.grey : const Color(0xFFFFC107),
        ),
      ),
    );
  }


  @override
  void dispose() {
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
    super.dispose();
  }
}
