

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maligaijaman/Users/productdetail_page.dart';
import 'productList_page.dart';
import 'cart_page.dart';
import 'profile_page.dart';
import 'wishlist_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'offer_productPage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:maligaijaman/ProfileOption_page.dart';
import 'myOrders_page.dart';
import 'package:maligaijaman/apiconstants.dart';



class UserProfile {
  final String id;
  final String name;
  final String username;
  final String phone;

  UserProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.phone,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isOffline = false;


  Future<bool> _checkInternetConnection() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }


  final List<Widget> _screens = [
    const HomeScreen(),
    const CartScreen(),
    const WishlistScreen(),
    const ProfileScreen()

  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if offline
    if (_isOffline) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 80, color: Colors.grey),
              SizedBox(height: 20),
              Text(
                'No Internet Connection',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('Please check your connection and try again'),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  bool connected = await _checkInternetConnection();
                  setState(() {
                    _isOffline = !connected;
                  });
                },
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(


        decoration: const BoxDecoration(

            border: Border(
              top: BorderSide(color: Colors.white, width: 1),
              bottom: BorderSide(color: Colors.white, width: 1),
            ),
            color: const Color(0xFF74C365)


        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Cart',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Wishlist',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.orangeAccent,
          unselectedItemColor: Colors.white70,
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<dynamic>> categories;
  Future<List<dynamic>> randomProducts = Future.value([]);
  Future<List<dynamic>> allProducts = Future.value([]);

  final TextEditingController _searchController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  late Future<Map<String, List<dynamic>>> _searchResults;
  bool _isSearching = false;
  final Map<String, int> _quantities = {};
  final Map<String, double> _prices = {};
  List<dynamic> _offers = [];
  int _currentOfferIndex = 0;
  String _currentCity = "Fetching...";
  String _currentPincode = "";
  bool _isLoadingLocation = false;
  bool _isOffline = false;
  UserProfile? userProfile;
  String _displayName = "Login"; // Changed to store display name
  bool _isLoggedIn = false;
  bool _isLoadingProfile = true; // Add loading state

  Future<bool> _checkInternetConnection() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    randomProducts = fetchRandomProducts();
    allProducts = fetchAllProducts();
    categories = fetchCategories();
    _loadOffers();
    _searchResults = Future.value({'products': [], 'categories': []});
    _checkConnection();
    _loadUserProfile();
    fetchUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      // First check if user is logged in
      final jwt = await _storage.read(key: 'jwt');
      final userid = await _storage.read(key: 'user_id');

      print('JWT: $jwt'); // Debug
      print('User ID: $userid'); // Debug

      if (jwt == null || userid == null || userid.isEmpty) {
        // User is not logged in
        if (mounted) {
          setState(() {
            _isLoggedIn = false;
            _displayName = "Login";
          });
        }
        return;
      }

      // User is logged in, fetch profile
      final profile = await fetchUserProfile();

      if (mounted) {
        setState(() {
          _isLoggedIn = true;
          _displayName =
          profile.name.isNotEmpty ? profile.name : profile.username;
        });
      }

      print('Profile loaded: ${profile.name}'); // Debug

    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _displayName = "Login";
        });
      }
    }
  }


  void _checkConnection() async {
    bool connected = await _checkInternetConnection();
    setState(() {
      _isOffline = !connected;
    });
  }

  // Modified to properly handle the offers
  Future<void> _loadOffers() async {
    try {
      List<dynamic> offers = await fetchOffers();
      setState(() {
        _offers = offers;
      });
    } catch (e) {
      print("Error loading offers: $e");
      // Initialize with a default offer in case of error
      setState(() {
        _offers = [
          {
            'id': '0',
            'name': 'Default Offer',
            'percentage': '10',
            'description': 'On all premium services'
          }
        ];
      });
    }
  }

  //
  Future<UserProfile> fetchUserProfile() async {
    print('hello user');
    final String? userid = await _storage.read(key: 'user_id');
    final uri =
    // Uri.parse('https://maligaijaman.rdegi.com/api/profile.php?id=$userid');
    Uri.parse("${Appconfig.baseurl}api/profile.php?id=$userid");
    final response = await http.get(uri);
    print(uri);

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      final jsonData = json.decode(response.body);
      if (jsonData is List && jsonData.isNotEmpty) {
        return UserProfile.fromJson(jsonData[0]);
      } else if (jsonData is Map && jsonData.containsKey('data')) {
        return UserProfile.fromJson(jsonData['data']);
      }
    }
    throw Exception('Failed to load profile');
  }


  Future<List<dynamic>> fetchCategories() async {
    final url = Uri.parse(
        "${Appconfig.baseurl}api/categorylist.php");

    print(url);
    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load categories. Status code: ${response.statusCode}');
      }

      // Decode the response body
      String responseBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = json.decode(responseBody);

      // Filter and validate data
      return data.where((item) =>
      item != null &&
          item['delete_flag'] == "0" &&
          item['id'] != null &&
          item['name'] != null &&
          item['imgpath'] != null
      ).toList();
    } catch (e) {
      print("Error fetching categories: $e");
      throw Exception("Failed to fetch categories: $e");
    }
  }

  Future<List<dynamic>> fetchRandomProducts() async {
    final url = Uri.parse("${Appconfig.baseurl}api/productlist.php");
    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load products. Status code: ${response.statusCode}');
      }

      String responseBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = json.decode(responseBody);

      // Filter valid products
      final validProducts = data.where((product) =>
      product != null &&
          product['delete_flag'] == "0" &&
          product['name'] != null &&
          (product['image_path'] != null || product['imgpath'] != null) &&
          product['price'] != null
      ).toList();

      // Shuffle and take first 10 products (or less if fewer are available)
      validProducts.shuffle();
      return validProducts.take(10).toList();
    } catch (e) {
      print("Error fetching products: $e");
      throw Exception("Failed to fetch products: $e");
    }
  }

  Future<List<dynamic>> fetchAllProducts() async {
    final url = Uri.parse("${Appconfig.baseurl}api/productlist.php");
    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load products. Status code: ${response.statusCode}');
      }

      String responseBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = json.decode(responseBody);

      // Filter valid products
      final allProducts = data.where((product) =>
      product != null &&
          product['delete_flag'] == "0" &&
          product['name'] != null &&
          (product['image_path'] != null || product['imgpath'] != null) &&
          product['price'] != null
      ).toList();



      return allProducts.toList();
    } catch (e) {
      print("Error fetching products: $e");
      throw Exception("Failed to fetch products: $e");
    }
  }


  Future<Map<String, List<dynamic>>> searchProductsAndCategories(
      String query) async {
    if (query.isEmpty) return {'products': [], 'categories': []};

    // Initialize result map
    Map<String, List<dynamic>> results = {
      'products': [],
      'categories': []
    };

    try {
      // Fetch and search products
      final productUrl = Uri.parse(
          "${Appconfig.baseurl}api/productlist.php");

      final productResponse = await http.get(productUrl).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException(
                'Network request timed out. Please check your connection.');
          }
      );

      if (productResponse.statusCode == 200) {
        String productResponseBody = utf8.decode(productResponse.bodyBytes);

        try {
          final List<dynamic> productData = json.decode(productResponseBody);

          // Filter products
          results['products'] = productData.where((product) =>
          product != null &&
              product['delete_flag'] == "0" &&
              ((product['name']?.toString().toLowerCase().contains(
                  query.toLowerCase()) ?? false) ||
                  (product['description']?.toString().toLowerCase().contains(
                      query.toLowerCase()) ?? false))
          ).toList();
        } catch (jsonError) {
          print("Error parsing product JSON: $jsonError");
          results['products'] = [];
        }
      } else {
        print(
            "Product API returned status code: ${productResponse.statusCode}");
        results['products'] = [];
      }

      // Fetch and search categories
      final categoryUrl = Uri.parse(
          "${Appconfig.baseurl}api/categorylist.php");

      final categoryResponse = await http.get(categoryUrl).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException(
                'Network request timed out. Please check your connection.');
          }
      );

      if (categoryResponse.statusCode == 200) {
        String categoryResponseBody = utf8.decode(categoryResponse.bodyBytes);

        try {
          final List<dynamic> categoryData = json.decode(categoryResponseBody);

          // Filter categories
          results['categories'] = categoryData.where((category) =>
          category != null &&
              category['delete_flag'] == "0" &&
              (category['name']?.toString().toLowerCase().contains(
                  query.toLowerCase()) ?? false)
          ).toList();
        } catch (jsonError) {
          print("Error parsing category JSON: $jsonError");
          results['categories'] = [];
        }
      } else {
        print("Category API returned status code: ${categoryResponse
            .statusCode}");
        results['categories'] = [];
      }

      return results;
    } catch (e) {
      print("Search error: $e");
      throw Exception("Failed to search: $e");
    }
  }


  Future<List<dynamic>> fetchOffers() async {
    final url = Uri.parse(
        "${Appconfig.baseurl}api/offer_list.php");
    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load offers. Status code: ${response.statusCode}');
      }

      // Decode the response body
      String responseBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = json.decode(responseBody);

      // Filter and validate data
      return data.where((offer) =>
      offer != null &&
          // item['delete_flag'] == "0" &&
          offer['id'] != null &&
          offer['name'] != null &&
          offer['percentage'] != null
      ).toList();
    } catch (e) {
      print("Error fetching offers: $e");
      throw Exception("Failed to fetch offers: $e");
    }
  }

  // Fetch location method
  Future<void> _fetchLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _currentCity = "Fetching...";
      _currentPincode = "";
    });

    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _currentCity = "Permission Denied";
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentCity = "Enable Location";
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Reverse geocode to get address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentCity =
              place.locality ?? place.subAdministrativeArea ?? 'Unknown City';
          _currentPincode = place.postalCode ?? '';
          _isLoadingLocation = false;
        });
      } else {
        setState(() {
          _currentCity = "Location Not Found";
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        _currentCity = "Error Fetching";
        _isLoadingLocation = false;
      });
      print('Location error: $e');
    }
  }





  Widget MidTile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(65, 117, 37, 1),
        border: const Border(
          bottom: BorderSide(color: Colors.white, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Contact Support
          GestureDetector(
            onTap: () {
              _showContactSupportMenu(context);
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  "Contact Support",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Location Display with Refresh
          GestureDetector(
            onTap: _isLoadingLocation ? null : () => _fetchLocation(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isLoadingLocation
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentCity,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_currentPincode.isNotEmpty)
                      Text(
                        _currentPincode,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Contact Support
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyOrdersScreen(),
                ),
              );
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  "My Orders",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


// Add this method to show contact support menu
  void _showContactSupportMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(85, 139, 47, 1),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Phone Number 1
              _buildContactOption(
                context,
                icon: Icons.phone,
                title: 'Customer Care',
                subtitle: '+91 7845298544',
                onTap: () {
                  // Add phone call functionality
                  // You can use url_launcher package: launch('tel:+911234567890');
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 20),
              // const Divider(height: 20),

              // Email
              _buildContactOption(
                context,
                icon: Icons.email,
                title: 'Email Support',
                subtitle: 'rdegi@.com',
                onTap: () {
                  // Add email functionality
                  // You can use url_launcher package: launch('mailto:support@maligaijamaan.com');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

// Helper widget for contact options
  Widget _buildContactOption(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(85, 139, 47, 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color.fromRGBO(85, 139, 47, 1),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSecondTile(BuildContext context) {
    return Container(
      color: const Color.fromRGBO(27, 94, 32, 1), // Green background
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: buildSearchBar(), // Directly place the search bar here
    );
  }


  Widget buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Icon(Icons.search, color: Colors.green, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products, categories, brands...',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    _isSearching = true;
                    _searchResults = searchProductsAndCategories(value);
                  });
                } else {
                  setState(() {
                    _isSearching = false;
                  });
                }
              },
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _isSearching = false;
                });
                FocusScope.of(context).unfocus();
              },
            ),
        ],
      ),
    );
  }


  Widget buildCategoryImage(String imageUrl) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
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

    );
  }

  Widget _buildPromotionBanner(BuildContext context) {
    // Check if offers list is empty
    if (_offers.isEmpty) {
      return const SizedBox.shrink(); // Return an empty widget if no offers
    }

    return Container(
      height: 220, // Adjusted height for the new design
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _offers.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final currentOffer = _offers[index];
          final percentage = currentOffer['percentage'] ?? '30';
          final name = currentOffer['name'] ?? 'Discount';
          final description = currentOffer['description'] ??
              'All Vegetables & Fruits';

          return Container(
            width: 320,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF4CAF50), // Green color matching the image
                  Color(0xFF66BB6A),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Background decorative circle
                  Positioned(
                    right: -40,
                    top: -40,
                    child: Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Color(0xFFFFF9C4).withOpacity(0.8), // Light yellow
                            Color(0xFFFFEB3B).withOpacity(0.6), // Yellow
                          ],
                          stops: [0.3, 1.0],
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                  // Main content container
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Left side content
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Discount label
                              Text(
                                name.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),

                              const SizedBox(height: 2),

                              // Percentage with bold styling
                              Text(
                                '$percentage%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),

                              const SizedBox(height: 2),

                              // Description text
                              Flexible(
                                child: Text(
                                  description,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // See Detail button
                              SizedBox(
                                height: 25,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    // Initialize secure storage
                                    final storage = FlutterSecureStorage();

                                    // Store offer details
                                    await storage.write(
                                        key: 'offer_name', value: name);
                                    await storage.write(key: 'offer_percentage',
                                        value: percentage);
                                    await storage.write(
                                        key: 'offer_description',
                                        value: description);
                                    await storage.write(key: 'offer_id',
                                        value: currentOffer['id']);

                                    // Navigate to product details page with the offer details
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            OfferPage(
                                              offerId: currentOffer['id'],
                                              offerName: name,
                                              offerPercentage: percentage,
                                              offerDescription: description,
                                              categoryId: currentOffer['category_id'] ??
                                                  '',
                                            ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFFFFEB3B),
                                    // Yellow button
                                    foregroundColor: Color(0xFF2E7D32),
                                    // Dark green text
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 2,
                                    minimumSize: Size(70, 28),
                                  ),
                                  child: const Text(
                                    'See Detail',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right side - Image container
                        Expanded(
                          flex: 5,
                          child: Container(
                            height: 150,
                            margin: const EdgeInsets.only(left: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Stack(
                                children: [
                                  // Background for image
                                  Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  // Image
                                  Positioned.fill(
                                    child: Image.asset(
                                      'assets/1289.jpg',
                                      // You can replace this with vegetables/fruits image
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error,
                                          stackTrace) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                                0.2),
                                            borderRadius: BorderRadius.circular(
                                                15),
                                          ),
                                          child: const Icon(
                                            Icons.shopping_basket_outlined,
                                            color: Colors.white,
                                            size: 50,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  Widget buildSearchResults() {
    return Expanded(
      child: FutureBuilder<Map<String, List<dynamic>>>(
        future: _searchResults,
        builder: (context, snapshot) {
          // Show loading indicator while waiting
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            );
          }
          // Handle error state
          else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  // Text(
                  //   'Error searching: ${snapshot.error}',
                  //   textAlign: TextAlign.center,
                  //   style: const TextStyle(color: Colors.red),
                  // ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchResults =
                            searchProductsAndCategories(_searchController.text);
                      });
                    },
                    child: const Text('Retry'),
                  )
                ],
              ),
            );
          }
          // Handle when there's no data or empty results
          else if (!snapshot.hasData ||
              snapshot.data == null ||
              (snapshot.data!['products']?.isEmpty == true &&
                  snapshot.data!['categories']?.isEmpty == true)) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search_off,
                    size: 60,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No items found for "${_searchController.text}"',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          // Get the results
          final categories = snapshot.data!['categories'] ?? [];
          final products = snapshot.data!['products'] ?? [];
          final totalItems = categories.length + products.length;

          // If there are no results even though we passed the above check
          if (totalItems == 0) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search_off,
                    size: 60,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No items found for "${_searchController.text}"',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: totalItems + 2, // +2 for the two section headers
            itemBuilder: (context, index) {
              // Category header
              if (index == 0) {
                // Only show if there are categories
                if (categories.isEmpty) return const SizedBox.shrink();

                return const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                );
              }
              // Category items
              else if (index <= categories.length) {
                // Skip if no categories
                if (categories.isEmpty) return const SizedBox.shrink();

                final category = categories[index - 1];
                return ListTile(
                  leading: category['imgpath'] != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      category['imgpath'],
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 40,
                          height: 40,
                          color: Colors.grey[200],
                          child: const Icon(Icons.category),
                        );
                      },
                    ),
                  )
                      : const Icon(Icons.category, size: 40),
                  title: Text(
                    category['name'] ?? 'Unnamed Category',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to products list filtered by this category
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductListScreen(
                              categoryId: category['id'],
                              categoryName: category['name'] ?? 'Products',
                            ),
                      ),
                    );
                  },
                );
              }
              // Products header
              else if (index == categories.length + 1) {
                // Only show if there are products
                if (products.isEmpty) return const SizedBox.shrink();

                return const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Products',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFC107),
                    ),
                  ),
                );
              }
              // Product items
              else {
                // Skip if no products
                if (products.isEmpty) return const SizedBox.shrink();

                final productIndex = index - categories.length - 2;
                if (productIndex >= 0 && productIndex < products.length) {
                  final product = products[productIndex];
                  return ListTile(
                    leading: (product['imgpath'] != null ||
                        product['image_path'] != null)
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        product['imgpath'] ?? product['image_path'] ?? '',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 40,
                            height: 40,
                            color: Colors.grey[200],
                            child: const Icon(Icons.shopping_bag),
                          );
                        },
                      ),
                    )
                        : const Icon(Icons.shopping_bag, size: 40),
                    title: Text(
                      product['name'] ?? 'Unnamed Product',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      product['description'] ?? 'No description',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      '\$${product['price'] ?? 'N/A'}',
                      style: const TextStyle(
                        color: Color(0xFFFFC107),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      final productId = product['id'];
                      final name = product['name'] ?? 'Unnamed Product';
                      final imageUrl = product['image_path'] ??
                          product['imgpath'] ?? '';
                      final unitPrice = double.tryParse(
                          product['price']?.toString() ?? '0.0') ?? 0.0;
                      final quantity = _quantities[productId] ?? 1;

                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CheckoutScreen(
                                  productId: productId,
                                  productName: name,
                                  productPrice: unitPrice,
                                  description: product['description'] ??
                                      'No description',
                                  imageUrl: imageUrl,
                                  quantity: quantity,
                                ),
                          )
                      );
                    },
                  );
                } else {
                  return const SizedBox.shrink();
                }
              }
            },
          );
        },
      ),
    );
  }


  Widget buildCategoriesGrid() {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade50,
            Colors.white,
            Colors.blue.shade50.withOpacity(0.3),
          ],
        ),
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Title
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme
                            .of(context)
                            .primaryColor,
                        Theme
                            .of(context)
                            .primaryColor
                            .withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Categories',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),

          // Categories Grid
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: categories,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme
                          .of(context)
                          .primaryColor,
                      strokeWidth: 3,
                    ),
                  );
                } else if (snapshot.hasError) {
                  return _buildErrorState();
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No categories available',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final category = snapshot.data![index];

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  Scaffold(
                                    body: ProductListScreen(
                                      categoryId: category['id'],
                                      categoryName: category['name'],
                                    ),
                                    bottomNavigationBar: _buildBottomNav(
                                        context),
                                  ),
                            ),
                          );
                        },
                        child: AnimatedScale(
                          scale: 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                  spreadRadius: 0,
                                ),
                                BoxShadow(
                                  color: Theme
                                      .of(context)
                                      .primaryColor
                                      .withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                  spreadRadius: -5,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Background image
                                  buildCategoryImage(category['imgpath']),

                                  // Enhanced gradient overlay
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.6),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Shimmer effect on top
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 60,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.white.withOpacity(0.2),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Category name with enhanced glass effect
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      margin: const EdgeInsets.all(12),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.3),
                                            Colors.white.withOpacity(0.15),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(25),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.6),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                                0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        category['name'],
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          letterSpacing: 0.8,
                                          height: 1.2,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 8,
                                              color: Colors.black54,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Corner accent
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.4),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
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

// 🔹 Extracted Error State Widget
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Colors.grey, size: 48),
          const SizedBox(height: 16),
          Text(
            'Oops! Could not load categories',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                categories = fetchCategories();
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Extracted Bottom Nav Widget
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
        top: BorderSide(color: Colors.white, width: 1),
      ),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF74C365)
            // UIColor(red: 255/255, green: 180/255, blue: 93/255, alpha: 1.0)
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite), label: 'Wishlist'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: 0,
        selectedItemColor: Colors.orangeAccent,
        // Changed to white for better visibility
        unselectedItemColor: Colors.white70,
        // Changed to white70 for better visibility
        backgroundColor: Colors.transparent,
        // Make background transparent
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        // Remove shadow
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: (index) {
          if (index == 0) {
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
    );
  }


  Widget buildRandomProducts() {
    return SizedBox(
      height: 260, // Slightly increased height for better proportions
      child: FutureBuilder<List<dynamic>>(
        future: randomProducts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                strokeWidth: 3,
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No products available',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final product = snapshot.data![index];
              final imagePath = product['image_path'] ?? product['imgpath'] ??
                  '';
              final price = product['price']?.toString() ?? 'N/A';
              final name = product['name'] ?? 'Unnamed Product';

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () {
                    final productId = product['id'];
                    final unitPrice = double.tryParse(price) ?? 0.0;
                    final originalUnitPrice = unitPrice + 10;
                    final quantity = _quantities[productId] ?? 1;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            Scaffold(
                              body: CheckoutScreen(
                                productId: productId,
                                productName: name,
                                productPrice: unitPrice,
                                description: product['description'] ??
                                    'No description',
                                imageUrl: imagePath,
                                quantity: quantity,
                              ),
                              bottomNavigationBar: BottomNavigationBar(
                                items: const <BottomNavigationBarItem>[
                                  BottomNavigationBarItem(
                                      icon: Icon(Icons.home), label: 'Home'),
                                  BottomNavigationBarItem(
                                      icon: Icon(Icons.shopping_cart),
                                      label: 'Cart'),
                                  BottomNavigationBarItem(
                                      icon: Icon(Icons.favorite),
                                      label: 'Wishlist'),
                                  BottomNavigationBarItem(
                                      icon: Icon(Icons.person),
                                      label: 'Profile'),
                                ],
                                currentIndex: 0,
                                selectedItemColor: const Color(0xFF4CAF50),
                                unselectedItemColor: Colors.grey,
                                backgroundColor: Colors.white,
                                type: BottomNavigationBarType.fixed,
                                showSelectedLabels: true,
                                showUnselectedLabels: true,
                                onTap: (index) {
                                  if (index == 0) {
                                    Navigator.pop(context);
                                  } else {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            MainScreen(initialIndex: index),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                      ),
                    );
                  },
                  child: Container(
                    width: 170,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Section
                        Stack(
                          children: [
                            Container(
                              height: 140,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.green.shade50,
                                    Colors.green.shade100,
                                  ],
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                                child: Image.network(
                                  imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.green.shade100,
                                            Colors.green.shade200,
                                          ],
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.image_outlined,
                                        size: 40,
                                        color: Colors.green.shade400,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            // Discount Badge
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade700,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '10% OFF',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            // Favorite Button
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.favorite_border,
                                  size: 16,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Content Section
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Product Name
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.grey.shade800,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                const SizedBox(height: 6),

                                // Rating
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.star,
                                            size: 12,
                                            color: Colors.amber.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '4.0',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const Spacer(),

                                // Price and Add Button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment
                                      .spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment
                                          .start,
                                      children: [
                                        Text(
                                          '₹$price',
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '₹${(double.parse(price) + 10)
                                              .toStringAsFixed(0)}',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                            decoration: TextDecoration
                                                .lineThrough,
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Add to Cart Button
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade600,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.green.withOpacity(
                                                0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget buildAllProducts() {
    return FutureBuilder<List<dynamic>>(
      future: allProducts,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
              strokeWidth: 3,
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'No products available',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final products = snapshot.data!;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(), // ✅ Disable internal scroll
          shrinkWrap: true, // ✅ Fit content height
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 per row
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.7,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final imagePath = product['image_path'] ?? product['imgpath'] ?? '';
            final price = product['price']?.toString() ?? 'N/A';
            final name = product['name'] ?? 'Unnamed Product';
            final productId = product['id'];
            final unitPrice = double.tryParse(price) ?? 0.0;
            final quantity = _quantities[productId] ?? 1;

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
                      imageUrl: imagePath,
                      quantity: quantity,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: Image.network(
                        imagePath,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 130,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.green.shade100,
                                  Colors.green.shade200,
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: Icon(
                              Icons.image_outlined,
                              size: 40,
                              color: Colors.green.shade400,
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey.shade800,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.star,
                                    size: 12, color: Colors.amber.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  '4.0',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '₹$price',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      '₹${(double.parse(price) + 10).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                        decoration:
                                        TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        // Adjust height to fit both tiles
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color.fromRGBO(85, 139, 47, 1),
          elevation: 0,
          flexibleSpace: Column(
            children: [
              // Top Tile
              Container(
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(85, 139, 47, 1),
                  border: Border(
                    bottom: BorderSide(color: Colors.white, width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/logo2.png',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag,
                                    color: Color.fromRGBO(85, 139, 47, 1),
                                    size: 24,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Maligaijamaan",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (
                                  context) => const ProfileOptionsScreen(),
                            ),
                          );
                          _loadUserProfile();
                        },
                        child: Row(
                          children: [
                            if (_isLoggedIn)
                              const Icon(
                                Icons.account_circle,
                                color: Colors.white,
                                size: 20,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              _displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Mid Tile
              MidTile(context),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSecondTile(context),
            const SizedBox(height: 5),

            if (_isSearching)
              Container(
                height: MediaQuery
                    .of(context)
                    .size
                    .height - 250,
                child: buildSearchResults(),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPromotionBanner(context),
                  Container(
                    height: 400,
                    child: buildCategoriesGrid(),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Text(
                      'Recommended Products',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  buildRandomProducts(),
             const SizedBox(height: 15),
                  const Padding(
                      padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Text(
                      'Maligaijaman Products',

                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  buildAllProducts(),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

