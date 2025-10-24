import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_miniproject/pages/rider/PickupDetailPage%20.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

class JobPreviewPage extends StatefulWidget {
  final String orderId;
  final String riderId;
  final String firstItem;
  final String secondItem;
  final String itemImageUrl; // (ข้อ 4.1.2)
  final String pickupAddress;
  final String destinationAddress;
  final String senderName;
  final String senderPhone;
  final String receiverName; // (ข้อ 4.1.2)
  final double pickupLat;
  final double pickupLon;
  final double destinationLat;
  final double destinationLon;

  const JobPreviewPage({
    Key? key,
    required this.orderId,
    required this.riderId,
    required this.firstItem,
    required this.secondItem,
    required this.itemImageUrl,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.senderName,
    required this.senderPhone,
    required this.receiverName,
    required this.pickupLat,
    required this.pickupLon,
    required this.destinationLat,
    required this.destinationLon,
  }) : super(key: key);

  @override
  State<JobPreviewPage> createState() => _JobPreviewPageState();
}

class _JobPreviewPageState extends State<JobPreviewPage> {
  final String longdoMapApiKey = 'ba51dc98b3fd0dd3bb1ab2224a3e36d1';
  WebViewController? _webViewController;
  bool _isMapLoading = true;

  // (ข้อ 4.2.1) ย้ายฟังก์ชันรับงานมาไว้ที่หน้านี้
  Future<void> _acceptOrder() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseFirestore.instance
          .collection('Product')
          .doc(widget.orderId)
          .update({'status': 2, 'riderId': widget.riderId});

      if (mounted) Navigator.pop(context); // ปิด Loading

      // ไปหน้า PickupDetailPage (ข้ามหน้า RiderMainPage ไปเลย)
      if (mounted) {
        Get.off(
          () => PickupDetailPage(
            orderId: widget.orderId,
            riderId: widget.riderId,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการรับงาน: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeMap();
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
                _isMapLoading = false;
              });
            }
          },
        ),
      )
      ..loadHtmlString(_buildMapHtml());
  }

  // (ข้อ 4.1.3) สร้างแผนที่
  String _buildMapHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="initial-scale=1.0, user-scalable=no" />
  <meta charset="utf-8">
  <style>
    html, body { height: 100%; margin: 0; padding: 0; overflow: hidden; }
    #map { height: 100%; }
  </style>
  <script src="https://api.longdo.com/map/?key=$longdoMapApiKey"></script>
</head>
<body>
  <div id="map"></div>
  <script>
    window.onload = function() {
      try {
        var map = new longdo.Map({
          placeholder: document.getElementById('map'),
          language: 'th'
        });
        
        var pickup = {lat: ${widget.pickupLat}, lon: ${widget.pickupLon}};
        var dest = {lat: ${widget.destinationLat}, lon: ${widget.destinationLon}};

        // ปักหมุดจุดรับ
        if (pickup.lat !== 0) {
          map.Overlays.add(new longdo.Marker({lon: pickup.lon, lat: pickup.lat}, {
            title: '📦 จุดรับสินค้า',
            icon: {
              html: '<div style="width:28px;height:28px;background:#FF5252;border-radius:50%;border:2px solid white;box-shadow:0 2px 5px rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;font-size:16px;">📦</div>',
              offset: {x: 14, y: 14}
            }
          }));
        }

        // ปักหมุดจุดส่ง
        if (dest.lat !== 0) {
          map.Overlays.add(new longdo.Marker({lon: dest.lon, lat: dest.lat}, {
            title: '🏠 จุดส่งสินค้า',
            icon: {
              html: '<div style="width:28px;height:28px;background:#2196F3;border-radius:50%;border:2px solid white;box-shadow:0 2px 5px rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;font-size:16px;">🏠</div>',
              offset: {x: 14, y: 14}
            }
          }));
        }

        // ตั้งค่ามุมมองให้เห็นทั้ง 2 จุด
        if (pickup.lat !== 0 && dest.lat !== 0) {
          map.bound({
            minLon: Math.min(pickup.lon, dest.lon) - 0.01,
            minLat: Math.min(pickup.lat, dest.lat) - 0.01,
            maxLon: Math.max(pickup.lon, dest.lon) + 0.01,
            maxLat: Math.max(pickup.lat, dest.lat) + 0.01
          });
        } else if (pickup.lat !== 0) {
           map.location({lon: pickup.lon, lat: pickup.lat}, true);
           map.zoom(14);
        }

      } catch (error) {
        console.error('Map init error:', error);
      }
    };
  </script>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ตรวจสอบรายละเอียดงาน',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // (ข้อ 4.1.3) ส่วนแผนที่
          SizedBox(
            height: 300,
            child: Stack(
              children: [
                if (_webViewController != null)
                  WebViewWidget(controller: _webViewController!),
                if (_isMapLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          // (ข้อ 4.1.2) ส่วนรายละเอียด
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // (ข้อ 4.1.2) รูปสินค้า
                  if (widget.itemImageUrl.isNotEmpty &&
                      widget.itemImageUrl.startsWith('http'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.itemImageUrl,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          return progress == null
                              ? child
                              : const SizedBox(
                                  height: 150,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    widget.firstItem,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.secondItem.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.secondItem,
                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                  ],
                  const Divider(height: 32),

                  // (ข้อ 4.1.2) ผู้ส่ง
                  _buildDetailRow(
                    icon: Icons.person,
                    color: Colors.blue,
                    title: 'ผู้ส่ง',
                    content: '${widget.senderName} (${widget.senderPhone})',
                  ),
                  const SizedBox(height: 16),
                  // (ข้อ 4.1.2) ที่อยู่รับ
                  _buildDetailRow(
                    icon: Icons.location_on,
                    color: Colors.red,
                    title: 'ที่อยู่รับสินค้า',
                    content: widget.pickupAddress,
                  ),
                  const Divider(height: 32),
                  // (ข้อ 4.1.2) ผู้รับ
                  _buildDetailRow(
                    icon: Icons.person_outline,
                    color: Colors.green,
                    title: 'ผู้รับ',
                    content: widget.receiverName,
                  ),
                  const SizedBox(height: 16),
                  // (ข้อ 4.1.2) ที่อยู่ส่ง
                  _buildDetailRow(
                    icon: Icons.location_on,
                    color: Colors.red,
                    title: 'ที่อยู่ปลายทาง',
                    content: widget.destinationAddress,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // (ข้อ 4.2.1) ปุ่มรับงาน
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _acceptOrder,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('รับออเดอร์นี้'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A5ACD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color color,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(content, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }
}
