import 'package:flutter/material.dart';
import 'myOrders_page.dart';
import '../main.dart';
import 'home_page.dart';
import 'package:maligaijaman/apiconstants.dart';
import 'package:maligaijaman/appcolors.dart';

class OrderSuccessPage extends StatelessWidget {
  const OrderSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar without a back button
      appBar: AppBar(
        title: const Text("Order Success"),
        backgroundColor: Appcolor.Appbarcolor,
        automaticallyImplyLeading: false, // 👈 Hides the back button
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 100),
            const SizedBox(height: 16),
            const Text(
              "Your order was successful!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            // ✅ Check Order Status Button
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Navigate to order status screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyOrdersScreen()),
                );

              },
              icon: const Icon(Icons.assignment),
              label: const Text("Check Order Status"),
              style: ElevatedButton.styleFrom(
                backgroundColor:  Color(0xFF00677E),
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 12),


            TextButton(
    onPressed: () {
    Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => MainScreen()), // Replace with your actual Home widget
    (route) => false,
    );
    },
              child: const Text(
                "Back to Home",
                style: TextStyle(color: Color(0xFF00677E)),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
