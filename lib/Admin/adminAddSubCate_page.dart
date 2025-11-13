import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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

class AddSubCategoryPage extends StatefulWidget {
  @override
  _AddSubCategoryPageState createState() => _AddSubCategoryPageState();
}

class _AddSubCategoryPageState extends State<AddSubCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  List<Category> categories = [];
  Category? selectedCategory;

  // Form controllers
  TextEditingController subcategoryNameController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();

  File? avatarImage;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          avatarImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchCategories();
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
          print(categories);
        });
      } else {
        throw Exception("Failed to load categories with status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load categories: $e')),
      );
    }
  }

  Future<void> addSubcategory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (avatarImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category image')),
      );
      return;
    }

    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String subcategoryname = subcategoryNameController.text.trim();
      final String description = descriptionController.text.trim();

      // Create a multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${Appconfig.baseurl}api/add_subcategory.php'),
      );

      // Add text fields
      request.fields['name'] = subcategoryname;
      request.fields['description'] = description;
      request.fields['category_id'] = selectedCategory!.id;

      // Add the image file
      request.files.add(
        await http.MultipartFile.fromPath('image', avatarImage!.path),
      );

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Raw Response body: "${response.body}"');

      if (response.statusCode == 200) {
        String responseBody = response.body.trim();

        // Extract the last JSON object from the response
        int jsonStart = responseBody.lastIndexOf('{');
        if (jsonStart != -1) {
          responseBody = responseBody.substring(jsonStart);
        }

        // Decode the JSON
        final responseData = json.decode(responseBody);

        if (responseData['message'] == 'SubCategory Added successfully') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sub category added successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Clear form fields
          subcategoryNameController.clear();
          descriptionController.clear();
          setState(() {
            selectedCategory = null;
            avatarImage = null; // Clear image
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'Sub category failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}\nBody: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Add Subcategory'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.lightGreen,
                      radius: 50,
                      backgroundImage: avatarImage != null
                          ? FileImage(avatarImage!)
                          : null,
                      child: avatarImage == null
                          ? Icon(Icons.camera, size: 50)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.camera_alt),
                        onPressed: _pickImage,
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
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: subcategoryNameController,
                decoration: InputDecoration(
                  labelText: 'Subcategory Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter subcategory name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),

              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : addSubcategory,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Save Subcategory'),
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
    subcategoryNameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}

