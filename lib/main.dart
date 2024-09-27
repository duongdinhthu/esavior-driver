import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'screens/login.dart';
import 'screens/order.dart';
import 'screens/profile.dart';
import 'screens/dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const primaryColor = Color.fromARGB(255, 200, 50, 0);
const whiteColor = Color.fromARGB(255, 255, 255, 255);
const blackColor = Color.fromARGB(255, 0, 0, 0);

void callbackDispatcher() {
  // Khởi tạo FlutterLocalNotificationsPlugin
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Cài đặt khởi tạo thông báo cho Android
  var initializationSettingsAndroid = AndroidInitializationSettings('app_icon'); // Đặt tên icon cho thông báo
  var initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

  // Khởi tạo plugin
  flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Hàm để thực hiện task
  Workmanager().executeTask((task, inputData) async {
    int driverId = inputData!['driverId'];
    final String apiUrl = 'https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/drivers/$driverId';

    Timer? timer;

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Kiểm tra trạng thái tài xế và trạng thái mở ứng dụng
        SharedPreferences prefs = await SharedPreferences.getInstance();
        bool isAppOpened = prefs.getBool('isAppOpened') ?? false;

        if (!isAppOpened) {
          if (data['status'] == 'Active') {
            print('Driver is active: ${data['driverName']}');

            // Gọi hàm để kiểm tra đơn hàng cứ mỗi 5 giây
            timer = Timer.periodic(Duration(seconds: 5), (timer) async {
              await _checkDriverBooking(driverId, flutterLocalNotificationsPlugin); // Hàm này gọi API check đơn hàng
            });
          } else {
            print('Driver chưa active, kiểm tra đơn hàng chưa hoàn thành.');
            timer = Timer.periodic(Duration(seconds: 5), (timer) async {
              await _checkUnfinishedBooking(driverId, flutterLocalNotificationsPlugin); // Gọi hàm kiểm tra đơn hàng chưa hoàn thành
            });
          }
        } else {
          // Nếu tài xế đã mở ứng dụng, dừng việc gửi thông báo
          timer?.cancel();
          print('Driver đã mở ứng dụng, dừng thông báo.');
        }
      } else {
        print('Failed to load driver: ${response.statusCode}');
      }
    } catch (e) {
      print('Error occurred: $e');
    }

    return Future.value(true);
  });
}


void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo WorkManager
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  runApp(MyApp());
}
Future<void> _checkUnfinishedBooking(int driverId, FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
  final response = await http.get(
    Uri.parse('https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/bookings/unfinished/$driverId'),
  );

  // Nếu request trả về 200, sẽ gửi thông báo liên tục
  if (response.statusCode == 200 && response.body.isNotEmpty) {
    // Gửi thông báo đơn giản về đơn hàng chưa hoàn thành
    await _showNotification(
      flutterLocalNotificationsPlugin,
      'Unfinished Booking',
      'You have an unfinished booking. Please complete it.',
    );
  } else {
    print('No unfinished booking found.');
  }
}

Future<void> _checkDriverBooking(int driverId, FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
  final response = await http.get(
    Uri.parse('https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/drivers/check-driver/$driverId'),
  );

  // Nếu request trả về 200, sẽ gửi thông báo mỗi 5 giây
  if (response.statusCode == 200) {
    // Gửi thông báo
    await _showNotification(flutterLocalNotificationsPlugin,
        'New Ride Request', 'You have a new ride request. Tap to view details.');
  } else {
    print("No ride request available.");
  }
}

Future<void> _showNotification(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin, String title, String body) async {
  var androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'your_channel_id', 'your_channel_name',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: false,
  );

  var platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(0, title, body, platformChannelSpecifics, payload: 'ride_request');
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
    checkLoginState(); // Kiểm tra trạng thái đăng nhập khi khởi động ứng dụng
    markAppAsOpened(); // Đánh dấu rằng ứng dụng đã được mở
  }

  Future<void> markAppAsOpened() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAppOpened', true); // Đánh dấu rằng ứng dụng đã được mở
  }
  Future<void> checkLoginState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? isLoggedIn = prefs.getBool('isLoggedIn');
    String? userType = prefs.getString('userType');

    if (isLoggedIn != null && isLoggedIn && userType == 'driver') {
      int? driverId = prefs.getInt('driverId');
      // Giả sử driverData được lưu dưới dạng JSON String (nếu cần)
      setState(() {
        this.isLoggedIn = true;
        this.driverId = driverId;
        // Khôi phục dữ liệu driverData nếu đã lưu trước đó (tùy vào cách bạn lưu driverData)
        // driverData = jsonDecode(prefs.getString('driverData') ?? '{}');
      });
    }
  }

  @override
  void dispose() {
    _webSocket?.close(); // Đóng kết nối WebSocket khi ứng dụng bị hủy
    super.dispose();
  }
  Future<void> markAppAsClosed() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAppOpened', false); // Đánh dấu rằng ứng dụng đã được đóng
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
      this.driverData = data;
      _selectedIndex = 1;
    });

    // Đăng ký task nền để kiểm tra đơn hàng mỗi 15 phút
    Workmanager().registerPeriodicTask(
      "checkDriverOrderTask", // Tên task
      "simpleTask",           // Mô tả task
      inputData: {"driverId": driverId}, // Truyền driverId vào task nền
      frequency: const Duration(minutes: 15), // Chạy mỗi 15 phút
    );
  }


  void handleLogout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Hủy task WorkManager khi tài xế đăng xuất
    Workmanager().cancelAll();

    setState(() {
      isLoggedIn = false;
      driverId = null;
      driverData = null;
      _selectedIndex = 1;
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
