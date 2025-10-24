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

  // --- [CHANGED] ลดพารามิเตอร์ลง เหลือแค่ orderId ---
  Future<void> _acceptOrder({required String orderId}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseFirestore.instance
          .collection('Product')
          .doc(orderId)
          .update({'status': 2, 'riderId': widget.riderId});

      if (mounted) Navigator.pop(context);

      if (mounted) {
        // --- [CHANGED] ส่งแค่ orderId และ riderId ---
        Get.to(
          () => PickupDetailPage(orderId: orderId, riderId: widget.riderId),
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

  // --- [CHANGED] การ์ดงานใหม่ - ลดพารามิเตอร์ ---
  Widget _buildOrderCard({
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
              const SizedBox(width: 16),
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('User')
                    .where('phone', isEqualTo: customerPhone)
                    .limit(1)
                    .get(),
                builder: (context, userSnapshot) {
                  String imageUrl = '';
                  if (userSnapshot.hasData &&
                      userSnapshot.data!.docs.isNotEmpty) {
                    final userData =
                        userSnapshot.data!.docs.first.data()
                            as Map<String, dynamic>;
                    imageUrl = userData['imageUrl'] ?? '';
                  }

                  return Container(
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
                              (imageUrl.isNotEmpty &&
                                  imageUrl.startsWith('http'))
                              ? NetworkImage(imageUrl)
                              : null,
                          child:
                              (imageUrl.isEmpty || !imageUrl.startsWith('http'))
                              ? Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Colors.grey.shade600,
                                )
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
                  );
                },
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
              child: ElevatedButton(
                onPressed: () {
                  // --- [CHANGED] ส่งแค่ orderId ---
                  _acceptOrder(orderId: orderId);
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

  // --- [CHANGED] การ์ดงานที่รับแล้ว - ลดพารามิเตอร์ ---
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

          // --- [CHANGED] ปุ่มไปที่แผนที่ - ส่งแค่ orderId และ riderId ---
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

          // ปุ่มดูสถานะ
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
                        builder: (context) => const LoadingPage(),
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

            // งานที่กำลังทำ
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'งานที่กำลังทำ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Product')
                  .where('riderId', isEqualTo: widget.riderId)
                  .where('status', whereIn: [2, 3])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Text(
                        'ยังไม่มีงานที่รับ',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                final products = snapshot.data!.docs;

                return ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final productDoc = products[index];
                    final data = productDoc.data() as Map<String, dynamic>;

                    // --- [CHANGED] ลดพารามิเตอร์ ---
                    return _buildAcceptedOrderCard(
                      orderId: productDoc.id,
                      firstItem: data['itemName'] ?? 'ไม่มีชื่อสินค้า',
                      secondItem: data['itemDescription'] ?? '',
                      pickupAddress: data['senderAddress'] ?? 'N/A',
                      destinationAddress: data['receiverAddress'] ?? 'N/A',
                      customerName: data['senderName'] ?? 'N/A',
                      customerPhone: data['senderPhone'] ?? '',
                    );
                  },
                );
              },
            ),

            // ออเดอร์ใหม่
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'รายการออเดอร์ใหม่',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Product')
                  .where('status', isEqualTo: 1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final products = snapshot.data!.docs;

                return ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final productDoc = products[index];
                    final data = productDoc.data() as Map<String, dynamic>;

                    // --- [CHANGED] ลดพารามิเตอร์ ---
                    return _buildOrderCard(
                      orderId: productDoc.id,
                      firstItem: data['itemName'] ?? 'ไม่มีชื่อสินค้า',
                      secondItem: data['itemDescription'] ?? '',
                      pickupAddress: data['senderAddress'] ?? 'N/A',
                      destinationAddress: data['receiverAddress'] ?? 'N/A',
                      customerName: data['senderName'] ?? 'N/A',
                      customerPhone: data['senderPhone'] ?? '',
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
