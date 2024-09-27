import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const primaryColor = Color.fromARGB(255, 200, 50, 0);
const whiteColor = Color.fromARGB(255, 255, 255, 255);
const blackColor = Color.fromARGB(255, 0, 0, 0);

class Login extends StatefulWidget {
  final Function(int, Map<String, dynamic>) onLogin; // Thay đổi đây

  Login({required this.onLogin});

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _loginKey = GlobalKey<FormState>();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _passController = TextEditingController();

  bool isLoading = false;
  bool _hidePass = true;

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final String email = _emailController.text;
    final String password = _passController.text;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/drivers/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Map<String, dynamic> driverData = data;
        final int driverId = driverData['driverId'];

        // Lưu trạng thái đăng nhập vào SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true); // Đánh dấu đã đăng nhập
        await prefs.setString('userType', 'driver'); // Lưu loại người dùng
        await prefs.setInt('driverId', driverId); // Lưu driverId

        // Gọi hàm onLogin và truyền driverId vào
        widget.onLogin(driverId, driverData);

        showTemporaryMessage(context, "Log in successfully!");
      } else {
        showTemporaryMessage(context, "Invalid email or password.");
      }
    } catch (error) {
      showTemporaryMessage(context, "Error during login. Please try again.");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }



  OverlayEntry? currentOverlayEntry;

  void showTemporaryMessage(BuildContext context, String message) {
    if (currentOverlayEntry != null) {
      currentOverlayEntry!.remove();
    }

    currentOverlayEntry = OverlayEntry(
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(12.0),
            margin: EdgeInsets.only(left: 12, right: 12),
            decoration: BoxDecoration(
              color: blackColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              message,
              style: TextStyle(
                  color: whiteColor,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context)?.insert(currentOverlayEntry!);

    Future.delayed(Duration(seconds: 3), () {
      currentOverlayEntry?.remove();
      currentOverlayEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: whiteColor,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: _buildLoginForm(),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginKey,
      child: Column(
        children: [
          SizedBox(height: 100),
          Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                      'assets/images/esavior-high-resolution-logo-transparent.png'),
                  fit: BoxFit.contain, // Đảm bảo toàn bộ logo hiển thị
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Container(
            width: double.infinity,
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              cursorColor: Colors.black54,
              style: TextStyle(
                  color: blackColor,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(
                    Icons.email,
                    color: Colors.black54,
                  ),
                ),
                hintText: 'Email Address',
                hintStyle: TextStyle(
                    color: Colors.black54,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black54, width: 1.0),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black54, width: 1.0),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.red,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.red,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                errorStyle: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email address cannot be empty';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  return 'Invalid email address';
                }
                return null;
              },
            ),
          ),
          SizedBox(height: 20),
          Container(
            width: double.infinity,
            child: TextFormField(
              obscureText: _hidePass,
              controller: _passController,
              cursorColor: Colors.black54,
              style: TextStyle(
                  color: blackColor,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(
                    Icons.lock,
                    color: Colors.black54,
                  ),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _hidePass ? Icons.visibility_off : Icons.visibility,
                    color: Colors.black54,
                  ),
                  onPressed: () {
                    setState(() {
                      _hidePass = !_hidePass;
                    });
                  },
                ),
                hintText: 'Password',
                hintStyle: TextStyle(
                    color: Colors.black54,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black54, width: 1.0),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black54, width: 1.0),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.red,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.red,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                errorStyle: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password cannot be empty';
                }
                return null;
              },
            ),
          ),
          SizedBox(height: 20),
          Container(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: isLoading
                  ? null
                  : () {
                if (_loginKey.currentState?.validate() ?? false) {
                  _handleLogin();
                }
              },
              child: isLoading
                  ? SizedBox(
                width: 24.0,
                height: 24.0,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              )
                  : Text(
                'Log in',
                style: TextStyle(
                    color: whiteColor,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}