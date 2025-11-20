
import 'package:flutter/material.dart';
import 'package:maligaijaman/Admin/admin_users.dart';
import 'package:maligaijaman/ProfileOption_page.dart';
import 'package:maligaijaman/Users/login_page.dart';
import 'package:maligaijaman/Vendors/Vendor_profile.dart';
import 'package:maligaijaman/main.dart';
import 'vendor_products.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'vendor_insights.dart';
import 'vendor_orders.dart';
import 'package:maligaijaman/Users/home_page.dart';
import 'package:maligaijaman/apiconstants.dart';


class StoreData {
  final String id;
  final String storeName;
  final String storeAddress;
  final String city;
  final String state;
  final String description;
  final String pincode;
  final String openingTime;
  final String closingTime;
  final String categories;
  final String status;
  final String name;
  final String phone;
  final String email;
  final String? accountHolderName;
  final String? accNumber;
  final String? bankName;
  final String? branch;
  final String? ifsc;

  StoreData({
    required this.id,
    required this.storeName,
    required this.storeAddress,
    required this.city,
    required this.state,
    required this.description,
    required this.pincode,
    required this.openingTime,
    required this.closingTime,
    required this.categories,
    required this.status,
    required this.name,
    required this.phone,
    required this.email,
    this.accountHolderName,
    this.accNumber,
    this.bankName,
    this.branch,
    this.ifsc,
  });

  factory StoreData.fromJson(Map<String, dynamic> json) {
    try {
      return StoreData(
        id: json['id']?.toString() ?? '',
        storeName: json['store_name']?.toString() ?? '',
        storeAddress: json['store_address']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        pincode: json['pincode']?.toString() ?? '',
        openingTime: json['opening_time']?.toString() ?? '',
        closingTime: json['closing_time']?.toString() ?? '',
        categories: json['categories']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        accountHolderName: json['account_holder_name']?.toString(),
        accNumber: json['Acc_Number']?.toString(),
        bankName: json['BankName']?.toString(),
        branch: json['Branch']?.toString(),
        ifsc: json['ifsc']?.toString(),
      );
    } catch (e) {
      print('Error parsing StoreData: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_name': storeName,
      'store_address': storeAddress,
      'city': city,
      'state': state,
      'description': description,
      'pincode': pincode,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'categories': categories,
      'status': status,
      'name': name,
      'phone': phone,
      'email': email,
      'account_holder_name': accountHolderName,
      'Acc_Number': accNumber,
      'BankName': bankName,
      'Branch': branch,
      'ifsc': ifsc,
    };
  }
}

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({Key? key}) : super(key: key);

  @override
  _VendorDashboardState createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final Color primaryGreen = const Color.fromRGBO(85, 139, 47, 1);
  final Color lightGreen = const Color.fromRGBO(85, 139, 47, 0.1);
  final Color darkGreen = const Color.fromRGBO(65, 119, 27, 1);

  bool isLoading = true;
  late StoreData storeData;
  String errorMessage = '';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )
      ..forward();
    fetchStoreData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }


  Future<void> fetchStoreData() async {
    try {
      final String? jwt = await _storage.read(key: 'jwt');
      final String? secretKey = await _storage.read(key: 'key');

      if (jwt == null || secretKey == null) {
        setState(() {
          errorMessage = 'Authentication tokens not found';
          isLoading = false;
        });
        return;
      }

      final apiUrl =
          'https://maligaijaman-app.staging-rdegi.com/api/store_list.php?jwt=$jwt&secretkey=$secretKey';
      print('API URL: $apiUrl');

      final request = http.Request('GET', Uri.parse(apiUrl))
        ..headers.addAll({
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        });

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      print('Status Code: ${streamedResponse.statusCode}');
      print('Response Headers: ${streamedResponse.headers}');
      print('Response Body: $responseBody');

      if (streamedResponse.statusCode == 200) {
        final decodedData = json.decode(responseBody);

        if (decodedData is List && decodedData.isNotEmpty) {
          setState(() {
            storeData = StoreData.fromJson(decodedData[0]);
            errorMessage = '';
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'No store data found';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage =
          'Failed to load data (Status: ${streamedResponse.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          brightness: Brightness.light,
        ),
      ),
      home: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: isLoading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading dashboard...',
                style: TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
            : errorMessage.isNotEmpty
            ? _buildErrorView()
            : _buildMainContent(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = '';
                });
                fetchStoreData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (storeData.status == "0") {
      return _buildApprovalPendingView();
    } else {
      return _buildDashboardView();
    }
  }

  Widget _buildApprovalPendingView() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 120,
          floating: false,
          pinned: true,
          backgroundColor: primaryGreen,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text(
              'Store Status',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryGreen, darkGreen],
                ),
              ),
            ),
          ),
          actions: [_buildLogoutButton()],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 5),
                    Text(
                      'Pending Approval',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your store is under review',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: lightGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Store Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                              Icons.store, 'Store Name', storeData.storeName),
                          _buildDetailRow(Icons.location_on, 'Address',
                              storeData.storeAddress),
                          _buildDetailRow(
                              Icons.location_city, 'City', storeData.city),
                          _buildDetailRow(Icons.map, 'State', storeData.state),
                          _buildDetailRow(
                              Icons.pin_drop, 'Pincode', storeData.pincode),
                          _buildDetailRow(Icons.access_time, 'Opening',
                              storeData.openingTime),
                          _buildDetailRow(Icons.access_time_filled, 'Closing',
                              storeData.closingTime),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Our team is reviewing your details. You\'ll be notified once approved.',
                              style: TextStyle(
                                fontSize: 14, // Increased from 8
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                          });
                          fetchStoreData();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Check Status'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade800,
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

  Widget _buildDashboardView() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 170,
          floating: false,
          pinned: true,
          backgroundColor: primaryGreen,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              'Welcome, ${storeData.name}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryGreen, darkGreen],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -50,
                    bottom: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [_buildLogoutButton()],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20.0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Your Store',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quick access to all your store operations',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          sliver: SliverGrid(
            delegate: SliverChildListDelegate([
              _buildModernCard(
                'Products',
                Icons.inventory_2_rounded,
                // 'Manage inventory',
                const Color(0xFF2196F3),
                VendorProductListScreen(),
                0,
              ),
              _buildModernCard(
                'Orders',
                Icons.shopping_bag_rounded,
                // 'View & fulfill',
                const Color(0xFF4CAF50),
                VendorOrdersScreen(),
                1,
              ),
              _buildModernCard(
                'Insights',
                Icons.insights_rounded,
                // 'Track performance',
                const Color(0xFFFF9800),
                SalesInsightsScreen(),
                2,
              ),
              _buildModernCard(
                'Profile',
                Icons.person_rounded,
                // 'Account settings',
                const Color(0xFF9C27B0),
                VendorProfileScreen(),
                3,
              ),
            ]),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 30,
              crossAxisSpacing: 16,
              childAspectRatio: 0.95,
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
      ],
    );
  }

  Widget _buildModernCard(String title,
      IconData icon,
      // String subtitle,
      Color color,
      Widget targetScreen,
      int index,) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Hero(
        tag: title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => targetScreen),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withOpacity(0.8),
                          color,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: color,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      offset: const Offset(0, 50),
      onSelected: (value) {
        if (value == 'logout') {
          _showLogoutDialog();
        }
      },
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                Icon(
                    Icons.logout_rounded, color: Colors.red.shade600, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ];
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.logout_rounded, color: primaryGreen),
                const SizedBox(width: 12),
                const Text('Logout'),
              ],
            ),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => HomeScreen()),
                        (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
    );
  }
}
