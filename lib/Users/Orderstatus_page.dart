import 'package:flutter/material.dart';
import 'package:timeline_tile/timeline_tile.dart';

class OrderStatusScreen extends StatelessWidget {
  final Map<String, dynamic> orderDetails;

  const OrderStatusScreen({Key? key, required this.orderDetails})
      : super(key: key);

  // Helper function to get current status as integer
  int getCurrentStatusIndex() {
    final status = orderDetails['status'] ?? '1';
    return int.tryParse(status.toString()) ?? 1;
  }

  // Helper function to format date string
  String formatDate(String date) {
    if (date.length >= 10) {
      return date.substring(0, 10);
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    // Parse only essential order data
    final status = getCurrentStatusIndex();
    final date = orderDetails['date_created'] ?? orderDetails['created_at'] ??
        'Unknown date';
    final orderId = orderDetails['order_id'] ?? orderDetails['id'] ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Order Status",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF2E7D32),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ID and Date Card
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #$orderId',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ordered on:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        formatDate(date.toString()),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Method:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        orderDetails['payment_method'] ?? 'Cash on Delivery',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Order Status Timeline
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Order Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 16),

            // Timeline
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildTimelineTile(
                    isFirst: true,
                    isActive: status >= 1,
                    title: 'Order Placed',
                    subtitle: 'Your order has been received',
                    icon: Icons.receipt_long,
                  ),
                  _buildTimelineTile(
                    isActive: status >= 2,
                    title: 'Processing',
                    subtitle: 'Your order is being processed',
                    icon: Icons.inventory,
                  ),
                  _buildTimelineTile(
                    isActive: status >= 3,
                    title: 'Packed',
                    subtitle: 'Your order has been packed',
                    icon: Icons.inventory_2,
                  ),
                  _buildTimelineTile(
                    isActive: status >= 4,
                    title: 'Shipped',
                    subtitle: 'Your order is on the way',
                    icon: Icons.local_shipping,
                  ),
                  _buildTimelineTile(
                    isLast: true,
                    isActive: status >= 5,
                    title: 'Delivered',
                    subtitle: 'Your order has been delivered',
                    icon: Icons.check_circle,
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Expected delivery information
            if (status < 5) // Only show if not delivered yet
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFFFE082), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color:Color(0xFF2E7D32), size: 28),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimated Delivery',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _getEstimatedDeliveryDate(date.toString(), status),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Customer support
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need Help?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.support_agent, size: 20, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        'Contact Customer Support',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (status < 5) // Only show cancel button if not delivered
                    ElevatedButton(
                      onPressed: () {
                        _showCancelConfirmationDialog(context);
                      },
                      child: Text('Cancel Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red),
                        padding: EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Color(0xFFF5F7FA),
    );
  }

  // Helper method to build timeline tiles
  Widget _buildTimelineTile({
    bool isFirst = false,
    bool isLast = false,
    required bool isActive,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return TimelineTile(
      isFirst: isFirst,
      isLast: isLast,
      beforeLineStyle: LineStyle(
        color: isActive ? Color(0xFF2E7D32): Colors.grey.shade300,
        thickness: 2,
      ),
      afterLineStyle: LineStyle(
        color: isActive && !isLast ? Color(0xFF2E7D32) : Colors.grey.shade300,
        thickness: 2,
      ),
      indicatorStyle: IndicatorStyle(
        width: 30,
        height: 30,
        indicator: Container(
          decoration: BoxDecoration(
            color: isActive ? Color(0xFF2E7D32) : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
      endChild: Container(
        constraints: BoxConstraints(minHeight: 80),
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        margin: EdgeInsets.only(left: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.black : Colors.grey,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to estimate delivery date based on order date and status
  String _getEstimatedDeliveryDate(String orderDate, int status) {
    try {
      // Parse the date
      DateTime parsedDate = DateTime.parse(orderDate);

      // Add delivery time based on status
      // If status is already delivered, no need to calculate
      if (status >= 5) {
        return "Delivered";
      }

      // Otherwise calculate based on status
      switch (status) {
        case 1: // Order placed
          return "${formatDate(
              parsedDate.add(Duration(days: 7)).toString())} (in 7 days)";
        case 2: // Processing
          return "${formatDate(
              parsedDate.add(Duration(days: 5)).toString())} (in 5 days)";
        case 3: // Packed
          return "${formatDate(
              parsedDate.add(Duration(days: 3)).toString())} (in 3 days)";
        case 4: // Shipped
          return "${formatDate(
              parsedDate.add(Duration(days: 1)).toString())} (tomorrow)";
        default:
          return "${formatDate(
              parsedDate.add(Duration(days: 7)).toString())} (in 7 days)";
      }
    } catch (e) {
      return "Delivery date unavailable";
    }
  }

  // Show cancel confirmation dialog
  void _showCancelConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Cancel Order"),
          content: Text("Are you sure you want to cancel this order?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text("No"),
            ),
            TextButton(
              onPressed: () {
                // Handle order cancellation logic here
                Navigator.of(context).pop(); // Close dialog

                // Show cancellation confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Order cancellation request submitted"),
                    backgroundColor: Colors.red,
                  ),
                );

                // Navigate back to orders screen
                Navigator.of(context).pop();
              },
              child: Text("Yes, Cancel"),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }
}
