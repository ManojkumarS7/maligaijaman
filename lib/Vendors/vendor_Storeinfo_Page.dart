import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:maligaijaman/apiconstants.dart';

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
class VendorStoreInfoPage extends StatefulWidget {
  const VendorStoreInfoPage({Key? key}) : super(key: key);

  @override
  State<VendorStoreInfoPage> createState() => _VendorStoreInfoPageState();
}

class _VendorStoreInfoPageState extends State<VendorStoreInfoPage> {
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phonenoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeAddressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Store variables
  TimeOfDay _openingTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 21, minute: 0);
  List<StoreCategory> _availableCategories = [];
  List<StoreCategory> _selectedCategories = [];
  File? _logoImage;
  String? _existingLogoUrl;
  bool _isLoading = false;
  bool _isLoadingCategories = true;
  bool _isLoadingStoreData = true;
  bool _hasExistingStore = false;
  bool _isStoreApproved = false;
  String _approvalStatus = ''; // To store the raw status value
  String _submissionDate = ''; // To show when the store was submitted

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
    _fetchCategories();
  }

  @override
  void dispose() {
    // Dispose controllers
    _nameController.dispose();
    _phonenoController.dispose();
    _emailController.dispose();
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Store selected category IDs temporarily
  List<String> _selectedCategoryIds = [];

  void _matchSelectedCategories() {
    if (_selectedCategoryIds.isNotEmpty && _availableCategories.isNotEmpty) {
      setState(() {
        _selectedCategories = _availableCategories
            .where((category) => _selectedCategoryIds.contains(category.id))
            .toList();

        print('Selected categories matched: ${_selectedCategories.length}');
        _selectedCategories.forEach((cat) =>
            print('Category: ${cat.id} - ${cat.name}'));
      });
    }
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    final url = Uri.parse(
        "${Appconfig.baseurl}api/categorylist.php");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = json.decode(responseBody);

        setState(() {
          _availableCategories = data
              .where((item) => item['delete_flag']?.toString() == '0')
              .map((item) => StoreCategory.fromJson(item))
              .toList();

          print('Available categories: ${_availableCategories.length}');
          _isLoadingCategories = false;

          // Match selected categories by ID
          _matchSelectedCategories();
        });
      } else {
        throw Exception("Failed to load categories with status code: ${response
            .statusCode}");
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load categories: $e')),
      );
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _fetchStoreData() async {
    setState(() {
      _isLoadingStoreData = true;
    });

    try {
      final String? jwt = await _storage.read(key: 'jwt');
      final String? secretKey = await _storage.read(key: 'key');

      if (jwt == null || secretKey == null) {
        print('JWT: $jwt');
        print('Secret key: $secretKey');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Authentication error. Please login again')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      // Construct the URL with query parameters
      final url = Uri.parse(
        '${Appconfig.baseurl}api/store_list.php?jwt=$jwt&secretkey=$secretKey',
      );

      print('Fetching from URL: $url');
      final response = await http.get(url);
      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseBody = response.body;

          if (responseBody.contains('"store_name"')) {
            final jsonStartIndex = responseBody.indexOf('[');
            final jsonEndIndex = responseBody.lastIndexOf(']') + 1;

            if (jsonStartIndex >= 0 && jsonEndIndex > jsonStartIndex) {
              final jsonPart = responseBody.substring(
                  jsonStartIndex, jsonEndIndex);
              final List<dynamic> stores = json.decode(jsonPart);

              if (stores.isNotEmpty) {
                final storeData = stores[0];

                // Check the approval status
                final status = storeData['status']?.toString() ?? '0';

                setState(() {
                  _approvalStatus = status;
                  _isStoreApproved = status == '1';
                  _hasExistingStore = true;

                  // Get submission date if available
                  _submissionDate = storeData['created_at'] ?? 'Recently';

                  // Fill form with existing data
                  _nameController.text = storeData['name'] ?? '';
                  _phonenoController.text = storeData['phone'] ?? '';
                  _emailController.text = storeData['email'] ?? '';
                  _storeNameController.text = storeData['store_name'] ?? '';
                  _storeAddressController.text =
                      storeData['store_address'] ?? '';
                  _cityController.text = storeData['city'] ?? '';
                  _stateController.text = storeData['state'] ?? '';
                  _pincodeController.text = storeData['pincode'] ?? '';
                  _descriptionController.text = storeData['description'] ?? '';

                  // Parse opening time
                  if (storeData['opening_time'] != null) {
                    final openingTime = storeData['opening_time'].toString();
                    if (openingTime.contains(':')) {
                      final parts = openingTime.split(':');
                      if (parts.length >= 2) {
                        _openingTime = TimeOfDay(
                          hour: int.parse(parts[0]),
                          minute: int.parse(parts[1]),
                        );
                      }
                    }
                  }

                  // Parse closing time
                  if (storeData['closing_time'] != null) {
                    final closingTime = storeData['closing_time'].toString();
                    if (closingTime.contains(':')) {
                      final parts = closingTime.split(':');
                      if (parts.length >= 2) {
                        _closingTime = TimeOfDay(
                          hour: int.parse(parts[0]),
                          minute: int.parse(parts[1]),
                        );
                      }
                    }
                  }

                  // Handle logo if available
                  if (storeData['logo'] != null && storeData['logo']
                      .toString()
                      .isNotEmpty) {
                    _existingLogoUrl =
                    '${Appconfig.baseurl}uploads/store_logos/${storeData['logo']}';
                  }

                  // Handle categories
                  if (storeData['categories'] != null && storeData['categories']
                      .toString()
                      .isNotEmpty) {
                    final categoryString = storeData['categories'].toString();
                    print('Raw category string: $categoryString');

                    // Handle different formats of category data
                    _selectedCategoryIds = [];

                    if (categoryString.contains(',')) {
                      _selectedCategoryIds = categoryString.split(',');
                    } else {
                      _selectedCategoryIds = [categoryString];
                    }

                    print('Selected category IDs: $_selectedCategoryIds');

                    // If categories are already loaded, match them now
                    if (_availableCategories.isNotEmpty) {
                      _matchSelectedCategories();
                    }
                  }
                });

                // Show appropriate message based on status
                if (status == '0') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your store is waiting for approval'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              }
            }
          } else {
            print('No store data found in response');
            setState(() {
              _hasExistingStore = false;
              _isStoreApproved = false;
            });
          }
        } catch (parseError) {
          print('Error parsing response body: $parseError');
          setState(() {
            _hasExistingStore = false;
            _isStoreApproved = false;
          });
        }
      } else {
        print('Failed to fetch store data: ${response.statusCode}');
        setState(() {
          _hasExistingStore = false;
          _isStoreApproved = false;
        });
      }
    } catch (e) {
      print('Exception in fetchStoreData: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching store data: $e')),
      );
      setState(() {
        _hasExistingStore = false;
        _isStoreApproved = false;
      });
    } finally {
      setState(() {
        _isLoadingStoreData = false;
      });
    }
  }

  Future<void> _selectLogo() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _logoImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectOpeningTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _openingTime,
    );
    if (picked != null && picked != _openingTime) {
      setState(() {
        _openingTime = picked;
      });
    }
  }

  Future<void> _selectClosingTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _closingTime,
    );
    if (picked != null && picked != _closingTime) {
      setState(() {
        _closingTime = picked;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final hours = timeOfDay.hour.toString().padLeft(2, '0');
    final minutes = timeOfDay.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
  Future<void> _submitStoreInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one product category')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final String? vendorId = await _storage.read(key: 'vendor_id');
      if (vendorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Authentication error. Please login again')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      final Map<String, String> requestBody = {
        'vendor_id': vendorId,
        'store_name': _storeNameController.text,
        'store_address': _storeAddressController.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'pincode': _pincodeController.text,
        'description': _descriptionController.text,
        'opening_time': _formatTimeOfDay(_openingTime),
        'closing_time': _formatTimeOfDay(_closingTime),
        'categories': _selectedCategories.map((c) => c.id.toString()).join(','),
        'name1': _nameController.text,
        'email1': _emailController.text,
        'phone1': _phonenoController.text,
      };

      // For debugging - print the request data
      print('Submitting store info with data:');
      requestBody.forEach((key, value) => print('$key: $value'));

      // Send POST request
      final response = await http.post(
        Uri.parse('${Appconfig.baseurl}api/add_vendor.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: requestBody,
      );

      // Print the raw response for debugging
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      // Check if the response body is empty
      if (response.body.isEmpty) {
        throw Exception('Server returned an empty response');
      }

      // Safely parse the JSON response
      dynamic responseData;
      try {
        responseData = json.decode(response.body);
      } catch (e) {
        throw Exception('Failed to parse server response: $e\nResponse was: ${response.body}');
      }

      // Process the response
      if (response.statusCode == 200 &&
          responseData is Map<String, dynamic> &&
          (responseData['message'] == "Store Added successfully" ||
              responseData['message'] == "Store Updated successfully")) {
        // Refresh store data to get the latest status
        await _fetchStoreData();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_hasExistingStore
                ? 'Store information updated successfully!'
                : 'Store information submitted for approval!'),
            backgroundColor: Colors.green,
          ),
        );

        // If this is a new store submission, stay on the page to show the pending approval UI
        if (!_hasExistingStore) {
          setState(() {
            _hasExistingStore = true;
            _approvalStatus = '0'; // Set to pending
            _isStoreApproved = false;
          });
        } else {
          // If updating an existing store, go back to dashboard
          Navigator.of(context).pushReplacementNamed('/vendor_dashboard');
        }
      } else {
        // Handle error response
        String errorMessage = 'Failed to save store information';
        if (responseData is Map<String, dynamic> && responseData.containsKey('message')) {
          errorMessage = responseData['message'];
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Exception in submitStoreInfo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // Widget for showing pending approval UI
  Widget _buildWaitingForApprovalUI() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated waiting icon
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 2),
                builder: (context, value, child) {
                  return Transform.rotate(
                    angle: value * 6.28,
                    child: const Icon(
                      Icons.hourglass_top,
                      size: 80,
                      color: Color(0xFFFFC107),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Store Approval Pending',
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00677E),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFFFFA000),
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your store information has been submitted and is waiting for administrator approval. You will be notified once approved.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (_submissionDate.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Submitted on: $_submissionDate',
                        style: GoogleFonts.montserrat(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Display store logo if available
              if (_existingLogoUrl != null) ...[
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage(_existingLogoUrl!),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Show store details in read-only mode
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.store, color: Color(0xFF00677E)),
                          const SizedBox(width: 8),
                          Text(
                            'Store Details',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      _infoRow('Store Name', _storeNameController.text),
                      _infoRow('Address', _storeAddressController.text),
                      _infoRow('City', _cityController.text),
                      _infoRow('State', _stateController.text),
                      _infoRow('Pincode', _pincodeController.text),
                      _infoRow('Opening Time', _formatTimeOfDay(_openingTime)),
                      _infoRow('Closing Time', _formatTimeOfDay(_closingTime)),
                      if (_selectedCategories.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(
                                  'Categories:',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _selectedCategories.map((category) {
                                    return Chip(
                                      label: Text(category.name),
                                      backgroundColor: const Color(0xFFE0F2F1),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Refresh to check if approval status has changed
                      _fetchStoreData();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00677E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget for displaying store info rows in read-only mode
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.montserrat(),
            ),
          ),
        ],
      ),
    );
  }

  // Widget for the store form UI when editing or creating
  Widget _buildStoreFormUI() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Store Profile',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Owner Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _phonenoController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.mail),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email address';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),


              const SizedBox(height: 24),

              // Store Name
              TextFormField(
                controller: _storeNameController,
                decoration: InputDecoration(
                  labelText: 'Store Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.store),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your store name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Store Address
              TextFormField(
                controller: _storeAddressController,
                decoration: InputDecoration(
                  labelText: 'Store Address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your store address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // City and State
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pincode
              TextFormField(
                controller: _pincodeController,
                decoration: InputDecoration(
                  labelText: 'Pincode',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.pin),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter pincode';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Store Timings
              Text(
                'Store Timings',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectOpeningTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Opening Time',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.access_time),
                        ),
                        child: Text(_formatTimeOfDay(_openingTime)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _selectClosingTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Closing Time',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.access_time),
                        ),
                        child: Text(_formatTimeOfDay(_closingTime)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Product Categories
              Text(
                'Product Categories',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _isLoadingCategories
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: MultiSelectDialogField<StoreCategory>(
                  initialValue: _selectedCategories,
                  title: const Text('Select Categories'),
                  buttonText: const Text('Select Categories'),
                  items: _availableCategories
                      .map((category) =>
                      MultiSelectItem<StoreCategory>(
                          category, category.name))
                      .toList(),
                  listType: MultiSelectListType.CHIP,
                  onConfirm: (values) {
                    setState(() {
                      _selectedCategories = values;
                    });
                  },
                  chipDisplay: MultiSelectChipDisplay<StoreCategory>(
                    onTap: (item) {
                      setState(() {
                        _selectedCategories.remove(item);
                      });
                      return _selectedCategories;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Store Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Store Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: 'Tell customers about your store...',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 32),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _hasExistingStore
              ? _isStoreApproved
              ? 'Update Store Information'
              : 'Store Approval Pending'
              : 'Store Information',
        ),
        backgroundColor: const Color.fromRGBO(85, 139, 47, 1),
        actions: [
          if (_hasExistingStore && !_isStoreApproved)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchStoreData,
              tooltip: 'Refresh Status',
            ),
        ],
      ),
      backgroundColor: Colors.white,
      body: _isLoadingStoreData
          ? const Center(child: CircularProgressIndicator())
          : _hasExistingStore && _approvalStatus == '0'
          ? _buildWaitingForApprovalUI()
          : _buildStoreFormUI(),
    );
  }
}
