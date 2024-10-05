import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http; // Import HTTP library
import 'package:project_flutter/main.dart';
import 'dart:convert'; // Import for JSON handling
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';

import 'chat_message.dart';

class Order extends StatefulWidget {
  final bool isLoggedIn;
  final Function onLogout;
  final int? driverId;
  final Map<String, dynamic> driverData;

  Order(
      {required this.isLoggedIn,
      required this.onLogout,
      this.driverId,
      required this.driverData});

  @override
  _OrderState createState() => _OrderState();
}

class _OrderState extends State<Order> {
  LatLng? _currentLocation;
  String _currentAddress = "Fetching address...";
  LatLng? _endLocation; // Khởi tạo giá trị null
  List<LatLng> polylinePoints = [];
  LatLng? customerLocation;
  String? customerName;
  String? phoneNumber;
  bool hasNewOrderNotification =
      false; // Variable to check if notification has been shown
  StreamSubscription<Position>? _positionStream;
  MapController _mapController = MapController();
  bool notification = false;
  int? bookingId2;
  bool hasAcknowledgedOrder =
      false; // Biến để theo dõi xem tài xế đã xác nhận đơn hàng chưa
  Timer? _locationTimer;
  Timer? _timer;
  IOWebSocketChannel? _channel; // Biến toàn cục để lưu WebSocket channel
  List<ChatMessage> messages = [];  // Danh sách lưu trữ các đối tượng ChatMessage
  bool openSocket = false;
  Stream? broadcastStream; // Khai báo biến toàn cục để lưu broadcastStream



  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    // Always get location from GPS
    _getCurrentLocationFromGPS();
    // Start periodic location updates and check for ride requests
    _startLocationUpdates();
    _loadDriverState(); // Tải lại trạng thái khi khởi động lại ứng dụng

    if (widget.driverData.containsKey('latitude') &&
        widget.driverData.containsKey('longitude')) {
      double latitude = widget.driverData['latitude'];
      double longitude = widget.driverData['longitude'];
      _currentLocation = LatLng(latitude, longitude);
      _updateAddress(_currentLocation!);
    } else {
      _getCurrentLocationFromGPS();
    }
  }

  void _resetScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Order(
          isLoggedIn: widget.isLoggedIn,
          onLogout: widget.onLogout,
          driverId: widget.driverId,
          driverData: widget.driverData,
        ),
      ),
    );
  }

  Future<void> _loadDriverState() async {
    final prefs = await SharedPreferences.getInstance();
    final double? driverLat = prefs.getDouble('driverLat');
    final double? driverLng = prefs.getDouble('driverLng');
    final double? customerLat = prefs.getDouble('customerLat');
    final double? customerLng = prefs.getDouble('customerLng');
    final double? endLat = prefs.getDouble('endLat');
    final double? endLng = prefs.getDouble('endLng');
    final String? savedCustomerName = prefs.getString('customerName');
    final String? savedPhoneNumber = prefs.getString('phoneNumber');
    final int? savedBookingId = prefs.getInt('bookingId');

    setState(() {
      if (driverLat != null && driverLng != null) {
        _currentLocation = LatLng(driverLat, driverLng);
      }
      if (customerLat != null && customerLng != null) {
        customerLocation = LatLng(customerLat, customerLng);
      }
      if (endLat != null && endLng != null) {
        _endLocation = LatLng(endLat, endLng);
      }
      if (savedCustomerName != null &&
          savedPhoneNumber != null &&
          savedBookingId != null) {
        customerName = savedCustomerName;
        phoneNumber = savedPhoneNumber;
        bookingId2 = savedBookingId;
        print("ten khach hang lay lai: " + customerName.toString());
        print("sdt khach hang lay lai: " + phoneNumber.toString());
      }
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _locationTimer?.cancel();
    _saveDriverState(); // Lưu trạng thái trước khi thoát
    _channel?.sink.close(); // Đảm bảo đóng WebSocket khi không sử dụng

    super.dispose();
  }

  Future<void> _saveDriverState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentLocation != null) {
      prefs.setDouble('driverLat', _currentLocation!.latitude);
      prefs.setDouble('driverLng', _currentLocation!.longitude);
    }
    if (customerLocation != null) {
      prefs.setDouble('customerLat', customerLocation!.latitude);
      prefs.setDouble('customerLng', customerLocation!.longitude);
    }
    if (_endLocation != null) {
      prefs.setDouble('endLat', _endLocation!.latitude);
      prefs.setDouble('endLng', _endLocation!.longitude);
    }
    prefs.setString('customerName', customerName ?? '');
    prefs.setString('phoneNumber', phoneNumber ?? '');
    prefs.setInt('bookingId', bookingId2 ?? 0);
    print("ten khach hang: " + customerName.toString());
    print("sdt khach hang: " + phoneNumber.toString());
  }

  // In ra thông báo hoàn thành đơn hàng
  void _startLocationUpdates() {
    Timer.periodic(Duration(seconds: 5), (timer) {
      print(
          'Driver ID after clearing: ${widget.driverId}'); // Thêm log kiểm tra
      _sendLocationUpdate();
      print(widget.driverId);
      // Send driver's location to server
      if (widget.driverId != null) {
        // Chỉ kiểm tra nếu tài xế chưa xác nhận đơn hàng
        getDriverById(widget.driverId!);
      } else {
        print("Driver ID is null or order has been acknowledged");
      }
    });
  }
  void _openWebSocketConnection(int? bookingId, {Function? setStateDialog}) {
    if (_channel == null) {
      _channel = IOWebSocketChannel.connect(
          'wss://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/ws/common?id=$bookingId&role=driver');

      // Chuyển đổi thành BroadcastStream và đảm bảo không bị null
      broadcastStream = _channel!.stream.asBroadcastStream();
      print("_channel connected");

      // Lắng nghe dữ liệu từ WebSocket
      broadcastStream!.listen((message) {  // Không cần dấu hỏi vì đã chắc chắn không null
        if (message.isNotEmpty) {
          print("Received from WebSocket: $message");

          // Lấy giá trị 'message'
          RegExp regex = RegExp(r'message=([^,}]+)');
          Match? match = regex.firstMatch(message);
          if (match != null) {
            String mess = match.group(1) ?? '';
            print('Received message: $mess');

            // Cập nhật danh sách tin nhắn
            if (setStateDialog != null) {
              setStateDialog(() {
                messages.add(ChatMessage(message: mess));
                print("Updated message in dialog");
                print(mess);
              });
            } else {
              setState(() {
                messages.add(ChatMessage(message: mess));
                print('Updated message without dialog');
                print(mess);
              });
            }
          }
        }
      }, onDone: () {
        print("WebSocket closed");
      }, onError: (error) {
        // Log lỗi chi tiết
        print("WebSocket error: $error");
      });

      openSocket = true; // Đặt trạng thái đã mở WebSocket
    }
  }






  void sendMessage(int? bookingId, String message) {
    if (_channel != null && message.isNotEmpty) {
      Map<String, dynamic> data = {
        'type': 'send_message',
        'id': bookingId,
        'role': 'driver',  // Role mặc định là driver
        'message': message
      };
      _channel!.sink.add(jsonEncode(data));  // Gửi dữ liệu JSON qua WebSocket
      print("Sent message: $message with bookingId: ${bookingId.toString()}");

      // Không thêm tin nhắn vào danh sách ngay tại đây
    } else {
      print("WebSocket channel is not connected or message is empty.");
    }
  }


  Future<void> _upDateBookingStatus(int? bookingId1) async {
    print('thuc hien goi aPi chuyen trang thai booking sang complete');
    print(bookingId1.toString());
    try {
      String status = 'Completed';

      print('Booking ID:' + bookingId1.toString());
      print('Booking Status: $status');

      // Thay thế URL API của bạn vào đây
      final response = await http.post(
        Uri.parse(
            'https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/bookings/update-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bookingStatus': status,
          'bookingId': bookingId1,
        }),
      );

      if (response.statusCode == 200) {
        showTemporaryMessage(context, "Emergency booking complete!");
        String status1 = "Active";
        await _updateDriverStatus(widget.driverId, status1);
        _clearBookingStatus();
        _resetScreen();

      } else {
        showTemporaryMessage(context, "Error during submit, Please try again.");
        print('Error: ${response.statusCode}, ${response.body}');
      }
    } catch (error) {
      showTemporaryMessage(context, "Error during submit, Please try again.");
      print('Exception: $error');
    }
  }

  void showTemporaryMessage(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(message),
      duration: Duration(seconds: 3), // Hiển thị trong 3 giây
    );

    // Hiển thị SnackBar trên màn hình
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _clearBookingStatus() async {
    try {
      // Gọi hàm để cập nhật trạng thái booking sang "Completed"
      // Xóa thông tin booking trong SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs
          .remove('isSuccessBooked'); // Xóa trạng thái đã đặt chỗ thành công
      await prefs.remove('currentLat'); // Xóa thông tin vị trí hiện tại
      await prefs.remove('currentLng');
      await prefs.remove('destinationLat'); // Xóa thông tin vị trí điểm đến
      await prefs.remove('destinationLng');
      await prefs.remove('driverName'); // Xóa thông tin tài xế
      await prefs.remove('driverPhone');

      // Đặt lại các biến trong trạng thái để trở về trang cũ
      setState(() {
        _endLocation = null;
        customerLocation = null;
        customerName = null;
        phoneNumber = null;
        hasAcknowledgedOrder = false;
        hasNewOrderNotification = false; // Variable to check if notification has been shown
        notification = false;
        hasAcknowledgedOrder = false; // Biến để theo dõi xem tài xế đã xác nhận đơn hàng chưa
        messages = []; // Danh sách lưu trữ ti
        openSocket = false;
        print(
            'Driver ID after clearing: ${widget.driverId}'); // Thêm log kiểm tra
      });
      } catch (error) {
      print("Error clearing booking status: $error");
      showTemporaryMessage(
          context, "Error clearing booking, please try again.");
    }
  }

  Future<void> _checkBookingStatus(int? bookingId2) async {
    try {
      // Gọi API để kiểm tra trạng thái booking
      final response = await http.get(Uri.parse(
          'https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/bookings/$bookingId2'));
      print('check booking status ' + response.statusCode.toString() + '  id booking: ' + bookingId2.toString());

      if (response.statusCode == 200) {
        // Parse JSON
        final bookingData = jsonDecode(response.body);

        // Kiểm tra nếu `bookingStatus` là 'Completed'
        if (bookingData['bookingStatus'] == 'Completed') {
          _resetScreen();
          _clearBookingStatus();
          // Thông báo cho người dùng về việc hoàn thành đặt chỗ
        }
      } else {
        print('Failed to load booking');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> getDriverById(int driverId) async {
    final String apiUrl =
        'https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/drivers/$driverId'; // Đặt URL API chính xác
    print('check tai xe ' + driverId.toString());
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        // Kiểm tra nếu status là "Active"
        if (data['status'] == 'Active') {
          print('Driver is active: ${data['driverName']}');
          _checkDriverBooking(); // Check for new ride request information
        } else if (data['status'] == 'Deactive') {
          print(
              'Tài xế chưa active, đang kiểm tra đơn hàng chưa hoàn thành...');
          _checkUnfinishedBooking(driverId);
        }
      } else if (response.statusCode == 404) {
        print('Driver not found');
      } else {
        print('Failed to load driver: ${response.statusCode}');
      }
    } catch (e) {
      print('Error occurred: $e');
    }
  }

  Future<void> _updateDriverStatus(int? driverId, String status) async {
    try {
      print("driver_id" + driverId.toString() + "status la:" + status);
      final response = await http.post(
        Uri.parse(
            'https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/drivers/update-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driverId': driverId,
          'status': status,
        }),
      );

      if (response.statusCode == 200) {
        print("Driver status updated successfully!");
      } else {
        print('Error: ${response.statusCode}, ${response.body}');
      }
    } catch (error) {
      print('Exception: $error');
    }
  }

  Future<void> _checkUnfinishedBooking(int driverId) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/bookings/unfinished/$driverId'),
      );
      print("check response unfinish booking : " + response.statusCode.toString());
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);

        // Thay đổi bookingId thành kiểu int
        int bookingId = data['bookingId']; // Sửa thành int
        String customerName1 = data['patientName'];
        String phoneNumber1 = data['patientPhone'];
        double pickupLatitude = data['latitude'];
        double pickupLongitude = data['longitude'];
        double destinationLatitude = data['destinationLatitude'];
        double destinationLongitude = data['destinationLongitude'];
        bookingId2 = bookingId;
        setState(() {
          customerLocation = LatLng(pickupLatitude, pickupLongitude);
          _endLocation = LatLng(destinationLatitude, destinationLongitude);
          customerName = customerName1;
          phoneNumber = phoneNumber1;
          print("ten khach hang chua hoan thanh: " + customerName.toString());
          print("sdt khach hang chua hoan than: " + phoneNumber.toString());
        });
        _checkBookingStatus(bookingId2);
        print(data.toString());
        if(bookingId2 != null){
          if(openSocket == false){
            _openWebSocketConnection(bookingId2);
          }
        }
        print('booking id chưa hoàn thành :' + bookingId.toString());
        if (!hasAcknowledgedOrder && hasNewOrderNotification == false) {
          _showNotification(
              'Đơn hàng chưa hoàn thành: Khách hàng $customerName, Điểm đón: ($pickupLatitude, $pickupLongitude), Điểm đến: ($destinationLatitude, $destinationLongitude)');
        }
      } else {
        print('Không có đơn hàng chưa hoàn thành.');
      }
    } catch (e) {
      print('Lỗi khi kiểm tra đơn hàng chưa hoàn thành: $e');
    }
  }

  // Send API request to check if the driver has a ride request
  // Send API request to check if the driver has a ride request
  Future<void> _checkDriverBooking() async {
    final driverId = widget.driverId;

    if (driverId != null) {
      // Chỉ kiểm tra đơn hàng mới nếu chưa xác nhận
      final response = await http.get(
        Uri.parse(
            'https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/drivers/check-driver/$driverId'),
      );
      print('check driver booking : ' + response.statusCode.toString());
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);

        // Get customer info and coordinates from response
        String newCustomerName = data['customerName'];
        String newPhoneNumber = data['phoneNumber'];

        // Get both pickup and destination coordinates
        double pickupLatitude = data['latitude']; // Vị trí đón (pickup)
        double pickupLongitude = data['longitude']; // Vị trí đón (pickup)
        double destinationLatitude =
            data['destinationLatitude']; // Vị trí đến (destination)
        double destinationLongitude =
            data['destinationLongitude']; // Vị trí đến (destination)

        int? bookingId3 = data['bookingId'];
        _checkBookingStatus(bookingId3);
        // Update customer pickup and destination locations
        if(bookingId3 != null){
          if(openSocket == false){
            _openWebSocketConnection(bookingId3);
          }
        }
        setState(() {
          customerLocation =
              LatLng(pickupLatitude, pickupLongitude); // Cập nhật vị trí đón
          customerName = newCustomerName;
          phoneNumber = newPhoneNumber;
          _endLocation = LatLng(
              destinationLatitude, destinationLongitude);
          print("ten khach hang ham check: " + customerName.toString());
          print("sdt khach hang ham check: " + phoneNumber.toString());// Cập nhật vị trí đến
        });

        // Show notification only if it hasn't been acknowledged
        if (!hasAcknowledgedOrder && hasNewOrderNotification == false) {
          _showNotification(
              'Customer: $customerName, Phone: $phoneNumber\nPickup: ($pickupLatitude, $pickupLongitude)\nDestination: ($destinationLatitude, $destinationLongitude)');
          // Mark that the notification has been displayed
        }

        // Update both pickup and destination locations on the map
        _getPolyline(); // Cập nhật tuyến đường giữa vị trí tài xế, điểm đón và điểm đến
      } else if(response.statusCode == 204) {
        print("No new ride request information.");
        _clearBookingStatus();
      }
    }
  }

  // Send API request to update location
  Future<void> _sendLocationUpdate() async {
    if (_currentLocation != null) {
      final response = await http.post(
        Uri.parse(
            'https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/patientlocation/update-location'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'driverId': widget.driverId,
          'latitude': _currentLocation!.latitude,
          'longitude': _currentLocation!.longitude,
        }),
      );

      // Cập nhật vị trí trung tâm của bản đồ theo vị trí tài xế
      if (response.statusCode == 200) {
        print("Location update successful");
      } else {
        print("Error updating location: ${response.statusCode}");
      }
    }
  }

  // Start sending periodic location updates

  // Show notification
  void _showNotification(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("New Ride Request Notification"),
          content: Text(message),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  notification = true;
                  hasAcknowledgedOrder = true;
                  hasNewOrderNotification = true;
                  // Tài xế đã xác nhận thông báo
                });
              },
            ),
          ],
        );
      },
    );
  }

  // Get current location from GPS
  Future<void> _getCurrentLocationFromGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location access denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location access denied permanently.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _updateAddress(_currentLocation!);
      _getPolyline();
    });
  }

  // Update address based on coordinates
  Future<void> _updateAddress(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress =
              '${place.street}, ${place.locality}, ${place.country}';
        });
      }
    } catch (e) {
      print('Error converting coordinates to address: $e');
    }
  }

  // Update the route from the current location to the destination
  void _getPolyline() {
    polylinePoints = [
      if (_currentLocation != null) _currentLocation!,
      if (_endLocation != null) _endLocation!,
      // Chỉ thêm _endLocation khi nó không null
    ];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: whiteColor,
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Stack(
              children: [
                SizedBox(
                  height: screenHeight * 0.7,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: _currentLocation ?? LatLng(21.0285, 105.8542),
                      zoom: 12.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: [
                          if (_currentLocation != null)
                            Marker(
                              width: 80.0,
                              height: 80.0,
                              point: _currentLocation!,
                              builder: (ctx) => Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 40.0,
                              ),
                            ),
                          if (customerLocation != null)
                            Marker(
                              width: 80.0,
                              height: 80.0,
                              point: customerLocation!,
                              builder: (ctx) => Icon(
                                Icons.person_pin,
                                color: Colors.green,
                                size: 40.0,
                              ),
                            ),
                          if (_endLocation != null)
                            Marker(
                              width: 80.0,
                              height: 80.0,
                              point: _endLocation!,
                              builder: (ctx) => Icon(
                                Icons.flag,
                                color: Colors.blue,
                                size: 40.0,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 20.0,
                  right: 20.0,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        backgroundColor: primaryColor,
                        onPressed: () {
                          if (_currentLocation != null) {
                            // Di chuyển map về vị trí tài xế và zoom đến mức 12.0
                            _mapController.move(_currentLocation!, 12.0);
                          } else {
                            print('Vị trí tài xế hiện chưa có.');
                          }
                        },
                        child: Icon(
                          Icons.my_location,
                          color: whiteColor,
                        ),
                      ),
                      SizedBox(height: 10),
                      FloatingActionButton(
                        backgroundColor: whiteColor,
                        onPressed: () {
                          _mapController.move(
                              _mapController.center, _mapController.zoom + 1);
                        },
                        child: Icon(
                          Icons.zoom_in,
                          color: blackColor,
                        ),
                      ),
                      SizedBox(height: 10),
                      FloatingActionButton(
                        backgroundColor: whiteColor,
                        onPressed: () {
                          _mapController.move(
                              _mapController.center, _mapController.zoom - 1);
                        },
                        child: Icon(
                          Icons.zoom_out,
                          color: blackColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text('Current Address: $_currentAddress'),
                ),
              ),
            ),
            if ((customerName?.isNotEmpty ?? false) &&
                (phoneNumber?.isNotEmpty ?? false)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListTile(
                    title: Text('Customer: $customerName'),
                    subtitle: Text('Phone: $phoneNumber'),
                    trailing: IconButton(
                      icon: Icon(Icons.call),
                      onPressed: () async {
                        final Uri launchUri = Uri(
                          scheme: 'tel',
                          path: phoneNumber,
                        );
                        await launch(launchUri.toString());
                      },
                    ),
                  ),
                ),
              ),
              // Đoạn thêm vào dưới ListTile chứa thông tin customer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    // Hiển thị popup nhập tin nhắn
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        TextEditingController messageController = TextEditingController();
                        return StatefulBuilder(
                          builder: (context, setStateDialog) {
                            // Truyền setStateDialog vào _openWebSocketConnection
                            _openWebSocketConnection(bookingId2, setStateDialog: setStateDialog); // Truyền setStateDialog vào đây
                            return AlertDialog(
                              title: const Text('Nhắn tin cho khách hàng'),
                              content: Container(
                                width: double.maxFinite,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: StreamBuilder(
                                        stream: broadcastStream,
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            // Giải mã dữ liệu nhận được từ WebSocket (snapshot.data là chuỗi JSON)
                                            try {
                                              Map<String, dynamic> messageData = jsonDecode(snapshot.data.toString());
                                              String mess = messageData['message'] ?? ''; // Chỉ lấy phần 'message'

                                              // Thêm tin nhắn vào danh sách
                                              messages.add(ChatMessage(message: mess));

                                            } catch (e) {
                                              print('Error decoding message: $e');
                                            }

                                            // Hiển thị danh sách tin nhắn
                                            return ListView.builder(
                                              itemCount: messages.length,
                                              itemBuilder: (context, index) {
                                                ChatMessage chatMessage = messages[index];
                                                return ListTile(
                                                  title: Text(chatMessage.message),
                                                );
                                              },
                                            );
                                          } else {
                                            return const Center(
                                              child: Text(
                                                'Chưa có tin nhắn', // Hoặc một thông báo khác
                                                style: TextStyle(fontSize: 16, color: Colors.grey),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),


                                    TextField(
                                      controller: messageController,
                                      decoration: const InputDecoration(
                                        hintText: 'Nhập tin nhắn...',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Hủy'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    final message = messageController.text;
                                    if (message.isNotEmpty) {
                                      sendMessage(bookingId2, message);
                                      messageController.clear();
                                      setStateDialog(() {
                                        messages.add(ChatMessage(message: message));
                                      });
                                    }
                                  },
                                  child: const Text('Gửi'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0), // Bo góc
                    ),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(
                    'Nhắn tin cho khách hàng',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Nút Confirm nằm ở đây
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 10.0),
                    ElevatedButton(
                      onPressed: _confirmOrder, // Gọi hàm xác nhận
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0), // Bo góc
                          ),
                          minimumSize: Size(double.infinity, 50),
                          elevation: 12,
                          shadowColor: Colors.black.withOpacity(0.7),
                          backgroundColor: primaryColor),
                      child: Text(
                        'Completed',
                        style: TextStyle(
                            color: whiteColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(height: 50.0), // Thêm margin dưới nút
                  ],
                ),
              )
            ],
          ],
        ),
      ),
    );
  }

  // Hàm để xử lý xác nhận đơn hàng
  void _confirmOrder() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Completion",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: blackColor)),
          content: Text(
              "Are you sure you want to mark the emergency as completed?",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: blackColor)),
          actions: [
            TextButton(
              child: Text(
                "Cancel",
                style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                "Confirm",
                style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _upDateBookingStatus(bookingId2);
                print('confirm booking ' + bookingId2.toString());
                showTemporaryMessage(context, "Booking completed !");
              },
            ),
          ],
        );
      },
    );
  }

  // Hàm để hiển thị thông báo
  void _showOrderNotification(String message) {
    // Đổi tên hàm
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Notification"),
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
}
