
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'adminAddUser_page.dart';
import 'admin_userdetail.dart';
import 'package:maligaijaman/apiconstants.dart';

class AdminUsers extends StatefulWidget {
  @override
  _AdminUserPageState createState() => _AdminUserPageState();
}

class _AdminUserPageState extends State<AdminUsers> {
  List<dynamic> vendors = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    setState(() {
      isLoading = true;
    });

    final url = Uri.parse("${Appconfig.baseurl}api/user_list.php");

    try {
      final response = await http.get(url);
      String responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(responseBody);
        setState(() {
          vendors = data;
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load users: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch users")),
      );
    }
  }

  Future<void> navigateToAddUser() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddUserPage()),
    );

    if (result == true) {
      await fetchUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User list updated successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        leading: BackButton(color: Colors.white),
        title: Text(
          'Users',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[500],
        child: Icon(Icons.add, color: Colors.white),
        onPressed: navigateToAddUser,
      ),
      body: RefreshIndicator(
        onRefresh: fetchUsers,
        color: Colors.green[700],
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.green[700]))
            : ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: vendors.length,
          itemBuilder: (context, index) {
            final vendor = vendors[index];
            final name = vendor['name'] ?? '';
            final email = vendor['email'] ?? '';
            final phone = vendor['phone'] ?? '';
            final avatarLetter =
            name.isNotEmpty ? name[0].toUpperCase() : '?';

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              margin: EdgeInsets.symmetric(vertical: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserDetailPage(user: vendor),
                    ),
                  );
                  if (result == true) {
                    await fetchUsers();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.green[500],
                        child: Text(
                          avatarLetter,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              email,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Icon(Icons.phone, size: 16, color: Colors.green[500]),
                          SizedBox(height: 4),
                          Text(
                            phone,
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
