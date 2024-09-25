import 'dart:io';
import 'package:flutter/material.dart';
import 'screens/login.dart';
import 'screens/order.dart';
import 'screens/profile.dart';
import 'screens/dashboard.dart';

const primaryColor = Color.fromARGB(255, 200, 50, 0);
const whiteColor = Color.fromARGB(255, 255, 255, 255);
const blackColor = Color.fromARGB(255, 0, 0, 0);

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isLoggedIn = false;
  int? driverId;
  Map<String, dynamic>? driverData; // Biến để lưu driverData
  int _selectedIndex = 1;

  WebSocket? _webSocket; // Biến WebSocket để lưu kết nối WebSocket
  String _receivedMessage = ""; // Biến lưu trữ tin nhắn từ WebSocket

  @override
  void initState() {
    super.initState();
    // Kết nối với WebSocket khi ứng dụng khởi động
  }

  @override
  void dispose() {
    _webSocket?.close(); // Đóng kết nối WebSocket khi ứng dụng bị hủy
    super.dispose();
  }

  // Kết nối WebSocket



  // Hiển thị thông báo khi nhận tin nhắn
  void _showNotification(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Thông báo"),
          content: Text(message),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void handleLogin(BuildContext context, int driverId, Map<String, dynamic> data) {
    setState(() {
      isLoggedIn = true;
      this.driverId = driverId;
      this.driverData = data; // Lưu driverData
      _selectedIndex = 1; // Chuyển sang trang Order sau khi đăng nhập
    });
  }

  void handleLogout(BuildContext context) {
    setState(() {
      isLoggedIn = false;
      driverId = null;
      driverData = null; // Reset driverData khi logout
      _selectedIndex = 1; // Chuyển về trang Order khi đăng xuất
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eSavior',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Nunito',
      ),
      home: isLoggedIn
          ? Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: whiteColor,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            Builder(
              builder: (context) => BookingListPage(
                isLoggedIn: isLoggedIn,
                driverId: driverId,
                onLogout: () => handleLogout(context),
              ),
            ),
            Builder(
              builder: (context) => Order(
                isLoggedIn: isLoggedIn,
                onLogout: () => handleLogout(context),
                driverId: driverId,
                driverData: driverData ?? {}, // Thêm dòng này
              ),
            ),
            Builder(
              builder: (context) => Profile(
                isLoggedIn: isLoggedIn,
                onLogout: () => handleLogout(context),
                driverData: driverData, // Truyền driverData vào Profile
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: whiteColor,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.car_crash),
              label: 'Order',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: primaryColor,
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
          unselectedItemColor: Colors.black54,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              _selectedIndex = 1;
            });
          },
          backgroundColor: primaryColor,
          child: Image.network(
            'https://img.icons8.com/ios-filled/50/FFFFFF/ambulance--v1.png',
            width: 35,
            height: 35,
          ),
        ),
      )
          : Login(onLogin: (int driverId, Map<String, dynamic> data) => handleLogin(context, driverId, data)), // Thêm 'data' vào hàm onLogin
    );
  }
}
