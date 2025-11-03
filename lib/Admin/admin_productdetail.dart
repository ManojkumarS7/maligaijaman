

import 'dart:convert';
import 'dart:io'; // For File and IO operations
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart'; // For image picking
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maligaijaman/apiconstants.dart';

class AdminProductDetailPage extends StatefulWidget {
  final String productId;

  const AdminProductDetailPage({
    Key? key,
    required this.productId,
  }) : super(key: key);

  @override
  State<AdminProductDetailPage> createState() => _AdminProductDetailPageState();
}

class _AdminProductDetailPageState extends State<AdminProductDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic> _productDetail = {};
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  List<String> _quantityTypes = ['kg', 'g','mg', 'ml', 'L', 'pc', 'pk','btl','can','bx','ctn','cs'];

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _variationNameController = TextEditingController();
  final TextEditingController _productPriceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Selected values
  String? _selectedSubcategoryId;
  String? _selectedQuantityType;
  String? _selectedCategoryId;
  List<Category> categories = [];
  List<SubCategory> subcategories = [];
  String? _error;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to pick image")),
      );
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Take a Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchData() async {
    try {
      await Future.wait([
        _fetchProductDetail(),
        fetchCategories(),
        _fetchSubCategories(),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _fetchProductDetail() async {
    final url = Uri.parse("${Appconfig.baseurl}api/edit_product.php?id=${widget.productId}");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        print("Response Body: $responseBody");

        if (responseBody.startsWith('JSON')) {
          responseBody = responseBody.substring(4).trim();
        }

        final List<dynamic> responseData = json.decode(responseBody);

        if (responseData.isNotEmpty) {
          setState(() {
            _productDetail = responseData[0].cast<String, dynamic>();
            _populateFormFields();
          });
        }
      } else {
        throw Exception("Failed to load product details: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
      throw Exception("Failed to fetch product details: $e");
    }
  }

  Future<void> fetchCategories() async {
    setState(() {
      _error = null;
    });

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
        throw Exception("Failed to load categories with status code: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load categories: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load categories: $e')),
      );
    }
  }

  Future<void> _fetchSubCategories() async {
    setState(() {
      _error = null;
    });

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
        throw Exception("Failed to load subcategories with status code: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load subcategories: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load subcategories: $e')),
      );
    }
  }

  void _populateFormFields() {
    _nameController.text = _productDetail['name'] ?? '';
    _variationNameController.text = _productDetail['product_variation_name'] ?? '';
    _productPriceController.text = _productDetail['price']?.toString() ?? '';
    _quantityController.text = _productDetail['quantity']?.toString() ?? '';
    _stockController.text = _productDetail['stock']?.toString() ?? '';
    _barcodeController.text = _productDetail['barcode'] ?? '';
    _descriptionController.text = _productDetail['description']?.replaceAll('&lt;p&gt;', '').replaceAll('&lt;/p&gt;', '') ?? '';

    setState(() {
      _selectedQuantityType = _productDetail['quantity_type'] ?? _quantityTypes.first;

      // Handle category_id with potential space in the field name
      _selectedCategoryId = _productDetail['category_id '] ??
          _productDetail['category_id '] ?? '';  // Note the space in 'category_id '

      _selectedSubcategoryId = _productDetail['subcategory_id'] ?? '';

      print('Populated category ID: $_selectedCategoryId');
      print('Populated subcategory ID: $_selectedSubcategoryId');
    });
  }

  Future<void> _updateProducts() async {
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a category")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${Appconfig.baseurl}api/update_product.php"),
      );

      // Add text fields
      request.fields['id'] = widget.productId;
      request.fields['product_name'] = _nameController.text;
      request.fields['category_id'] = _selectedCategoryId!;
      request.fields['subcategory_id'] = _selectedSubcategoryId ?? '';
      request.fields['price'] = _productPriceController.text;
      request.fields['product_variation_name'] = _variationNameController.text;
      request.fields['quantity'] = _quantityController.text;
      request.fields['stock'] = _stockController.text;
      request.fields['unit'] = _selectedQuantityType ?? '';
      request.fields['product_code'] = _barcodeController.text;
      request.fields['description'] = _descriptionController.text;

      // Add image file if selected
      if (_imageFile != null) {
        print("Adding image file: ${_imageFile!.path}");
        request.files.add(
          await http.MultipartFile.fromPath(
            'image', // Field name for the image on the server
            _imageFile!.path,
            filename: 'product_image.jpg', // Add explicit filename
          ),
        );
      } else {
        // If no new image is selected, explicitly send a flag to keep the existing image
        request.fields['keep_existing_image'] = 'true';
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      print("Update response: ${response.body}");

      if (response.statusCode == 200) {
        // Check if response contains success message
        if (response.body.toLowerCase().contains('success') ||
            response.body.contains('updated') ||
            response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Product updated successfully")),
          );
          Navigator.pop(context, true); // Return true to trigger refresh
        } else {
          throw Exception("Server response: ${response.body}");
        }
      } else {
        throw Exception("Failed to update product: ${response.statusCode}, ${response.body}");
      }
    } catch (e) {
      print("Error updating product: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating product: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProduct() async {
    try {
      final url = Uri.parse("${Appconfig.baseurl}api/delete_product.php");
      final response = await http.post(
        url,
        body: {
          'id': widget.productId,
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Product deleted successfully")),
        );
        Navigator.pop(context, true); // Return true to trigger refresh
      } else {
        throw Exception("Failed to delete Product");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete Product: $e")),
      );
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Product"),
          content: Text("Are you sure you want to delete this Product?"),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.pop(context);
                _deleteProduct();
              },
            ),
          ],
        );
      },
    );
  }

  // Get filtered subcategories based on selected category
  List<SubCategory> getFilteredSubcategories() {
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      return [];
    }

    return subcategories
        .where((subcat) => subcat.categoryId == _selectedCategoryId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Product Detail')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Get filtered subcategories
    final filteredSubcategories = getFilteredSubcategories();

    // Check if current selectedSubcategoryId belongs to the current category
    bool isValidSubcategoryId = filteredSubcategories
        .any((subcat) => subcat.sid == _selectedSubcategoryId);

    // Reset subcategory if it's not valid for the selected category
    if (_selectedSubcategoryId != null && !isValidSubcategoryId && filteredSubcategories.isNotEmpty) {
      _selectedSubcategoryId = null;
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: Colors.blue),
        title: Text('Edit Product', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: _showDeleteConfirmation,
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image Section
            Stack(
              alignment: Alignment.center,
              children: [
                // Show either picked image or existing image
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _imageFile != null
                      ? Image.file(
                    _imageFile!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                      : _productDetail['image_path'] != null &&
                      _productDetail['image_path'].isNotEmpty
                      ? Image.network(
                    _productDetail['image_path'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.image_not_supported, size: 50),
                  )
                      : Icon(Icons.image_not_supported, size: 50),
                ),
                // Image picker button overlay
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.camera_alt, color: Colors.green),
                      onPressed: _showImagePickerOptions,
                      tooltip: 'Change Image',
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Product Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: categories.any((category) => category.id == _selectedCategoryId)
                  ? _selectedCategoryId
                  : null, // Ensure the value is in the list
              decoration: InputDecoration(
                labelText: 'Select Category',
                border: OutlineInputBorder(),
              ),
              items: categories.isNotEmpty
                  ? categories.map((Category category) {
                return DropdownMenuItem<String>(
                  value: category.id,
                  child: Text(category.name),
                );
              }).toList()
                  : [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('No category found'),
                )
              ],
              onChanged: categories.isNotEmpty
                  ? (value) {
                setState(() {
                  _selectedCategoryId = value;
                  _selectedSubcategoryId = null; // Reset subcategory when category changes
                });
              }
                  : null, // Disable dropdown if no categories exist
            ),

            SizedBox(height: 16),


            DropdownButtonFormField<String>(
              value: subcategories.any((subcat) => subcat.sid == _selectedSubcategoryId)
                  ? _selectedSubcategoryId
                  : null, // Ensure value is valid
              decoration: InputDecoration(
                labelText: 'Select Subcategory',
                border: OutlineInputBorder(),
              ),
              items: getFilteredSubcategories().isNotEmpty
                  ? getFilteredSubcategories().map((SubCategory subcat) {
                return DropdownMenuItem<String>(
                  value: subcat.sid,
                  child: Text(subcat.name),
                );
              }).toList()
                  : [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('No subcategory found'),
                )
              ],
              onChanged: getFilteredSubcategories().isNotEmpty
                  ? (value) {
                setState(() {
                  _selectedSubcategoryId = value;
                });
              }
                  : null, // Disable dropdown if no subcategories exist
            ),


            SizedBox(height: 16),

            // Variation Name
            TextField(
              controller: _variationNameController,
              decoration: InputDecoration(
                labelText: 'Product Variation Name',
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 16),

            // Product Price
            TextField(
              controller: _productPriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Product Price',
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 16),

            // Quantity
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 16),



            // Quantity Type Dropdown
            DropdownButtonFormField<String>(
              value: _selectedQuantityType,
              decoration: InputDecoration(
                labelText: 'Quantity Type',
                border: OutlineInputBorder(),
              ),
              items: _quantityTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedQuantityType = value;
                });
              },
            ),

            SizedBox(height: 16),

            // Stock
            TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Stock',
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 16),

            // Barcode
            TextField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Barcode',
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 32),

            // Update Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _updateProducts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Update Products', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _variationNameController.dispose();
    _productPriceController.dispose();
    _quantityController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

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
  final String sid;
  final String name;
  final String categoryId;

  SubCategory(
      {required this.sid, required this.name, required this.categoryId});

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      sid: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? '',
    );
  }
}

