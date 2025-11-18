import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import 'home_page.dart';
import 'package:maligaijaman/appcolors.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int _selectedIndex = 3; // Profile tab selected by default
  final String appVersion = '1.0';

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // Do nothing if same tab

    setState(() {
      _selectedIndex = index;
    });

    // Handle navigation based on the selected tab
    switch (index) {
      case 0:
      // Return to Home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainScreen(initialIndex: 0)),
              (route) => false,
        );
        break;
      case 1:
      // Navigate to Cart
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen(initialIndex: 1)),
        );
        break;
      case 2:
      // Navigate to Wishlist
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen(initialIndex: 2)),
        );
        break;
      case 3:
      // Navigate to Profile
        Navigator.pop(context); // Go back to profile
        break;
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch $url'),
        ),
      );
    }
  }

  Widget _buildInfoCard(String title, String content, {bool isHtml = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          isHtml
              ? RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.5,
              ),
              children: _buildTextSpans(content),
            ),
          )
              : Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildTextSpans(String content) {
    // Very simple HTML parser for links - for a real app, use a proper HTML parser
    final RegExp exp = RegExp(r'<a href="([^"]+)">([^<]+)</a>');
    final matches = exp.allMatches(content);

    if (matches.isEmpty) {
      return [TextSpan(text: content)];
    }

    final List<TextSpan> spans = [];
    int lastEnd = 0;

    for (final match in matches) {
      // Add text before the link
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }

      // Add the link
      spans.add(
        TextSpan(
          text: match.group(2),
          style: const TextStyle(
            color: Color(0xFF2E7D32),
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              _launchURL(match.group(1)!);
            },
        ),
      );

      lastEnd = match.end;
    }

    // Add any remaining text after the last link
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'About',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Appcolor.Appbarcolor, // Yellow background
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2E7D32), width: 2),
              ),
              padding: const EdgeInsets.all(3),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 80,
                  width: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.shopping_basket,
                      size: 60,
                      color: Color(0xFF2E7D32),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Maligaijamaan',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version $appVersion',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            _buildInfoCard(
                'About Us',
                "Welcome to Maligaijamaan — Tamil Nadu's vibrant multivendor grocery hub,"
                    "We're revolutionizing everyday shopping by bringing your trusted neighborhood vendors online. Imagine browsing a marketplace filled with fresh produce, everyday essentials, and household staples — all at your fingertips, with just a few clicks,"
            ),
            _buildInfoCard(
              'Our Mission',

              "At Maligaijamaan, community and convenience go hand in hand. Our platform connects you directly to local sellers, offering a seamless experience to compare, select, and order groceries from the comfort of your home. Fast, reliable, and packed with quality — we deliver freshness straight to your doorstep.",
            ),
            _buildInfoCard(
              'Contact Us',
              'Email: info@rdegi.com\nPhone: +91 78452 98544\nAddress: AIC Raise Startup Incubation Centre,Coimbatore – 641 021.',
            ),

            _buildInfoCard(
              'Terms & Privacy Policy',
              'By using our app, you agree to our <a href="https://www.maligaijamaan.com/terms">Terms of Service</a> and <a href="https://www.maligaijamaan.com/privacy">Privacy Policy</a>. These documents outline how we collect, use, and protect your data, as well as your rights and responsibilities as a user.',
              isHtml: true,
            ),
            const SizedBox(height: 16),
            Text(
              '© ${DateTime
                  .now()
                  .year} Maligaijamaan. All rights reserved.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Wishlist',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

}

