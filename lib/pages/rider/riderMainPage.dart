<<<<<<< HEAD:lib/pages/riderMainPage.dart
import 'package:delivery_miniproject/pages/viewRiderProfilePage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
=======
// ✨ Imports (เหมือนเดิม, ตรวจสอบ path ให้ถูกต้อง)
import 'package:delivery_miniproject/pages/rider/EditRiderProfilePage.dart';
import 'package:delivery_miniproject/pages/rider/PickupDetailPage%20.dart';
>>>>>>> ed346d717ee9bfd9dd6400d596871e3572080422:lib/pages/rider/riderMainPage.dart

import 'package:delivery_miniproject/pages/rider/viewRiderProfilePage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ยังคง import ไว้เผื่อใช้ภายหลัง
import 'package:get/get.dart'; // Import Get
import 'package:delivery_miniproject/pages/loginRiderPage.dart';

class RiderMainPage extends StatefulWidget {
  final String riderId; // ยังคงรับ riderId ไว้สำหรับส่วน Profile

  const RiderMainPage({super.key, required this.riderId});

  @override
  State<RiderMainPage> createState() => _RiderMainPageState();
}

class _RiderMainPageState extends State<RiderMainPage> {
  // ✨ Comment out or remove stream for now
  // final Stream<QuerySnapshot> _ordersStream = FirebaseFirestore.instance
  //     .collection('orders')
  //     .snapshots();

  late final Stream<DocumentSnapshot> _riderStream;

  @override
  void initState() {
    super.initState();
    // Stream สำหรับ Profile ยังคงทำงานเหมือนเดิม
    _riderStream = FirebaseFirestore.instance
        .collection('Rider')
        .doc(widget.riderId)
        .snapshots();
  }

  // ✨ ฟังก์ชัน _buildOrderCard (ปรับ UI ตามรูป)
  Widget _buildOrderCard({
    required String orderId, // ยังคงรับ parameter ไว้
    required String firstItem,
    required String secondItem,
    required String pickupAddress,
    required String destinationAddress,
    required String customerName,
    required String customerPhone, // เก็บไว้เผื่อใช้ส่งไปหน้า Pickup
    required String customerImageUrl,
    required String pickupLat, // เก็บไว้เผื่อใช้ส่งไปหน้า Pickup
    required String pickupLon, // เก็บไว้เผื่อใช้ส่งไปหน้า Pickup
    required String destinationLat, // เก็บไว้เผื่อใช้ส่งไปหน้า Pickup
    required String destinationLon, // เก็บไว้เผื่อใช้ส่งไปหน้า Pickup
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E6FA), // สีม่วงอ่อน
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Items and Customer Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Side: Items
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.brown,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'สินค้าที่ต้องจัดส่ง',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• $firstItem',
                      style: const TextStyle(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• $secondItem',
                      style: const TextStyle(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right Side: Customer
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage:
                          (customerImageUrl.isNotEmpty &&
                              customerImageUrl.startsWith('http'))
                          ? NetworkImage(customerImageUrl)
                          : null, // ใช้ NetworkImage ถ้า URL ถูกต้อง
                      child:
                          (customerImageUrl.isEmpty ||
                              !customerImageUrl.startsWith('http'))
                          ? Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.grey.shade600,
                            ) // Placeholder
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Divider
          Container(height: 1.0, color: Colors.black26.withOpacity(0.2)),
          const SizedBox(height: 16),
          // Pickup Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Color(0xFF9370DB), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ที่อยู่รับสินค้า',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      pickupAddress,
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Destination Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ที่อยู่ปลายทาง',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      destinationAddress,
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Accept Button
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Get.to(
                    () => PickupDetailPage(
                      orderId: orderId, // ส่ง ID ที่ได้รับมา
                      customerName: customerName,
                      customerPhone: customerPhone,
                      pickupAddress: pickupAddress,
                      pickupLat: pickupLat,
                      pickupLon: pickupLon,
                      firstItem: firstItem,
                      secondItem: secondItem,
                      destinationAddress: destinationAddress,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A5ACD),
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'รับออเดอร์',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          padding: const EdgeInsets.only(top: 30.0, left: 16.0, right: 16.0),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  SizedBox(width: 8),
                  Text(
                    'ไรเดอร์',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.black),
                onSelected: (String value) {
                  if (value == 'profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ViewRiderProfilePage(riderId: widget.riderId),
                      ),
                    );
                  } else if (value == 'logout') {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginRiderPage(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'profile',
                    child: Text('ดูโปรไฟล์'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('ออกจากระบบ'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Rider Profile Section (Uses StreamBuilder - Remains the same) ---
            StreamBuilder<DocumentSnapshot>(
              stream: _riderStream,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<DocumentSnapshot> snapshot,
                  ) {
                    // (โค้ดแสดงโปรไฟล์ไรเดอร์เหมือนเดิม)
                    if (snapshot.hasError) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'มีข้อผิดพลาดในการโหลดโปรไฟล์',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('ไม่พบข้อมูลโปรไฟล์'),
                        ),
                      );
                    }
                    Map<String, dynamic> data =
                        snapshot.data!.data() as Map<String, dynamic>;
                    String riderName = data['name'] ?? 'ไม่มีชื่อ';
                    String carReg = data['carRegistration'] ?? 'ไม่มีทะเบียน';
                    String profileImageUrl =
                        data['imageUrl'] ?? ''; // Get the URL

                    return Container(
                      margin: const EdgeInsets.all(16.0),
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6E6FA),
                        borderRadius: BorderRadius.circular(20.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFD4AF37), // Gold border
                                width: 4,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.grey.shade300,
                              // Use NetworkImage if URL is valid, otherwise show placeholder
                              backgroundImage:
                                  (profileImageUrl.isNotEmpty &&
                                      profileImageUrl.startsWith('http'))
                                  ? NetworkImage(profileImageUrl)
                                  : null,
                              child:
                                  (profileImageUrl.isEmpty ||
                                      !profileImageUrl.startsWith('http'))
                                  ? Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.grey.shade600,
                                    ) // Placeholder Icon
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            riderName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            carReg,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
            ),
            const SizedBox(height: 16),
            // --- "รายการออเดอร์" Heading ---
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'รายการออเดอร์',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            // --- ✨ Hardcoded Order Cards ---
            // Card 1 (Example 1 from image)
            _buildOrderCard(
              orderId: 'dummy_order_1', // Dummy ID
              firstItem: 'Iphone 13',
              secondItem: 'โน้ตบุ๊คเกมมิ่ง',
              pickupAddress:
                  '456 หมู่12 ต.บ้านดินดำ อ.กันทรวิชัย จ.มหาสารคาม 44150',
              destinationAddress:
                  '67/8 หมู่8 ต.ขามเรียง อ.กันทรวิชัย จ.มหาสารคาม 44150',
              customerName: 'คุณสมชาย',
              customerPhone: '1234', // Dummy phone
              // Placeholder image URL or a real one if you have one
              customerImageUrl:
                  'https://placehold.co/100x100/A9A9A9/FFFFFF?text=S',
              pickupLat: '16.3000', // Dummy coordinates
              pickupLon: '103.2000',
              destinationLat: '16.3100',
              destinationLon: '103.2100',
            ),
            // Card 2 (Example 2 from image)
            _buildOrderCard(
              orderId: 'dummy_order_2', // Dummy ID
              firstItem: 'Ps5 slim',
              secondItem:
                  'โน้ตบุ๊คเกมมิ่ง', // (Example had the same second item)
              pickupAddress:
                  '123 หมู่12 ต.ท่าขอนยาง อ.กันทรวิชัย จ.มหาสารคาม 44150',
              destinationAddress:
                  '21/22 หมู่12 ต.ขามเรียง อ.กันทรวิชัย จ.มหาสารคาม 44150',
              customerName: 'Aof',
              customerPhone: '5678', // Dummy phone
              // Placeholder image URL or a real one if you have one
              customerImageUrl:
                  'https://placehold.co/100x100/A9A9A9/FFFFFF?text=A',
              pickupLat: '16.3200', // Dummy coordinates
              pickupLon: '103.2200',
              destinationLat: '16.3300',
              destinationLon: '103.2300',
            ),
            const SizedBox(height: 16), // Add some bottom padding
            // ✨ Commented out the StreamBuilder for orders
            /*
            StreamBuilder<QuerySnapshot>(
              stream: _ordersStream,
              builder: (
                BuildContext context,
                AsyncSnapshot<QuerySnapshot> snapshot,
              ) {
                // ... (Original StreamBuilder code) ...
              },
            ),
            */
          ],
        ),
      ),
    );
  }
}
