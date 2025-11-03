import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';
import 'cart_page.dart';
import 'wishlist_screen.dart';
import 'profile_page.dart';
import 'order_DetailScreen.dart';
import 'package:maligaijaman/apiconstants.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({Key? key}) : super(key: key);

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
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
    try {
      final String? jwt = await _storage.read(key: 'jwt');
      final String? secretKey = await _storage.read(key: 'key');
      final String? userId = await _storage.read(key: 'user_id');

      if (jwt == null || secretKey == null) {
        // Don't show error, just handle as no orders
        setState(() {
          isLoading = false;
          orders = [];
          groupedOrders = {};
        });
        return;
      }

      final url = Uri.parse(
          "${Appconfig.baseurl}api/conformorder.php?jwt=$jwt&secretkey=$secretKey");

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          // Handle timeout without showing error
          setState(() {
            isLoading = false;
            orders = [];
            groupedOrders = {};
          });
          return http.Response(
              '[]', 200); // Return empty array to prevent further processing
        },
      );

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        try {
          // Handle empty response
          if (response.body
              .trim()
              .isEmpty) {
            setState(() {
              isLoading = false;
              orders = [];
              groupedOrders = {};
            });
            return;
          }

          // Parse JSON response
          final dynamic decodedData = json.decode(response.body);

          if (decodedData is List) {
            // Direct list of orders
            setState(() {
              orders = decodedData;
              groupOrdersByOrderId(decodedData);
              isLoading = false;
            });
          } else if (decodedData is Map) {
            // Handle case where response is a map that might contain orders
            final possibleOrdersList = decodedData.values.firstWhere(
                    (v) => v is List,
                orElse: () => []
            );

            final ordersList = possibleOrdersList is List
                ? possibleOrdersList
                : [];
            setState(() {
              orders = ordersList;
              groupOrdersByOrderId(ordersList);
              isLoading = false;
            });
          } else {
            // Unknown format, treat as no orders
            setState(() {
              isLoading = false;
              orders = [];
              groupedOrders = {};
            });
          }
        } catch (e) {
          // JSON parsing error, treat as no orders
          print("Error parsing JSON: $e");
          setState(() {
            isLoading = false;
            orders = [];
            groupedOrders = {};
          });
        }
      } else {
        // Any HTTP error, treat as no orders
        setState(() {
          isLoading = false;
          orders = [];
          groupedOrders = {};
        });
      }
    } catch (e) {
      // Any exception, treat as no orders
      print("Error fetching orders: $e");
      setState(() {
        isLoading = false;
        orders = [];
        groupedOrders = {};
      });
    }
  }

  // New method to group orders by order_id
  void groupOrdersByOrderId(List<dynamic> ordersList) {
    Map<String, dynamic> grouped = {};

    for (var order in ordersList) {
      final orderID = order['order_id'] ?? 'NO ID';

      if (!grouped.containsKey(orderID)) {
        // Initialize a new group for this order ID
        grouped[orderID] = {
          'order_id': orderID,
          'items': 1,
          // Count of items
          'total_amount': 0.0,
          // Total amount for this order
          'date': order['date_created'] ?? order['created_at'] ??
              'Unknown date',
          'status': order['status'] ?? '1',
          'original_orders': [order],
          // Keep original order data for details view
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
        final productPrice = order['price'] ?? order['product_price'] ?? '0';
        if (productPrice != null && productPrice
            .toString()
            .isNotEmpty) {
          price = double.parse(productPrice.toString());
        }
      } catch (e) {
        print("Error parsing price: $e");
      }

      try {
        final quantity = order['Product_qty'] ?? order['quantity'] ?? '1';
        if (quantity != null && quantity
            .toString()
            .isNotEmpty) {
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

  // Helper function to get order status text
  String getStatusText(String status) {
    switch (status) {
      case "1":
        return "Order placed";
      case "2":
        return "Processing";
      case "3":
        return "Shipped";
      case "4":
        return "Delivered";
      case "5":
        return "Cancelled";
      default:
        return "Order placed";
    }
  }

  // Add a function to retry loading orders
  void retryFetchOrders() {
    setState(() {
      isLoading = true;
    });
    fetchOrders();
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          " My Orders",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF2E7D32), // Golden yellow color
        elevation: 0,
        actions: [
          // Add refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: retryFetchOrders,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
      ))
          : groupedOrders.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              "No orders found",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "You haven't placed any orders yet",
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Navigate to shopping page
                Navigator.of(context).pop();
              },
              child: Text('Start Shopping'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: groupedOrders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final orderId = groupedOrders.keys.elementAt(index);
          final orderGroup = groupedOrders[orderId];

          final String orderID = orderGroup['order_id'];
          final int itemCount = orderGroup['items'];
          final double totalAmount = orderGroup['total_amount'];
          final String date = orderGroup['date'];
          final String status = orderGroup['status'];

          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              // Make the entire card clickable
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailPage(orderId: orderID),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 16),
                    // Order details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order ID: $orderID',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Items: $itemCount',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ordered on: ${date
                                .toString()
                                .length >= 10
                                ? date.toString().substring(0, 10)
                                : date}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${totalAmount > 0
                                ? totalAmount.toStringAsFixed(2)
                                : "N/A"}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32), // Golden yellow color
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Order status with tap indicator
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            getStatusText(status),
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                        // Visual tap indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility,
                              size: 14,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "View Details",
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
