// [IMPORTS from pasted_content_3.txt remain the same]
import 'dart:developer';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PickupDetailPage extends StatefulWidget {
  final String orderId;
  final String riderId;
  const PickupDetailPage({
    Key? key,
    required this.orderId,
    required this.riderId,
  }) : super(key: key);
  @override
  State<PickupDetailPage> createState() => _PickupDetailPageState();
}

class _PickupDetailPageState extends State<PickupDetailPage>
    with WidgetsBindingObserver {
  final String longdoMapApiKey = 'ba51dc98b3fd0dd3bb1ab2224a3e36d1';
  WebViewController? _webViewController;

  bool _isPageFinished = false;
  bool _isMapReady = false;
  bool _isDataLoaded = false;

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<DocumentSnapshot>? _riderLocationSubscription;

  // ADDED: State variables for throttling, similar to RiderMap
  Timer? _updateTimer;
  Position? _lastPosition;
  bool _isUpdatingFirestore = false;

  double? _currentRiderLat;
  double? _currentRiderLon;

  String _customerName = '';
  String _customerPhone = '';
  String _pickupAddress = '';
  double _pickupLat = 0.0;
  double _pickupLon = 0.0;
  String _destinationAddress = '';
  double _destinationLat = 0.0;
  double _destinationLon = 0.0;
  String _firstItem = '';
  String _secondItem = '';

  String _estimatedDistance = 'กำลังคำนวน...';
  String _estimatedTime = '...';
  int _currentStatus = 2;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  final cloudinary = CloudinaryPublic(
    'dzicj4dci',
    'flutter_unsigned',
    cache: false,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOrderAndRiderData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSubscription?.cancel();
    _riderLocationSubscription?.cancel();
    _updateTimer?.cancel(); // ADDED: Cancel timer on dispose
    _webViewController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 App resumed');
      if (_currentRiderLat != null &&
          _currentRiderLon != null &&
          _webViewController != null &&
          _isMapReady) {
        // เมื่อแอปกลับมาทำงาน ให้ "วาป" ไปตำแหน่งล่าสุดเลย ไม่ต้องรอ
        _webViewController!.runJavaScript('''
          if (window.riderMarker) {
            window.riderMarker.location({lon: $_currentRiderLon, lat: $_currentRiderLat});
          }
        ''');
      }
    }
  }

  Future<void> _loadOrderAndRiderData() async {
    try {
      DocumentSnapshot productDoc = await FirebaseFirestore.instance
          .collection('Product')
          .doc(widget.orderId)
          .get();
      if (!productDoc.exists) throw Exception('ไม่พบข้อมูลออเดอร์');

      Map<String, dynamic> productData =
          productDoc.data() as Map<String, dynamic>;
      DocumentSnapshot riderDoc = await FirebaseFirestore.instance
          .collection('Rider')
          .doc(widget.riderId)
          .get();
      if (!riderDoc.exists) throw Exception('ไม่พบข้อมูลไรเดอร์');

      Map<String, dynamic> riderData = riderDoc.data() as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _customerName = productData['senderName'] ?? 'N/A';
          _customerPhone = productData['senderPhone'] ?? '';
          _pickupAddress = productData['senderAddress'] ?? 'N/A';
          _pickupLat = (productData['senderLat'] ?? 0.0).toDouble();
          _pickupLon = (productData['senderLng'] ?? 0.0).toDouble();
          _destinationAddress = productData['receiverAddress'] ?? 'N/A';
          _destinationLat = (productData['receiverLat'] ?? 0.0).toDouble();
          _destinationLon = (productData['receiverLng'] ?? 0.0).toDouble();
          _firstItem = productData['itemName'] ?? 'ไม่มีชื่อสินค้า';
          _secondItem = productData['itemDescription'] ?? '';
          _currentStatus = productData['status'] ?? 2;
          _currentRiderLat = (riderData['currentLat'] ?? _pickupLat).toDouble();
          _currentRiderLon = (riderData['currentLng'] ?? _pickupLon).toDouble();

          _isDataLoaded = true;
        });

        _initializeMap();
        _startListeningToRiderLocation();
        _startLocationTracking();
      }
    } catch (e) {
      debugPrint('Error loading order data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  // CHANGED: This is now the *single source of truth* for UI updates.
  void _startListeningToRiderLocation() {
    debugPrint('🎧 เริ่มฟังตำแหน่งไรเดอร์จาก Firestore...');
    _riderLocationSubscription = FirebaseFirestore.instance
        .collection('Rider')
        .doc(widget.riderId)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
          if (!snapshot.exists || !mounted) return;

          try {
            Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
            double newLat = (data['currentLat'] ?? 0.0).toDouble();
            double newLng = (data['currentLng'] ?? 0.0).toDouble();

            if (mounted && newLat != 0.0 && newLng != 0.0) {
              // ตรวจสอบว่าตำแหน่งมีการเปลี่ยนแปลงจริงหรือไม่
              if (newLat == _currentRiderLat && newLng == _currentRiderLon) {
                return; // ถ้าตำแหน่งเดิม ไม่ต้องทำอะไร
              }

              // This is now the ONLY place we call setState for location
              setState(() {
                _currentRiderLat = newLat;
                _currentRiderLon = newLng;
              });

              // Update map and distance ONLY when Firestore data changes
              _updateMapRiderPosition(newLng, newLat);
              _calculateDistance();

              debugPrint('📡 Firestore → UI/Map: $newLng, $newLat');
            }
          } catch (e) {
            debugPrint('❌ Error parsing location: $e');
          }
        });
  }

  // --- *** 🚗 แก้ไขหลัก (ทำให้สมูท) *** ---
  // เราเปลี่ยนจากการ "ลบและสร้างใหม่" เป็นการ "ย้าย" (move)
  void _updateMapRiderPosition(double lon, double lat) {
    if (_webViewController == null || !_isMapReady) return;
    _webViewController!.runJavaScript(''' 
      (function() {
        try {
          if (window.riderMarker && window.map) {
            // ใช้ .move() เพื่อให้เกิด Animation
            // move(location, autoZoom, duration_ms, onMoveEndCallback)
            window.riderMarker.move({lon: $lon, lat: $lat}, false, 800); 
          } else if (window.DebugLog) {
            window.DebugLog.postMessage('❌ Marker not ready for move');
          }
        } catch(e) {
          if (window.DebugLog) {
            window.DebugLog.postMessage('❌ Error moving marker: ' + e.message);
          }
        }
      })();
    ''');

    debugPrint('📍 Moved smoothly: $lon, $lat');
  }
  // --- *** สิ้นสุดการแก้ไข *** ---

  void _calculateDistance() {
    if (_currentRiderLat == null || _currentRiderLon == null) return;
    final double targetLat = _currentStatus == 2 ? _pickupLat : _destinationLat;
    final double targetLon = _currentStatus == 2 ? _pickupLon : _destinationLon;

    double distanceInMeters = Geolocator.distanceBetween(
      _currentRiderLat!,
      _currentRiderLon!,
      targetLat,
      targetLon,
    );
    setState(() {
      if (distanceInMeters < 1000) {
        _estimatedDistance = '${distanceInMeters.toStringAsFixed(0)} ม.';
      } else {
        _estimatedDistance =
            '${(distanceInMeters / 1000).toStringAsFixed(1)} กม.';
      }
      double estimatedMinutes = (distanceInMeters / 1000) / 30 * 60;
      _estimatedTime = '${estimatedMinutes.toStringAsFixed(0)} นาที';
    });
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // CHANGED: This stream *only* saves the position and schedules an update.
  // It no longer updates UI or calls Firestore directly.
  Future<void> _startLocationTracking() async {
    bool hasPermission = await _checkLocationPermission();
    if (!hasPermission || !mounted) return;
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Using 5-meter filter from your original code
    );
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (!mounted) return;

            // 1. Save the latest position (like in RiderMap)
            _lastPosition = position;

            // 2. Schedule a throttled update (like in RiderMap)
            _scheduleFirestoreUpdate();

            debugPrint('📍 GPS: ${position.longitude}, ${position.latitude}');
          },
        );
  }

  // ADDED: Throttling function from RiderMap
  void _scheduleFirestoreUpdate() {
    if (_updateTimer?.isActive ?? false) return;
    _updateTimer = Timer(const Duration(seconds: 1), () {
      // Check mounted state here as well
      if (_lastPosition != null && !_isUpdatingFirestore && mounted) {
        _updateRiderLocationToFirestore(_lastPosition!);
      }
    });
  }

  // CHANGED: Adapted from RiderMap
  // Uses Position object and _isUpdatingFirestore flag
  Future<void> _updateRiderLocationToFirestore(Position position) async {
    if (_isUpdatingFirestore) return;
    _isUpdatingFirestore = true;

    try {
      await FirebaseFirestore.instance
          .collection('Rider') // Your collection
          .doc(widget.riderId) // Your doc ID
          .update({
            'currentLat': position.latitude,
            'currentLng': position.longitude,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
      // Using log() like RiderMap
      log(
        '✅ Updated rider location: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      log('❌ Firestore update failed: $e');
    } finally {
      _isUpdatingFirestore = false;
    }
  }

  void _initializeMap() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'MapReady',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('✅ Map พร้อมแล้ว!');
          if (mounted) {
            setState(() => _isMapReady = true);

            // อัปเดตตำแหน่งเริ่มต้น (ใช้ .location ธรรมดา ไม่ต้อง move)
            if (_currentRiderLat != null && _currentRiderLon != null) {
              _webViewController!.runJavaScript('''
                if (window.riderMarker) {
                  window.riderMarker.location({lon: $_currentRiderLon, lat: $_currentRiderLat});
                }
              ''');
            }
          }
        },
      )
      ..addJavaScriptChannel(
        'DebugLog',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('🟦 JS: ${message.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isPageFinished = true);
            }
          },
        ),
      )
      ..loadHtmlString(_buildMapHtml());
  }

  // --- *** แก้ไข *** ---
  // แก้ไข URL ให้ถูกต้องและเป็น HTTPS
  void _openGoogleMapsNavigation() async {
    final double targetLat = _currentStatus == 2 ? _pickupLat : _destinationLat;
    final double targetLon = _currentStatus == 2 ? _pickupLon : _destinationLon;

    // CHANGED: Using a proper, cross-platform Google Maps URL
    final url = Uri.parse('http://googleusercontent.com/maps/google.com/1');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch $url');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่สามารถเปิด Google Maps ได้')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการเปิดแอป: $e')),
        );
      }
    }
  }
  // --- *** สิ้นสุดการแก้ไข *** ---

  Future<void> _takePhotoAndUpdateStatus(int newStatus) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (photo == null) return;

      setState(() => _isUploading = true);

      final Directory tempDir = await getApplicationDocumentsDirectory();
      final String newFileName =
          '${DateTime.now().millisecondsSinceEpoch}${p.extension(photo.name)}';
      final File file = File('${tempDir.path}/$newFileName');
      await photo.saveTo(file.path);

      final CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      await FirebaseFirestore.instance
          .collection('Product')
          .doc(widget.orderId)
          .update({
            'status': newStatus,
            'statusPhotos.$newStatus': response.secureUrl,
            'status${newStatus}UpdatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        setState(() {
          _currentStatus = newStatus;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 3
                  ? 'ยืนยันการรับสินค้าสำเร็จ'
                  : 'ยืนยันการส่งสินค้าสำเร็จ',
            ),
          ),
        );

        if (newStatus == 4) {
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  // --- *** 📍 แก้ไขหลัก (เปลี่ยนไอคอน) *** ---
  String _buildMapHtml() {
    final double initialRiderLat = _currentRiderLat ?? _pickupLat;
    final double initialRiderLon = _currentRiderLon ?? _pickupLon;

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="initial-scale=1.0, user-scalable=no" />
  <meta charset="utf-8">
  <style>
    html, body { height: 100%; margin: 0; padding: 0; }
    #map { height: 100%; }

    /* CSS Animation สำหรับไอคอนใหม่ (จุดกระพริบ) */
    @keyframes pulseDot {
      0% {
        transform: scale(0.9);
        box-shadow: 0 0 0 0 rgba(111, 53, 165, 0.7);
      }
      70% {
        transform: scale(1);
        box-shadow: 0 0 0 10px rgba(111, 53, 165, 0);
      }
      100% {
        transform: scale(0.9);
        box-shadow: 0 0 0 0 rgba(111, 53, 165, 0);
      }
    }
  </style>
  <script src="https://api.longdo.com/map/?key=$longdoMapApiKey"></script>
</head>
<body>
  <div id="map"></div>
  
  <script>
    // ⭐ Global variables
    window.map = null;
    window.riderMarker = null;

    window.onload = function() {
      try {
        window.map = new longdo.Map({
          placeholder: document.getElementById('map'),
          language: 'th'
        });
        var pickup = {lat: $_pickupLat, lon: $_pickupLon};
        var dest = {lat: $_destinationLat, lon: $_destinationLon};
        var rider = {lat: $initialRiderLat, lon: $initialRiderLon};

        // ตั้งค่ามุมมอง
        if (pickup.lat !== 0 && dest.lat !== 0) {
          window.map.bound({
            minLon: Math.min(pickup.lon, dest.lon, rider.lon) - 0.01,
            minLat: Math.min(pickup.lat, dest.lat, rider.lat) - 0.01,
            maxLon: Math.max(pickup.lon, dest.lon, rider.lon) + 0.01,
            maxLat: Math.max(pickup.lat, dest.lat, 
            rider.lat) + 0.01
          });
        } else {
          window.map.location({lon: rider.lon, lat: rider.lat}, true);
          window.map.zoom(14);
        }

        // Marker จุดรับ
        if (pickup.lat !== 0) {
          window.map.Overlays.add(new longdo.Marker({lon: pickup.lon, lat: pickup.lat}, {
            title: '📦 จุดรับสินค้า',
            icon: {
              html: '<div style="width:28px;height:28px;background:#FF5252;border-radius:50%;border:2px solid white;box-shadow:0 2px 5px rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;font-size:16px;">📦</div>',
              offset: {x: 14, y: 14}
            }
          }));
        }

        // Marker จุดส่ง
        if (dest.lat !== 0) {
          window.map.Overlays.add(new longdo.Marker({lon: dest.lon, lat: dest.lat}, {
            title: '🏠 จุดส่งสินค้า',
            icon: {
              html: '<div style="width:28px;height:28px;background:#2196F3;border-radius:50%;border:2px solid white;box-shadow:0 2px 5px rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;font-size:16px;">🏠</div>',
              offset: {x: 14, y: 14}
            }
          }));
        }

        // ⭐ Rider Marker เริ่มต้น (สร้างแค่ครั้งเดียว)
        // นี่คือไอคอนใหม่ครับ!
        window.riderMarker = new longdo.Marker({lon: rider.lon, lat: rider.lat}, {
          title: '📍 ไรเดอร์',
          icon: {
            html: '<div style="width:18px;height:18px;background-color:#6F35A5;border-radius:50%;border:2px solid white;box-shadow:0 2px 4px rgba(0,0,0,0.3);animation:pulseDot 2s infinite;"></div>',
            offset: {x: 9, y: 9} // ครึ่งนึงของ 18px
          }
        });
        window.map.Overlays.add(window.riderMarker);

        if (window.MapReady) window.MapReady.postMessage('ready');
      } catch (error) {
        if (window.DebugLog) {
          window.DebugLog.postMessage('❌ Init error: ' + error.message);
        }
      }
    };
  </script>
</body>
</html>
    ''';
  }
  // --- *** สิ้นสุดการแก้ไข *** ---

  // --- BUILD WIDGETS (โค้ดส่วน UI เหมือนเดิมทั้งหมด) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_isDataLoaded && _webViewController != null)
            WebViewWidget(controller: _webViewController!),
          if (!_isDataLoaded || !_isMapReady)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF6F35A5)),
                    SizedBox(height: 16),
                    Text(
                      'กำลังโหลดแผนที่...',
                      style: TextStyle(fontSize: 16, color: Color(0xFF6F35A5)),
                    ),
                  ],
                ),
              ),
            ),
          if (_isDataLoaded && _isMapReady) ...[
            _buildEstimateInfo(),
            _buildControlButtons(),
            _buildDraggableSheet(),
          ],
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'กำลังอัพโหลดรูปภาพ...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEstimateInfo() {
    return Positioned(
      top: 50,
      left: 16,
      right: 80,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.navigation, color: Color(0xFF6F35A5), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentStatus == 2
                        ? 'ระยะทางไปจุดรับสินค้า'
                        : 'ระยะทางไปจุดส่งสินค้า',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '$_estimatedDistance${_estimatedTime != '...' ? ' • $_estimatedTime' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Positioned(
      top: 50,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF6F35A5),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: IconButton(
          onPressed: _openGoogleMapsNavigation,
          icon: const Icon(Icons.directions, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDraggableSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.15,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 10,
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSenderInfo(),
                const SizedBox(height: 24),
                _buildAddressInfo(
                  icon: Icons.location_on,
                  color: Colors.red,
                  title: 'ที่อยู่รับสินค้า',
                  address: _pickupAddress,
                ),
                const SizedBox(height: 16),
                _buildAddressInfo(
                  icon: Icons.location_on,
                  color: Colors.blue,
                  title: 'ที่อยู่ปลายทาง',
                  address: _destinationAddress,
                ),
                const SizedBox(height: 24),
                _buildStatusButtons(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSenderInfo() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey,
          child: Icon(Icons.person, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _customerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                '(ผู้ส่ง)',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () async {
            final url = Uri.parse('tel:$_customerPhone');
            if (await canLaunchUrl(url)) await launchUrl(url);
          },
          icon: const Icon(Icons.call, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildAddressInfo({
    required IconData icon,
    required Color color,
    required String title,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(address, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusButtons() {
    if (_currentRiderLat == null || _currentRiderLon == null) {
      return const SizedBox();
    }

    if (_currentStatus == 2) {
      final distance = Geolocator.distanceBetween(
        _currentRiderLat!,
        _currentRiderLon!,
        _pickupLat,
        _pickupLon,
      );
      final isNear = distance <= 50;

      return Column(
        children: [
          if (!isNear)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'คุณอยู่ห่างจากจุดรับ ${distance.toStringAsFixed(0)} ม.\nต้องเข้าใกล้ไม่เกิน 50 เมตร',
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isNear ? () => _takePhotoAndUpdateStatus(3) : null,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                isNear ? 'ถ่ายรูปยืนยันรับสินค้า' : 'เข้าใกล้จุดรับเพื่อยืนยัน',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isNear ? Colors.green : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (_currentStatus == 3) {
      final distance = Geolocator.distanceBetween(
        _currentRiderLat!,
        _currentRiderLon!,
        _destinationLat,
        _destinationLon,
      );
      final isNear = distance <= 50;

      return Column(
        children: [
          if (!isNear)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'คุณอยู่ห่างจากจุดส่ง ${distance.toStringAsFixed(0)} ม.\nต้องเข้าใกล้ไม่เกิน 50 เมตร',
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isNear ? () => _takePhotoAndUpdateStatus(4) : null,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                isNear ? 'ถ่ายรูปยืนยันส่งสินค้า' : 'เข้าใกล้จุดส่งเพื่อยืนยัน',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isNear ? const Color(0xFF6F35A5) : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text(
              'ส่งสินค้าสำเร็จแล้ว',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }
  }
}
