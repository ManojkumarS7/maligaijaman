import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:maligaijaman/apiconstants.dart';

class AddCategoryPage extends StatefulWidget {
  @override
  _AddCategoryPageState createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // Form controllers
  TextEditingController categoryNameController = TextEditingController();
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



  Future<void> addCategory() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if image is selected
    if (avatarImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a category image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String categoryName = categoryNameController.text.trim();
      final String description = descriptionController.text.trim();

      // Create multipart request
      final url = Uri.parse('${Appconfig.baseurl}api/insert_category.php');
      final request = http.MultipartRequest('POST', url);

      // Add text fields
      request.fields['name'] = categoryName;
      request.fields['description'] = description;

      // Add image file
      request.files.add(
          await http.MultipartFile.fromPath('image', avatarImage!.path)
      );

      // Send the request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      // Enhanced response handling
      Map<String, dynamic> responseData;
      try {
        // Try to parse the last valid JSON object from the response
        final String cleanedResponse = responseBody.substring(responseBody.lastIndexOf('{'));
        responseData = json.decode(cleanedResponse);
      } catch (e) {
        print('JSON parsing error: $e');
        print('Raw response: $responseBody');
        // Fallback to a default success message if we can't parse the JSON
        responseData = {
          'message': response.statusCode == 200
              ? 'Category added successfully'
              : 'Failed to add category'
        };
      }

      if (response.statusCode == 200) {
        // Check for various success message formats
        final bool isSuccess = responseData['message']?.toString().toLowerCase().contains('success') ?? false ||
            responseData['message']!.toString().toLowerCase().contains('added') ?? false;

        if (isSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Category added successfully'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(responseData['message'] ?? 'Category addition failed'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server error: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
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
      backgroundColor: Color(0xFFFFC107),
      appBar: AppBar(
          backgroundColor: Color(0xFFFFC107),
        title: Text('Add Category'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Image Picker
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor:  Color(0xFF00677E),
                      radius: 50,
                      backgroundImage: avatarImage != null
                          ? FileImage(avatarImage!)
                          : null,
                      child: avatarImage == null
                          ? Icon(Icons.camera, size: 50, color: Colors.white,)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.camera_alt, color: Colors.white,),
                        onPressed: _pickImage,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Category Name
              TextFormField(
                controller: categoryNameController,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter category name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Description
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
              SizedBox(height: 24),

              // Submit Button
              Center(
                child: _isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:  Color(0xFF00677E),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: addCategory,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: Text('Save Category'),
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
    categoryNameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}


