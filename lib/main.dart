import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(BGWFlixApp());
}

class BGWFlixApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BGW Flix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: HomeScreen(),
    );
  }
}
