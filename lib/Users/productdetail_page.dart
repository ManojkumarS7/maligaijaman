
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'adress_Viewpage.dart';
import '../main.dart';
import 'home_page.dart';import 'package:flutter/services.dart'; // For Clipboard
import 'package:maligaijaman/apiconstants.dart';
import 'package:maligaijaman/appcolors.dart';
import 'login_page.dart';


class Review {
  final String id;
  final String productId;
  final String username;
  final String review;
  final String date;
  final int rating ;


  Review({
    required this.id,
    required this.productId,
    required this.username,
    required this.review,
    required this.date,
    required this.rating

  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      productId: json['product_id'],
      username: json['username'],
      review: json['review'],
      date: json['date'],
      rating:  int.parse(json['review_count']),
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final double productPrice;
  final int quantity;
  final String imageUrl;
  final String description;
  final String? vendorid;



  const CheckoutScreen({
    Key? key,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.imageUrl,
    this.description = 'No description available.',
    required this.vendorid,
  }) : super(key: key);




  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  int quantity = 1;
  final int buttonId = 01;
  String? _jwt;
  String? _secretKey;
  String? _username;
  String? _userid;
  final TextEditingController _reviewController = TextEditingController();

  List<Review> reviews = [];
  bool isLoadingReviews = true;
  int _rating = 0;
  @override
  void initState() {
    super.initState();
    quantity = widget.quantity;
    // _debugCheckStoredDetails();
    _loadCredentials();
    _fetchReviews();

    print(widget.productId);
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    _jwt = await _storage.read(key: 'jwt');
    _secretKey = await _storage.read(key: 'key');
    _username = await _storage.read(key: 'name');
     _userid = await _storage.read(key: 'user_id');

    print("jwt is$_jwt");
    print(_secretKey);
    print(_username);
  }

  Future<void> _storeButtonId(int id) async {
    await _storage.write(key: "button_id", value: id.toString());
    print("Button ID stored: $id"); // Debugging purpose
  }

  Future<void> _storeProductDetails() async {
    await _storage.write(key: "product_id", value: widget.productId);
    await _storage.write(key: "product_name", value: widget.productName);
    await _storage.write(
        key: "product_price", value: widget.productPrice.toString());
    await _storage.write(key: "product_quantity", value: quantity.toString());
    await _storage.write(key: "product_image", value: widget.imageUrl);
    await _storage.write(key: "vendor_id", value: widget.vendorid ?? '');
    print("Product Details stored in Secure Storage.");
  }

  Future<void> _fetchReviews() async {
    setState(() {
      isLoadingReviews = true;
    });

    try {
      final fetchedReviews = await _fetchReviewsFromServer();
      setState(() {
        reviews = fetchedReviews;
        isLoadingReviews = false;
      });
    } catch (e) {
      setState(() {
        isLoadingReviews = false;
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Error loading reviews: $e'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    }
  }


  Future<List<Review>> _fetchReviewsFromServer() async {
    final url = Uri.parse('${Appconfig.baseurl}api/review.php');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      print("Response Body: ${response.body}");
      print("Filtering for product_id: ${widget.productId}");

      // Filter the reviews by product_id
      final filteredData = data.where((review) {
        return review['product_id'].toString() == widget.productId.toString();
      }).toList();

      return filteredData.map((item) => Review.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load reviews. Status code: ${response.statusCode}');
    }
  }



  Future<void> _submitReview() async {
    if (_jwt == null || _secretKey == null || _username == null) {
      await _loadCredentials();
    }

    if (_jwt == null || _secretKey == null || _username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to submit a review'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_reviewController.text
        .trim()
        .isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a review'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final url = Uri.parse(
          '${Appconfig.baseurl}api/review_insert.php');
      final Map<String, dynamic> requestBody = {
        'product_id': widget.productId,
        'username': _username,
        'review': _reviewController.text.trim(),
        'review_count': _rating.toString(),
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _reviewController.clear();
          _fetchReviews(); // Refresh reviews
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  responseData['message'] ?? 'Failed to submit review'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Server error: ${response.statusCode}'),
        //     backgroundColor: Colors.red,
        //   ),
        // );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Error submitting review: $e'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    }
  }

  Future<void> addToCart(String productId, String productName,
      double productPrice, int qty) async {
    if (_jwt == null || _secretKey == null || _userid == null ) {
      // await _loadCredentials();
      print(_userid);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please login to add items to cart'),
        backgroundColor: Colors.redAccent,
        action: SnackBarAction(label: 'click here to login',textColor: Colors.white,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen())
              );
            }
        ),
      ),
    );

    try {
      final url = Uri.parse(
          '${Appconfig.baseurl}api/cart_insert.php');
      final Map<String, dynamic> requestBody = {
        'secretkey': _secretKey,
        'jwt': _jwt,
        'productid': productId,
        'productname': productName,
        'productprice': productPrice.toString(),
        'qty': qty.toString(),
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product added to cart successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  responseData['message'] ?? 'Failed to add product to cart'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding to cart: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Product Details',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Appcolor.Appbarcolor,
        elevation: 2,

      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Product Image with Hero animation
                    Container(
                      height: 250,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Product Name
                    Text(
                      widget.productName,
                      style: TextStyle(
                        fontSize: 28,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Price with discount tag
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(widget.productPrice * quantity).toStringAsFixed(
                              2)} INR',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color:  Color(0xFF2E7D32),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${((widget.productPrice * 1.2) * quantity)
                              .toStringAsFixed(2)} INR',
                          style: TextStyle(
                            fontSize: 16,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(width: 25),


                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: 'SAVE20'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Coupon code copied!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.green.shade700,
                                width: 1,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'SAVE20',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.content_copy,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Quantity selector
                    Row(
                      children: [
                        Text(
                          'Quantity: ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 16),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove),
                                onPressed: () {
                                  if (quantity > 1) {
                                    setState(() {
                                      quantity--;
                                    });
                                  }
                                },
                              ),
                              Text(
                                quantity.toString(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.add),
                                onPressed: () {
                                  setState(() {
                                    quantity++;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Description section with tabs
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Product Description',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: Text(
                              widget.description,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Customer reviews section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Customer Reviews',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                      Icons.refresh, color:  Color(0xFF2E7D32)),
                                  onPressed: _fetchReviews,
                                ),
                              ],
                            ),
                            SizedBox(height: 12),

                            // Review submission section
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Write a Review',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  TextField(
                                    controller: _reviewController,
                                    decoration: InputDecoration(
                                      hintText: 'Share your thoughts about this product...',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.all(12),
                                    ),
                                    maxLines: 3,
                                  ),
                                  SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: _submitReview,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:  Color(0xFF2E7D32),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                    child: Text('Submit Review'),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 8),



                            Row(
                              children: [
                                Text(
                                  'Your Rating:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8),

                                // 5 Stars
                                Row(
                                  children: List.generate(5, (index) {
                                    final starIndex = index + 1;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _rating = starIndex.toInt();
                                        });
                                      },
                                      child: Icon(
                                        Icons.star,
                                        size: 28,
                                        color: _rating >= starIndex ? Colors.amber : Colors.grey,
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),

                            SizedBox(height: 16),

                            // Reviews list
                            if (isLoadingReviews)
                              Center(
                                child: CircularProgressIndicator(
                                  color:  Color(0xFF2E7D32),
                                ),
                              )
                            else
                              if (reviews.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'No reviews yet. Be the first to review!',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                )
                              else

                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: reviews.length,
                                  itemBuilder: (context, index) {
                                    final review = reviews[index];

                                    return Container(
                                      margin: EdgeInsets.only(bottom: 12),
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor:  Color(0xFF2E7D32),
                                                child: Text(
                                                  review.username.isNotEmpty
                                                      ? review.username[0].toUpperCase()
                                                      : 'A',
                                                  style: TextStyle(color: Colors.white),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      review.username,
                                                      style: TextStyle(fontWeight: FontWeight.bold),
                                                    ),

                                                    Text(
                                                      review.date != '0000-00-00'
                                                          ? review.date
                                                          : 'Recent',
                                                      style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),



                                          SizedBox(height: 8),

                                          // ⭐ ADD STAR DISPLAY HERE
                                          Row(
                                            children: List.generate(5, (index) {
                                              return Icon(
                                                index < review.rating ? Icons.star : Icons.star_border,
                                                color: Colors.amber,
                                                size: 20,
                                              );
                                            }),
                                          ),


                                          SizedBox(height: 8),
                                          Text(
                                            review.review,
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )

                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom action buttons
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Add To Cart button
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _storeButtonId(2); // Different ID for cart
                        await _storeProductDetails();

                        // Call the addToCart function
                        await addToCart(
                            widget.productId,
                            widget.productName,
                            widget.productPrice,
                            quantity
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor:  Color(0xFF2E7D32),
                        side: BorderSide(color:  Color(0xFF2E7D32)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Buy Now button
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {


                        if (_jwt == null || _secretKey == null || _userid == null) {
                          await _loadCredentials();
                        }

                        if (_jwt == null || _secretKey == null || _userid == null) {
                          SnackBar(
                            content: const Text('Please login to add items to cart'),
                            backgroundColor: Colors.redAccent,
                            action: SnackBarAction(label: 'click here to login',textColor: Colors.white,
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen())
                                  );
                                }
                            ),
                          );
                          return;
                        }

                        await _storeButtonId(1);
                        await _storeProductDetails();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              body: AddressViewScreen(),
                              bottomNavigationBar: BottomNavigationBar(  // Bottom bar stays here
                                items: const <BottomNavigationBarItem>[
                                  BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                                  BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
                                  BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Wishlist'),
                                  BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
                                ],
                                currentIndex: 1, // Highlight Cart tab (since checkout relates to cart)
                                selectedItemColor: const  Color(0xFF2E7D32),
                                unselectedItemColor: Colors.grey,
                                onTap: (index) {
                                  if (index == 1) {
                                    Navigator.pop(context); // Close CheckoutScreen if already on Cart
                                  } else {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MainScreen(initialIndex: index),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        );

                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:  Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Buy Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
