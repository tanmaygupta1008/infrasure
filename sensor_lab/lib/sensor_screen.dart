import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});

  @override
  _SensorScreenState createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  BluetoothConnection? connection;
  String receivedData = '';

  double distance = 0.0;
  int moisture = 0;
  double flexResistance = 0.0;

  bool isConnecting = true;
  bool isDisconnecting = false;

  @override
  void initState() {
    super.initState();
    connectToBluetooth();
  }

  // void connectToBluetooth() async {
  //   try {
  //     // Connect to the first paired HC-05 device found
  //     BluetoothDevice? hc05 = (await FlutterBluetoothSerial.instance
  //             .getBondedDevices())
  //         .firstWhere((device) => device.name == 'HC-05', orElse: () => null);

  //     if (hc05 == null) {
  //       print('No HC-05 device found!');
  //       return;
  //     }

  //     BluetoothConnection.toAddress(hc05.address).then((_connection) {
  //       print('Connected to HC-05');
  //       connection = _connection;
  //       setState(() {
  //         isConnecting = false;
  //       });

  //       connection!.input!.listen((data) {
  //         setState(() {
  //           receivedData += String.fromCharCodes(data);
  //         });

  //         if (receivedData.contains('\n')) {
  //           parseData(receivedData);
  //           receivedData = '';
  //         }
  //       }).onDone(() {
  //         print('Disconnected!');
  //         if (this.mounted) {
  //           setState(() {
  //             isDisconnecting = true;
  //           });
  //         }
  //       });
  //     });
  //   } catch (e) {
  //     print('Error: $e');
  //   }
  // }

  void connectToBluetooth() async {
    try {
      // Get all bonded devices
      List<BluetoothDevice> devices =
          await FlutterBluetoothSerial.instance.getBondedDevices();

      // Find HC-05 device
      BluetoothDevice? hc05;
      for (var device in devices) {
        if (device.name == 'HC-05') {
          hc05 = device;
          break;
        }
      }

      if (hc05 == null) {
        print('No HC-05 device found!');
        setState(() {
          isConnecting = false;
        });
        return;
      }

      // Continue with your existing connection logic using hc05...
      BluetoothConnection.toAddress(hc05.address).then((connection) {
        // Your existing connection code continues here
        print('Connected to HC-05');
        connection = connection;
        setState(() {
          isConnecting = false;
        });

        connection!.input!.listen((data) {
          setState(() {
            receivedData += String.fromCharCodes(data);
          });

          if (receivedData.contains('\n')) {
            parseData(receivedData);
            receivedData = '';
          }
        }).onDone(() {
          print('Disconnected!');
          if (mounted) {
            setState(() {
              isDisconnecting = true;
            });
          }
        });
      });
    } catch (e) {
      print('Error: $e');
      setState(() {
        isConnecting = false;
      });
    }
  }

  void parseData(String data) {
    print('Raw Data: $data');

    try {
      // Expecting structured data
      // Example format:
      // ------ Sensor Data ------
      // Distance (cm): 123.45
      // Moisture Detected (%): 67
      // Flex Sensor Resistance (Ohms): 10450.2
      // -------------------------

      List<String> lines = data.split('\n');

      double tempDistance = 0.0;
      int tempMoisture = 0;
      double tempFlex = 0.0;

      for (String line in lines) {
        if (line.contains('Distance (cm):')) {
          tempDistance = double.tryParse(line.split(':')[1].trim()) ?? 0.0;
        } else if (line.contains('Moisture Detected (%):')) {
          tempMoisture = int.tryParse(line.split(':')[1].trim()) ?? 0;
        } else if (line.contains('Flex Sensor Resistance (Ohms):')) {
          tempFlex = double.tryParse(line.split(':')[1].trim()) ?? 0.0;
        }
      }

      setState(() {
        distance = tempDistance;
        moisture = tempMoisture;
        flexResistance = tempFlex;
      });

      uploadDataToFirebase();
    } catch (e) {
      print('Error parsing data: $e');
    }
  }

  void uploadDataToFirebase() {
    FirebaseFirestore.instance.collection('sensorData').add({
      'distance': distance,
      'moisture': moisture,
      'flexResistance': flexResistance,
      'timestamp': FieldValue.serverTimestamp(),
    }).then((value) {
      print('Data uploaded successfully!');
    }).catchError((error) {
      print('Failed to upload data: $error');
    });
  }

  @override
  void dispose() {
    if (connection != null && connection!.isConnected) {
      connection!.dispose();
      connection = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Data via Bluetooth'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isConnecting
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live Sensor Readings:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text('Distance: ${distance.toStringAsFixed(2)} cm'),
                  Text('Moisture: $moisture %'),
                  Text(
                      'Flex Resistance: ${flexResistance.toStringAsFixed(2)} Ohms'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: uploadDataToFirebase,
                    child: const Text('Upload Current Data Manually'),
                  ),
                ],
              ),
      ),
    );
  }
}
