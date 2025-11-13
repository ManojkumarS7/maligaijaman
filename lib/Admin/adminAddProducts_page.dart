
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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

class AddProductsPage extends StatefulWidget {
  @override
  _AddProductsPageState createState() => _AddProductsPageState();
}

class _AddProductsPageState extends State<AddProductsPage> {
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
    final url = Uri.parse(
        "${Appconfig.baseurl}api/categorylist.php");
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
    final url = Uri.parse(
        "${Appconfig.baseurl}api/subcategory_list.php");
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
      final url = Uri.parse(
          '${Appconfig.baseurl}api/add_product.php');
      final request = http.MultipartRequest('POST', url);

      request.fields['product_name'] = productNameController.text.trim();
      request.fields['description'] = descriptionController.text.trim();
      request.fields['price'] = productPriceController.text.trim();
      request.fields['category_id'] = selectedCategory!.id;
      request.fields['subcategory_id'] = selectedsubcategory!.id;
      request.fields['product_code'] = productCodeController.text.trim();
      request.fields['product_variation_name'] =
          productVariationController.text.trim();
      request.fields['quantity'] = productQuantityController.text.trim();
      request.fields['stock'] = productStockController.text.trim();
      request.fields['unit'] = unitType;

      request.files.add(
          await http.MultipartFile.fromPath('image', productImage!.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      Map<String, dynamic> responseData;
      try {
        final String cleanedResponse = responseBody.substring(
            responseBody.lastIndexOf('{'));
        responseData = json.decode(cleanedResponse);
      } catch (e) {
        print('JSON parsing error: $e');
        print('Raw response: $responseBody');
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
              content: Text(
                  responseData['message'] ?? 'Product added successfully'),
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
        backgroundColor: Color.fromRGBO(85, 139, 47, 1),
        foregroundColor: Colors.white,
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
                      backgroundColor: Colors.grey[300],
                      radius: 50,
                      backgroundImage: productImage != null ? FileImage(
                          productImage!) : null,
                      child: productImage == null
                          ? Icon(
                          Icons.camera_alt, size: 40, color: Colors.grey[600])
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.camera_alt, color: Colors.white,
                              size: 20),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Category Dropdown
              DropdownButtonFormField<Category>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Select Category *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
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
                validator: (value) =>
                value == null
                    ? 'Please select a category'
                    : null,
              ),
              SizedBox(height: 16),

              // SubCategory Dropdown
              DropdownButtonFormField<SubCategory>(
                value: selectedsubcategory,
                decoration: InputDecoration(
                  labelText: 'Select SubCategory *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.subdirectory_arrow_right),
                ),
                items: filteredSubcategories.map((SubCategory subcategory) {
                  return DropdownMenuItem<SubCategory>(
                    value: subcategory,
                    child: Text(subcategory.name),
                  );
                }).toList(),
                onChanged: filteredSubcategories.isEmpty ? null : (
                    SubCategory? newValue) {
                  setState(() {
                    selectedsubcategory = newValue;
                  });
                },
                validator: (value) =>
                value == null
                    ? 'Please select a subcategory'
                    : null,
                hint: Text(selectedCategory == null
                    ? 'Select category first'
                    : filteredSubcategories.isEmpty
                    ? 'No subcategories available'
                    : 'Choose a subcategory'),
              ),
              SizedBox(height: 16),

              // Product Name
              TextFormField(
                controller: productNameController,
                decoration: InputDecoration(
                  labelText: 'Product Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag),
                ),
                validator: (value) =>
                value!.isEmpty
                    ? 'Please enter product name'
                    : null,
              ),
              SizedBox(height: 16),

              // Product Variation
              TextFormField(
                controller: productVariationController,
                decoration: InputDecoration(
                  labelText: 'Product Variation *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.style),
                ),
                validator: (value) =>
                value!.isEmpty
                    ? 'Please enter product variation'
                    : null,
              ),
              SizedBox(height: 16),

              // Price
              TextFormField(
                controller: productPriceController,
                decoration: InputDecoration(
                  labelText: 'Price *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) =>
                value!.isEmpty
                    ? 'Please enter price'
                    : null,
              ),
              SizedBox(height: 16),

              // Quantity and Stock Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: productQuantityController,
                      decoration: InputDecoration(
                        labelText: 'Quantity *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                      value!.isEmpty
                          ? 'Enter quantity'
                          : null,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: productStockController,
                      decoration: InputDecoration(
                        labelText: 'Stock *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                      value!.isEmpty
                          ? 'Enter stock'
                          : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Unit Dropdown
              DropdownButtonFormField<String>(
                value: unitType,
                decoration: InputDecoration(
                  labelText: 'Unit *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.straighten),
                ),
                items: [
                  DropdownMenuItem(value: 'mg', child: Text('Milligram (mg)')),
                  DropdownMenuItem(value: 'g', child: Text('Gram (g)')),
                  DropdownMenuItem(value: 'kg', child: Text('Kilogram (kg)')),
                  DropdownMenuItem(value: 'ml', child: Text('Milliliter (ml)')),
                  DropdownMenuItem(value: 'L', child: Text('Liter (L)')),
                  DropdownMenuItem(value: 'pc', child: Text('Piece (pc)')),
                  DropdownMenuItem(value: 'pk', child: Text('Pack (pk)')),
                  DropdownMenuItem(value: 'btl', child: Text('Bottle (btl)')),
                  DropdownMenuItem(value: 'can', child: Text('Can (can)')),
                  DropdownMenuItem(value: 'bx', child: Text('Box (bx)')),
                  DropdownMenuItem(value: 'ctn', child: Text('Carton (ctn)')),
                  DropdownMenuItem(value: 'cs', child: Text('Case (cs)')),
                ],
                onChanged: (value) {
                  setState(() {
                    unitType = value!;
                  });
                },
              ),
              SizedBox(height: 16),

              // Product Code
              TextFormField(
                controller: productCodeController,
                decoration: InputDecoration(
                  labelText: 'Product Code *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code),
                ),
                validator: (value) =>
                value!.isEmpty
                    ? 'Please enter product code'
                    : null,
              ),
              SizedBox(height: 16),

              // Description
              TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (value) =>
                value!.isEmpty
                    ? 'Please enter description'
                    : null,
              ),
              SizedBox(height: 24),

              // Submit Button
              Center(
                child: _isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: addProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(85, 139, 47, 1),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Save Product',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(height: 24),
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
