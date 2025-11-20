import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:maligaijaman/apiconstants.dart';
import 'package:maligaijaman/appcolors.dart';
import 'package:maligaijaman/Vendors/vendor_orders.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vendor Approval System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const VendorApprovalScreen(),
    );
  }
}

class StoreCategory {
  final String id;
  final String name;

  StoreCategory({
    required this.id,
    required this.name,
  });

  factory StoreCategory.fromJson(Map<String, dynamic> json) {
    return StoreCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class Vendor {
  final String id;
  final String storeName;
  final String description;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String openingTime;
  final String closingTime;
  final String categoryIds;
  String status;

  Vendor({
    required this.id,
    required this.storeName,
    required this.description,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.openingTime,
    required this.closingTime,
    required this.categoryIds,
    required this.status,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id']?.toString() ?? '',
      storeName: json['store_name']?.toString() ?? 'Unknown Store',
      description: json['description']?.toString() ?? '',
      address: json['store_address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      openingTime: json['opening_time']?.toString() ?? '',
      closingTime: json['closing_time']?.toString() ?? '',
      categoryIds: json['categories']?.toString() ?? '',
      status: json['status']?.toString() ?? '0',
    );
  }

  Vendor copyWith({String? newStatus}) {
    return Vendor(
      id: this.id,
      storeName: this.storeName,
      description: this.description,
      address: this.address,
      city: this.city,
      state: this.state,
      pincode: this.pincode,
      openingTime: this.openingTime,
      closingTime: this.closingTime,
      categoryIds: this.categoryIds,
      status: newStatus ?? this.status,
    );
  }
}

class VendorApprovalScreen extends StatefulWidget {
  const VendorApprovalScreen({Key? key}) : super(key: key);

  @override
  _VendorApprovalScreenState createState() => _VendorApprovalScreenState();
}

class _VendorApprovalScreenState extends State<VendorApprovalScreen>
    with SingleTickerProviderStateMixin {
  List<Vendor> vendors = [];
  List<StoreCategory> availableCategories = [];
  bool isLoading = true;
  bool isLoadingCategories = true;
  Map<String, String> categoriesMap = {};
  final secureStorage = FlutterSecureStorage();
  late TabController _tabController;
  String filterStatus = 'all';
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    fetchCategories().then((_) {
      fetchVendors();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      switch (_tabController.index) {
        case 0:
          filterStatus = 'all';
          break;
        case 1:
          filterStatus = '0';
          break;
        case 2:
          filterStatus = '1';
          break;
        case 3:
          filterStatus = '2';
          break;
      }
    });
  }

  Future<void> fetchCategories() async {
    setState(() {
      isLoadingCategories = true;
    });

    final url = Uri.parse("${Appconfig.baseurl}api/categorylist.php");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = json.decode(responseBody);

        setState(() {
          availableCategories = data
              .where((item) => item['delete_flag']?.toString() == '0')
              .map((item) => StoreCategory.fromJson(item))
              .toList();

          for (var category in availableCategories) {
            categoriesMap[category.id] = category.name;
          }

          print('Available categories: ${availableCategories.length}');
          isLoadingCategories = false;
        });
      } else {
        throw Exception(
            "Failed to load categories with status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load categories: $e')),
        );
        setState(() {
          isLoadingCategories = false;
        });
      }
    }
  }

  String getCategoryNameById(String categoryId) {
    if (categoryId.isEmpty) return 'No category';

    if (categoryId.contains(',')) {
      List<String> ids = categoryId.split(',');
      List<String> names =
      ids.map((id) => categoriesMap[id.trim()] ?? 'Unknown').toList();
      return names.join(', ');
    }

    return categoriesMap[categoryId] ?? 'Unknown category';
  }

  Future<void> fetchVendors() async {
    setState(() {
      isLoading = true;
    });

    final url = Uri.parse("${Appconfig.baseurl}api/store_list_admin.php");

    try {
      final response = await http.get(url);
      String responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(responseBody);

        setState(() {
          vendors = data.map((v) => Vendor.fromJson(v)).toList();
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load vendors: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to fetch vendors: $e")),
        );
      }
    }
  }

  Future<void> _confirmStatusChange(Vendor vendor, String newStatus) async {
    String statusText = newStatus == '1' ? 'approve' : 'disapprove';
    String statusTextPast = newStatus == '1' ? 'approved' : 'disapproved';

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm ${statusText.capitalize()}'),
        content: Text(
            'Are you sure you want to $statusText "${vendor.storeName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(statusText.toUpperCase()),
            style: TextButton.styleFrom(
              foregroundColor: newStatus == '1' ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: LinearProgressIndicator(),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final url = Uri.parse("${Appconfig.baseurl}api/shop_approve.php");
      final response = await http.post(
        url,
        body: {
          'vendor_id': vendor.id,
          'status': newStatus,
        },
      );

      ScaffoldMessenger.of(context).clearSnackBars();

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          setState(() {
            final index = vendors.indexWhere((v) => v.id == vendor.id);
            if (index != -1) {
              vendors[index] = vendor.copyWith(newStatus: newStatus);
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vendor $statusTextPast successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
              Text('Message: ${responseData['message'] ?? 'Unknown error'}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('HTTP Error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update vendor status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _navigateToVendorOrders(Vendor vendor) async {
    // Store vendor ID in secure storage
    await secureStorage.write(key: 'vendor_id', value: vendor.id);
    await secureStorage.write(key: 'vendor_name', value: vendor.storeName);

    // Navigate to orders screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VendorOrdersScreen(

          ),
        ),
      );
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case '0':
        return 'Pending';
      case '1':
        return 'Approved';
      case '2':
        return 'Disapproved';
      default:
        return 'Unknown';
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case '0':
        return Colors.orange;
      case '1':
        return Colors.green;
      case '2':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildActionButton(Vendor vendor) {
    final status = vendor.status;

    if (status == '1') {
      return ElevatedButton.icon(
        icon: const Icon(Icons.close, color: Colors.white),
        label: const Text('Disapprove'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        onPressed: () => _confirmStatusChange(vendor, '2'),
      );
    } else {
      return ElevatedButton.icon(
        icon: const Icon(Icons.check, color: Colors.white),
        label: const Text('Approve'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        onPressed: () => _confirmStatusChange(vendor, '1'),
      );
    }
  }

  String _formatTime(String time) {
    if (time.isEmpty) return 'Not specified';

    try {
      final timeValue = DateFormat('HH:mm:ss').parse(time.split('.')[0]);
      return DateFormat('h:mm a').format(timeValue);
    } catch (e) {
      return time.split('.')[0];
    }
  }

  Widget _buildInfoRow(String label, String value) {
    if (value.isEmpty) value = 'Not specified';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  List<Vendor> _getFilteredVendors() {
    return vendors.where((vendor) {
      if (filterStatus != 'all' && vendor.status != filterStatus) {
        return false;
      }

      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        return vendor.storeName.toLowerCase().contains(query) ||
            vendor.description.toLowerCase().contains(query) ||
            vendor.address.toLowerCase().contains(query) ||
            vendor.city.toLowerCase().contains(query) ||
            vendor.state.toLowerCase().contains(query) ||
            getCategoryNameById(vendor.categoryIds)
                .toLowerCase()
                .contains(query);
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredVendors = _getFilteredVendors();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Management',
            style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        backgroundColor: Appcolor.Appbarcolor,
        leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
            )),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search vendors...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        setState(() {
                          searchQuery = '';
                        });
                      },
                    )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  Tab(text: 'All (${vendors.length})'),
                  Tab(
                      text:
                      'Pending (${vendors.where((v) => v.status == '0').length})'),
                  Tab(
                      text:
                      'Approved (${vendors.where((v) => v.status == '1').length})'),
                  Tab(
                      text:
                      'Disapproved (${vendors.where((v) => v.status == '2').length})'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
            onPressed: () {
              fetchCategories().then((_) {
                fetchVendors();
              });
            },
            tooltip: 'Refresh vendor list',
          ),
        ],
      ),
      body: isLoading || isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : filteredVendors.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty
                  ? 'No vendors found matching "$searchQuery"'
                  : filterStatus == 'all'
                  ? 'No vendors found'
                  : 'No ${getStatusText(filterStatus).toLowerCase()} vendors found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: filteredVendors.length,
        padding: const EdgeInsets.all(8.0),
        itemBuilder: (context, index) {
          final vendor = filteredVendors[index];

          return Card(
            margin: const EdgeInsets.symmetric(
                vertical: 8.0, horizontal: 4.0),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 8.0),
              childrenPadding: const EdgeInsets.all(16.0),
              leading: CircleAvatar(
                backgroundColor: getStatusColor(vendor.status),
                child: Text(
                  vendor.storeName.isNotEmpty
                      ? vendor.storeName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                vendor.storeName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    getCategoryNameById(vendor.categoryIds),
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: getStatusColor(vendor.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          getStatusText(vendor.status),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ID: ${vendor.id}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    _buildInfoRow('Description', vendor.description),

                    // View Orders Button - Added here
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('View Receiving Orders'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Appcolor.Appbarcolor,
                          side: BorderSide(color: Appcolor.Appbarcolor),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onPressed: () => _navigateToVendorOrders(vendor),
                      ),
                    ),

                    const Divider(),
                    _buildInfoRow('Address', vendor.address),
                    _buildInfoRow('City', vendor.city),
                    _buildInfoRow('State', vendor.state),
                    _buildInfoRow('Pincode', vendor.pincode),
                    _buildInfoRow('Opening Time',
                        _formatTime(vendor.openingTime)),
                    _buildInfoRow('Closing Time',
                        _formatTime(vendor.closingTime)),
                    _buildInfoRow('Categories',
                        getCategoryNameById(vendor.categoryIds)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildActionButton(vendor),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}