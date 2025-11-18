import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maligaijaman/Admin/admin_productdetail.dart';
// import '../Admin/adminAddProducts_page.dart';
import 'package:maligaijaman/Vendors/vendor_addProducts.dart';
import 'package:maligaijaman/apiconstants.dart';
import 'package:maligaijaman/appcolors.dart';

class VendorProductListScreen extends StatefulWidget {
  const VendorProductListScreen({Key? key}) : super(key: key);

  @override
  State<VendorProductListScreen> createState() => _VendorProductListScreenState();
}

class Product {
  final String name;
  final double price;
  final String imageUrl;
  final String id;
  final String? vendorId;

  Product({
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.id,
    this.vendorId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      imageUrl: json['image_url'] ?? '',
      vendorId: json['vendor_id'],
    );
  }
}

class _VendorProductListScreenState extends State<VendorProductListScreen> {
  final Map<String, int> _quantities = {};
  final Map<String, double> _prices = {};
  final _storage = const FlutterSecureStorage();
  String? _jwt;
  String? _secretKey;
  String? _vendorId;
  List<dynamic> _allProducts = [];
  List<dynamic> _filteredProducts = [];
  TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    try {
      _jwt = await _storage.read(key: 'jwt');
      _secretKey = await _storage.read(key: 'key');
      _vendorId = await _storage.read(key: 'vendor_id');

      print(_vendorId);

      if (_jwt == null || _secretKey == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login to continue'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        _fetchProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading credentials: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse("${Appconfig.baseurl}api/productlist.php");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> products = json.decode(responseBody);

        // Filter products by vendor_id and delete_flag
        setState(() {
          _allProducts = products.where((product) {
            // Only show products with delete_flag = 0
            bool notDeleted = product['delete_flag']?.toString() == '0';

            // If vendor_id is available, filter by it
            if (_vendorId != null && _vendorId!.isNotEmpty) {
              return notDeleted && product['vendor_id']?.toString() == _vendorId;
            }

            // If no vendor_id, show all non-deleted products
            return notDeleted;
          }).toList();

          _filteredProducts = List.from(_allProducts);
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to load products with status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToProductDetail(String productId) async {
    // Navigate to the product detail page and wait for result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminProductDetailPage(productId: productId),
      ),
    );

    // Refresh the product list if we get back a true result
    if (result == true) {
      _fetchProducts();
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final name = product['name']?.toString().toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Appcolor.Appbarcolor,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VendorAddProductsPage())
              );
              if (result == true) {
                _fetchProducts();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchProducts,
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Products", style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search products...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFC107)))
                : _filteredProducts.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("No products found."),
                  if (_vendorId != null)
                    const SizedBox(height: 8),
                  if (_vendorId != null)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromRGBO(85, 139, 47, 1),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => VendorAddProductsPage()),
                        ).then((_) => _fetchProducts());
                      },
                      child: Text('Add Product', style: TextStyle(color: Color.fromRGBO(85, 139, 47, 1))),
                    ),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredProducts.length,
              separatorBuilder: (context, index) => const Divider(height: 32),
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        product['image_path'] ?? '',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                    title: Text(
                      product['name'] ?? 'Unnamed Product',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("₹${product['price'] ?? '0.0'}",
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        Text("Stock: ${product['stock'] ?? '0'} ${product['quantity_type'] ?? ''}"),
                      ],
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, color: Color.fromRGBO(85, 139, 47, 1)),
                    onTap: () async {
                      final String? catid = product['category_id '];
                      final String? subcatid = product['subcategory_id'];

                      if (catid != null) {
                        await _storage.write(key: 'categoryid', value: catid);
                      }
                      if (subcatid != null) {
                        await _storage.write(key: 'subcategoryid', value: subcatid);
                      }

                      _navigateToProductDetail(product['id'].toString());
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}