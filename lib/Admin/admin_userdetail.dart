
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maligaijaman/apiconstants.dart';
import 'package:maligaijaman/appcolors.dart';
import 'package:maligaijaman/Users/myOrders_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'admin_userOrders.dart';

class UserDetailPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserDetailPage({Key? key, required this.user}) : super(key: key);

  @override
  _UserDetailPageState createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController passwordController;
  final _storage = const FlutterSecureStorage();
  bool isLoading = false;

  String userid = "";

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.user['name'] ?? '');
    emailController = TextEditingController(text: widget.user['username'] ?? '');
    phoneController = TextEditingController(text: widget.user['phone'] ?? '');
    passwordController = TextEditingController(); // Leave empty to set new one
  }

  Future<void> updateUser() async {
    setState(() => isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${Appconfig.baseurl}api/update_adminuser.php"),
      );

      request.fields['id'] = widget.user['id'];
      request.fields['name'] = nameController.text;
      request.fields['username'] = emailController.text;
      request.fields['phone'] = phoneController.text;
      if (passwordController.text.isNotEmpty) {
        request.fields['password'] = passwordController.text;
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User updated successfully")),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception("Failed to update user");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update user: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteUser() async {
    try {
      final url = Uri.parse("${Appconfig.baseurl}api/delete_user.php");
      final response = await http.post(url, body: {
        'id': widget.user['id'],
      });

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User deleted successfully")),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception("Failed to delete user");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete user: $e")),
      );
    }
  }

  void showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete User"),
          content: Text("Are you sure you want to delete this user?"),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.pop(context);
                deleteUser();
              },
            ),
          ],
        );
      },
    );
  }

  InputDecoration buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.green[700]),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.green.shade300, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.green.shade300, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.green.shade700, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Appcolor.Appbarcolor,
       leading: IconButton(
           onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back_ios,color: Colors.white,)),
        title: Text('User Details',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.white),
            onPressed: showDeleteConfirmation,
          ),
        ],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: buildInputDecoration("Name", Icons.person_outline),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: buildInputDecoration("Email", Icons.email_outlined),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: buildInputDecoration("Phone", Icons.phone_outlined),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: buildInputDecoration("Password", Icons.lock_outline),
                ),
                SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Write user_id to storage (returns Future<void>, not String)
                      await _storage.write(key: 'user_id', value: widget.user['id']);

                      // Then navigate
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AdminUserorders()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: isLoading
                        ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : Icon(Icons.shopping_cart_outlined, color: Colors.white),
                    label: Text(
                      "Orders",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : updateUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: isLoading
                        ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : Icon(Icons.save, color: Colors.white),
                    label: Text(
                      isLoading ? "Updating..." : "Update",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
