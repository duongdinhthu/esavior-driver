import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const primaryColor = Color.fromARGB(255, 200, 50, 0);
const whiteColor = Color.fromARGB(255, 255, 255, 255);
const blackColor = Color.fromARGB(255, 0, 0, 0);
const blueColor = Color.fromARGB(255, 33, 150, 233);

class Profile extends StatefulWidget {
  final bool isLoggedIn;
  final Function onLogout;
  final Map<String, dynamic>? driverData;

  Profile({
    required this.isLoggedIn,
    required this.onLogout,
    required this.driverData,
  });

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  String name = '';
  String email = '';
  String phone = '';
  String license = '';
  String password = '';
  bool isLoading = false;
  final _formKey = GlobalKey<FormState>();

  TextEditingController driverNameController = TextEditingController();
  TextEditingController driverEmailController = TextEditingController();
  TextEditingController driverPhoneController = TextEditingController();
  TextEditingController driverLicenseController = TextEditingController();

  @override
  void dispose() {
    driverNameController.dispose();
    driverEmailController.dispose();
    driverPhoneController.dispose();
    driverLicenseController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Kiểm tra nếu driverData không null và gán dữ liệu
    if (widget.driverData != null) {
      name = widget.driverData!['driverName'] ?? '';
      email = widget.driverData!['email'] ?? '';
      phone = widget.driverData!['driverPhone'] ?? '';
      license = widget.driverData!['licenseNumber'] ?? '';
      password = widget.driverData!['password'] ?? '';
    }
    driverNameController.text = name;
    driverEmailController.text = email;
    driverPhoneController.text = phone;
    driverLicenseController.text = license;
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

  Future<void> updateDriver(Map<String, dynamic> driverData) async {
    final response = await http.put(
      Uri.parse(
          'https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/drivers/${widget.driverData?['driverId']}'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'driverName': name,
        'driverPhone': phone,
        'licenseNumber': license,
        'status': "Active",
        'password': password
      }),
    );

    if (response.statusCode == 200) {
      print("Update successful");
      showTemporaryMessage(context, 'Update successfully!');
    } else {
      showTemporaryMessage(context, 'Update failed!');
      print("Update failed with status code: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white), // Đổi màu icon
            onPressed: () {
              widget.onLogout();
            },
          ),
        ],
      ),
      backgroundColor: whiteColor,
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Stack(
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 50),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: whiteColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 40,
                            ),
                            Center(
                              child: Text(
                                name,
                                style: TextStyle(
                                    color: blackColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22),
                              ),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(top: 20.0),
                              child: TextFormField(
                                controller: driverNameController,
                                cursorColor: Color.fromARGB(255, 20, 121, 255),
                                onChanged: (value) =>
                                    setState(() => name = value),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16.0,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  labelStyle: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16.0,
                                  ),
                                  floatingLabelStyle: TextStyle(
                                    color: Color.fromARGB(255, 20, 121, 255),
                                    fontSize: 14.0,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color:
                                            Color.fromARGB(255, 20, 121, 255),
                                        width: 2.0),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Colors.grey, width: 1.0),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.red, // Màu viền khi có lỗi
                                      width: 1.0,
                                    ),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.red,
                                      width: 2.0,
                                    ),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  errorStyle: TextStyle(color: Colors.red),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Name cannot be empty';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(top: 20.0),
                              child: TextFormField(
                                controller: driverEmailController,
                                cursorColor: Color.fromARGB(255, 20, 121, 255),
                                onChanged: (value) =>
                                    setState(() => email = value),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16.0,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  labelStyle: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16.0,
                                  ),
                                  floatingLabelStyle: TextStyle(
                                    color: Color.fromARGB(255, 20, 121, 255),
                                    fontSize: 14.0,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color:
                                            Color.fromARGB(255, 20, 121, 255),
                                        width: 2.0),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Colors.grey, width: 1.0),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.red, // Màu viền khi có lỗi
                                      width: 1.0,
                                    ),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.red,
                                      width: 2.0,
                                    ),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  errorStyle: TextStyle(color: Colors.red),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Email address cannot be empty';
                                  }
                                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                      .hasMatch(value)) {
                                    return 'Invalid email address';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(top: 20.0),
                              child: TextFormField(
                                keyboardType: TextInputType.phone,
                                controller: driverPhoneController,
                                cursorColor: Color.fromARGB(255, 20, 121, 255),
                                onChanged: (value) =>
                                    setState(() => phone = value),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16.0,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  labelStyle: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16.0,
                                  ),
                                  floatingLabelStyle: TextStyle(
                                    color: Color.fromARGB(255, 20, 121, 255),
                                    fontSize: 14.0,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color:
                                            Color.fromARGB(255, 20, 121, 255),
                                        width: 2.0),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Colors.grey, width: 1.0),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.red, // Màu viền khi có lỗi
                                      width: 1.0,
                                    ),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.red,
                                      width: 2.0,
                                    ),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  errorStyle: TextStyle(color: Colors.red),
                                ),
                                validator: (value) {
                                  if (!RegExp(r'^\d+$').hasMatch(value!)) {
                                    return 'Phone number must contain only digits';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(top: 20.0),
                              child: TextFormField(
                                controller: driverLicenseController,
                                cursorColor: Color.fromARGB(255, 20, 121, 255),
                                onChanged: (value) =>
                                    setState(() => license = value),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16.0,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Address',
                                  labelStyle: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16.0,
                                  ),
                                  floatingLabelStyle: TextStyle(
                                    color: Color.fromARGB(255, 20, 121, 255),
                                    fontSize: 14.0,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color:
                                            Color.fromARGB(255, 20, 121, 255),
                                        width: 2.0),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Colors.grey, width: 1.0),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 20,
                            ),
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
                                        if (_formKey.currentState?.validate() ??
                                            false) {
                                          Map<String, dynamic> updatedFields = {
                                            'email': email,
                                            'driverName': name,
                                            'driverPhone': phone,
                                            'licenseNumber': license,
                                            'status': "Active",
                                            'password': password,
                                          };
                                          updateDriver(updatedFields);
                                        }
                                      },
                                child: isLoading
                                    ? SizedBox(
                                        width: 24.0,
                                        height: 24.0,
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  primaryColor),
                                        ),
                                      )
                                    : Text(
                                        'Save Changes',
                                        style: TextStyle(
                                            color: whiteColor,
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
