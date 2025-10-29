
import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_page.dart';
import 'myOrders_page.dart';
import 'about_page.dart';
import 'refer_friendPage.dart';
import 'feedback_Page.dart';
import 'edit_profile_page.dart';

class UserProfile {
  final String id;
  final String name;
  final String username;
  final String phone;

  UserProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.phone,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  bool _isLoggedIn = false;
  bool _isLoading = true;
  UserProfile? _userProfile;
  late AnimationController _controller;

  final Color primaryGreen = const Color.fromRGBO(85, 139, 47, 1);

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
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
        _controller.forward();
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
    final uri =
    Uri.parse('https://maligaijaman.rdegi.com/api/profile.php?id=$userid');
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
    });
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (color ?? primaryGreen).withOpacity(0.15),
          child: Icon(icon, color: color ?? primaryGreen),
        ),
        title: Text(title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: primaryGreen,
            )),
        trailing: Icon(Icons.arrow_forward_ios,
            size: 16, color: Colors.grey.shade500),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isLoggedIn) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Please login to see profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<UserProfile>(
        future: fetchUserProfile(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data!;

          return Column(
            children: [
              // Header
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryGreen, primaryGreen.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        child: Text(
                          profile.username.isNotEmpty
                              ? profile.username[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(profile.name,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text(profile.username,
                          style:
                          const TextStyle(fontSize: 14, color: Colors.white70)),
                      Text(profile.phone,
                          style:
                          const TextStyle(fontSize: 14, color: Colors.white70)),
                    ],
                  ),
                ),
              ),

              // Menu list
              Expanded(
                child: FadeTransition(
                  opacity: _controller,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    children: [
                      _buildMenuTile(
                          icon: Icons.person_rounded,
                          title: "Edit Profile",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(
                                  id: profile.id,
                                  name: profile.name,
                                  username: profile.username,
                                  phone: profile.phone,
                                ),
                              ),
                            );
                          }),
                      _buildMenuTile(
                          icon: Icons.shopping_bag,
                          title: "My Orders",
                          color: Colors.orange,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MyOrdersScreen(),
                              ),
                            );
                          }),
                      _buildMenuTile(
                          icon: Icons.feedback,
                          title: "Feedback",
                          color: Colors.purple,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FeedbackScreen(),
                              ),
                            );
                          }),
                      _buildMenuTile(
                          icon: Icons.group_add,
                          title: "Refer a Friend",
                          color: Colors.teal,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReferFriendScreen(),
                              ),
                            );
                          }),
                      _buildMenuTile(
                          icon: Icons.info,
                          title: "About",
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AboutScreen(),
                              ),
                            );
                          }),
                      const SizedBox(height: 30),

                      // Logout Button
                      Center(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: primaryGreen, width: 2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 14),
                          ),
                          onPressed: _handleLogout,
                          icon: Icon(Icons.logout, color: primaryGreen),
                          label: Text("Logout",
                              style: TextStyle(
                                  fontSize: 16, color: primaryGreen)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
