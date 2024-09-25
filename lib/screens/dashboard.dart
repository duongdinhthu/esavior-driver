import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const primaryColor = Color.fromARGB(255, 200, 50, 0);
const whiteColor = Color.fromARGB(255, 255, 255, 255);
const blackColor = Color.fromARGB(255, 0, 0, 0);
const blueColor = Color.fromARGB(255, 33, 150, 233);

class Booking {
  final int bookingId;
  final String pickupAddress;
  final String bookingStatus;
  final double latitude;
  final double longitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final String bookingType;
  final String pickupTime;
  final String ambulanceType;
  final double cost;

  Booking({
    required this.bookingId,
    required this.pickupAddress,
    required this.bookingStatus,
    required this.latitude,
    required this.longitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.bookingType,
    required this.pickupTime,
    required this.ambulanceType,
    required this.cost,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      bookingId: json['bookingId'],
      pickupAddress: json['pickupAddress'] ?? '',
      bookingStatus: json['bookingStatus'] ?? '',
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      destinationLatitude: json['destinationLatitude']?.toDouble() ?? 0.0,
      destinationLongitude: json['destinationLongitude']?.toDouble() ?? 0.0,
      bookingType: json['bookingType'] ?? '',
      pickupTime: json['pickupTime'] ?? '',
      ambulanceType: json['ambulanceType'] ?? '',
      cost: json['cost']?.toDouble() ?? 0.0,
    );
  }
}

class BookingListPage extends StatefulWidget {
  final bool isLoggedIn;
  final Function onLogout;
  final int? driverId;

  BookingListPage(
      {required this.isLoggedIn, required this.onLogout, this.driverId});

  @override
  _BookingListPageState createState() => _BookingListPageState();
}

class _BookingListPageState extends State<BookingListPage> {
  List<Booking> bookings = [];
  bool _isLoggedIn = false;
  int _selectedTab = 0; // 0 for Bookings, 1 for Completed Bookings
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.isLoggedIn;
    if (_isLoggedIn) {
      fetchBookings();
    }
  }

  Future<void> fetchBookings() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/bookings/driverId/${widget.driverId}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> bookingData = json.decode(response.body);
        setState(() {
          bookings = bookingData.map((data) => Booking.fromJson(data)).toList();
        });
      } else {
        print('Failed to load bookings. Status code: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching bookings: $error');
    }
  }

  void _login() {
    String username = _usernameController.text;
    String password = _passwordController.text;

    if (username == 'user' && password == 'password') {
      setState(() {
        _isLoggedIn = true;
        errorMessage = '';
        fetchBookings();
      });
    } else {
      setState(() {
        errorMessage = 'Invalid username or password';
      });
    }
  }

  Future<void> _updateBookingStatus(int bookingId) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/bookings/update-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bookingId': bookingId,
          'bookingStatus': 'Completed',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        fetchBookings();
      } else {
        print(response.statusCode);
        setState(() {
          errorMessage = 'Failed to update booking status';
        });
      }
    } catch (error) {
      print(error);
      setState(() {
        errorMessage = 'Error updating booking: ${error.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor, // Đổi màu nền
        title: Text(
          _isLoggedIn ? 'List of booking trips' : 'Login',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold), // Đổi màu và kiểu chữ
        ),
      ),
      body: _isLoggedIn ? _buildBookingTabs() : _buildLoginScreen(),
    );
  }

  Widget _buildLoginScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: 'Username'),
          ),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _login,
            child: Text('Login'),
          ),
          if (errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                errorMessage,
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBookingTabs() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0), // Thêm padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedTab = 0; // Show Bookings
                    });
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor), // Đổi màu nút
                  child: Text('Calendar Book',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
              SizedBox(width: 8), // Thêm khoảng cách giữa các nút
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedTab = 1; // Show Completed Bookings
                    });
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor), // Đổi màu nút
                  child: Text('History Gone',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _selectedTab == 0
              ? _buildActiveBookings()
              : _buildCompletedBookings(),
        ),
      ],
    );
  }

  Widget _buildActiveBookings() {
    final activeBookings =
        bookings.where((b) => b.bookingStatus != 'Completed').toList();
    activeBookings.sort((a, b) =>
        b.bookingId.compareTo(a.bookingId)); // Sort by bookingId descending

    return activeBookings.isEmpty
        ? Center(child: Text('No active bookings'))
        : ListView.builder(
            itemCount: activeBookings.length,
            itemBuilder: (context, index) {
              final booking = activeBookings[index];

              // Parse and format the pickupTime
              DateTime pickupTime =
                  DateTime.tryParse(booking.pickupTime) ?? DateTime.now();
              String formattedTime =
                  DateFormat('dd/MM/yyyy HH:mm').format(pickupTime);

              return Card(
                color: Colors.white,
                margin: EdgeInsets.all(8.0), // Add margin between cards
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded corners
                  side: BorderSide(color: Colors.grey, width: 2), // Blue border
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0), // Add padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pickup Time in red with formatted time
                      Text(
                        'Pickup Time: $formattedTime',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red, // Red color for pickup time
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Pickup Address: ${booking.pickupAddress}'),
                      Row(
                        children: [
                          Text('Status: '), // Keep "Status" label unchanged
                          Text(
                            '${booking.bookingStatus}',
                            style: TextStyle(
                              color: booking.bookingStatus == 'Pending'
                                  ? Colors.orange // Yellow for pending status
                                  : Colors
                                      .black, // Default color for other statuses
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text('Ambulance Type: ${booking.ambulanceType}'),
                      Text('Cost: \$${booking.cost.toStringAsFixed(2)}'),
                      if (booking.bookingStatus != 'Completed')
                        ElevatedButton(
                          onPressed: () =>
                              _showConfirmationDialog(context, booking),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                primaryColor, // Change button color
                          ),
                          child: Text('Mark as Completed',
                              style: TextStyle(color: Colors.white)),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  void _showConfirmationDialog(BuildContext context, Booking booking) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Completion'),
          content:
              Text('Are you sure you want to mark this booking as completed?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () {
                _updateBookingStatus(booking.bookingId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompletedBookings() {
    final completedBookings =
        bookings.where((b) => b.bookingStatus == 'Completed').toList();
    completedBookings.sort((a, b) =>
        b.bookingId.compareTo(a.bookingId)); // Sort by bookingId descending

    return completedBookings.isEmpty
        ? Center(child: Text('No completed bookings'))
        : ListView.builder(
            itemCount: completedBookings.length,

            itemBuilder: (context, index) {
              final booking = completedBookings[index];
              DateTime pickupTime =
                  DateTime.tryParse(booking.pickupTime) ?? DateTime.now();
              String formattedTime =
              DateFormat('dd/MM/yyyy HH:mm').format(pickupTime);
              return Card(
                color: Colors.white, // Background color
                margin: EdgeInsets.all(8.0), // Margin
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey, width: 2),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pickup Time in red
                          Text(
                            'Pickup Time: $formattedTime',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red, // Red color for pickup time
                            ),
                          ),
                          SizedBox(height: 8),
                          Text('Pickup Address: ${booking.pickupAddress}'),
                          Row(
                            children: [
                              Text('Status: '),
                              Text(
                                '${booking.bookingStatus}',
                                style: TextStyle(
                                  color: booking.bookingStatus == 'Completed'
                                      ? Colors.green
                                      : Colors
                                          .black, // Blue only for 'Completed'
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text('Ambulance Type: ${booking.ambulanceType}'),
                          Text('Cost: \$${booking.cost.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                    // Checkmark icon in the top-right corner
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.check_circle,
                        color: primaryColor, // Green checkmark
                        size: 24,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }
}
