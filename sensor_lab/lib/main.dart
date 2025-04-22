import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart'; // For displaying the graph
import 'sensor_screen.dart'; // Importing the Sensor Screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sensor Bluetooth App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SensorScreen(), // Set SensorScreen as the home page
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'sensor_screen.dart'; // Importing the Sensor Screen

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(); // Initialize Firebase
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Sensor Bluetooth App',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: SensorScreen(), // Set SensorScreen as the home page
//     );
//   }
// }
