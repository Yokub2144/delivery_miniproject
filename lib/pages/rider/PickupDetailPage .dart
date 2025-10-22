import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class PickupDetailPage extends StatefulWidget {
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
  final String longdoMapApiKey = 'ba51dc98b3fd0dd3bb1ab2224a3e36d1';
  late WebViewController _webViewController;
  bool _isPageFinished = false;
  bool _isProfileLoaded = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  double? _currentRiderLat;
  double? _currentRiderLon;
  String _riderImageUrl = '';
  String _riderName = '';
  String _estimatedDistance = 'กำลังคำนวณ...';
  String _estimatedTime = '...';

  @override
  void initState() {
    super.initState();
    _loadRiderProfileAndInitialize();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
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

  void _updateRiderPosition(Position position) {
    if (!mounted) return;

    setState(() {
      _currentRiderLat = position.latitude;
      _currentRiderLon = position.longitude;
    });

    final pickupLat = double.tryParse(widget.pickupLat) ?? 0.0;
    final pickupLon = double.tryParse(widget.pickupLon) ?? 0.0;

    double distanceInMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      pickupLat,
      pickupLon,
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
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('เกิดข้อผิดพลาดการโหลดแผนที่: ${error.description}');
          },
        ),
      )
      ..loadHtmlString(_buildMapHtml());
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
    final pickupLat = widget.pickupLat;
    final pickupLon = widget.pickupLon;

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$pickupLat,$pickupLon&travelmode=driving',
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

  String _buildMapHtml() {
    final pickupLat = double.tryParse(widget.pickupLat) ?? 13.7563;
    final pickupLon = double.tryParse(widget.pickupLon) ?? 100.5018;

    final safeAddress = widget.pickupAddress.replaceAll("'", "\\'");
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
    let riderMarker;

    function init() {
      try {
        map = new longdo.Map({
          placeholder: document.getElementById('map'),
          language: 'th'
        });
        
        const pickupLocation = { lon: $pickupLon, lat: $pickupLat };
        map.location(pickupLocation, true);
        map.zoom(15, true);

        pickupMarker = new longdo.Marker(
          pickupLocation,
          { 
            visible: true,
            title: 'จุดรับสินค้า',
            detail: '$safeAddress',
            icon: {
              url: 'https://map.longdo.com/mmmap/images/pin_red.png'
            }
          } 
        );
        map.Overlays.add(pickupMarker);

        riderMarker = new longdo.Marker(
          pickupLocation,
          { 
            visible: false,
            title: 'ตำแหน่งของคุณ: $_riderName',
            icon: {
              html: '<div class="rider-marker"><img src="$safeImageUrl" onerror="this.src=\\'https://ui-avatars.com/api/?name=R&background=6F35A5&color=fff&size=100\\'" /></div>',
              offset: { x: 25, y: 25 }
            }
          } 
        );
        map.Overlays.add(riderMarker);

      } catch (e) {
        console.error('Error during map initialization:', e);
      }
    }

    function updateRiderLocation(lon, lat) {
      if (riderMarker) {
        const newLocation = { lon: lon, lat: lat };
        riderMarker.location(newLocation);
        riderMarker.visible(true);
      }
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.navigation, color: Color(0xFF6F35A5), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ระยะทางไปจุดรับสินค้า',
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
                  _buildConfirmButton(),
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

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ยืนยันการรับสินค้าเรียบร้อย'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        },
        icon: const Icon(Icons.camera_alt),
        label: const Text(
          'ถ่ายเอกสาร',
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
  }
}
