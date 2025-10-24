// (ข้อ 4.1.3) Import หน้า Preview
import 'package:delivery_miniproject/pages/rider/job_preview_page.dart';

import 'package:delivery_miniproject/pages/loadingPage.dart';
import 'package:delivery_miniproject/pages/rider/EditRiderProfilePage.dart';
import 'package:delivery_miniproject/pages/rider/PickupDetailPage%20.dart';
import 'package:delivery_miniproject/pages/rider/viewRiderProfilePage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:delivery_miniproject/pages/loginRiderPage.dart';
import 'package:delivery_miniproject/pages/statusPage.dart';
import 'package:delivery_miniproject/pages/statusPage.dart' as sp;

class RiderMainPage extends StatefulWidget {
  final String riderId;

  const RiderMainPage({super.key, required this.riderId});

  @override
  State<RiderMainPage> createState() => _RiderMainPageState();
}

class _RiderMainPageState extends State<RiderMainPage> {
  late final Stream<DocumentSnapshot> _riderStream;

  @override
  void initState() {
    super.initState();
    _riderStream = FirebaseFirestore.instance
        .collection('Rider')
        .doc(widget.riderId)
        .snapshots();
  }

  // --- (ข้อ 4.2.1) ฟังก์ชัน _acceptOrder ถูก "ย้าย" ไปที่ job_preview_page.dart แล้ว ---

  // --- *** [แก้ไข] การ์ดงานใหม่ (ข้อ 4.1.2 และ 4.1.3) *** ---
  Widget _buildOrderCard({
    required String orderId,
    required String firstItem,
    required String secondItem,
    required String itemImageUrl, // เพิ่มรูปสินค้า
    required String pickupAddress,
    required String destinationAddress,
    required String senderName,
    required String senderPhone,
    required String receiverName, // เพิ่มชื่อผู้รับ
    // (ข้อ 4.1.3) เพิ่ม Lat/Lng เพื่อส่งไปหน้า Preview
    required double pickupLat,
    required double pickupLon,
    required double destinationLat,
    required double destinationLon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E6FA),
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
      // (ข้อ 4.1.3) ทำให้การ์ดกดได้
      child: InkWell(
        borderRadius: BorderRadius.circular(20.0),
        onTap: () {
          // ไปหน้า Preview
          Get.to(
            () => JobPreviewPage(
              orderId: orderId,
              riderId: widget.riderId,
              firstItem: firstItem,
              secondItem: secondItem,
              itemImageUrl: itemImageUrl,
              pickupAddress: pickupAddress,
              destinationAddress: destinationAddress,
              senderName: senderName,
              senderPhone: senderPhone,
              receiverName: receiverName,
              pickupLat: pickupLat,
              pickupLon: pickupLon,
              destinationLat: destinationLat,
              destinationLon: destinationLon,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // (ข้อ 4.1.2) แสดงรูปสินค้า
                  if (itemImageUrl.isNotEmpty &&
                      itemImageUrl.startsWith('http'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Image.network(
                        itemImageUrl,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    // รูป Default
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.grey.shade400,
                        size: 30,
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstItem,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (secondItem.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            secondItem,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        // (ข้อ 4.1.2) แสดงชื่อผู้ส่งและผู้รับ
                        const SizedBox(height: 8),
                        Text(
                          'ผู้ส่ง: $senderName',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ผู้รับ: $receiverName',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
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
              Container(height: 1.0, color: Colors.black26.withOpacity(0.2)),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFF9370DB),
                    size: 20,
                  ),
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
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // --- (ข้อ 4.1.3) ลบปุ่มรับออเดอร์ออกจากตรงนี้ ---
            ],
          ),
        ),
      ),
    );
  }

  // (การ์ดงานที่รับแล้ว - ไม่เปลี่ยนแปลง)
  Widget _buildAcceptedOrderCard({
    required String orderId,
    required String firstItem,
    required String secondItem,
    required String pickupAddress,
    required String destinationAddress,
    required String customerName,
    required String customerPhone,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF6A5ACD)),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    if (secondItem.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '• $secondItem',
                        style: const TextStyle(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1.0, color: Colors.black26.withOpacity(0.2)),
          const SizedBox(height: 16),
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Get.to(
                    () => PickupDetailPage(
                      orderId: orderId,
                      riderId: widget.riderId,
                    ),
                  );
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text(
                  'ไปที่แผนที่/รับของ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A5ACD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Get.to(
                    () => StatusPage(
                      productId: orderId,
                      userRole: sp.UserRole.rider,
                    ),
                  );
                },
                icon: const Icon(Icons.timeline),
                label: const Text(
                  'ดูสถานะ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6A5ACD),
                  side: const BorderSide(color: Color(0xFF6A5ACD), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
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
      // --- (ข้อ 4.3) ปรับ UI AppBar ---
      appBar: AppBar(
        title: const Text(
          'ไรเดอร์',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
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
                  MaterialPageRoute(builder: (context) => const LoadingPage()),
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ส่วนโปรไฟล์ (เหมือนเดิม)
            StreamBuilder<DocumentSnapshot>(
              stream: _riderStream,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<DocumentSnapshot> snapshot,
                  ) {
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
                    String profileImageUrl = data['imageUrl'] ?? '';

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
                                color: const Color(0xFFD4AF37),
                                width: 4,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.grey.shade300,
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
                                    )
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

            // 2. ส่วนงาน (งานที่กำลังทำ + งานใหม่)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Product')
                  .where('riderId', isEqualTo: widget.riderId)
                  .where('status', whereIn: [2, 3])
                  .snapshots(),
              builder: (context, activeJobSnapshot) {
                // --- ตรวจสอบสถานะ "ไม่ว่าง" ---
                final bool isRiderBusy =
                    activeJobSnapshot.hasData &&
                    activeJobSnapshot.data!.docs.isNotEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 2.1) ส่วนของ "งานที่กำลังทำ" ---
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'งานที่กำลังทำ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (activeJobSnapshot.connectionState ==
                        ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator()),

                    if (activeJobSnapshot.hasError)
                      Center(
                        child: Text(
                          'เกิดข้อผิดพลาด: ${activeJobSnapshot.error}',
                        ),
                      ),

                    if (isRiderBusy)
                      ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: activeJobSnapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final productDoc =
                              activeJobSnapshot.data!.docs[index];
                          final data =
                              productDoc.data() as Map<String, dynamic>;

                          return _buildAcceptedOrderCard(
                            orderId: productDoc.id,
                            firstItem: data['itemName'] ?? 'ไม่มีชื่อสินค้า',
                            secondItem: data['itemDescription'] ?? '',
                            pickupAddress: data['senderAddress'] ?? 'N/A',
                            destinationAddress:
                                data['receiverAddress'] ?? 'N/A',
                            customerName: data['senderName'] ?? 'N/A',
                            customerPhone: data['senderPhone'] ?? '',
                          );
                        },
                      )
                    else if (activeJobSnapshot.connectionState !=
                        ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.0),
                          child: Text(
                            'ยังไม่มีงานที่รับ',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ),

                    // --- 2.2) ส่วนของ "รายการออเดอร์ใหม่" ---
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'รายการออเดอร์ใหม่',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- (ข้อ 4.2.1) ถ้าไม่ว่าง (Busy) ให้ซ่อนลิสต์งานใหม่ ---
                    if (isRiderBusy)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 40.0,
                            horizontal: 24.0,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.pause_circle_outline,
                                size: 60,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'กรุณาเคลียร์งานที่กำลังทำให้เสร็จสิ้น',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    // --- (ข้อ 4.2.1) ถ้าว่าง (Not Busy) ให้แสดงลิสต์งานใหม่ ---
                    else
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('Product')
                            .where('status', isEqualTo: 1)
                            .snapshots(),
                        builder: (context, newJobSnapshot) {
                          if (newJobSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (newJobSnapshot.hasError) {
                            return Center(
                              child: Text(
                                'เกิดข้อผิดพลาด: ${newJobSnapshot.error}',
                              ),
                            );
                          }
                          if (!newJobSnapshot.hasData ||
                              newJobSnapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'ยังไม่มีออเดอร์ใหม่',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final products = newJobSnapshot.data!.docs;

                          return ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final productDoc = products[index];
                              final data =
                                  productDoc.data() as Map<String, dynamic>;

                              // (ข้อ 4.1.2) ส่งข้อมูลเพิ่ม
                              return _buildOrderCard(
                                orderId: productDoc.id,
                                firstItem:
                                    data['itemName'] ?? 'ไม่มีชื่อสินค้า',
                                secondItem: data['itemDescription'] ?? '',
                                itemImageUrl:
                                    data['imageUrl'] ?? '', // รูปสินค้า
                                pickupAddress: data['senderAddress'] ?? 'N/A',
                                destinationAddress:
                                    data['receiverAddress'] ?? 'N/A',
                                senderName: data['senderName'] ?? 'N/A',
                                senderPhone: data['senderPhone'] ?? '',
                                receiverName:
                                    data['receiverName'] ?? 'N/A', // ชื่อผู้รับ
                                // (ข้อ 4.1.3) ส่ง Lat/Lng
                                pickupLat: (data['senderLat'] ?? 0.0)
                                    .toDouble(),
                                pickupLon: (data['senderLng'] ?? 0.0)
                                    .toDouble(),
                                destinationLat: (data['receiverLat'] ?? 0.0)
                                    .toDouble(),
                                destinationLon: (data['receiverLng'] ?? 0.0)
                                    .toDouble(),
                              );
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
