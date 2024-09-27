import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

// Hàm kiểm tra đơn hàng của tài xế
Future<void> checkDriverBooking(int driverId) async {
  final String apiUrl = 'https://techwiz-b3fsfvavawb9fpg8.japanwest-01.azurewebsites.net/api/drivers/$driverId';

  try {
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      // Kiểm tra nếu status là "Active"
      if (data['status'] == 'Active') {
        print('Driver is active: ${data['driverName']}');
        // Thực hiện hành động kiểm tra đơn hàng mới
        // Gọi API để kiểm tra đơn hàng mới cho tài xế
      } else {
        print('Tài xế chưa active, đang kiểm tra đơn hàng chưa hoàn thành...');
        // Gọi API kiểm tra đơn hàng chưa hoàn thành
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

// Hàm được gọi bởi WorkManager khi thực hiện task nền
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    int driverId = inputData!['driverId'];
    await checkDriverBooking(driverId);
    return Future.value(true);
  });
}
