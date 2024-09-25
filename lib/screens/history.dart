import 'package:flutter/material.dart';
import 'package:flutter/services.dart';



class History extends StatefulWidget {
  final bool isLoggedIn;
  final Function onLogout;

  History({required this.isLoggedIn, required this.onLogout});

  @override
  _HistoryState createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(),
    );
  }
}
