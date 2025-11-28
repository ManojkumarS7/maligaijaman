import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';
import '../Users/cart_page.dart';
import '../Users/wishlist_screen.dart';
import '../Users/profile_page.dart';
import 'package:maligaijaman/apiconstants.dart';
import 'package:maligaijaman/appcolors.dart';


class AdminOrderslistScreen extends StatefulWidget {
  const AdminOrderslistScreen({Key? key}) : super(key: key);

  @override
  State<AdminOrderslistScreen> createState() => _AdminOrderslistScreenState();
}

class _AdminOrderslistScreenState extends State<AdminOrderslistScreen> {
  final _storage = const FlutterSecureStorage();
  bool isLoading = true;
  List<dynamic> orders = [];
  Map<String, dynamic> groupedOrders = {};
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse("${Appconfig.baseurl}api/admin_order_list.php");

      print(url);

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          setState(() {
            isLoading = false;
            orders = [];
            groupedOrders = {};
          });
          return http.Response('[]', 200);
        },
      );

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        try {
          String responseBody = response.body.trim();

          // Check if the response starts with "JSON" (invalid response case)
          if (responseBody.startsWith('JSON')) {
            responseBody = responseBody.substring(4).trim();
          }

          if (responseBody.isEmpty) {
            setState(() {
              isLoading = false;
              orders = [];
              groupedOrders = {};
            });
            return;
          }

          // Parse JSON response
          final List<dynamic> ordersList = json.decode(responseBody);

          setState(() {
            orders = ordersList;
            groupOrdersByOrderId(ordersList);
            isLoading = false;
          });
        } catch (e) {
          print("Error parsing JSON: $e");
          setState(() {
            isLoading = false;
            orders = [];
            groupedOrders = {};
          });
        }
      } else {
        setState(() {
          isLoading = false;
          orders = [];
          groupedOrders = {};
        });
      }
    } catch (e) {
      print("Error fetching orders: $e");
      setState(() {
        isLoading = false;
        orders = [];
        groupedOrders = {};
      });
    }
  }

  // Group orders by order_id
  void groupOrdersByOrderId(List<dynamic> ordersList) {
    Map<String, dynamic> grouped = {};

    for (var order in ordersList) {
      final orderID = order['order_id'] ?? 'NO ID';

      if (!grouped.containsKey(orderID)) {
        // Initialize a new group for this order ID
        grouped[orderID] = {
          'order_id': orderID,
          'items': 1,
          'total_amount': 0.0,
          'date': order['date_created'] ?? 'Unknown date',
          'status': order['order_status'] ?? 'Created', // FIXED: Use order_status
          'original_orders': [order],
        };
      } else {
        // Add to existing group
        grouped[orderID]['items'] += 1;
        grouped[orderID]['original_orders'].add(order);
      }

      // Calculate price for this item
      double price = 0.0;
      int qty = 1;

      try {
        final productPrice = order['product_price'] ?? '0';
        if (productPrice.toString().isNotEmpty) {
          price = double.parse(productPrice.toString());
        }
      } catch (e) {
        print("Error parsing price: $e");
      }

      try {
        final quantity = order['qty'] ?? '1';
        if (quantity.toString().isNotEmpty) {
          qty = int.parse(quantity.toString());
        }
      } catch (e) {
        print("Error parsing quantity: $e");
      }

      final itemTotal = price * qty;
      grouped[orderID]['total_amount'] += itemTotal;
    }

    groupedOrders = grouped;
  }

  // Get status color based on order status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "created":
        return Colors.blue;
      case "pending":
        return Colors.orange;
      case "confirmed":
        return Colors.green;
      case "processing":
        return Colors.purple;
      case "allocated":
        return Colors.indigo;
      case "on hold":
        return Colors.amber;
      case "dispatch":
      case "shipped":
        return Colors.teal;
      case "delivered":
        return Colors.green[700]!;
      case "cancelled":
        return Colors.red;
      case "returned":
        return Colors.deepOrange;
      case "refunded":
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  // Helper function to get order status text
  String getStatusText(String status) {
    // Just return the status as is since it's already properly formatted from API
    return status;
  }

  // Add a function to retry loading orders
  void retryFetchOrders() {
    setState(() {
      isLoading = true;
    });
    fetchOrders();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pop(context);
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CartScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => WishlistScreen()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfileScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Orders', style: TextStyle(color: Colors.white)),
        backgroundColor: Appcolor.Appbarcolor,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: retryFetchOrders,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
              Color.fromRGBO(85, 139, 47, 1)),
        ),
      )
          : groupedOrders.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No customer orders found",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "You haven't received any orders yet",
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Back to Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(85, 139, 47, 1),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: groupedOrders.length,
        separatorBuilder: (context, index) =>
        const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final orderId = groupedOrders.keys.elementAt(index);
          final orderGroup = groupedOrders[orderId];

          final String orderID = orderGroup['order_id'];
          final int itemCount = orderGroup['items'];
          final double totalAmount = orderGroup['total_amount'];
          final String date = orderGroup['date'];
          final String status = orderGroup['status'];

          // Get customer info from the first item in the order
          final firstOrder = orderGroup['original_orders'][0];
          final String customerName =
              firstOrder['user_name'] ?? 'Unknown'; // FIXED: Use user_name
          final String customerPhone =
              firstOrder['vendor_phone'] ?? 'N/A'; // This gets vendor phone from order

          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order header with status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Order #$orderID',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            getStatusText(status),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Customer Information
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person,
                                  size: 16, color: Colors.grey[700]),
                              SizedBox(width: 8),
                              Text(
                                'Customer: $customerName',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.phone,
                                  size: 16, color: Colors.grey[700]),
                              SizedBox(width: 8),
                              Text(
                                'Phone: $customerPhone',
                                style: TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Order details section
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.shopping_bag,
                                      size: 16,
                                      color: Colors.grey[700]),
                                  SizedBox(width: 8),
                                  Text(
                                    '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 16,
                                      color: Colors.grey[700]),
                                  SizedBox(width: 8),
                                  Text(
                                    '${date.toString().length >= 10 ? date.toString().substring(0, 10) : date}',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Price section
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${totalAmount > 0 ? totalAmount.toStringAsFixed(2) : "N/A"}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color:
                                Color.fromRGBO(85, 139, 47, 1),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      backgroundColor: Color(0xFFF5F7FA),
    );
  }
}