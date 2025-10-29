

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'payment_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';
import 'cart_page.dart';
import 'wishlist_screen.dart';
import 'profile_page.dart';

class AddressViewScreen extends StatefulWidget {
  const AddressViewScreen({Key? key}) : super(key: key);

  @override
  _AddressViewScreenState createState() => _AddressViewScreenState();
}

class _AddressViewScreenState extends State<AddressViewScreen> {
  final loc.Location _location = loc.Location();
  List<dynamic> _addresses = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedAddressId; // Track selected address

  int _selectedIndex = 0;

  final _storage = const FlutterSecureStorage();
  String? _jwt;
  String? _secretKey;

  @override
  void initState() {
    super.initState();
    checkLoginStatus().then((_) {
      _fetchAddresses();
    });
  }

  Future<void> checkLoginStatus() async {
    _jwt = await _storage.read(key: 'jwt');
    _secretKey = await _storage.read(key: 'key');
  }

  Future<void> _fetchAddresses() async {
    if (_jwt == null || _jwt!.isEmpty || _secretKey == null || _secretKey!.isEmpty) {
      setState(() {
        _error = 'Authentication details missing';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = Uri.parse('https://maligaijaman.rdegi.com/api/addressget.php?jwt=$_jwt&secretkey=$_secretKey');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            _addresses = data;
            _isLoading = false;
            // Auto-select default address or first address
            if (_addresses.isNotEmpty && _selectedAddressId == null) {
              var defaultAddress = _addresses.firstWhere(
                    (addr) => addr['is_default'] == '1',
                orElse: () => _addresses[0],
              );
              _selectedAddressId = defaultAddress['id']?.toString();
            }
          });
        } else if (data is Map && data['status'] == 'success') {
          setState(() {
            _addresses = data['addresses'] ?? [];
            _isLoading = false;
            // Auto-select default address or first address
            if (_addresses.isNotEmpty && _selectedAddressId == null) {
              var defaultAddress = _addresses.firstWhere(
                    (addr) => addr['is_default'] == '1',
                orElse: () => _addresses[0],
              );
              _selectedAddressId = defaultAddress['id']?.toString();
            }
          });
        } else {
          setState(() {
            _error = data is Map ? data['message'] ?? 'Unknown error occurred' : 'Invalid response format';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Failed to load addresses: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _proceedToPayment() {
    if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a delivery address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Find the selected address
    final selectedAddress = _addresses.firstWhere(
          (addr) => addr['id']?.toString() == _selectedAddressId,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          selectedAddress: selectedAddress,
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          setState(() {
            _error = 'Location service is disabled';
            _isLoading = false;
          });
          return;
        }
      }

      loc.PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          setState(() {
            _error = 'Location permission is denied';
            _isLoading = false;
          });
          return;
        }
      }

      final locationData = await _location.getLocation();

      List<Placemark> placemarks = await placemarkFromCoordinates(
          locationData.latitude!,
          locationData.longitude!
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        final addressData = {
          'name': '',
          'phonenumber': '',
          'state': place.administrativeArea ?? '',
          'city': place.locality ?? '',
          'door_no': place.subThoroughfare ?? '',
          'street_village': place.thoroughfare ?? place.subLocality ?? '',
          'pincode': place.postalCode ?? '',
          'latitude': locationData.latitude,
          'longitude': locationData.longitude,
        };

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddAddressScreen(
              initialAddress: addressData,
              jwt: _jwt,
              secretKey: _secretKey,
            ),
          ),
        );

        await _fetchAddresses();
      } else {
        setState(() {
          _error = 'Could not determine address from location';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to get current location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshAddresses() async {
    await _fetchAddresses();
  }

  Future<void> _deleteAddress(String addressId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('https://maligaijaman.rdegi.com/api/delete_address.php');
      final response = await http.post(
        url,
        body: {
          'id': addressId,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Clear selection if deleted address was selected
          if (_selectedAddressId == addressId) {
            _selectedAddressId = null;
          }
          await _fetchAddresses();
        } else {
          setState(() {
            _error = data['message'] ?? 'Failed to delete address';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Error: HTTP ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pop(context);
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CartScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => WishlistScreen()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfileScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF2E7D32),
        title: const Text(
          'Select Delivery Address',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAddresses,
          ),
        ],
      ),
      body: _addresses.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No saved addresses found',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddAddressScreen(
                      jwt: _jwt,
                      secretKey: _secretKey,
                    ),
                  ),
                );
                await _fetchAddresses();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add New Address'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAddresses,
              child: ListView.builder(
                itemCount: _addresses.length,
                itemBuilder: (context, index) {
                  final address = _addresses[index];
                  final addressId = address['id']?.toString();

                  return AddressCard(
                    address: address,
                    isSelected: _selectedAddressId == addressId,
                    onSelect: () {
                      setState(() {
                        _selectedAddressId = addressId;
                      });
                    },
                    onEdit: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddAddressScreen(
                            initialAddress: address,
                            isEditing: true,
                            jwt: _jwt,
                            secretKey: _secretKey,
                          ),
                        ),
                      );
                      await _fetchAddresses();
                    },
                    onDelete: () async {
                      bool confirm = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Address'),
                          content: const Text('Are you sure you want to delete this address?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ) ?? false;

                      if (confirm) {
                        await _deleteAddress(addressId!);
                      }
                    },
                  );
                },
              ),
            ),
          ),
          // Proceed button at the bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _proceedToPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Proceed to Payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            heroTag: 'currentLocation',
            onPressed: _getCurrentLocation,
            backgroundColor: Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'addAddress',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddAddressScreen(
                    jwt: _jwt,
                    secretKey: _secretKey,
                  ),
                ),
              );
              await _fetchAddresses();
            },
            child: const Icon(Icons.add),
            backgroundColor: Color(0xFF2E7D32),
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class AddressCard extends StatelessWidget {
  final Map<String, dynamic> address;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AddressCard({
    Key? key,
    required this.address,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String name = address['name'] ?? '';
    String phone = address['phonenumber'] ?? '';
    String doorNo = address['address_line1'] ?? '';
    String street = address['address_line2'] ?? '';
    String city = address['city'] ?? '';
    String state = address['state'] ?? '';
    String pincode = address['pincode'] ?? '';

    String addressLine1 = address['address_line1'] ?? '';
    String addressLine2 = address['address_line2'] ?? '';

    bool isDefault = address['is_default'] == '1';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Color(0xFF2E7D32) : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: isSelected,
                    onChanged: (value) => onSelect(),
                    activeColor: Color(0xFF2E7D32),
                  ),
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name.isNotEmpty ? name : 'Address',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isDefault)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Default',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: onEdit,
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (doorNo.isNotEmpty || street.isNotEmpty)
                      Text(
                        [
                          if (doorNo.isNotEmpty) doorNo,
                          if (street.isNotEmpty) street
                        ].join(', '),
                        style: const TextStyle(fontSize: 15),
                      )
                    else if (addressLine1.isNotEmpty)
                      Text(
                        addressLine1,
                        style: const TextStyle(fontSize: 15),
                      ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Phone: $phone',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                    if (addressLine2.isNotEmpty && addressLine2 != 'null') ...[
                      const SizedBox(height: 4),
                      Text(
                        addressLine2,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                    const SizedBox(height: 4),
                    if (city.isNotEmpty || state.isNotEmpty || pincode.isNotEmpty)
                      Text(
                        [
                          if (city.isNotEmpty) city,
                          if (state.isNotEmpty) state,
                          if (pincode.isNotEmpty) pincode
                        ].where((s) => s.isNotEmpty).join(', '),
                        style: const TextStyle(fontSize: 15),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? initialAddress;
  final bool isEditing;
  final String? jwt;
  final String? secretKey;

  const AddAddressScreen({
    Key? key,
    this.initialAddress,
    this.isEditing = false,
    this.jwt,
    this.secretKey,
  }) : super(key: key);

  @override
  _AddAddressScreenState createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _doorNoController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  bool _isDefault = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showSuccessNotification = false;

  // Address type selection
  String _addressType = 'Home';
  final List<String> _addressTypes = ['Home', 'Work', 'Other'];

  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      // Handle both new and old format
      _nameController.text = widget.initialAddress!['name'] ?? '';
      _phoneController.text = widget.initialAddress!['phonenumber'] ?? '';
      _doorNoController.text = widget.initialAddress!['address_line1'] ?? '';
      _streetController.text = widget.initialAddress!['address_line2'] ?? '';
      _cityController.text = widget.initialAddress!['city'] ?? '';
      _stateController.text = widget.initialAddress!['state'] ?? '';
      _pincodeController.text = widget.initialAddress!['pincode'] ?? '';

      // Set address type if available
      if (widget.initialAddress!['address_type'] != null) {
        _addressType = widget.initialAddress!['address_type'];
      }

      // For backward compatibility
      if (_doorNoController.text.isEmpty &&
          widget.initialAddress!['address_line1'] != null) {
        _doorNoController.text = widget.initialAddress!['address_line1'];
      }

      _isDefault = widget.initialAddress!['is_default'] == '1';
      _latitude = widget.initialAddress!['latitude'];
      _longitude = widget.initialAddress!['longitude'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _doorNoController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _continueShoppingAction() {
    // Navigate to payment page with the newly saved address
    Map<String, dynamic> savedAddress = {
      'name': _nameController.text,
      'phonenumber': _phoneController.text,
      'address_line1': _doorNoController.text,
      'address_line2': _streetController.text,
      'city': _cityController.text,
      'state': _stateController.text,
      'pincode': _pincodeController.text,
      'address_type': _addressType,
      'is_default': _isDefault ? '1' : '0',
      // Include any ID if this was an edit operation
      if (widget.isEditing && widget.initialAddress != null &&
          widget.initialAddress!.containsKey('id'))
        'id': widget.initialAddress!['id'],
      // Include coordinates if available
      if (_latitude != null) 'latitude': _latitude,
      if (_longitude != null) 'longitude': _longitude,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PaymentPage(
              selectedAddress: savedAddress,
            ),
      ),
    );
  }

  void _saveAndGoBackAction() {
    // Pop the current screen to go back to the address list
    Navigator.pop(context, true); // Return true to indicate completed address
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse(widget.isEditing
          ? 'https://maligaijaman.rdegi.com/api/update_address.php'
          : 'https://maligaijaman.rdegi.com/api/addressinsert.php');

      final Map<String, dynamic> bodyData = {
        'jwt': widget.jwt,
        'secretkey': widget.secretKey,
        'name': _nameController.text,
        'phonenumber': _phoneController.text,
        'address_line1': _doorNoController.text,
        'address_line2': _streetController.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'pincode': _pincodeController.text,
        'address_type': _addressType,
        'is_default': _isDefault ? '1' : '0',
      };

      // Add address ID for updates
      if (widget.isEditing && widget.initialAddress != null) {
        bodyData['id'] = widget.initialAddress!['id'];
      }

      // Add coordinates if available
      if (_latitude != null && _longitude != null) {
        bodyData['latitude'] = _latitude.toString();
        bodyData['longitude'] = _longitude.toString();
      }

      final response = await http.post(url, body: bodyData);

      print('API Response: ${response.body}'); // Add this debug print

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('JSON Response: $data'); // Add this debug print

        // Show notification whether API returns success or not for debugging purposes
        setState(() {
          _isLoading = false;
          _showSuccessNotification = true; // Force show notification for now
          if (data['status'] != 'success') {
            _errorMessage = data['message'] ?? 'Failed to save address';
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Error: HTTP ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Exception: $e'); // Add this debug print
      setState(() {
        _errorMessage = 'Failed to save address: $e';
        _isLoading = false;
      });
    }
  }

// Add this method to manually toggle the notification for testing
  void _toggleNotification() {
    setState(() {
      _showSuccessNotification = !_showSuccessNotification;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:  Color(0xFF2E7D32),
        title: Text(widget.isEditing ? 'Edit Address' : 'Add New Address'),
        actions: [
          // Add a test button in the app bar for debugging
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: _toggleNotification,
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      color:  Color(0xFF2E7D32),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.black),
                      ),
                    ),

                  // Address Type Selection
                  Container(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Address Type',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: _addressTypes.map((type) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(type),
                                selected: _addressType == type,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _addressType = type;
                                    });
                                  }
                                },
                                selectedColor:  Color(0xFF2E7D32),
                                backgroundColor: Colors.grey.shade200,
                                labelStyle: TextStyle(
                                  color: _addressType == type
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      return null; // Optional
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      return null; // Optional
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _doorNoController,
                    decoration: const InputDecoration(
                      labelText: 'Address line 1',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      return null; // Optional
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _streetController,
                    decoration: const InputDecoration(
                      labelText: 'Address line 2',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      return null; // Optional
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter city';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'State',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter state';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _pincodeController,
                    decoration: const InputDecoration(
                      labelText: 'Pincode',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter pincode';
                      }
                      if (value.length != 6 || int.tryParse(value) == null) {
                        return 'Please enter a valid 6-digit pincode';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Checkbox(
                        value: _isDefault,
                        onChanged: (value) {
                          setState(() {
                            _isDefault = value ?? false;
                          });
                        },
                      ),
                      const Text('Set as default address'),
                    ],
                  ),

                  if (_latitude != null && _longitude != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(
                              Icons.location_on, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'GPS Location: ${_latitude!.toStringAsFixed(
                                6)}, ${_longitude!.toStringAsFixed(6)}',
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:  Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        widget.isEditing ? 'Update Address' : 'Save Address',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  // Debug information
                  SizedBox(height: 16),
                  Text('Show notification: $_showSuccessNotification',
                      style: TextStyle(color: Colors.grey)),

                  SizedBox(height: 80),
                  // Extra space at bottom for notification bar
                ],
              ),
            ),
          ),

          // Success Notification Bar - Moved outside conditionally to debug
          if (_showSuccessNotification)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      color: Colors.green.shade100,
                      width: double.infinity,
                      child: Text(
                        widget.isEditing
                            ? 'Address updated successfully!'
                            : 'Address added successfully!',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [

                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveAndGoBackAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:  Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Save & Go Back'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

