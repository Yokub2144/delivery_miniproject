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

class _PickupDetailPageState extends State<PickupDetailPage> {
  final String longdoMapApiKey = 'ba51dc98b3fd0dd3bb1ab2224a3e36d1';
  late WebViewController _webViewController;
  bool _isPageFinished = false;
  bool _isDataLoaded = false;
  StreamSubscription<Position>? _positionStreamSubscription;

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

  String _riderName = '';
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
    _loadOrderAndRiderData();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadOrderAndRiderData() async {
    try {
      DocumentSnapshot productDoc = await FirebaseFirestore.instance
          .collection('Product')
          .doc(widget.orderId)
          .get();

      if (!productDoc.exists) {
        throw Exception('ไม่พบข้อมูลออเดอร์');
      }

      Map<String, dynamic> productData =
          productDoc.data() as Map<String, dynamic>;

      DocumentSnapshot riderDoc = await FirebaseFirestore.instance
          .collection('Rider')
          .doc(widget.riderId)
          .get();

      if (!riderDoc.exists) {
        throw Exception('ไม่พบข้อมูลไรเดอร์');
      }

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
          _riderName = riderData['name'] ?? 'ไรเดอร์';

          _isDataLoaded = true;
        });

        debugPrint('📍 Pickup: $_pickupLat, $_pickupLon');
        debugPrint('📍 Destination: $_destinationLat, $_destinationLon');
        debugPrint('📢 Status: $_currentStatus');

        _initializeMap();
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

    // อัพเดทตำแหน่งไรเดอร์บนแผนที่แบบเรียลไทม์
    if (_isPageFinished) {
      _webViewController.runJavaScript('''
        updateRiderLocation(${position.longitude}, ${position.latitude});
      ''');
    }

    final double targetLat = _currentStatus == 2 ? _pickupLat : _destinationLat;
    final double targetLon = _currentStatus == 2 ? _pickupLon : _destinationLon;

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
      double estimatedMinutes = (distanceInMeters / 1000) / 30 * 60;
      _estimatedTime = '${estimatedMinutes.toStringAsFixed(0)} นาที';
    });
  }

  void _initializeMap() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            if (mounted) {
              setState(() {
                _isPageFinished = true;
              });
              debugPrint('✅ Map loaded successfully');
              _startLocationTracking();
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('เกิดข้อผิดพลาดการโหลดแผนที่: ${error.description}');
          },
        ),
      )
      ..loadHtmlString(_buildMapHtml());
  }

  void _openGoogleMapsNavigation() async {
    final double targetLat = _currentStatus == 2 ? _pickupLat : _destinationLat;
    final double targetLon = _currentStatus == 2 ? _pickupLon : _destinationLon;

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

  Future<void> _takePhotoAndUpdateStatus(int newStatus) async {
    try {
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

      setState(() {
        _isUploading = true;
      });

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
      final downloadUrl = response.secureUrl;
      log('อัปโหลด Cloudinary สำเร็จ: $downloadUrl');

      final String photoKey = newStatus.toString();
      await FirebaseFirestore.instance
          .collection('Product')
          .doc(widget.orderId)
          .update({
            'status': newStatus,
            'statusPhotos.$photoKey': downloadUrl,
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
          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      log('Error taking photo and updating status: $e');
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

  String _buildMapHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="initial-scale=1.0, user-scalable=no" />
  <meta charset="utf-8">
  <style>
    html, body { height: 100%; margin: 0; padding: 0; }
    #map { height: 100%; }
    .marker-label {
      background: white;
      padding: 4px 8px;
      border-radius: 4px;
      font-weight: bold;
      box-shadow: 0 2px 4px rgba(0,0,0,0.3);
      font-size: 12px;
      white-space: nowrap;
    }
  </style>
  <script src="https://api.longdo.com/map/?key=$longdoMapApiKey"></script>
</head>
<body>
  <div id="map"></div>
  
  <script>
    var map;
    var pickupMarker;
    var destinationMarker;
    var riderMarker;
    var routeLayer;

    window.onload = function() {
      initMap();
    };

    function initMap() {
      try {
        console.log('🗺️ Initializing Longdo Map...');
        
        map = new longdo.Map({
          placeholder: document.getElementById('map'),
          language: 'th'
        });

        console.log('✅ Map created');

        var pickupLat = $_pickupLat;
        var pickupLon = $_pickupLon;
        var destLat = $_destinationLat;
        var destLon = $_destinationLon;

        console.log('📍 Pickup:', pickupLat, pickupLon);
        console.log('📍 Destination:', destLat, destLon);

        var isPickupValid = (pickupLat !== 0.0 && pickupLon !== 0.0);
        var isDestValid = (destLat !== 0.0 && destLon !== 0.0);

        var centerLat = 13.7563;
        var centerLon = 100.5018;
        var zoom = 10;

        if (isPickupValid && isDestValid) {
          centerLon = (pickupLon + destLon) / 2;
          centerLat = (pickupLat + destLat) / 2;
          zoom = 13;
        } else if (isPickupValid) {
          centerLon = pickupLon;
          centerLat = pickupLat;
          zoom = 14;
        } else if (isDestValid) {
          centerLon = destLon;
          centerLat = destLat;
          zoom = 14;
        }

        map.location({ lon: centerLon, lat: centerLat }, true);
        map.zoom(zoom, true);

        console.log('🎯 Map centered at:', centerLat, centerLon, 'zoom:', zoom);

        // เพิ่มหมุดจุดรับสินค้า (สีแดง + ไอคอน + ป้ายชื่อ)
        if (isPickupValid) {
          console.log('📌 Adding PICKUP marker...');
          
          pickupMarker = new longdo.Marker(
            { lon: pickupLon, lat: pickupLat },
            {
              title: '🔴 จุดรับสินค้า',
              detail: '$_pickupAddress',
              icon: {
                html: '<div style="text-align:center;"><div class="marker-label" style="background:#FF5252;color:white;margin-bottom:4px;">📦 รับที่นี่</div><div style="width:40px;height:40px;background:#FF5252;border-radius:50%;border:4px solid white;box-shadow:0 3px 6px rgba(0,0,0,0.4);display:flex;align-items:center;justify-content:center;font-size:20px;">1</div></div>',
                offset: { x: 20, y: 50 }
              }
            }
          );
          
          map.Overlays.add(pickupMarker);
          console.log('✅ Pickup marker added');
        }

        // เพิ่มหมุดจุดส่งสินค้า (สีน้ำเงิน + ไอคอน + ป้ายชื่อ)
        if (isDestValid) {
          console.log('📌 Adding DESTINATION marker...');
          
          destinationMarker = new longdo.Marker(
            { lon: destLon, lat: destLat },
            {
              title: '🔵 จุดส่งสินค้า',
              detail: '$_destinationAddress',
              icon: {
                html: '<div style="text-align:center;"><div class="marker-label" style="background:#2196F3;color:white;margin-bottom:4px;">🏠 ส่งที่นี่</div><div style="width:40px;height:40px;background:#2196F3;border-radius:50%;border:4px solid white;box-shadow:0 3px 6px rgba(0,0,0,0.4);display:flex;align-items:center;justify-content:center;font-size:20px;">2</div></div>',
                offset: { x: 20, y: 50 }
              }
            }
          );
          
          map.Overlays.add(destinationMarker);
          console.log('✅ Destination marker added');
        }

        // สร้างเส้นทางระหว่างจุดรับและจุดส่ง
        if (isPickupValid && isDestValid) {
          drawRoute(pickupLon, pickupLat, destLon, destLat);
        }

        // สร้างหมุดไรเดอร์ (จะอัพเดทตำแหน่งแบบเรียลไทม์)
        createRiderMarker(centerLon, centerLat);

        console.log('🎉 Map initialization complete!');
        
      } catch (error) {
        console.error('❌ Error:', error);
      }
    }

    // ฟังก์ชันสร้างหมุดไรเดอร์
    function createRiderMarker(lon, lat) {
      riderMarker = new longdo.Marker(
        { lon: lon, lat: lat },
        {
          title: '🏍️ ไรเดอร์',
          detail: 'ตำแหน่งปัจจุบัน',
          icon: {
            html: '<div style="width:50px;height:50px;background:#4CAF50;border-radius:50%;border:4px solid white;box-shadow:0 4px 8px rgba(0,0,0,0.5);display:flex;align-items:center;justify-content:center;font-size:24px;animation:pulse 2s infinite;">🏍️</div><style>@keyframes pulse{0%,100%{transform:scale(1)}50%{transform:scale(1.1)}}</style>',
            offset: { x: 25, y: 25 }
          }
        }
      );
      map.Overlays.add(riderMarker);
      console.log('✅ Rider marker created');
    }

    // ฟังก์ชันอัพเดทตำแหน่งไรเดอร์แบบเรียลไทม์
    function updateRiderLocation(lon, lat) {
      if (riderMarker) {
        riderMarker.location({ lon: lon, lat: lat });
        console.log('🔄 Rider position updated:', lon, lat);
      }
    }

    // ฟังก์ชันวาดเส้นทาง
    function drawRoute(fromLon, fromLat, toLon, toLat) {
      try {
        // ลบเส้นทางเก่า (ถ้ามี)
        if (routeLayer) {
          map.Overlays.remove(routeLayer);
        }

        // สร้างเส้นทางใหม่
        routeLayer = new longdo.Polyline(
          [
            { lon: fromLon, lat: fromLat },
            { lon: toLon, lat: toLat }
          ],
          {
            title: 'เส้นทาง',
            lineWidth: 5,
            lineColor: 'rgba(103, 58, 183, 0.8)',
            arrow: true
          }
        );
        
        map.Overlays.add(routeLayer);
        console.log('✅ Route drawn');
      } catch (error) {
        console.error('❌ Error drawing route:', error);
      }
    }
  </script>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_isDataLoaded)
            SafeArea(
              bottom: false,
              child: WebViewWidget(controller: _webViewController),
            ),
          if (!_isDataLoaded || !_isPageFinished)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF6F35A5)),
                    SizedBox(height: 16),
                    Text(
                      'กำลังโหลดข้อมูล...',
                      style: TextStyle(fontSize: 16, color: Color(0xFF6F35A5)),
                    ),
                  ],
                ),
              ),
            ),
          if (_isDataLoaded && _isPageFinished) ...[
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
          tooltip: 'นำทาง',
        ),
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
                    address: _pickupAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildAddressInfo(
                    icon: Icons.location_on,
                    iconColor: Colors.blue,
                    title: 'ที่อยู่ปลายทาง',
                    address: _destinationAddress,
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
                _customerName,
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
            final url = Uri.parse('tel:$_customerPhone');
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
          onPressed: () {},
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
      // คำนวณระยะห่างจากจุดรับ
      double? distance;
      if (_currentRiderLat != null && _currentRiderLon != null) {
        distance = Geolocator.distanceBetween(
          _currentRiderLat!,
          _currentRiderLon!,
          _pickupLat,
          _pickupLon,
        );
      }

      bool isNearPickup = distance != null && distance <= 20;

      return Column(
        children: [
          if (!isNearPickup && distance != null)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'คุณอยู่ห่างจากจุดรับ ${distance.toStringAsFixed(0)} ม.\nต้องเข้าใกล้ไม่เกิน 20 เมตร',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isNearPickup
                  ? () => _takePhotoAndUpdateStatus(3)
                  : null, // ปิดปุ่มถ้าห่างเกิน 20 เมตร
              icon: Icon(Icons.camera_alt),
              label: Text(
                isNearPickup
                    ? 'ถ่ายรูปยืนยันรับสินค้า'
                    : 'เข้าใกล้จุดรับเพื่อยืนยัน',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isNearPickup ? Colors.green : Colors.grey,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      );
    }
    // เหมือนกันสำหรับ status == 3 (จุดส่ง)
    else if (_currentStatus == 3) {
      double? distance;
      if (_currentRiderLat != null && _currentRiderLon != null) {
        distance = Geolocator.distanceBetween(
          _currentRiderLat!,
          _currentRiderLon!,
          _destinationLat,
          _destinationLon,
        );
      }

      bool isNearDestination = distance != null && distance <= 20;

      return Column(
        children: [
          if (!isNearDestination && distance != null)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'คุณอยู่ห่างจากจุดส่ง ${distance.toStringAsFixed(0)} ม.\nต้องเข้าใกล้ไม่เกิน 20 เมตร',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isNearDestination
                  ? () => _takePhotoAndUpdateStatus(4)
                  : null,
              icon: Icon(Icons.camera_alt),
              label: Text(
                isNearDestination
                    ? 'ถ่ายรูปยืนยันส่งสินค้า'
                    : 'เข้าใกล้จุดส่งเพื่อยืนยัน',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isNearDestination
                    ? Color(0xFF6F35A5)
                    : Colors.grey,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      );
    }
    // Status 4: สำเร็จแล้ว
    else {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green),
        ),
        child: Row(
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
