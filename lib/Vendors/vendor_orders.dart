import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';
import '../Users/cart_page.dart';
import '../Users/wishlist_screen.dart';
import '../Users/profile_page.dart';
import 'vendor_OrderDetail_Page.dart';
import 'package:maligaijaman/apiconstants.dart';
import 'package:maligaijaman/appcolors.dart';


class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({Key? key}) : super(key: key);

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
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
      final String? vendorId = await _storage.read(key: 'vendor_id');

      if (vendorId == null) {
        setState(() {
          isLoading = false;
          orders = [];
          groupedOrders = {};
        });
        return;
      }

      final url = Uri.parse(
          "${Appconfig.baseurl}api/vendor_order_list.php?vendor_id=$vendorId");

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
            // Handle this special case - maybe the actual JSON is after this prefix
            // Try to extract the actual JSON part
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
          'date': order['date_created'] ?? 'Unknown date',
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
        final productPrice = order['product_price'] ?? '0';
        if (productPrice
            .toString()
            .isNotEmpty) {
          price = double.parse(productPrice.toString());
        }
      } catch (e) {
        print("Error parsing price: $e");
      }

      try {
        final quantity = order['qty'] ?? '1';
        if (quantity
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
      case "Created":
        return "Created";
      case "Pending":
        return "Pending";
      case "Confirmed":
        return "Confirmed";
      case "Processing":
        return "Processing";
      case "Allocated":
        return "Allocated";
      case "On Hold":
        return "On Hold";
      case "Dispatch":
        return "Dispatch";
      case "Shipped":
        return "Shipped";
      case "Delivered":
        return "Delivered";
      case "Cancelled":
        return "Cancelled";
      case "Returned":
        return "Returned";
      case "Refunded":
        return "Refunded";
      default:
        return "Created";
    }
  }

  // // Helper method to determine status color
  // Color _getStatusColor(String status) {
  //   switch (status) {
  //     case "1":
  //       return Colors.blue; // Order placed
  //     case "2":
  //       return Colors.orange; // Processing
  //     case "3":
  //       return Colors.purple; // Shipped
  //     case "4":
  //       return Colors.green; // Delivered
  //     case "5":
  //       return Colors.red; // Cancelled
  //     default:
  //       return Colors.blue;
  //   }
  // }

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

  // Dialog to update order status
  void _showUpdateStatusDialog(String orderId, String currentStatus) {
    String selectedStatus = currentStatus;

    showDialog(

      context: context,
      builder: (context) =>
          StatefulBuilder(

            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: Text('Update Order Status'),

                 content:  SingleChildScrollView(

                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Order #$orderId'),
                          SizedBox(height: 10),
                          RadioListTile(
                            title: Text('Created'),
                            value: "Created",
                            groupValue: selectedStatus,
                            onChanged: (value) => setState(() => selectedStatus = value!),
                          ),
                          RadioListTile(
                            title: Text('Pending'),
                            value: "Pending",
                            groupValue: selectedStatus,
                            onChanged: (value) => setState(() => selectedStatus = value!),
                          ),
                          RadioListTile(
                            title: Text('Confirmed'),
                            value: "Confirmed",
                            groupValue: selectedStatus,
                            onChanged: (value) => setState(() => selectedStatus = value!),
                          ),
                          RadioListTile(
                            title: Text('Processing'),
                            value: "Processing",
                            groupValue: selectedStatus,
                            onChanged: (value) => setState(() => selectedStatus = value!),
                          ),
                          RadioListTile(
                            title: Text('Allocated'),
                            value: "Allocated",
                            groupValue: selectedStatus,
                            onChanged: (value) => setState(() => selectedStatus = value!),
                          ),
                          RadioListTile(
                            title: Text('On Hold'),
                            value: "On Hold",
                            groupValue: selectedStatus,
                            onChanged: (value) => setState(() => selectedStatus = value!),
                          ),
                          RadioListTile(
                            title: Text('Dispatch'),
                            value: "Dispatch",
                            groupValue: selectedStatus,
                            onChanged: (value) => setState(() => selectedStatus = value!),
                          ),
                          RadioListTile(
                            title: Text('Shipped'),
                            value: "Shipped",
                            groupValue: selectedStatus,
                            onChanged: (value) => setState(() => selectedStatus = value!),
                          ),
                          RadioListTile(
                            title: Text('Delivered'),
                            value: "Delivered",
                            groupValue: selectedStatus,
                            onChanged: (value) => setState(() => selectedStatus = value!),
                          ),
                          RadioListTile(
                            title: Text('Cancelled'),
                            value: "Cancelled",
                            groupValue: selectedStatus,
                            onChanged: (value) => setState(() => selectedStatus = value!),
                          ),
                          RadioListTile(
                            title: Text('Returned'),
                            value: "Returned",
                            groupValue: selectedStatus,
                            onChanged: (value) => setState(() => selectedStatus = value!),
                          ),
                          RadioListTile(
                            title: Text('Refunded'),
                            value: "Refunded",
                            groupValue: selectedStatus,
                            onChanged: (value) => setState(() => selectedStatus = value!),
                          ),
                        ],
                      ),
                    ),
                  ),

                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',style: TextStyle(color: Colors.redAccent),),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Close dialog
                      Navigator.pop(context);

                      // Call update status method
                      _updateOrderStatus(orderId, selectedStatus);
                    },
                    child: Text('Update'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromRGBO(85, 139, 47, 1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      setState(() {
        isLoading = true;
      });

      final String? vendorId = await _storage.read(key: 'vendor_id');

      if (vendorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vendor ID not found')),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      final url = Uri.parse("${Appconfig.baseurl}api/update_vendor_order_status.php");

      print("Request URL: $url");

      // Prepare form-data body
      final Map<String, String> bodyData = {
        "vendor_id": vendorId,
        "order_id": orderId,
        "order_status": newStatus,
      };

      final response = await http
          .post(
        url,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Accept": "application/json",
        },
        body: bodyData,
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Request timed out. Please try again.')),
          );
          setState(() {
            isLoading = false;
          });

          return http.Response(
            '{"status":"error","message":"Timeout"}',
            408,
          );
        },
      );

      print("Update status response: ${response.body}");

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);

          if (data['status'] == 'success') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Order status updated successfully')),
            );

            fetchOrders();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? 'Failed to update status')),
            );
            setState(() {
              isLoading = false;
            });
          }
        } catch (e) {
          print("JSON Parse Error: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating order status')),
          );
          setState(() {
            isLoading = false;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error. Failed to update status.')),
        );
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Exception: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong')),
      );
      setState(() {
        isLoading = false;
      });
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
        title: Text('Vendor Orders', style: TextStyle(color: Colors.white),),
        backgroundColor: Appcolor.Appbarcolor,

        actions: [
          // Add refresh button
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: retryFetchOrders,
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color.fromRGBO(85, 139, 47, 1)),
      ))
          : groupedOrders.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store,
              size: 80,
              color: Colors.grey,
            ),
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
                // Navigate back to vendor dashboard
                Navigator.of(context).pop();
              },
              child: Text('Back to Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(85, 139, 47, 1),
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

          // Get customer info from the first item in the order
          final firstOrder = orderGroup['original_orders'][0];
          final String customerName = firstOrder['name'] ?? 'Unknown';
          final String customerPhone = firstOrder['phone'] ?? 'N/A';

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
                    builder: (context) => VendorOrderDetailPage(orderId: orderID),
                  ),
                );
              },
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
                            // color: _getStatusColor(status),
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

                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer Information
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: Colors.grey[700]),
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
                              Icon(Icons.phone, size: 16, color: Colors.grey[700]),
                              SizedBox(width: 8),
                              Text(
                                'Phone: $customerPhone',
                                style: TextStyle(
                                  fontSize: 15,
                                ),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.shopping_bag, size: 16,
                                      color: Colors.grey[700]),
                                  SizedBox(width: 8),
                                  Text(
                                    '$itemCount ${itemCount == 1
                                        ? 'item'
                                        : 'items'}',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16,
                                      color: Colors.grey[700]),
                                  SizedBox(width: 8),
                                  Text(
                                    '${date
                                        .toString()
                                        .length >= 10 ? date.toString()
                                        .substring(0, 10) : date}',
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
                              '₹${totalAmount > 0 ? totalAmount.toStringAsFixed(
                                  2) : "N/A"}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(85, 139, 47, 1), // Golden yellow color
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

                    // Action buttons
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(width: 12),

                        // Only show update status button if not delivered or cancelled
                        if (status != "4" && status != "5")
                          ElevatedButton.icon(
                            icon: Icon(Icons.update),
                            label: Text('Update Status'),
                            onPressed: () {
                              _showUpdateStatusDialog(orderID, status);

                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromRGBO(85, 139, 47, 1),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
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
