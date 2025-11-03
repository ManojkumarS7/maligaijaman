
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maligaijaman/Admin/adminAddSubCate_page.dart';
import 'package:maligaijaman/Admin/admin_subcatdetail.dart';
import 'package:maligaijaman/apiconstants.dart';

class AdminSubCategoryListScreen extends StatefulWidget {
  const AdminSubCategoryListScreen({Key? key}) : super(key: key);

  @override
  State<AdminSubCategoryListScreen> createState() =>
      _AdminSubCategoryListScreenState();
}

class _AdminSubCategoryListScreenState
    extends State<AdminSubCategoryListScreen> {
  final _storage = const FlutterSecureStorage();
  final Color primaryColor = const Color.fromRGBO(85, 139, 47, 1);

  List<dynamic> _allCategory = [];
  List<dynamic> _filteredCategory = [];
  TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSubCategory();
    _searchController.addListener(_filterProducts);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This ensures the list refreshes when navigating back
    if (mounted) {
      _fetchSubCategory();
    }
  }

  Future<void> _fetchSubCategory() async {
    setState(() {
      _isLoading = true;
    });
    final url =
    Uri.parse("${Appconfig.baseurl}api/subcategory_list.php");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> products = json.decode(responseBody);

        setState(() {
          _allCategory = products
              .where((product) => product['delete_flag']?.toString() == '0')
              .toList();
          _filteredCategory = List.from(_allCategory);
        });
      } else {
        throw Exception(
            "Failed to load products with status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load subcategories'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCategory = _allCategory.where((product) {
        final name = product['name']?.toString().toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "SubCategories",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddSubCategoryPage()),
              );
              if (result == true) {
                await _fetchSubCategory();
                _filterProducts();
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
                hintText: "Search subcategories...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide:
                  BorderSide(color: primaryColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
          ),

          // Subcategories list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCategory.isEmpty
                ? const Center(
              child: Text(
                "No subcategories found.",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchSubCategory,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: _filteredCategory.length,
                itemBuilder: (context, index) {
                  final subcategory = _filteredCategory[index];
                  return GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminSubCategoryDetail(
                            subCategoryId: subcategory['id'],
                            name: subcategory['name'] ?? 'Unnamed',
                            description: subcategory['description'] ??
                                'No description available',
                            imageUrl: subcategory['imgpath'] ?? '',
                            categoryId: subcategory['category_id'] ??
                                '',
                          ),
                        ),
                      );
                      if (result == true) {
                        _fetchSubCategory();
                      }
                    },
                    child: Card(
                      elevation: 3,
                      margin:
                      const EdgeInsets.symmetric(vertical: 8),
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
                              subcategory['imgpath'] ?? '',
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                  Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey),
                                  ),
                            ),
                          ),
                          // Texts
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subcategory['name'] ??
                                        'Unnamed SubCategory',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    subcategory['description'] ?? '',
                                    maxLines: 2,
                                    overflow:
                                    TextOverflow.ellipsis,
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
