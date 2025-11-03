import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:maligaijaman/apiconstants.dart';

class SalesInsightsScreen extends StatefulWidget {
  const SalesInsightsScreen({Key? key}) : super(key: key);

  @override
  State<SalesInsightsScreen> createState() => _SalesInsightsScreenState();
}

class _SalesInsightsScreenState extends State<SalesInsightsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _reportData = {
    'totalOrders': '0',
    'totalOrdersChange': 0,
    'ordersCompleted': '0',
    'ordersCompletedChange': 0,
    'ordersCancelled': '0',
    'ordersCancelledChange': 0,
    'totalRevenue': '₹0',
    'totalRevenueChange': 0,
    'averageOrderValue': '₹0',
    'averageOrderValueChange': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Replace with your actual API endpoint
      final response = await http.get(
        Uri.parse('https://your-api.com/sales/reports'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_AUTH_TOKEN', // Replace with actual auth method
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _reportData = {
            'totalOrders': data['totalOrders']?.toString() ?? '0',
            'totalOrdersChange': data['totalOrdersChange'] ?? 0,
            'ordersCompleted': data['ordersCompleted']?.toString() ?? '0',
            'ordersCompletedChange': data['ordersCompletedChange'] ?? 0,
            'ordersCancelled': data['ordersCancelled']?.toString() ?? '0',
            'ordersCancelledChange': data['ordersCancelledChange'] ?? 0,
            'totalRevenue': '₹${data['totalRevenue'] ?? 0}',
            'totalRevenueChange': data['totalRevenueChange'] ?? 0,
            'averageOrderValue': '₹${data['averageOrderValue'] ?? 0}',
            'averageOrderValueChange': data['averageOrderValueChange'] ?? 0,
          };
          _isLoading = false;
        });
      } else {
        _handleError('Failed to load data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      _handleError('Error fetching data: $e');
    }
  }

  void _handleError(String message) {
    setState(() {
      _isLoading = false;
    });

    // Show error snackbar
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(message),
    //     backgroundColor: Colors.red,
    //     action: SnackBarAction(
    //       label: 'Retry',
    //       onPressed: _fetchReports,
    //       textColor: Colors.white,
    //     ),
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFFC107),
        title: const Text(
          'Sales Insights',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        // backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchReports,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInsightCard(
                title: 'Total Orders',
                value: _reportData['totalOrders'],
                change: _reportData['totalOrdersChange'],
                iconBackgroundColor: const Color(0xFFFFF4E0),
                iconColor: Colors.orange,
                icon: Icons.shopping_cart,
              ),
              const SizedBox(height: 16),
              _buildInsightCard(
                title: 'Total Orders Completed',
                value: _reportData['ordersCompleted'],
                change: _reportData['ordersCompletedChange'],
                iconBackgroundColor: const Color(0xFFE8F5E9),
                iconColor: Colors.green,
                icon: Icons.check_circle,
              ),
              const SizedBox(height: 16),
              _buildInsightCard(
                title: 'Orders Cancelled',
                value: _reportData['ordersCancelled'],
                change: _reportData['ordersCancelledChange'],
                reverseMetric: true,  // Lower is better for cancellations
                iconBackgroundColor: const Color(0xFFFEEAEA),
                iconColor: Colors.red,
                icon: Icons.cancel,
              ),
              const SizedBox(height: 16),
              _buildInsightCard(
                title: 'Total Revenue',
                value: _reportData['totalRevenue'],
                change: _reportData['totalRevenueChange'],
                iconBackgroundColor: const Color(0xFFE3F2FD),
                iconColor: Colors.blue,
                icon: Icons.payments,
              ),
              const SizedBox(height: 16),
              _buildInsightCard(
                title: 'Average Order Value',
                value: _reportData['averageOrderValue'],
                change: _reportData['averageOrderValueChange'],
                iconBackgroundColor: const Color(0xFFE8F5E9),
                iconColor: Colors.green,
                icon: Icons.trending_up,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    required int change,
    bool isTimeMetric = false,
    bool reverseMetric = false,
    required Color iconBackgroundColor,
    required Color iconColor,
    required IconData icon,
  }) {
    // For normal metrics: positive change is good
    // For time metrics: negative change (less time) is good
    // For reverse metrics: negative change is good (like cancellations)
    final isPositive = reverseMetric ? change < 0 : (isTimeMetric ? change < 0 : change > 0);
    final isNegative = reverseMetric ? change > 0 : (isTimeMetric ? change > 0 : change < 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: isPositive ? Colors.green : (isNegative ? Colors.red : Colors.grey),
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                '${change.abs()}%',
                style: TextStyle(
                  color: isPositive ? Colors.green : (isNegative ? Colors.red : Colors.grey),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Vs last month',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Example of how to use this screen in your app
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sales Insights',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const SalesInsightsScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}