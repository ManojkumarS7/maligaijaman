
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import 'vendor_dashboard.dart';

class VendorPhoneAuthScreen extends StatefulWidget {
  final bool returnToProductPage;

  const VendorPhoneAuthScreen({Key? key, this.returnToProductPage = false}) : super(key: key);

  @override
  State<VendorPhoneAuthScreen> createState() => _VendorPhoneAuthScreenState();
}

class _VendorPhoneAuthScreenState extends State<VendorPhoneAuthScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  bool otpSent = false;
  bool isLoading = false;
  String? errorMessage;
  String? generatedOtp;
  Map<String, dynamic>? userResponse;

  Future<void> sendPhoneNumberToAPI() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final phone = phoneController.text.trim();

    try {
      final response = await http.post(
        Uri.parse('https://maligaijaman.rdegi.com/otp/vendor-otp.php'),
        // Uri.parse('https://cabnew.staging-rdegi.com/otp/check-otp.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'phone': phone},
      );

      if (response.statusCode == 200) {
        final data = response.body;

        // Try to decode full response
        try {
          final jsonData = json.decode(data);

          // Case 1: Invalid Mobile Number
          if (jsonData is Map && jsonData['message'] == 'Invalid Mobile Number') {
            setState(() {
              isLoading = false;
              errorMessage = "Invalid Mobile Number, please enter a registered number.";
            });
            return;
          }
        } catch (_) {
          // ignore here, since response may contain two concatenated JSONs
        }

        // Case 2: Success (two JSON objects concatenated)
        final parts = data.split('}');
        if (parts.length >= 2) {
          final jsonStr = '${parts[1]}}'; // second JSON
          final jsonData = json.decode(jsonStr);

          setState(() {
            generatedOtp = jsonData['OTP'].toString();
            userResponse = jsonData;
            otpSent = true;
            isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP sent successfully')),
          );
        } else {
          throw Exception("Unexpected API response format");
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> verifyOtpAndLogin() async {
    final enteredOtp = otpController.text.trim();

    if (enteredOtp.isEmpty) {
      setState(() => errorMessage = 'Please enter the OTP');
      return;
    }

    if (enteredOtp != generatedOtp) {
      setState(() => errorMessage = 'Incorrect OTP');
      return;
    }

    if (userResponse == null) {
      setState(() => errorMessage = 'Unexpected error occurred');
      return;
    }

    final jwt = userResponse!['jwt'];
    final secretKey = userResponse!['secretkey'];
    final userId = userResponse!['id']?.toString();

    try {
      if (jwt != null) await storage.write(key: 'jwt', value: jwt);
      if (secretKey != null) await storage.write(key: 'key', value: secretKey);
      if (userId != null) await storage.write(key: 'user_id', value: userId);

      onAuthSuccess();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to save credentials: ${e.toString()}';
      });
    }
  }

  void onAuthSuccess() {
    setState(() => isLoading = false);

    if (widget.returnToProductPage) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const VendorDashboard() ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Attractive green shades
    final primaryGreen = const Color(0xFF43A047); // vibrant medium green
    final accentGreen = const Color(0xFFA5D6A7);  // soft light green

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Phone Authentication'),
        backgroundColor: primaryGreen,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accentGreen.withOpacity(0.6), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Icon(Icons.verified_user, size: 80, color: primaryGreen),
                    const SizedBox(height: 12),
                    Text(
                      otpSent ? "Verify OTP" : "Enter Your Phone Number",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      enabled: !otpSent,
                    ),
                    if (!otpSent) ...[
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: isLoading ? null : sendPhoneNumberToAPI,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Send OTP', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                    if (otpSent) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: otpController,
                        decoration: InputDecoration(
                          labelText: 'Enter OTP',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.lock),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: isLoading ? null : verifyOtpAndLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Verify OTP', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            otpSent = false;
                            phoneController.clear();
                            otpController.clear();
                            errorMessage = null;
                          });
                        },
                        child: const Text('Change Phone Number'),
                      ),
                    ],
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
