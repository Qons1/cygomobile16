import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'qr_code_screen.dart';
import 'package:cygo_ps/app_drawer.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'vehicle_selection_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final String userName;
  final String profileImageUrl;

  const WelcomeScreen({
    super.key,
    required this.userName,
    required this.profileImageUrl,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final DatabaseReference _layoutRef =
      FirebaseDatabase.instance.ref('/configurations/layout/slotsByFloor');

  int carCount = 0;
  int motorCount = 0;
  Stream<DatabaseEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _layoutRef.onValue;
    _sub!.listen((event) {
      final data = event.snapshot.value;
      int newCar = 0;
      int newMotor = 0;

      if (data is Map) {
        data.forEach((floor, types) {
          if (types is Map) {
            final carList = types['Car'];
            final motorList = types['Motorcycle'];
            newCar += _countSlots(carList);
            newMotor += _countSlots(motorList);
          }
        });
      } else if (data is List) {
        for (final types in data) {
          if (types is Map) {
            final carList = types['Car'];
            final motorList = types['Motorcycle'];
            newCar += _countSlots(carList);
            newMotor += _countSlots(motorList);
          }
        }
      }

      setState(() {
        carCount = newCar;
        motorCount = newMotor;
      });
    });
  }

  int _countSlots(dynamic list) {
    if (list is List) {
      // list items can be strings or objects {id, name}
      return list.length;
    }
    return 0;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        userName: widget.userName,
        profileImageUrl: widget.profileImageUrl,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 25.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset('assets/image.png', height: 50),
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, size: 28),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Welcome To CYGO Parking System!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text("Available Slots", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Container(
              width: 500,
              height: 150,
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.yellow[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Car", style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text("$carCount", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(width: 1, color: Colors.white),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Motorcycle", style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text("$motorCount", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 400,
                child: SlideAction(
                  borderRadius: 25,
                  text: "Slide to Proceed to Parking",
                  textStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  outerColor: Colors.amber,
                  innerColor: Colors.white,
                  onSubmit: () async {
                    try {
                      final u = FirebaseAuth.instance.currentUser;
                      if (u != null) {
                        final snap = await FirebaseDatabase.instance.ref('users/' + u.uid).get();
                        final activeTx = snap.child('activeTransaction').value?.toString();
                        if (activeTx != null && activeTx.isNotEmpty) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => QRCodeScreen(vehicleType: 'CAR', existingTxId: activeTx)),
                            (route) => false,
                          );
                          return;
                        }
                      }
                    } catch (_) {}
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const VehicleSelectionScreen()),
                      (route) => false,
                    );
                  },
                  sliderButtonIcon: const Icon(Icons.arrow_forward, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
