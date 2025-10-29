

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maligaijaman/Users/productdetail_page.dart';
import 'Users/productList_page.dart';
import 'Users/cart_page.dart';
import 'Users/profile_page.dart';
import 'Users/wishlist_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'Users/offer_productPage.dart';
import 'ProfileOption_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'Users/home_page.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grocery App',
      home: MainScreen(),
    );
  }
}


