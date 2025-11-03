

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:maligaijaman/Vendors/vendor_login.dart';
import 'dart:io';
import 'vendor_dashboard.dart';
import 'package:maligaijaman/apiconstants.dart';

class BusinessIdPage extends StatefulWidget {
  @override
  _BusinessIdPageState createState() => _BusinessIdPageState();
}

class _BusinessIdPageState extends State<BusinessIdPage> {
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final TextEditingController _businessIdController = TextEditingController();

  bool _isLoading = false;
  File? _selectedImage;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitAllData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // First store the business ID
      await _storage.write(
          key: 'business_id', value: _businessIdController.text);

      // Retrieve ALL stored values at once
      final allValues = await _storage.readAll();

      // Debug: Print all stored values to verify
      print('Stored values: $allValues');

      // Prepare the complete payload with all required fields
      final payload = {
        'name': allValues['vendor_name'] ?? '',
        'username': allValues['vendor_email'] ?? '',
        'password': allValues['vendor_password'] ?? '',
        'phone': allValues['vendor_phone'] ?? '',
        'store_name': allValues['store_name'] ?? '',
        'store_address': allValues['store_address'] ?? '',
        'city': allValues['city'] ?? '',
        'state': allValues['state'] ?? '',
        'categories': allValues['categories'] ?? '',
        'description': allValues['description'] ?? '',
        'pincode': allValues['pincode'] ?? '',
        'opening_time': allValues['opening_time'] ?? '',
        'closing_time': allValues['closing_time'] ?? '',
        'acc_holder_name': allValues['acc_holder_name'] ?? '',
        'acc_no': allValues['acc_no'] ?? '',
        'bank_name': allValues['bank_name'] ?? '',
        'branch': allValues['branch'] ?? '',
        'ifsc': allValues['ifsc'] ?? '',
        'business_id': allValues['business_id'] ?? '',
      };

      // Debug: Print the payload before sending
      print('Final payload: $payload');

      // Make the POST request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://maligaijaman.rdegi.com/api/vendor_signup.php'),
      );

      // Add all fields
      payload.forEach((key, value) {
        request.fields[key] = value;
      });

      // Add image file
      if (_selectedImage != null) {
        final file = await http.MultipartFile.fromPath(
          'image', // This should match your API's expected field name
          _selectedImage!.path,
        );
        request.files.add(file);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Fix for malformed JSON response
        String responseBody = response.body;
        print('Raw response: $responseBody');

        // Attempt to safely parse the response
        Map<String, dynamic> responseData;
        try {
          responseData = json.decode(responseBody);
        } catch (e) {
          // If standard parsing fails, attempt to extract message from malformed JSON
          if (responseBody.contains('"message"')) {
            final messageMatch = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(responseBody);
            if (messageMatch != null && messageMatch.groupCount >= 1) {
              final message = messageMatch.group(1);
              responseData = {'message': message};
            } else {
              responseData = {'message': 'Could not parse server response'};
            }
          } else {
            responseData = {'message': 'Received malformed response from server'};
          }
        }

        // Check for user already exists message specifically
        if (responseBody.contains("User Name Already Exist")) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User name already exists. Please use a different email address.')),
          );
          return;
        }

        // Check for the specific success message you're looking for
        if (responseData['message'] == 'User registered successfully') {
          // Clean up temporary data
          await _cleanupSignupData();

          // Navigate to dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VendorLoginScreen(),
            ),
          );
          return;
        }

        // Check for other success responses
        if (responseData['User registered successfully'] == true ||
            (responseData['message'] != null &&
                responseData['message'].toString().toLowerCase().contains('User registered successfully'))) {

          // Store authentication tokens if they exist
          if (responseData.containsKey('jwt')) {
            await _storage.write(key: 'jwt', value: responseData['jwt'].toString());
          }
          if (responseData.containsKey('secretkey')) {
            await _storage.write(key: 'key', value: responseData['secretkey'].toString());
          }
          if (responseData.containsKey('vendor_id')) {
            await _storage.write(
                key: 'vendor_id', value: responseData['vendor_id'].toString());
          }

          // Clean up temporary data
          await _cleanupSignupData();

          // Navigate to dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VendorLoginScreen(),
            ),
          );
        } else {
          // Show the message from the response or a default message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
                responseData['message'] ?? 'Signup failed. Please try again.')),
          );
        }
      } else {
        throw Exception(
            'Server responded with status code: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cleanupSignupData() async {
    // Remove all temporary signup data while keeping auth tokens
    final keysToRemove = [
      'vendor_name', 'vendor_email', 'vendor_password', 'vendor_phone',
      'store_name', 'store_address', 'city', 'state', 'pincode', 'description',
      'opening_time', 'closing_time', 'categories', 'acc_holder_name', 'acc_no',
      'bank_name', 'branch', 'ifsc', 'business_id'
    ];

    for (var key in keysToRemove) {
      await _storage.delete(key: key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Identification'),
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Please provide your business identification details',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _businessIdController,
                decoration: const InputDecoration(
                  labelText: 'Business ID/Registration Number',
                  hintText: 'Enter your business registration or tax ID',
                ),
                validator: (value) =>
                value?.isEmpty ?? true
                    ? 'Required'
                    : null,
              ),
              const SizedBox(height: 16),

              // Image upload section
              const Text(
                'Upload Business Document/Image',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _selectedImage == null
                      ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload, size: 40, color: Colors.grey),
                      Text('Tap to upload image'),
                    ],
                  )
                      : Image.file(_selectedImage!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedImage != null)
                TextButton(
                  onPressed: _pickImage,
                  child: const Text('Change Image'),
                ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitAllData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Complete Signup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}