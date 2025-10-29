
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'Vendors/vendor_login.dart';
import 'Admin/admin_login.dart';
import 'Users/login_page.dart';

class UserProfile {
  final String email;
  final String? name;

  UserProfile({required this.email, this.name});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      email: json['email'] ?? '',
      name: json['name'],
    );
  }
}

class ProfileOptionsScreen extends StatefulWidget {
  const ProfileOptionsScreen({Key? key}) : super(key: key);

  @override
  State<ProfileOptionsScreen> createState() => _ProfileOptionsScreenState();
}

class _ProfileOptionsScreenState extends State<ProfileOptionsScreen> {
  final _storage = FlutterSecureStorage();
  bool _isLoggedIn = false;
  bool _isLoading = true;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    final jwt = await _storage.read(key: 'jwt');
    final secretKey = await _storage.read(key: 'key');
    final userid = await _storage.read(key: 'user_id');

    setState(() {
      _isLoggedIn = jwt != null && secretKey != null && userid != null;
    });

    if (_isLoggedIn) {
      fetchUserProfile().then((profile) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }).catchError((e) {
        setState(() {
          _isLoading = false;
        });
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<UserProfile> fetchUserProfile() async {
    final String? userid = await _storage.read(key: 'user_id');
    final uri = Uri.parse('https://maligaijaman.rdegi.com/api/profile.php?id=$userid');
    final response = await http.get(uri);

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      final jsonData = json.decode(response.body);
      if (jsonData is List && jsonData.isNotEmpty) {
        return UserProfile.fromJson(jsonData[0]);
      } else if (jsonData is Map && jsonData.containsKey('data')) {
        return UserProfile.fromJson(jsonData['data']);
      }
    }
    throw Exception('Failed to load profile');
  }

  Future<void> _handleLogout() async {
    await _storage.deleteAll();
    setState(() {
      _isLoggedIn = false;
      _userProfile = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged out successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showLoginRequiredDialog(String accountType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout Required',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'You are currently logged in as a user. Please logout first to access $accountType login.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.green.shade700,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Account Options',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade700,
              Colors.green.shade500,
              Colors.green.shade50,
            ],
            stops: [0.0, 0.2, 0.2],
          ),
        ),
        child: Column(
          children: [
            // Header Section
            Container(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade800,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isLoggedIn ? Icons.person : Icons.person_outline,
                      size: 40,
                      color: Colors.green.shade700,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    _isLoggedIn ? 'Welcome Back!' : 'Welcome to Maligaijaman',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _isLoggedIn
                        ? (_userProfile?.email ?? 'Loading...')
                        : 'Choose your login option',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // Options Card
            Expanded(
              child: Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    // User Login/Logout Option
                    if (_isLoggedIn)
                      _buildLogoutOption(
                        context,
                        icon: Icons.logout,
                        title: 'Logout',
                        subtitle: 'Sign out from your account',
                        color: Colors.red.shade700,
                        onTap: _handleLogout,
                      )
                    else
                      _buildLoginOption(
                        context,
                        icon: Icons.person,
                        title: 'User Login',
                        subtitle: 'Access your personal account',
                        color: Colors.green.shade600,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => LoginScreen()),
                          ).then((_) => checkLoginStatus());
                        },
                      ),

                    SizedBox(height: 20),

                    // Vendor Login Option
                    _buildLoginOption(
                      context,
                      icon: Icons.business,
                      title: 'Vendor Login',
                      subtitle: 'Manage your products and orders',
                      color: Colors.orange.shade700,
                      isDisabled: _isLoggedIn,
                      onTap: () {
                        if (_isLoggedIn) {
                          _showLoginRequiredDialog('Vendor');
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => VendorLoginScreen()),
                          );
                        }
                      },
                    ),

                    SizedBox(height: 20),

                    // Admin Login Option
                    _buildLoginOption(
                      context,
                      icon: Icons.admin_panel_settings,
                      title: 'Admin Login',
                      subtitle: 'Access admin dashboard',
                      color: Colors.red.shade700,
                      isDisabled: _isLoggedIn,
                      onTap: () {
                        if (_isLoggedIn) {
                          _showLoginRequiredDialog('Admin');
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AdminLoginScreen()),
                          );
                        }
                      },
                    ),

                    Spacer(),

                    // Footer text
                    Text(
                      'Maligaijaman v1.0',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginOption(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        required VoidCallback onTap,
        bool isDisabled = false,
      }) {
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDisabled)
                Icon(
                  Icons.lock,
                  color: Colors.grey.shade400,
                  size: 20,
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutOption(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
