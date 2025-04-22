import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class SensorScreen extends StatefulWidget {
  @override
  _SensorScreenState createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  BluetoothConnection? connection;
  bool isConnected = false;
  String receivedData = "";
  String flexValue = "--";
  String soilValue = "--";
  String ultrasonicValue = "--";
  List<FlSpot> flexSpots = [], soilSpots = [], ultraSpots = [];
  int timeCounter = 0;

  // Define thresholds for each sensor
  double flexThreshold = 70.0;
  double soilThreshold = 70.0;
  double ultrasonicThreshold = 70.0;

  @override
  void initState() {
    super.initState();
    connectToHC05();
  }

  void connectToHC05() async {
    try {
      BluetoothDevice? device;
      final bondedDevices =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      for (var d in bondedDevices) {
        if (d.name == "HC-05") {
          device = d;
          break;
        }
      }

      if (device != null) {
        connection = await BluetoothConnection.toAddress(device.address);
        setState(() => isConnected = true);

        connection!.input!.listen((data) {
          final String incoming = ascii.decode(data);
          setState(() {
            receivedData += incoming;
          });

          if (incoming.contains("\n")) {
            final lines = receivedData.split("\n");
            for (var line in lines) {
              if (line.contains(',')) {
                List<String> parts = line.trim().split(',');
                if (parts.length >= 3) {
                  double flex = double.tryParse(parts[0]) ?? 0;
                  double soil = double.tryParse(parts[1]) ?? 0;
                  double ultra = double.tryParse(parts[2]) ?? 0;

                  setState(() {
                    flexValue = flex.toStringAsFixed(1);
                    soilValue = soil.toStringAsFixed(1);
                    ultrasonicValue = ultra.toStringAsFixed(1);
                    flexSpots.add(FlSpot(timeCounter.toDouble(), flex));
                    soilSpots.add(FlSpot(timeCounter.toDouble(), soil));
                    ultraSpots.add(FlSpot(timeCounter.toDouble(), ultra));
                    timeCounter++;
                  });

                  // Check if any sensor value exceeds its threshold
                  if (flex > flexThreshold ||
                      soil > soilThreshold ||
                      ultra > ultrasonicThreshold) {
                    uploadToFirebase(flex, soil, ultra);
                  }
                }
              }
            }
            receivedData = "";
          }
        });
      } else {
        print("HC-05 not found");
      }
    } catch (e) {
      print("Connection failed: $e");
    }
  }

  // Function to upload data to Firebase
  void uploadToFirebase(double flex, double soil, double ultra) {
    FirebaseFirestore.instance.collection("sensor_data").add({
      'flex': flex,
      'soil': soil,
      'ultrasonic': ultra,
      'flex_exceeded': flex > flexThreshold,
      'soil_exceeded': soil > soilThreshold,
      'ultrasonic_exceeded': ultra > ultrasonicThreshold,
      'timestamp': Timestamp.now(),
    });
  }

  // Function to manually upload current values
  void manualUpload() {
    double flex = double.tryParse(flexValue) ?? 0;
    double soil = double.tryParse(soilValue) ?? 0;
    double ultra = double.tryParse(ultrasonicValue) ?? 0;

    // Upload to Firebase with threshold status
    FirebaseFirestore.instance.collection("sensor_data").add({
      'flex': flex,
      'soil': soil,
      'ultrasonic': ultra,
      'flex_exceeded': flex > flexThreshold,
      'soil_exceeded': soil > soilThreshold,
      'ultrasonic_exceeded': ultra > ultrasonicThreshold,
      'manual_upload': true,
      'timestamp': Timestamp.now(),
    }).then((_) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload data: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  Widget buildSensorCard(String label, String value, double threshold) {
    double parsedValue = double.tryParse(value) ?? 0;
    bool isExceeded = parsedValue > threshold;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.sensors, color: Colors.blue),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    color: isExceeded ? Colors.red : Colors.green)),
            if (isExceeded) Icon(Icons.warning, color: Colors.red, size: 18)
          ],
        ),
      ),
    );
  }

  Widget buildLineChart(List<FlSpot> data, String title) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
                height: 200,
                child: LineChart(LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: data,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                    )
                  ],
                ))),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text("Sensor Monitor"), backgroundColor: Colors.blue),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 10),
            Text(
              isConnected ? "Connected to HC-05" : "Disconnected",
              style: TextStyle(
                  color: isConnected ? Colors.green : Colors.red, fontSize: 16),
            ),
            buildSensorCard("Flex Sensor", flexValue, flexThreshold),
            buildSensorCard("Soil Moisture", soilValue, soilThreshold),
            buildSensorCard("Ultrasonic", ultrasonicValue, ultrasonicThreshold),

            // Manual upload button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton.icon(
                onPressed: manualUpload,
                icon: Icon(Icons.cloud_upload),
                label: Text("Upload Current Values"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),

            buildLineChart(flexSpots, "Flex Sensor Data"),
            buildLineChart(soilSpots, "Soil Moisture Data"),
            buildLineChart(ultraSpots, "Ultrasonic Data"),
          ],
        ),
      ),
    );
  }
}













// Latest working code
// import 'package:flutter/material.dart';
// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// class SensorScreen extends StatefulWidget {
//   const SensorScreen({super.key});

//   @override
//   _SensorScreenState createState() => _SensorScreenState();
// }

// class _SensorScreenState extends State<SensorScreen> {
//   BluetoothConnection? connection;
//   String receivedData = '';

//   double distance = 0.0;
//   int moisture = 0;
//   double flexResistance = 0.0;

//   // Define threshold values for sensors
//   final double distanceThreshold = 50.0; // cm
//   final int moistureThreshold = 70; // percentage
//   final double flexResistanceThreshold = 15000.0; // Ohms

//   bool isConnecting = true;
//   bool isDisconnecting = false;
//   bool thresholdsExceeded = false;

//   // For displaying the exceeded thresholds
//   Map<String, bool> exceededSensors = {
//     'distance': false,
//     'moisture': false,
//     'flexResistance': false
//   };

//   @override
//   void initState() {
//     super.initState();
//     connectToBluetooth();
//   }

//   void connectToBluetooth() async {
//     try {
//       // Get all bonded devices
//       List<BluetoothDevice> devices =
//           await FlutterBluetoothSerial.instance.getBondedDevices();

//       // Find HC-05 device
//       BluetoothDevice? hc05;
//       for (var device in devices) {
//         if (device.name == 'HC-05') {
//           hc05 = device;
//           break;
//         }
//       }

//       if (hc05 == null) {
//         print('No HC-05 device found!');
//         setState(() {
//           isConnecting = false;
//         });
//         return;
//       }

//       // Continue with your existing connection logic using hc05...
//       BluetoothConnection.toAddress(hc05.address).then((conn) {
//         // Your existing connection code continues here
//         print('Connected to HC-05');
//         connection = conn;
//         setState(() {
//           isConnecting = false;
//         });

//         connection!.input!.listen((data) {
//           setState(() {
//             receivedData += String.fromCharCodes(data);
//           });

//           if (receivedData.contains('\n')) {
//             parseData(receivedData);
//             receivedData = '';
//           }
//         }).onDone(() {
//           print('Disconnected!');
//           if (mounted) {
//             setState(() {
//               isDisconnecting = true;
//             });
//           }
//         });
//       });
//     } catch (e) {
//       print('Error: $e');
//       setState(() {
//         isConnecting = false;
//       });
//     }
//   }

//   void parseData(String data) {
//     print('Raw Data: $data');

//     try {
//       // Expecting structured data
//       // Example format:
//       // ------ Sensor Data ------
//       // Distance (cm): 123.45
//       // Moisture Detected (%): 67
//       // Flex Sensor Resistance (Ohms): 10450.2
//       // -------------------------

//       List<String> lines = data.split('\n');

//       double tempDistance = 0.0;
//       int tempMoisture = 0;
//       double tempFlex = 0.0;

//       for (String line in lines) {
//         if (line.contains('Distance (cm):')) {
//           tempDistance = double.tryParse(line.split(':')[1].trim()) ?? 0.0;
//         } else if (line.contains('Moisture Detected (%):')) {
//           tempMoisture = int.tryParse(line.split(':')[1].trim()) ?? 0;
//         } else if (line.contains('Flex Sensor Resistance (Ohms):')) {
//           tempFlex = double.tryParse(line.split(':')[1].trim()) ?? 0.0;
//         }
//       }

//       setState(() {
//         distance = tempDistance;
//         moisture = tempMoisture;
//         flexResistance = tempFlex;

//         // Check if any threshold is exceeded
//         exceededSensors['distance'] = distance > distanceThreshold;
//         exceededSensors['moisture'] = moisture > moistureThreshold;
//         exceededSensors['flexResistance'] =
//             flexResistance > flexResistanceThreshold;

//         thresholdsExceeded = exceededSensors.values.any((exceeded) => exceeded);
//       });

//       // Only upload data if any threshold is exceeded
//       if (thresholdsExceeded) {
//         uploadDataToFirebase();
//       }
//     } catch (e) {
//       print('Error parsing data: $e');
//     }
//   }

//   void uploadDataToFirebase() {
//     FirebaseFirestore.instance.collection('sensorData').add({
//       'distance': distance,
//       'moisture': moisture,
//       'flexResistance': flexResistance,
//       'distanceExceeded': exceededSensors['distance'],
//       'moistureExceeded': exceededSensors['moisture'],
//       'flexResistanceExceeded': exceededSensors['flexResistance'],
//       'timestamp': FieldValue.serverTimestamp(),
//     }).then((value) {
//       print('Data uploaded successfully!');
//     }).catchError((error) {
//       print('Failed to upload data: $error');
//     });
//   }

//   @override
//   void dispose() {
//     if (connection != null && connection!.isConnected) {
//       connection!.dispose();
//       connection = null;
//     }
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Sensor Data via Bluetooth'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: isConnecting
//             ? const Center(child: CircularProgressIndicator())
//             : Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Live Sensor Readings:',
//                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 20),
//                   Text(
//                     'Distance: ${distance.toStringAsFixed(2)} cm',
//                     style: TextStyle(
//                       color: exceededSensors['distance']!
//                           ? Colors.red
//                           : Colors.black,
//                       fontWeight: exceededSensors['distance']!
//                           ? FontWeight.bold
//                           : FontWeight.normal,
//                     ),
//                   ),
//                   Text(
//                     'Moisture: $moisture %',
//                     style: TextStyle(
//                       color: exceededSensors['moisture']!
//                           ? Colors.red
//                           : Colors.black,
//                       fontWeight: exceededSensors['moisture']!
//                           ? FontWeight.bold
//                           : FontWeight.normal,
//                     ),
//                   ),
//                   Text(
//                     'Flex Resistance: ${flexResistance.toStringAsFixed(2)} Ohms',
//                     style: TextStyle(
//                       color: exceededSensors['flexResistance']!
//                           ? Colors.red
//                           : Colors.black,
//                       fontWeight: exceededSensors['flexResistance']!
//                           ? FontWeight.bold
//                           : FontWeight.normal,
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   Text(
//                     'Thresholds:',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                   Text('Distance: $distanceThreshold cm'),
//                   Text('Moisture: $moistureThreshold %'),
//                   Text('Flex Resistance: $flexResistanceThreshold Ohms'),
//                   const SizedBox(height: 20),
//                   thresholdsExceeded
//                       ? const Text(
//                           'Alert: Thresholds exceeded!',
//                           style: TextStyle(
//                             color: Colors.red,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 18,
//                           ),
//                         )
//                       : const SizedBox.shrink(),
//                   const SizedBox(height: 20),
//                   Row(
//                     children: [
//                       ElevatedButton(
//                         onPressed: uploadDataToFirebase,
//                         child: const Text('Upload Current Data Manually'),
//                       ),
//                       const SizedBox(width: 10),
//                       ElevatedButton(
//                         onPressed: () {
//                           // Reset the connection
//                           if (connection != null && connection!.isConnected) {
//                             connection!.dispose();
//                             connection = null;
//                           }
//                           setState(() {
//                             isConnecting = true;
//                           });
//                           connectToBluetooth();
//                         },
//                         child: const Text('Reconnect Bluetooth'),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//       ),
//     );
//   }
// }

















// import 'package:flutter/material.dart';
// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// class SensorScreen extends StatefulWidget {
//   const SensorScreen({super.key});

//   @override
//   _SensorScreenState createState() => _SensorScreenState();
// }

// class _SensorScreenState extends State<SensorScreen> {
//   BluetoothConnection? connection;
//   String receivedData = '';

//   double distance = 0.0;
//   int moisture = 0;
//   double flexResistance = 0.0;

//   bool isConnecting = true;
//   bool isDisconnecting = false;

//   @override
//   void initState() {
//     super.initState();
//     connectToBluetooth();
//   }

//   // void connectToBluetooth() async {
//   //   try {
//   //     // Connect to the first paired HC-05 device found
//   //     BluetoothDevice? hc05 = (await FlutterBluetoothSerial.instance
//   //             .getBondedDevices())
//   //         .firstWhere((device) => device.name == 'HC-05', orElse: () => null);

//   //     if (hc05 == null) {
//   //       print('No HC-05 device found!');
//   //       return;
//   //     }

//   //     BluetoothConnection.toAddress(hc05.address).then((_connection) {
//   //       print('Connected to HC-05');
//   //       connection = _connection;
//   //       setState(() {
//   //         isConnecting = false;
//   //       });

//   //       connection!.input!.listen((data) {
//   //         setState(() {
//   //           receivedData += String.fromCharCodes(data);
//   //         });

//   //         if (receivedData.contains('\n')) {
//   //           parseData(receivedData);
//   //           receivedData = '';
//   //         }
//   //       }).onDone(() {
//   //         print('Disconnected!');
//   //         if (this.mounted) {
//   //           setState(() {
//   //             isDisconnecting = true;
//   //           });
//   //         }
//   //       });
//   //     });
//   //   } catch (e) {
//   //     print('Error: $e');
//   //   }
//   // }

//   void connectToBluetooth() async {
//     try {
//       // Get all bonded devices
//       List<BluetoothDevice> devices =
//           await FlutterBluetoothSerial.instance.getBondedDevices();

//       // Find HC-05 device
//       BluetoothDevice? hc05;
//       for (var device in devices) {
//         if (device.name == 'HC-05') {
//           hc05 = device;
//           break;
//         }
//       }

//       if (hc05 == null) {
//         print('No HC-05 device found!');
//         setState(() {
//           isConnecting = false;
//         });
//         return;
//       }

//       // Continue with your existing connection logic using hc05...
//       BluetoothConnection.toAddress(hc05.address).then((connection) {
//         // Your existing connection code continues here
//         print('Connected to HC-05');
//         connection = connection;
//         setState(() {
//           isConnecting = false;
//         });

//         connection!.input!.listen((data) {
//           setState(() {
//             receivedData += String.fromCharCodes(data);
//           });

//           if (receivedData.contains('\n')) {
//             parseData(receivedData);
//             receivedData = '';
//           }
//         }).onDone(() {
//           print('Disconnected!');
//           if (mounted) {
//             setState(() {
//               isDisconnecting = true;
//             });
//           }
//         });
//       });
//     } catch (e) {
//       print('Error: $e');
//       setState(() {
//         isConnecting = false;
//       });
//     }
//   }

//   void parseData(String data) {
//     print('Raw Data: $data');

//     try {
//       // Expecting structured data
//       // Example format:
//       // ------ Sensor Data ------
//       // Distance (cm): 123.45
//       // Moisture Detected (%): 67
//       // Flex Sensor Resistance (Ohms): 10450.2
//       // -------------------------

//       List<String> lines = data.split('\n');

//       double tempDistance = 0.0;
//       int tempMoisture = 0;
//       double tempFlex = 0.0;

//       for (String line in lines) {
//         if (line.contains('Distance (cm):')) {
//           tempDistance = double.tryParse(line.split(':')[1].trim()) ?? 0.0;
//         } else if (line.contains('Moisture Detected (%):')) {
//           tempMoisture = int.tryParse(line.split(':')[1].trim()) ?? 0;
//         } else if (line.contains('Flex Sensor Resistance (Ohms):')) {
//           tempFlex = double.tryParse(line.split(':')[1].trim()) ?? 0.0;
//         }
//       }

//       setState(() {
//         distance = tempDistance;
//         moisture = tempMoisture;
//         flexResistance = tempFlex;
//       });

//       uploadDataToFirebase();
//     } catch (e) {
//       print('Error parsing data: $e');
//     }
//   }

//   void uploadDataToFirebase() {
//     FirebaseFirestore.instance.collection('sensorData').add({
//       'distance': distance,
//       'moisture': moisture,
//       'flexResistance': flexResistance,
//       'timestamp': FieldValue.serverTimestamp(),
//     }).then((value) {
//       print('Data uploaded successfully!');
//     }).catchError((error) {
//       print('Failed to upload data: $error');
//     });
//   }

//   @override
//   void dispose() {
//     if (connection != null && connection!.isConnected) {
//       connection!.dispose();
//       connection = null;
//     }
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Sensor Data via Bluetooth'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: isConnecting
//             ? const Center(child: CircularProgressIndicator())
//             : Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Live Sensor Readings:',
//                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 20),
//                   Text('Distance: ${distance.toStringAsFixed(2)} cm'),
//                   Text('Moisture: $moisture %'),
//                   Text(
//                       'Flex Resistance: ${flexResistance.toStringAsFixed(2)} Ohms'),
//                   const SizedBox(height: 20),
//                   ElevatedButton(
//                     onPressed: uploadDataToFirebase,
//                     child: const Text('Upload Current Data Manually'),
//                   ),
//                 ],
//               ),
//       ),
//     );
//   }
// }
