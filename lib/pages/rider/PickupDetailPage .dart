// [แก้ไข] เพิ่ม import ที่จำเป็น
import 'dart:developer'; // For log()
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:cloudinary_public/cloudinary_public.dart';

// [แก้ไข] ลบ import ของ Firebase Storage
// import 'package:firebase_storage/firebase_storage.dart';

// --- (import อื่นๆ เหมือนเดิม) ---
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PickupDetailPage extends StatefulWidget {
  // --- (Properties เหมือนเดิม) ---
  final String orderId;
  final String customerName;
  final String customerPhone;
  final String pickupAddress;
  final String pickupLat;
  final String pickupLon;
  final String firstItem;
  final String secondItem;
  final String destinationAddress;
  final String destinationLat;
  final String destinationLon;
  final String riderId;

  const PickupDetailPage({
    Key? key,
    required this.orderId,
    required this.customerName,
    required this.customerPhone,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLon,
    required this.firstItem,
    required this.secondItem,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLon,
    required this.riderId,
  }) : super(key: key);

  @override
  State<PickupDetailPage> createState() => _PickupDetailPageState();
}

class _PickupDetailPageState extends State<PickupDetailPage> {
  // --- (Properties ส่วนใหญ่เหมือนเดิม) ---
  final String longdoMapApiKey = 'ba51dc98b3fd0dd3bb1ab2224a3e36d1';
  late WebViewController _webViewController;
  bool _isPageFinished = false;
  bool _isProfileLoaded = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  double? _currentRiderLat;
  double? _currentRiderLon;
  String _riderImageUrl = '';
  String _riderName = '';
  String _estimatedDistance = 'กำลังคำนวน...';
  String _estimatedTime = '...';

  int _currentStatus = 2;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // --- [เพิ่ม] Initialize Cloudinary (เหมือนใน statusPage.dart) ---
  final cloudinary = CloudinaryPublic(
    'dzicj4dci', // Cloud Name จาก statusPage.dart
    'flutter_unsigned', // Upload Preset จาก statusPage.dart
    cache: false,
  );
  // --- [สิ้นสุดการเพิ่ม] ---

  @override
  void initState() {
    super.initState();
    _loadRiderProfileAndInitialize();
    _loadCurrentStatus();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // --- (ฟังก์ชัน _loadCurrentStatus, _loadRiderProfileAndInitialize, _loadRiderProfile, _checkLocationPermission, _startLocationTracking, _updateRiderLocationToFirestore, _updateRiderPosition, _initializeMap, _updateMapBasedOnStatus, _updateRiderMarkerOnMap, _updateRouteOnMap, _centerOnRider, _openGoogleMapsNavigation เหมือนเดิมทุกประการ) ---

  // ( ... คัดลอกฟังก์ชันที่ไม่ได้แก้ไขมาวางที่นี่ ... )
  // ... (ขอย่อไว้เพื่อไม่ให้ข้อความยาวเกินไป) ...
  // ... (ตั้งแต่ _loadCurrentStatus() จนถึง _openGoogleMapsNavigation()) ...

  // --- [แก้ไข] โหลดสถานะปัจจุบันจาก Firestore ---
  Future<void> _loadCurrentStatus() async {
    try {
      DocumentSnapshot productDoc = await FirebaseFirestore.instance
          .collection('Product')
          .doc(widget.orderId)
          .get();

      if (productDoc.exists) {
        Map<String, dynamic> data = productDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentStatus = data['status'] ?? 2;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading status: $e');
    }
  }

  Future<void> _loadRiderProfileAndInitialize() async {
    await _loadRiderProfile();
    if (mounted) {
      setState(() {
        _isProfileLoaded = true;
      });
      _initializeMap();
    }
  }

  Future<void> _loadRiderProfile() async {
    try {
      DocumentSnapshot riderDoc = await FirebaseFirestore.instance
          .collection('Rider')
          .doc(widget.riderId)
          .get();

      if (riderDoc.exists) {
        Map<String, dynamic> data = riderDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _riderImageUrl = data['imageUrl'] ?? '';
            _riderName = data['name'] ?? 'ไรเดอร์';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading rider profile: $e');
    }
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('กรุณาเปิด GPS')));
      }
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('กรุณาอนุญาตการเข้าถึงตำแหน่ง')),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเปิดสิทธิ์ตำแหน่งในการตั้งค่า')),
        );
      }
      return false;
    }

    return true;
  }

  Future<void> _startLocationTracking() async {
    bool hasPermission = await _checkLocationPermission();
    if (!hasPermission) return;

    // --- ⚠️ โหมดทดสอบ: ใช้ตำแหน่งปลายทางเป็นตำแหน่งจำลอง ---
    const bool _isTesting =
        false; // 👈 ----------------- ปิด/เปิด โหมดทดสอบที่นี่
    if (_isTesting && mounted) {
      debugPrint('--- ⚠️ กำลังทำงานในโหมดทดสอบ (Mock Location) ---');
      final double targetLat = _currentStatus == 2
          ? (double.tryParse(widget.pickupLat) ?? 13.7563)
          : (double.tryParse(widget.destinationLat) ?? 16.250377);
      final double targetLon = _currentStatus == 2
          ? (double.tryParse(widget.pickupLon) ?? 100.5018)
          : (double.tryParse(widget.destinationLon) ?? 103.275482);
      Position fakePosition = Position.fromMap({
        'latitude': targetLat,
        'longitude': targetLon,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'accuracy': 5.0,
        'altitude': 0.0,
        'altitude_accuracy': 0.0,
        'heading': 0.0,
        'heading_accuracy': 0.0,
        'speed': 10.0,
        'speed_accuracy': 1.0,
        'is_mocked': true,
      });
      _updateRiderPosition(fakePosition);
      return;
    }
    // --- ⚠️ สิ้นสุดโหมดทดสอบ ---

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _updateRiderPosition(position);
    } catch (e) {
      debugPrint('Error getting initial position: $e');
    }
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _updateRiderPosition(position);
          },
        );
  }

  Future<void> _updateRiderLocationToFirestore(double lat, double lng) async {
    try {
      await FirebaseFirestore.instance
          .collection('Rider')
          .doc(widget.riderId)
          .update({
            'currentLat': lat,
            'currentLng': lng,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
      debugPrint('อัพเดทตำแหน่งไรเดอร์สำเร็จ: $lat, $lng');
    } catch (e) {
      debugPrint('Error updating rider location: $e');
    }
  }

  void _updateRiderPosition(Position position) {
    if (!mounted) return;
    setState(() {
      _currentRiderLat = position.latitude;
      _currentRiderLon = position.longitude;
    });
    _updateRiderLocationToFirestore(position.latitude, position.longitude);
    final double targetLat = _currentStatus == 2
        ? (double.tryParse(widget.pickupLat) ?? 0.0)
        : (double.tryParse(widget.destinationLat) ?? 0.0);
    final double targetLon = _currentStatus == 2
        ? (double.tryParse(widget.pickupLon) ?? 0.0)
        : (double.tryParse(widget.destinationLon) ?? 0.0);
    double distanceInMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
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
      double estimatedMinutes =
          (distanceInMeters / 1000) / 30 * 60; // สมมติ 30 กม/ชม
      _estimatedTime = '${estimatedMinutes.toStringAsFixed(0)} นาที';
    });
    if (_isPageFinished) {
      _updateRiderMarkerOnMap();
    }
  }

  void _initializeMap() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isPageFinished = true;
              });
              _startLocationTracking();
              _updateMapBasedOnStatus();
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('เกิดข้อผิดพลาดการโหลดแผนที่: ${error.description}');
          },
        ),
      )
      ..loadHtmlString(_buildMapHtml());
  }

  void _updateMapBasedOnStatus() {
    if (!_isPageFinished) return;
    final pickupLat = double.tryParse(widget.pickupLat) ?? 13.7563;
    final pickupLon = double.tryParse(widget.pickupLon) ?? 100.5018;
    final destLat = double.tryParse(widget.destinationLat) ?? 13.7563;
    final destLon = double.tryParse(widget.destinationLon) ?? 100.5018;
    if (_currentStatus == 2) {
      final jsCode =
          '''
        showPickupMarker($pickupLon, $pickupLat, '${widget.pickupAddress.replaceAll("'", "\\'")}');
        hideDestinationMarker();
        if (typeof updateRiderLocation === 'function' && $_currentRiderLon != null && $_currentRiderLat != null) {
          updateRiderLocation($_currentRiderLon, $_currentRiderLat);
          drawRoute($_currentRiderLon, $_currentRiderLat, $pickupLon, $pickupLat);
        }
      ''';
      _webViewController.runJavaScript(jsCode);
    } else if (_currentStatus == 3) {
      final jsCode =
          '''
        hidePickupMarker();
        showDestinationMarker($destLon, $destLat, '${widget.destinationAddress.replaceAll("'", "\\'")}');
        if (typeof updateRiderLocation === 'function' && $_currentRiderLon != null && $_currentRiderLat != null) {
          updateRiderLocation($_currentRiderLon, $_currentRiderLat);
          drawRoute($_currentRiderLon, $_currentRiderLat, $destLon, $destLat);
        }
      ''';
      _webViewController.runJavaScript(jsCode);
    }
  }

  void _updateRiderMarkerOnMap() {
    if (_currentRiderLat != null && _currentRiderLon != null) {
      final jsCode =
          '''
        if (typeof updateRiderLocation === 'function') {
          updateRiderLocation($_currentRiderLon, $_currentRiderLat);
        }
      ''';
      _webViewController.runJavaScript(jsCode);
      _updateRouteOnMap();
    }
  }

  void _updateRouteOnMap() {
    if (_currentRiderLat == null || _currentRiderLon == null) return;
    final pickupLat = double.tryParse(widget.pickupLat) ?? 13.7563;
    final pickupLon = double.tryParse(widget.pickupLon) ?? 100.5018;
    final destLat = double.tryParse(widget.destinationLat) ?? 13.7563;
    final destLon = double.tryParse(widget.destinationLon) ?? 100.5018;
    if (_currentStatus == 2) {
      final jsCode =
          'drawRoute($_currentRiderLon, $_currentRiderLat, $pickupLon, $pickupLat);';
      _webViewController.runJavaScript(jsCode);
    } else if (_currentStatus == 3) {
      final jsCode =
          'drawRoute($_currentRiderLon, $_currentRiderLat, $destLon, $destLat);';
      _webViewController.runJavaScript(jsCode);
    }
  }

  void _centerOnRider() {
    if (_currentRiderLat != null && _currentRiderLon != null) {
      final jsCode =
          '''
        if (typeof centerOnRider === 'function') {
          centerOnRider($_currentRiderLon, $_currentRiderLat);
        }
      ''';
      _webViewController.runJavaScript(jsCode);
    }
  }

  void _openGoogleMapsNavigation() async {
    final String targetLat = _currentStatus == 2
        ? widget.pickupLat
        : widget.destinationLat;
    final String targetLon = _currentStatus == 2
        ? widget.pickupLon
        : widget.destinationLon;
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$targetLat,$targetLon&travelmode=driving',
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่สามารถเปิด Google Maps ได้')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching maps: $e');
    }
  }

  // --- [แก้ไข] ฟังก์ชันถ่ายรูปและอัพโหลด (เปลี่ยนไปใช้ Cloudinary) ---
  Future<void> _takePhotoAndUpdateStatus(int newStatus) async {
    try {
      // 1. ถ่ายรูป
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('ยกเลิกการถ่ายรูป')));
        }
        return;
      }

      // 2. แสดง Loading
      setState(() {
        _isUploading = true;
      });

      // --- 3. [NEW] อัพโหลดไปยัง Cloudinary (เหมือน statusPage.dart) ---
      final Directory tempDir = await getApplicationDocumentsDirectory();
      final String fileExtension = p.extension(photo.name);
      final String newFileName =
          '${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final File file = File('${tempDir.path}/$newFileName');
      await photo.saveTo(file.path);

      log('กำลังอัปโหลดรูปไป Cloudinary...');
      final CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      final downloadUrl = response.secureUrl; // นี่คือ Cloudinary URL
      log('อัปโหลด Cloudinary สำเร็จ: $downloadUrl');
      // --- [END NEW] ---

      // 4. อัพเดท Firestore (เปลี่ยน schema ให้ตรงกับ statusPage.dart)
      final String photoKey = newStatus.toString(); // '3' หรือ '4'
      await FirebaseFirestore.instance
          .collection('Product')
          .doc(widget.orderId)
          .update({
            'status': newStatus,
            'statusPhotos.$photoKey':
                downloadUrl, // <-- [แก้ไข] ใช้ statusPhotos map
            // 'status${newStatus}ImageUrl': downloadUrl, // <-- ลบอันเก่า
            'status${newStatus}UpdatedAt':
                FieldValue.serverTimestamp(), // <-- อันนี้เก็บไว้ได้
          });

      // 5. อัพเดทสถานะใน State
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

        // [แก้ไข] อัพเดทแผนที่และ UI หลังจากเปลี่ยนสถานะ
        if (newStatus == 3) {
          _updateMapBasedOnStatus(); // เปลี่ยนเป็นเส้นทางไปจุดส่ง
        } else if (newStatus == 4) {
          // ถ้าอัพเดทเป็น status 4 แล้ว ให้กลับไปหน้าหลัก
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      log('Error taking photo and updating status: $e'); // ใช้ log
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  // --- (ฟังก์ชัน _buildMapHtml, build, _buildEstimateInfo, _buildControlButtons, _buildDraggableSheet, _buildSenderInfo, _buildAddressInfo, _buildStatusButtons เหมือนเดิมทุกประการ) ---

  // ( ... คัดลอกฟังก์ชันที่เหลือ (ตั้งแต่ _buildMapHtml) มาวางที่นี่ ... )
  // ... (ขอย่อไว้เพื่อไม่ให้ข้อความยาวเกินไป) ...
  String _buildMapHtml() {
    final pickupLat = double.tryParse(widget.pickupLat) ?? 13.7563;
    final pickupLon = double.tryParse(widget.pickupLon) ?? 100.5018;

    final safeImageUrl = _riderImageUrl.isEmpty
        ? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_riderName)}&background=6F35A5&color=fff&size=100'
        : _riderImageUrl;

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="initial-scale=1.0, user-scalable=no" />
  <style type="text/css">
    html { height: 100% }
    body { height: 100%; margin: 0; padding: 0 }
    #map { height: 100% }
    .rider-marker {
      width: 50px;
      height: 50px;
      border-radius: 50%;
      border: 3px solid #6F35A5;
      box-shadow: 0 3px 10px rgba(0,0,0,0.4);
      background: white;
      overflow: hidden;
      position: relative;
    }
    .rider-marker img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  </style>
  <script src="https://api.longdo.com/map/?key=$longdoMapApiKey"></script>
  <script>
    let map;
    let pickupMarker;
    let destinationMarker;
    let riderMarker;
    let route;

    function init() {
      try {
        map = new longdo.Map({
          placeholder: document.getElementById('map'),
          language: 'th'
        });
        
        map.location({ lon: $pickupLon, lat: $pickupLat }, true);
        map.zoom(15, true);

        pickupMarker = new longdo.Marker(
          { lon: $pickupLon, lat: $pickupLat },
          { 
            visible: false,
            title: 'จุดรับสินค้า',
            icon: { url: 'https://map.longdo.com/mmmap/images/pin_red.png' }
          } 
        );
        map.Overlays.add(pickupMarker);

        destinationMarker = new longdo.Marker(
          { lon: 100.5018, lat: 13.7563 }, 
          { 
            visible: false,
            title: 'จุดส่งสินค้า',
            icon: { url: 'https://map.longdo.com/mmmap/images/pin_blue.png' }
          }
        );
        map.Overlays.add(destinationMarker);

        riderMarker = new longdo.Marker(
          { lon: $pickupLon, lat: $pickupLat },
          { 
            visible: false,
            title: 'ตำแหน่งของคุณ: $_riderName',
            icon: {
              html: '<div class="rider-marker"><img src="$safeImageUrl" onerror="this.src=\\'https://ui-avatars.com/api/?name=R&background=6F35A5&color=fff&size=100\\'"/></div>',
              offset: { x: 25, y: 25 }
            }
          } 
        );
        map.Overlays.add(riderMarker);

        route = new longdo.Route(null, {
            color: '#6F35A5',
            weight: 6,
            opacity: 0.8
        });
        map.Overlays.add(route);

      } catch (e) {
        console.error('Error during map initialization:', e);
      }
    }

    function showPickupMarker(lon, lat, detail) {
      pickupMarker.location({ lon: lon, lat: lat });
      pickupMarker.detail(detail);
      pickupMarker.visible(true);
    }
    function hidePickupMarker() {
      pickupMarker.visible(false);
    }
    function showDestinationMarker(lon, lat, detail) {
      destinationMarker.location({ lon: lon, lat: lat });
      destinationMarker.detail(detail);
      destinationMarker.visible(true);
    }
    function hideDestinationMarker() {
      destinationMarker.visible(false);
    }

    function updateRiderLocation(lon, lat) {
      if (riderMarker) {
        const newLocation = { lon: lon, lat: lat };
        riderMarker.location(newLocation);
        riderMarker.visible(true);
      }
    }
    
    function drawRoute(fromLon, fromLat, toLon, toLat) {
        map.Route.search({ lon: fromLon, lat: fromLat }, { lon: toLon, lat: toLat }, (result) => {
            if (result.data) {
                route.data(result.data);
                map.bound(route.bound()); 
            }
        });
    }

    function centerOnRider(lon, lat) {
      if (map) {
        map.location({ lon: lon, lat: lat }, true);
        map.zoom(16, true);
      }
    }
  </script>
</head>
<body onload="init();">
  <div id="map"></div>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_isProfileLoaded)
            SafeArea(
              bottom: false,
              child: WebViewWidget(controller: _webViewController),
            ),
          if (!_isProfileLoaded || !_isPageFinished)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
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
          if (_isProfileLoaded && _isPageFinished) ...[
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
    final String titleText = _currentStatus == 2
        ? 'ระยะทางไปจุดรับสินค้า'
        : 'ระยะทางไปจุดส่งสินค้า';

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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.navigation, color: Color(0xFF6F35A5), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
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
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
              onPressed: _centerOnRider,
              icon: const Icon(Icons.my_location, color: Color(0xFF6F35A5)),
              tooltip: 'ตำแหน่งของฉัน',
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
              tooltip: 'นำทาง',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.15,
      maxChildSize: 0.9,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24.0),
              topRight: Radius.circular(24.0),
            ),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSenderInfo(),
                  const SizedBox(height: 24),
                  _buildAddressInfo(
                    icon: Icons.location_on,
                    iconColor: Colors.red,
                    title: 'ที่อยู่รับสินค้า',
                    address: widget.pickupAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildAddressInfo(
                    icon: Icons.location_on,
                    iconColor: Colors.blue,
                    title: 'ที่อยู่ปลายทาง',
                    address: widget.destinationAddress,
                  ),
                  const SizedBox(height: 24),

                  _buildStatusButtons(),
                  const SizedBox(height: 24),
                ],
              ),
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
                widget.customerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
            final url = Uri.parse('tel:${widget.customerPhone}');
            try {
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            } catch (e) {
              debugPrint('Error launching phone: $e');
            }
          },
          icon: const Icon(Icons.call, color: Colors.black54),
        ),
        IconButton(
          onPressed: () {
            // TODO: ฟังก์ชันแชท
          },
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildAddressInfo({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
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
              Text(
                address,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusButtons() {
    if (_currentStatus == 2) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _takePhotoAndUpdateStatus(3),
          icon: const Icon(Icons.camera_alt),
          label: const Text(
            'ถ่ายรูปยืนยันรับสินค้า',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      );
    } else if (_currentStatus == 3) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _takePhotoAndUpdateStatus(4),
          icon: const Icon(Icons.camera_alt),
          label: const Text(
            'ถ่ายรูปยืนยันส่งสินค้า',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6F35A5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
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
