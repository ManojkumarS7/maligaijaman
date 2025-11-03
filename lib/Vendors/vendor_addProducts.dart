

import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maligaijaman/apiconstants.dart';

class Category {
  final String id;
  final String name;

  Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class SubCategory {
  final String id;
  final String categoryId;
  final String name;

  SubCategory({required this.id, required this.categoryId, required this.name});

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['id']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class VendorAddProductsPage extends StatefulWidget {
  @override
  _VendorAddProductsPageState createState() => _VendorAddProductsPageState();
}

class _VendorAddProductsPageState extends State<VendorAddProductsPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // Lists
  List<Category> categories = [];
  List<SubCategory> subcategories = [];
  List<SubCategory> filteredSubcategories = [];

  // Selected values
  Category? selectedCategory;
  SubCategory? selectedsubcategory;
  String unitType = 'kg';

  final _storage = const FlutterSecureStorage();

  // Form controllers
  TextEditingController productNameController = TextEditingController();
  TextEditingController productVariationController = TextEditingController();
  TextEditingController productPriceController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController productCodeController = TextEditingController();
  TextEditingController productQuantityController = TextEditingController();
  TextEditingController productStockController = TextEditingController();

  File? productImage;

  @override
  void initState() {
    super.initState();
    fetchCategories();
    fetchSubCategories();
  }

  Future<void> fetchCategories() async {
    final url = Uri.parse("${Appconfig.baseurl}api/categorylist.php");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = json.decode(responseBody);

        setState(() {
          categories = data
              .where((item) => item['delete_flag']?.toString() == '0')
              .map((item) => Category.fromJson(item))
              .toList();
        });
      } else {
        throw Exception("Failed to load categories: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load categories: $e')),
        );
      }
    }
  }

  Future<void> fetchSubCategories() async {
    final url = Uri.parse("${Appconfig.baseurl}api/subcategory_list.php");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = json.decode(responseBody);

        setState(() {
          subcategories = data
              .where((item) => item['delete_flag']?.toString() == '0')
              .map((item) => SubCategory.fromJson(item))
              .toList();
        });
      } else {
        throw Exception("Failed to load subcategories: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load subcategories: $e')),
        );
      }
    }
  }

  void filterSubcategories(String categoryId) {
    setState(() {
      filteredSubcategories = subcategories
          .where((subcat) => subcat.categoryId == categoryId)
          .toList();
      // Reset selected subcategory when category changes
      selectedsubcategory = null;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          productImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> addProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    if (selectedsubcategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a subcategory')),
      );
      return;
    }

    if (productImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a product image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get vendor ID from secure storage
      final String? vendorId = await _storage.read(key: 'vendor_id');

      if (vendorId == null || vendorId.isEmpty) {
        throw Exception("Vendor ID not found. Please login again.");
      }

      final url = Uri.parse('${Appconfig.baseurl}api/add_product.php');
      final request = http.MultipartRequest('POST', url);

      // Include vendor_id in request
      request.fields['vendor_id'] = vendorId;
      request.fields['product_name'] = productNameController.text.trim();
      request.fields['description'] = descriptionController.text.trim();
      request.fields['price'] = productPriceController.text.trim();
      request.fields['category_id'] = selectedCategory!.id;
      request.fields['subcategory_id'] = selectedsubcategory!.id;
      request.fields['product_code'] = productCodeController.text.trim();
      request.fields['product_variation_name'] = productVariationController.text.trim();
      request.fields['quantity'] = productQuantityController.text.trim();
      request.fields['stock'] = productStockController.text.trim();
      request.fields['unit'] = unitType;

      request.files.add(await http.MultipartFile.fromPath('image', productImage!.path));

      // For debugging
      print('Sending request with fields: ${request.fields}');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print('Raw response: $responseBody');

      Map<String, dynamic> responseData;
      try {
        final String cleanedResponse = responseBody.substring(responseBody.lastIndexOf('{'));
        responseData = json.decode(cleanedResponse);
      } catch (e) {
        print('JSON parsing error: $e');
        responseData = {
          'message': response.statusCode == 200
              ? 'Product added successfully'
              : 'Failed to add product'
        };
      }

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'Product added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'Failed to add product'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Add Product'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image Picker
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color.fromRGBO(85, 139, 47, 1),
                      radius: 50,
                      backgroundImage: productImage != null ? FileImage(productImage!) : null,
                      child: productImage == null
                          ? Icon(Icons.camera_alt, size: 40, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(85, 139, 47, 1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Category Dropdown
              DropdownButtonFormField<Category>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Select Category',
                  border: OutlineInputBorder(),
                ),
                items: categories.map((Category category) {
                  return DropdownMenuItem<Category>(
                    value: category,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (Category? newValue) {
                  setState(() {
                    selectedCategory = newValue;
                    if (newValue != null) {
                      filterSubcategories(newValue.id);
                    } else {
                      filteredSubcategories = [];
                      selectedsubcategory = null;
                    }
                  });
                },
                validator: (value) => value == null ? 'Please select a category' : null,
              ),
              SizedBox(height: 20),

              // SubCategory Dropdown
              DropdownButtonFormField<SubCategory>(
                value: selectedsubcategory,
                decoration: InputDecoration(
                  labelText: 'Select SubCategory',
                  border: OutlineInputBorder(),
                ),
                items: filteredSubcategories.map((SubCategory subcategory) {
                  return DropdownMenuItem<SubCategory>(
                    value: subcategory,
                    child: Text(subcategory.name),
                  );
                }).toList(),
                onChanged: filteredSubcategories.isEmpty ? null : (SubCategory? newValue) {
                  setState(() {
                    selectedsubcategory = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a subcategory' : null,
                hint: Text(selectedCategory == null
                    ? 'Select category first'
                    : filteredSubcategories.isEmpty
                    ? 'No subcategories available'
                    : 'Choose a subcategory'),
              ),
              SizedBox(height: 20),

              // Product Name
              TextFormField(
                controller: productNameController,
                decoration: InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter product name' : null,
              ),
              SizedBox(height: 20),

              // Product Variation
              TextFormField(
                controller: productVariationController,
                decoration: InputDecoration(
                  labelText: 'Product Variation',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter product variation' : null,
              ),
              SizedBox(height: 20),

              // Price
              TextFormField(
                controller: productPriceController,
                decoration: InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter price' : null,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),

              // Quantity
              TextFormField(
                controller: productQuantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter Quantity' : null,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),

              // Stock
              TextFormField(
                controller: productStockController,
                decoration: InputDecoration(
                  labelText: 'Stock',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter Stock' : null,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),

              // Unit Dropdown
              DropdownButtonFormField<String>(
                value: unitType,
                decoration: InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'mg', child: Text('mg')),
                  DropdownMenuItem(value: 'kg', child: Text('kg')),
                  DropdownMenuItem(value: 'g', child: Text('g')),
                  DropdownMenuItem(value: 'ml', child: Text('ml')),
                  DropdownMenuItem(value: 'L', child: Text('L')),
                  DropdownMenuItem(value: 'pc', child: Text('pc')),
                  DropdownMenuItem(value: 'pk', child: Text('pk')),
                  DropdownMenuItem(value: 'btl', child: Text('btl')),
                  DropdownMenuItem(value: 'can', child: Text('can')),
                  DropdownMenuItem(value: 'bx', child: Text('bx')),
                  DropdownMenuItem(value: 'ctn', child: Text('ctn')),
                  DropdownMenuItem(value: 'cs', child: Text('cs')),
                ],
                onChanged: (value) {
                  setState(() {
                    unitType = value!;
                  });
                },
              ),
              SizedBox(height: 20),

              // Product Code
              TextFormField(
                controller: productCodeController,
                decoration: InputDecoration(
                  labelText: 'Product Code',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter Product Code' : null,
              ),
              SizedBox(height: 20),

              // Description
              TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter description' : null,
                maxLines: 3,
              ),
              SizedBox(height: 24),

              // Submit Button
              Center(
                child: _isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(85, 139, 47, 1),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: addProduct,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: Text('Save Product'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    productNameController.dispose();
    productVariationController.dispose();
    productPriceController.dispose();
    descriptionController.dispose();
    productCodeController.dispose();
    productQuantityController.dispose();
    productStockController.dispose();
    super.dispose();
  }
}