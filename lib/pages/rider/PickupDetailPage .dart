import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// นี่คือหน้าจอสำหรับแสดงรายละเอียดของงานรับสินค้า
// ประกอบด้วยแผนที่แสดงตำแหน่ง และแผงข้อมูลที่สามารถเลื่อนขึ้นลงได้
class PickupDetailPage extends StatefulWidget {
  final String orderId;
  final String customerName;
  final String customerPhone;
  final String pickupAddress;
  final String pickupLat;
  final String pickupLon;
  final String firstItem; // แม้ใน UI ใหม่จะไม่ได้ใช้ แต่เก็บไว้เผื่ออนาคต
  final String secondItem; // เช่นกัน
  final String destinationAddress;

  const PickupDetailPage({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.customerPhone,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLon,
    required this.firstItem,
    required this.secondItem,
    required this.destinationAddress,
  });

  @override
  State<PickupDetailPage> createState() => _PickupDetailPageState();
}

class _PickupDetailPageState extends State<PickupDetailPage> {
  // API Key สำหรับ Longdo Map (อย่าลืมเปลี่ยนเป็น Key ของคุณเอง)
  final String longdoMapApiKey = 'ba51dc98b3fd0dd3bb1ab2224a3e36d1';
  late WebViewController _webViewController;
  bool _isPageFinished = false;

  @override
  void initState() {
    super.initState();
    // ตั้งค่า WebViewController สำหรับแสดงแผนที่
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          // เมื่อหน้าเว็บโหลดเสร็จ ให้ซ่อนตัวโหลดดิ้ง
          onPageFinished: (String url) {
            setState(() {
              _isPageFinished = true;
            });
          },
          // แสดงข้อผิดพลาดถ้ามีปัญหาในการโหลดแผนที่
          onWebResourceError: (WebResourceError error) {
            debugPrint('เกิดข้อผิดพลาดการโหลดแผนที่: ${error.description}');
          },
        ),
      )
      // โหลด HTML ที่มีโค้ดของ Longdo Map
      ..loadHtmlString(_buildMapHtml());
  }

  // ฟังก์ชันนี้สร้างโค้ด HTML สำหรับแผนที่ Longdo
  String _buildMapHtml() {
    // แปลงค่า Lat/Lon ที่รับมาเป็น String ให้เป็น double
    // ถ้าแปลงไม่ได้ ให้ใช้ค่าเริ่มต้นเป็นตำแหน่งของกรุงเทพฯ
    final lat = double.tryParse(widget.pickupLat) ?? 13.7563;
    final lon = double.tryParse(widget.pickupLon) ?? 100.5018;

    // โค้ด HTML, CSS, และ JavaScript สำหรับแสดงแผนที่และปักหมุด
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="initial-scale=1.0, user-scalable=no" />
        <style type="text/css">
          html { height: 100% }
          body { height: 100%; margin: 0; padding: 0 }
          #map { height: 100% }
        </style>
        <script src="https://api.longdo.com/map/?key=$longdoMapApiKey"></script>
        <script>
          let map;
          let marker;

          function init() {
            try {
              map = new longdo.Map({
                placeholder: document.getElementById('map'),
                language: 'th'
              });
              
              const pickupLocation = { lon: $lon, lat: $lat };
              map.location(pickupLocation, true);
              map.zoom(15, true);

              marker = new longdo.Marker(
                  pickupLocation,
                  { 
                    visible: true,
                    title: 'ต้นทางรับสินค้า'
                  } 
              );
              map.Overlays.add(marker);
            } catch (e) {
              console.error('Error during map initialization:', e);
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
      // ไม่ต้องใช้ AppBar แล้ว เพราะ UI ใหม่เป็นแบบเต็มจอ
      body: Stack(
        children: [
          // ส่วนแสดงแผนที่ จะอยู่ชั้นล่างสุด
          // ใช้ SafeArea เพื่อป้องกันไม่ให้แผนที่แสดงทับ Status Bar ด้านบน
          // โดยปิดการทำงานสำหรับด้านล่าง (bottom: false) เพื่อให้ DraggableSheet ชิดขอบล่างได้
          SafeArea(
            bottom: false,
            child: WebViewWidget(controller: _webViewController),
          ),

          // แสดงตัวโหลดดิ้งขณะที่แผนที่กำลังโหลด
          if (!_isPageFinished)
            const Center(child: CircularProgressIndicator()),

          // ส่วนของข้อมูลที่เลื่อนได้ จะอยู่ชั้นบนสุด
          _buildDraggableSheet(),
        ],
      ),
    );
  }

  // สร้าง Widget ที่เป็นแผงข้อมูลด้านล่างที่สามารถลากขึ้นลงได้
  Widget _buildDraggableSheet() {
    return DraggableScrollableSheet(
      // ขนาดเริ่มต้นของแผงข้อมูล (ประมาณ 40% ของหน้าจอ)
      initialChildSize: 0.4,
      // ขนาดเล็กสุดเมื่อลากลง (ประมาณ 15% ของหน้าจอ)
      minChildSize: 0.15,
      // ขนาดใหญ่สุดเมื่อลากขึ้น (90% ของหน้าจอ)
      maxChildSize: 0.9,
      builder: (BuildContext context, ScrollController scrollController) {
        // ใช้ Container เพื่อสร้างขอบมนและเงา
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
          // ใช้ SingleChildScrollView เพื่อให้เนื้อหาข้างในสามารถเลื่อนได้
          // เมื่อลากแผงข้อมูลขึ้นจนสุด
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // แถบสำหรับให้ผู้ใช้รู้ว่าลากได้
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

                  // ส่วนแสดงข้อมูลผู้ส่ง (รูป, ชื่อ, ปุ่มโทร/แชท)
                  _buildSenderInfo(),
                  const SizedBox(height: 24),

                  // ส่วนแสดงที่อยู่ต้นทางและปลายทาง
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

                  // ปุ่มยืนยันการรับสินค้า
                  _buildConfirmButton(),
                  const SizedBox(height: 24), // เพิ่ม padding ด้านล่าง
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Widget สำหรับแสดงข้อมูลผู้ส่ง
  Widget _buildSenderInfo() {
    return Row(
      children: [
        // รูปโปรไฟล์
        const CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey,
          // ในอนาคตอาจจะเปลี่ยนเป็น Image.network(widget.customerImageUrl)
          child: Icon(Icons.person, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        // ชื่อและสถานะ
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
        // ปุ่มโทร
        IconButton(
          onPressed: () {
            /* TODO: ใส่ฟังก์ชันการโทร */
          },
          icon: const Icon(Icons.call, color: Colors.black54),
        ),
        // ปุ่มแชท
        IconButton(
          onPressed: () {
            /* TODO: ใส่ฟังก์ชันการแชท */
          },
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.black54),
        ),
      ],
    );
  }

  // Widget สำหรับแสดงข้อมูลที่อยู่ (ใช้ซ้ำได้ทั้งต้นทางและปลายทาง)
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

  // Widget สำหรับปุ่มยืนยัน
  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // แสดง SnackBar เพื่อแจ้งเตือน
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ยืนยันการรับสินค้าเรียบร้อย'),
              duration: Duration(seconds: 2),
            ),
          );
          // กลับไปหน้าก่อนหน้า
          Navigator.pop(context);
        },
        icon: const Icon(Icons.camera_alt),
        label: const Text(
          'ถ่ายเอกสาร', // เปลี่ยนข้อความตาม UI ที่ให้มา
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6F35A5), // สีม่วงเข้ม
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
