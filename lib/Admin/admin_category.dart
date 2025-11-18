
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'adminAddCategory_page.dart';
import 'admin_categorydetail.dart';
import 'package:maligaijaman/apiconstants.dart';
import 'package:maligaijaman/appcolors.dart';

class AdminCategoryListScreen extends StatefulWidget {
  const AdminCategoryListScreen({Key? key}) : super(key: key);

  @override
  State<AdminCategoryListScreen> createState() =>
      _AdminCategoryListScreenState();
}

class _AdminCategoryListScreenState extends State<AdminCategoryListScreen> {
  final _storage = const FlutterSecureStorage();
  List<dynamic> _allCategories = [];
  List<dynamic> _filteredCategories = [];
  TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  final Color primaryColor = const Color.fromRGBO(85, 139, 47, 1);

  // @override
  // void initState() {
  //   super.initState();
  //   _fetchCategories();
  //   _searchController.addListener(_filterCategories);
  // }

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _searchController.addListener(_filterCategories);
  }

  // Add this method to handle refreshing when returning to screen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This ensures the list refreshes when navigating back
    if (mounted) {
      _fetchCategories();
    }
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse("${Appconfig.baseurl}api/categorylist.php");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        dynamic decodedResponse = json.decode(responseBody);

        List<dynamic> categories;
        if (decodedResponse is List) {
          categories = decodedResponse;
        } else if (decodedResponse is Map && decodedResponse.containsKey('data')) {
          categories = List.from(decodedResponse['data']);
        } else {
          throw Exception("Unexpected response format");
        }

        setState(() {
          _allCategories = categories.where((category) {
            final deleteFlag = category['delete_flag']?.toString() ?? '0';
            return deleteFlag == '0';
          }).toList();
          _filteredCategories = List.from(_allCategories);
        });
      } else {
        throw Exception("Failed to load categories: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories: $e'),
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

  void _filterCategories() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCategories = _allCategories.where((category) {
        final name = category['name']?.toString().toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Appcolor.Appbarcolor,
        elevation: 4,
        title: const Text(
          "Categories",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddCategoryPage()),
              );
              if (result == true) {
                await _fetchCategories();
                _filterCategories();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search categories...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
          ),

          // Categories list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCategories.isEmpty
                ? const Center(
              child: Text(
                "No categories found.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchCategories,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _filteredCategories.length,
                itemBuilder: (context, index) {
                  final category = _filteredCategories[index];
                  return GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryDetailPage(category: category),
                        ),
                      );
                      if (result == true) {
                        await _fetchCategories();
                        _filterCategories();
                      }
                    },
                    child: Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          // Image
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(15),
                              bottomLeft: Radius.circular(15),
                            ),
                            child: Image.network(
                              category['imgpath'] ??
                                  category['image_url'] ??
                                  '',
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.image_not_supported,
                                        color: Colors.grey),
                                  ),
                            ),
                          ),
                          // Texts
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category['name'] ?? 'Unnamed Category',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    category['description'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.grey),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
