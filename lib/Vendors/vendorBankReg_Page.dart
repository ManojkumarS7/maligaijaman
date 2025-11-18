import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'vendorBussinessID_Page.dart';
import 'package:maligaijaman/apiconstants.dart';
import 'package:maligaijaman/appcolors.dart';

class BankInformationPage extends StatefulWidget {
  // final String vendorId;

  // const BankInformationPage({Key? key, required this.vendorId}) : super(key: key);

  @override
  _BankInformationPageState createState() => _BankInformationPageState();
}

class _BankInformationPageState extends State<BankInformationPage> {
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  bool _isLoading = false;


  Future<void> _submitBankInformation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final storage = const FlutterSecureStorage();

      await storage.write(key: 'acc_holder_name', value: _accountNameController.text);
      await storage.write(key: 'acc_no', value: _accountNumberController.text);
      await storage.write(key: 'bank_name', value: _bankNameController.text);
      await storage.write(key: 'branch', value: _branchController.text);
      await storage.write(key: 'ifsc', value: _ifscController.text);

      // Verify storage
      final stored = await storage.readAll();
      print('Stored bank info: $stored');

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BusinessIdPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving bank info: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bank Information',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Appcolor.Appbarcolor, // Yellow background
        elevation: 0,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_ios, color: Colors.white,)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _accountNameController,
                decoration: InputDecoration(labelText: 'Account Holder Name'),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _accountNumberController,
                decoration: InputDecoration(labelText: 'Account Number'),
                keyboardType: TextInputType.number,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _bankNameController,
                decoration: InputDecoration(labelText: 'Bank Name'),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _branchController,
                decoration: InputDecoration(labelText: 'Branch'),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _ifscController,
                decoration: InputDecoration(labelText: 'IFSC Code'),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : _submitBankInformation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Continue to Business ID'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
