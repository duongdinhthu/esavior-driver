import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http; // Import HTTP library
import 'dart:convert'; // Import for JSON handling
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';


class Order extends StatefulWidget {
  final bool isLoggedIn;
  final Function onLogout;
  final int? driverId;
  final Map<String, dynamic> driverData;


  Order({required this.isLoggedIn, required this.onLogout, this.driverId, required this.driverData});


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
  bool hasNewOrderNotification = false; // Variable to check if notification has been shown
  StreamSubscription<Position>? _positionStream;
  MapController _mapController = MapController();
  bool notification = false;
  int? bookingId2;
  bool hasAcknowledgedOrder = false;  // Biến để theo dõi xem tài xế đã xác nhận đơn hàng chưa
  Timer? _locationTimer;
  Timer? _timer;

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
      customerName = savedCustomerName;
      phoneNumber = savedPhoneNumber;
      bookingId2 = savedBookingId;
    });
  }


  @override
  void dispose() {
    _positionStream?.cancel();
    _locationTimer?.cancel();
    _saveDriverState(); // Lưu trạng thái trước khi thoát
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
    prefs.setString('customerName', customerName ?? '');
    prefs.setString('phoneNumber', phoneNumber ?? '');
    prefs.setInt('bookingId', bookingId2 ?? 0);
  }

  // In ra thông báo hoàn thành đơn hàng
  void _startLocationUpdates() {
    Timer.periodic(Duration(seconds: 5), (timer) {
      print('Driver ID after clearing: ${widget.driverId}'); // Thêm log kiểm tra
      _sendLocationUpdate();
      print(widget.driverId);
      // Send driver's location to server
      if (widget.driverId != null) {  // Chỉ kiểm tra nếu tài xế chưa xác nhận đơn hàng
        getDriverById(widget.driverId!);
      } else {
        print("Driver ID is null or order has been acknowledged");
      }
    });
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
        Uri.parse('https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/bookings/update-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bookingStatus': status,
          'bookingId': bookingId1,
        }),
      );

      if (response.statusCode == 200) {
        showTemporaryMessage(context, "Emergency booking complete!");
        String status1 = "Active";
        await _updateDriverStatus(widget.driverId,
            status1);
        _resetScreen();
        _clearBookingStatus();
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
      await prefs.remove('isSuccessBooked'); // Xóa trạng thái đã đặt chỗ thành công
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
        print('Driver ID after clearing: ${widget.driverId}'); // Thêm log kiểm tra

      });

      // Thông báo cho người dùng
      showTemporaryMessage(context, "Booking cleared successfully!");
    } catch (error) {
      print("Error clearing booking status: $error");
      showTemporaryMessage(context, "Error clearing booking, please try again.");
    }
  }

  Future<void> _checkBookingStatus(int? bookingId2) async {
    try {
      // Gọi API để kiểm tra trạng thái booking
      final response = await http.get(Uri.parse('https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/bookings/$bookingId2'));
      print('check status booking with booking ' + bookingId2.toString());

      if (response.statusCode == 200) {
        // Parse JSON
        final bookingData = jsonDecode(response.body);

        // Kiểm tra nếu `bookingStatus` là 'Completed'
        if (bookingData['bookingStatus'] == 'Completed') {

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
    final String apiUrl = 'https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/drivers/$driverId'; // Đặt URL API chính xác
    print('check tai xe '+driverId.toString());
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        // Kiểm tra nếu status là "Active"
        if (data['status'] == 'Active') {
          print('Driver is active: ${data['driverName']}');
          _checkDriverBooking(); // Check for new ride request information
        } else if(data['status'] == 'Deactive'){
          print('Tài xế chưa active, đang kiểm tra đơn hàng chưa hoàn thành...');
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
        Uri.parse('https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/bookings/unfinished/$driverId'),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);

        // Thay đổi bookingId thành kiểu int
        int bookingId = data['bookingId']; // Sửa thành int
        String customerName = data['patientName'];
        String phoneNumber = data['patientPhone'];
        double pickupLatitude = data['latitude'];
        double pickupLongitude = data['longitude'];
        double destinationLatitude = data['destinationLatitude'];
        double destinationLongitude = data['destinationLongitude'];
        bookingId2 = bookingId;
        setState(() {
          customerLocation = LatLng(pickupLatitude, pickupLongitude);
          _endLocation = LatLng(destinationLatitude, destinationLongitude);
          this.customerName = customerName;
          this.phoneNumber = phoneNumber;
        });
        _checkBookingStatus(bookingId2);
        print(data.toString() );
        print('booking id chưa hoàn thành :' + bookingId.toString());
        if(notification == true && hasAcknowledgedOrder == true ){

          _showNotification('Đơn hàng chưa hoàn thành: Khách hàng $customerName, Điểm đón: ($pickupLatitude, $pickupLongitude), Điểm đến: ($destinationLatitude, $destinationLongitude)');
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

    if (driverId != null) {  // Chỉ kiểm tra đơn hàng mới nếu chưa xác nhận
      final response = await http.get(
        Uri.parse('https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/drivers/check-driver/$driverId'),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);

        // Get customer info and coordinates from response
        String newCustomerName = data['customerName'];
        String newPhoneNumber = data['phoneNumber'];

        // Get both pickup and destination coordinates
        double pickupLatitude = data['latitude']; // Vị trí đón (pickup)
        double pickupLongitude = data['longitude']; // Vị trí đón (pickup)
        double destinationLatitude = data['destinationLatitude']; // Vị trí đến (destination)
        double destinationLongitude = data['destinationLongitude']; // Vị trí đến (destination)

        // Update customer pickup and destination locations
        setState(() {
          customerLocation = LatLng(pickupLatitude, pickupLongitude); // Cập nhật vị trí đón
          customerName = newCustomerName;
          phoneNumber = newPhoneNumber;
          _endLocation = LatLng(destinationLatitude, destinationLongitude); // Cập nhật vị trí đến
        });

        // Show notification only if it hasn't been acknowledged
        if (!hasAcknowledgedOrder) {
          _showNotification(
              'Customer: $customerName, Phone: $phoneNumber\nPickup: ($pickupLatitude, $pickupLongitude)\nDestination: ($destinationLatitude, $destinationLongitude)');
          hasNewOrderNotification = true; // Mark that the notification has been displayed
        }

        // Update both pickup and destination locations on the map
        _getPolyline(); // Cập nhật tuyến đường giữa vị trí tài xế, điểm đón và điểm đến
      } else {
        if(hasAcknowledgedOrder == true)
        print("No new ride request information.");
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
      _mapController.move(_currentLocation!, 12.0); // Mức độ zoom là 12.0

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
      if (_endLocation != null) _endLocation!, // Chỉ thêm _endLocation khi nó không null
    ];
    setState(() {});
  }



  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;


    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: screenHeight * 0.7,
              child: FlutterMap(
                mapController: _mapController, // Gán MapController vào đây
                options: MapOptions(
                  center: _currentLocation ?? LatLng(21.0285, 105.8542),
                  zoom: 12.0, // Đặt mức độ zoom ban đầu
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
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
            if (customerName != null && phoneNumber != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
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
              // Nút Confirm nằm ở đây
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    SizedBox(height: 10.0), // Thêm khoảng cách phía trên nút (20.0 là giá trị bạn có thể tùy chỉnh)
                    ElevatedButton(
                      onPressed: _confirmOrder, // Gọi hàm xác nhận
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0), // Chỉ padding theo chiều dọc
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0), // Bo góc
                        ),
                        minimumSize: Size(double.infinity, 50), // Mở rộng hết chiều ngang, với chiều cao là 50
                        elevation: 12, // Độ đậm bóng (càng lớn thì bóng càng đậm)
                        shadowColor: Colors.black.withOpacity(0.7), // Màu của bóng đổ
                      ),
                      child: Text('Confirm'),
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
          title: Text("Confirm Order"),
          content: Text("Do you want to confirm this order?"),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Confirm"),
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
  void _showOrderNotification(String message) { // Đổi tên hàm
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

