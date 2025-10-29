

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AdminSubCategoryDetail extends StatefulWidget {
  final String subCategoryId;
  final String name;
  final String description;
  final String imageUrl;
  final String categoryId;

  const AdminSubCategoryDetail({
    Key? key,
    required this.subCategoryId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.categoryId,
  }) : super(key: key);

  @override
  _AdminSubCategoryDetailState createState() => _AdminSubCategoryDetailState();
}

class _AdminSubCategoryDetailState extends State<AdminSubCategoryDetail> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  String? _selectedCategoryId;
  List<Category> categories = [];
  bool _isLoading = true;
  String? _error;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _descriptionController = TextEditingController(text: widget.description);
    _selectedCategoryId = widget.categoryId;
    print(_selectedCategoryId);
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final url = Uri.parse("https://maligaijaman.rdegi.com/api/categorylist.php");
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
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to load categories with status code: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load categories: $e';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load categories: $e')),
      );
    }
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

  Future<void> _updateSubCategory() async {
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a category")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("https://maligaijaman.rdegi.com/api/update_subcategory.php"),
      );

      // Add text fields
      request.fields['id'] = widget.subCategoryId;
      request.fields['name'] = _nameController.text;
      request.fields['description'] = _descriptionController.text;
      request.fields['category_id'] = _selectedCategoryId!;

      // Add image file if selected
      if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'image', // Field name for the image on the server
            _imageFile!.path,
          ),
        );
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Subcategory updated successfully")),
        );
        Navigator.pop(context, true); // Return true to trigger refresh
      } else {
        throw Exception("Failed to update subcategory: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating subcategory: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSubCategory() async {
    try {
      final url = Uri.parse("https://maligaijaman.rdegi.com/api/delete_subcategory.php");
      final response = await http.post(
        url,
        body: {
          'id': widget.subCategoryId,
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Subcategory deleted successfully")),
        );
        Navigator.pop(context, true); // Return true to trigger refresh
      } else {
        throw Exception("Failed to delete subcategory");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete subcategory: $e")),
      );
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Subcategory"),
          content: Text("Are you sure you want to delete this subcategory?"),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.pop(context);
                _deleteSubCategory();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: Colors.blue),
        title: Text('Edit Subcategory', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: _showDeleteConfirmation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subcategory Image with Camera Icon
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _imageFile != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _imageFile!,
                          fit: BoxFit.cover,
                        ),
                      )
                          : widget.imageUrl.isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                        ),
                      )
                          : Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        onPressed: _showImagePickerOptions,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),

            // Name Field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Subcategory Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Description Field
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Category Dropdown
            // if (_error != null)
            //   Text(_error!, style: TextStyle(color: Colors.red))
            // else
            //   DropdownButtonFormField<String>(
            //     value: _selectedCategoryId,
            //     decoration: InputDecoration(
            //       labelText: 'Select Category',
            //       border: OutlineInputBorder(),
            //     ),
            //     items: categories.map((Category category) {
            //       return DropdownMenuItem<String>(
            //         value: category.id,
            //         child: Text(category.name),
            //       );
            //     }).toList(),
            //     onChanged: (value) {
            //       setState(() {
            //         _selectedCategoryId = value;
            //       });
            //     },
            //   ),

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
                });
              }
                  : null, // Disable dropdown if no categories exist
            ),


            SizedBox(height: 32),

            // Update Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _updateSubCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Update Subcategory', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
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

