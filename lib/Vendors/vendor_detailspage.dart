import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'vendorBankReg_Page.dart';
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

class VendorStoreRegPage extends StatefulWidget {
  const VendorStoreRegPage({Key? key}) : super(key: key);

  @override
  State<VendorStoreRegPage> createState() => _VendorStoreInfoPageState();
}

class _VendorStoreInfoPageState extends State<VendorStoreRegPage> {
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

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
  bool _isLoading = false;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    final url = Uri.parse("${Appconfig.baseurl}api/categorylist.php");
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
          _isLoadingCategories = false;
        });
      } else {
        throw Exception("Failed to load categories with status code: ${response.statusCode}");
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

  Future<void> _submitShopInformation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final storage = const FlutterSecureStorage();

      // Store each field with a clear prefix
      await storage.write(key: 'store_name', value: _storeNameController.text);
      await storage.write(key: 'store_address', value: _storeAddressController.text);
      await storage.write(key: 'city', value: _cityController.text);
      await storage.write(key: 'state', value: _stateController.text);
      await storage.write(key: 'pincode', value: _pincodeController.text);
      await storage.write(key: 'description', value: _descriptionController.text);
      await storage.write(key: 'opening_time', value: _formatTimeOfDay(_openingTime));
      await storage.write(key: 'closing_time', value: _formatTimeOfDay(_closingTime));
      await storage.write(key: 'categories', value: _selectedCategories.map((c) => c.id).join(','));

      // Verify storage
      final stored = await storage.readAll();
      print('Stored shop info: $stored');

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BankInformationPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving shop info: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Information'),
        backgroundColor:  Colors.green.shade700,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete Your Store Profile',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fill in the details below to set up your store',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // Store Logo
                Center(
                  child: Column(
                    children: [
                      InkWell(
                        onTap: _selectLogo,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 5,
                                color: Colors.black.withOpacity(0.2),
                                offset: const Offset(0, 2),
                              ),
                            ],
                            image: _logoImage != null
                                ? DecorationImage(
                              image: FileImage(_logoImage!),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: _logoImage == null
                              ? const Icon(
                            Icons.add_photo_alternate,
                            size: 40,
                            color: Color(0xFF00677E),
                          )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _selectLogo,
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Select Store Logo'),
                      ),
                    ],
                  ),
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
                        .map((category) => MultiSelectItem<StoreCategory>(
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

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null : _submitShopInformation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:  Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                        'Continue to Bank Information',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
