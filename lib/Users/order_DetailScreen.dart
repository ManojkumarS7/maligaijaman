import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maligaijaman/Users/Orderstatus_page.dart';
import 'package:maligaijaman/apiconstants.dart';
import 'package:maligaijaman/appcolors.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final _storage = const FlutterSecureStorage();
  bool isLoading = true;
  bool isReordering = false;
  List<dynamic> orderItems = [];
  double subtotal = 0.0;
  double deliveryCharge = 40.0;

  String? _jwt;
  String? _secretKey;
  String? _userid;
  String? _address;
  String? OrderStatus;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    fetchOrderDetails();
  }

  Future<void> _loadUserData() async {
    _jwt = await _storage.read(key: 'jwt');
    _secretKey = await _storage.read(key: 'key');
    _userid = await _storage.read(key: 'user_id');
    _address = await _storage.read(key: 'address');
  }

  Future<void> fetchOrderDetails() async {
    try {
      final String? jwt = await _storage.read(key: 'jwt');
      final String? secretKey = await _storage.read(key: 'key');

      if (jwt == null || secretKey == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final url = Uri.parse(
          "${Appconfig.baseurl}api/conformorder.php?jwt=$jwt&secretkey=$secretKey");
      print(url);

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () => http.Response('[]', 200),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> allOrders =
        data is List ? data : (data.values.firstWhere((v) => v is List,
            orElse: () => []));

        final filtered = allOrders
            .where((item) => item['order_id'] == widget.orderId)
            .toList();

        double total = 0.0;
        for (var item in filtered) {
          double price = 0.0;
          int qty = 1;

          try {
            final productPrice = item['price'] ?? item['product_price'] ?? '0';
            final quantity = item['Product_qty'] ?? item['quantity'] ?? '1';
          OrderStatus = item['order_status'] ?? 'Processing';

          print(OrderStatus);

            if (productPrice.toString().isNotEmpty) {
              price = double.parse(productPrice.toString());
            }

            if (quantity.toString().isNotEmpty) {
              qty = int.parse(quantity.toString());
            }

            total += price * qty;
          } catch (e) {
            print("Error calculating price: $e");
          }
        }

        setState(() {
          orderItems = filtered;
          subtotal = total;
          OrderStatus = OrderStatus;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _reorderProducts() async {

    if (orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No products to reorder'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isReordering = true;
    });

    try {
      final url = Uri.parse("${Appconfig.baseurl}api/conformorderinsert.php");
      int successCount = 0;
      int failCount = 0;

      for (var product in orderItems) {
        try {
          print("Reordering: ${product['Product_name']}");

          final response = await http.post(
            url,
            body: {
              "jwt": _jwt!,
              "secretkey": _secretKey!,
              "user_id": _userid ?? '',
              "productid": (product['product_id'] ?? product['productid'] ?? product['id'] ?? '').toString(),
              "productname": product['Product_name'] ?? product['product_name'] ?? '',
              "productprice": (product['price'] ?? product['product_price'] ?? '0').toString(),
              "price": (product['price'] ?? product['product_price'] ?? '0').toString(),
              "quantity": (product['Product_qty'] ?? product['quantity'] ?? '1').toString(),
              "qty": (product['Product_qty'] ?? product['quantity'] ?? '1').toString(),
              "vendor_id": (product['vendor_id'] ?? '').toString(),
              "is_from_cart": "0",
              "address": _address ?? '',
            },
          );

          print("Reorder Response (${response.statusCode}): ${response.body}");

          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
            // Check if response contains success indicator
            if (responseData is Map &&
                (responseData['success'] == true ||
                    responseData['status'] == 'success' ||
                    response.body.contains('success'))) {
              successCount++;
              print("Successfully reordered: ${product['Product_name']}");
            } else {
              failCount++;
              print("Failed to reorder: ${product['Product_name']}");
            }
          } else {
            failCount++;
            print("Failed to reorder: ${product['Product_name']} - Status: ${response.statusCode}");
          }
        } catch (e) {
          failCount++;
          print("Error reordering ${product['Product_name']}: $e");
        }
      }

      setState(() {
        isReordering = false;
      });

      // Show result
      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount > 0
                  ? 'Reordered $successCount items. $failCount failed.'
                  : 'Successfully reordered all $successCount items!',
            ),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View Orders',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reorder items. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isReordering = false;
      });
      print("Error in reorder process: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred while reordering'),
          backgroundColor: Colors.red,
        ),
      );
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
        title: const Text(
          "Order Details",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Appcolor.Appbarcolor,
        elevation: 0,

      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
      ))
          : orderItems.isEmpty
          ? _buildEmptyOrderView()
          : _buildOrderBillView(),
      backgroundColor: Color(0xFFF5F7FA),
    );
  }

  Widget _buildEmptyOrderView() {
    return Center(
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
              Navigator.of(context).pop();
            },
            child: Text('Start Shopping'),
            style: ElevatedButton.styleFrom(
              backgroundColor:Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderBillView() {
    final totalAmount = subtotal + deliveryCharge;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${widget.orderId}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // SizedBox(height: 4),
              // Text(
              //   'Status: $OrderStatus',
              //   style: TextStyle(
              //     // color: _getStatusColor(OrderStatus),
              //     fontWeight: FontWeight.w500,
              //   ),
              // ),
              SizedBox(height: 4),
              Text(
                'Date: ${orderItems.isNotEmpty
                    ? _formatDate(orderItems[0]['date_created'] ??
                    orderItems[0]['created_at'] ?? 'Unknown date')
                    : 'Unknown date'}',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orderItems.length,
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final order = orderItems[index];

              final productName = order['Product_name'] ??
                  order['product_name'] ?? 'Unknown Product';
              final productPrice = order['price'] ?? order['product_price'] ??
                  '0';
              final quantity = order['Product_qty'] ?? order['quantity'] ?? '1';
              final imagePath = order['img_path'] ?? order['image_path'] ??
                  order['image'] ?? '';

              double price = 0.0;
              int qty = 1;

              try {
                if (productPrice.toString().isNotEmpty) {
                  price = double.parse(productPrice.toString());
                }
              } catch (e) {
                print("Error parsing price: $e");
              }

              try {
                if (quantity.toString().isNotEmpty) {
                  qty = int.parse(quantity.toString());
                }
              } catch (e) {
                print("Error parsing quantity: $e");
              }

              final itemTotal = price * qty;

              return Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imagePath.toString(),
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported),
                            ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${price.toStringAsFixed(2)} × $qty',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${itemTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 8),

                        TextButton(
                              onPressed: () {
                                Map<String, dynamic> statusDetails = {
                                  'id': widget.orderId,
                                  'status': orderItems.isNotEmpty
                                      ? orderItems[0]['status'] ?? '1'
                                      : '1',
                                  'date_created': orderItems.isNotEmpty
                                      ? orderItems[0]['date_created'] ??
                                      orderItems[0]['created_at'] ?? DateTime.now().toString()
                                      : DateTime.now().toString(),
                                  'payment_method': orderItems.isNotEmpty
                                      ? orderItems[0]['payment_method'] ?? 'Cash on Delivery'
                                      : 'Cash on Delivery',
                                };

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        OrderStatusScreen(orderDetails: statusDetails),
                                  ),
                                );
                              },
                          child: Text(
                            "Status: $OrderStatus",
                            style: TextStyle(
                              color: Colors.green,        // text color
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )

                      ],
                    )
                    )

                    

                  ],
                ),
              );
            },
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    '₹${subtotal.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Delivery Charge',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    '₹${deliveryCharge.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₹${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isReordering ? null : _reorderProducts,
                  child: isReordering
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Reordering...'),
                    ],
                  )
                      : Text('Reorder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    disabledBackgroundColor: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.length >= 10) {
      return dateStr.substring(0, 10);
    }
    return dateStr;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}