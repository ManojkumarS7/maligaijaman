

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maligaijaman/Vendors/vendor_Storeinfo_Page.dart';
import '../Users/login_page.dart';
import 'vendor_detailspage.dart';
import '../Users/about_page.dart';
import 'package:maligaijaman/apiconstants.dart';

class VendorProfile {

  final String username;
  final String email;
  final String phone;

  VendorProfile({

    required this.username,
    required this.email,
    this.phone = '',
  });

  factory VendorProfile.fromJson(Map<String, dynamic> json) {
    return VendorProfile(

      username: json['name'] ?? '',
      email: json['username'] ?? '',
      phone: json['phone'] ?? '',
    );
  }
}

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({Key? key}) : super(key: key);

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final _storage = const FlutterSecureStorage();
  bool _isLoggedIn = false;
  bool _isLoading = true;

  VendorProfile? _vendorProfile;

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    final jwt = await _storage.read(key: 'jwt');
    final secretKey = await _storage.read(key: 'key');

    setState(() {
      _isLoggedIn = jwt != null && secretKey != null;
    });

    if (_isLoggedIn) {
      fetchUserProfile().then((profile) {
        setState(() {
          _vendorProfile = profile;
          _isLoading = false;
        });
      }).catchError((e) {
        setState(() {
          _isLoading = false;
        });
        print('Error fetching profile: $e');
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<VendorProfile> fetchUserProfile() async {
    final String? jwt = await _storage.read(key: 'jwt');
    final String? secretKey = await _storage.read(key: 'key');
    print('JWT: $jwt');
    print('Secret Key: $secretKey');

    if (jwt == null || secretKey == null) {
      throw Exception('Authentication tokens not found');
    }

    try {
      final response = await http.get(
        Uri.parse(
            '${Appconfig.baseurl}api/vendor_profile.php?jwt=$jwt&secretkey=$secretKey'),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        final vendorid = jsonData['id'].toString(); // convert to string for storage
        await _storage.write(key: 'vendor_id', value: vendorid);
        print('Stored vendor ID: $vendorid');

        print('Decoded JSON: $jsonData');

        // If response is wrapped in `data`
        final userData = jsonData['data'] ?? jsonData;
        return VendorProfile.fromJson(userData);
      } else {
        throw Exception('Failed to load profile: Server error');
      }
    } catch (e) {
      print('Error occurred: $e');
      throw Exception('Failed to load profile: $e');
    }
  }


  Future<void> _handleLogout() async {
    await _storage.deleteAll();
    setState(() {
      _isLoggedIn = false;
    });
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.account_circle,
            size: 100,
            color: Colors.grey,
          ),
          const SizedBox(height: 20),
          const Text(
            'Please login to view your profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
              if (result == true) {
                checkLoginStatus();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightGreen,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
            ),
            child: const Text(
              'Login',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption(String text, {Color textColor = Colors.black}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 0.5,
      color: Colors.grey,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _buildLoginPrompt(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: const Color.fromRGBO(85, 139, 47, 1), // Yellow background
        elevation: 0,
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.favorite_border, color: Colors.white),
        //     onPressed: () {},
        //   ),
        //   IconButton(
        //     icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
        //     onPressed: () {},
        //   ),
        // ],
      ),
      body: FutureBuilder<VendorProfile>(
        future: fetchUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasData) {
            final profile = snapshot.data!;

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  color: const Color.fromRGBO(85, 139, 47, 1), // Yellow background
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                profile.username.isNotEmpty ? profile
                                    .username[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.username,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                profile.phone.isNotEmpty
                                    ? profile.phone
                                    : '+91 8564XXXXX',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                profile.email,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const VendorStoreInfoPage()),
                            );
                          },
                          child: _buildMenuOption('Shop information'),
                        ),
                        _buildDivider(),
                        // InkWell(
                        //   onTap: () {
                        //
                        //   },
                        //   child: _buildMenuOption('Bank Details'),
                        // ),
                        //
                        // _buildDivider(),
                        // InkWell(
                        //   onTap: () {
                        //     // Navigate to Feedback
                        //   },
                        //   child: _buildMenuOption('Your Business Document'),
                        // ),
                        _buildDivider(),
                        // InkWell(
                        //   onTap: () {
                        //     // Navigate to Refer a Friend
                        //   },
                        //   child: _buildMenuOption('History'),
                        // ),
                        // _buildDivider(),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => AboutScreen()
                              ),
                            );
                          },
                          child: _buildMenuOption('About'),
                        ),
                        _buildDivider(),
                        InkWell(
                          onTap: () {
                            // Show confirmation dialog
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Logout'),
                                  content: const Text('Are you sure you want to logout?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop(); // Close the dialog
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop(); // Close the dialog
                                        _handleLogout(); // Call the logout function
                                      },
                                      child: const Text('Yes', style: TextStyle(color: Color.fromRGBO(85, 139, 47, 1))),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: _buildMenuOption('Logout', textColor: const Color.fromRGBO(85, 139, 47, 1)),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),

                ),
              ],
            );
          } else {
            return const Center(child: Text('No data available'));
          }
        },
      ),
    );
  }

  Widget _buildNavigationItem(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isSelected ? const Color.fromRGBO(85, 139, 47, 1) : Colors.grey,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? const Color.fromRGBO(85, 139, 47, 1) : Colors.grey,
          ),
        ),
      ],
    );
  }
}
