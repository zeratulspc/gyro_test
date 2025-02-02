import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ✅ Localization 추가

void main() {
  runApp(const FindMyDemoApp());
}

class FindMyDemoApp extends StatelessWidget {
  const FindMyDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // 영어 지원
        Locale('ko', ''), // 한국어 지원
      ],
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find My Demo')),
      body: const RotatingArrow(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.edit_location),
        onPressed: () => _showCoordinateInputDialog(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showCoordinateInputDialog(BuildContext context) {
    final latController = TextEditingController();
    final lonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('목표 좌표 입력'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: latController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '위도'),
              ),
              TextField(
                controller: lonController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '경도'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final lat = double.tryParse(latController.text);
                final lon = double.tryParse(lonController.text);
                if (lat != null && lon != null) {
                  Navigator.pop(context);
                  RotatingArrowState.updateDestination(lat, lon);
                }
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}

class RotatingArrow extends StatefulWidget {
  const RotatingArrow({super.key});

  @override
  RotatingArrowState createState() => RotatingArrowState();
}

class RotatingArrowState extends State<RotatingArrow> {
  double _heading = 0;
  double _bearing = 0;
  double _distance = 0;
  double _pitch = 0;
  double _roll = 0;

  static double destinationLat = 35.128516;
  static double destinationLon = 128.664106;

  static void updateDestination(double lat, double lon) {
    destinationLat = lat;
    destinationLon = lon;
  }

  @override
  void initState() {
    super.initState();
    _initLocationAndSensors();
  }

  Future<void> _initLocationAndSensors() async {
    await Geolocator.requestPermission();
    Geolocator.getPositionStream().listen((Position position) {
      _calculateBearingAndDistance(position.latitude, position.longitude);
    });

    FlutterCompass.events!.listen((event) {
      setState(() {
        _heading = event.heading ?? 0;
      });
    });

    accelerometerEvents.listen((event) {
      setState(() {
        _pitch = math.atan2(event.y, math.sqrt(event.x * event.x + event.z * event.z));
        _roll = math.atan2(-event.x, event.z);
      });
    });
  }

  void _calculateBearingAndDistance(double lat1, double lon1) {
    final double lat2 = destinationLat * math.pi / 180;
    final double lon2 = destinationLon * math.pi / 180;
    lat1 = lat1 * math.pi / 180;
    lon1 = lon1 * math.pi / 180;

    final double dLon = lon2 - lon1;
    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final double bearing = math.atan2(y, x);

    final double a = math.pow(math.sin((lat2 - lat1) / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = 6371000 * c; // 지구 반지름 (미터 단위)

    setState(() {
      _bearing = (bearing * 180 / math.pi + 360) % 360;
      _distance = distance;
    });
  }

  Color _calculateBackgroundColor() {
    final double directionDifference = (_bearing - _heading).abs();
    double intensity = (1 - (directionDifference / 180)).clamp(0, 1);
    return Color.lerp(Colors.white, Colors.green, intensity)!;
  }

  String _formatDistance(double distance) {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    } else {
      return '${distance.toStringAsFixed(2)} m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double direction = ((_bearing - _heading) * math.pi / 180);

    return Container(
      color: _calculateBackgroundColor(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateZ(direction)
                ..rotateX(_pitch)
                ..rotateY(_roll),
              child: const Icon(
                Icons.arrow_upward,
                size: 100,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '남은 거리: ${_formatDistance(_distance)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
