import 'package:delivery_miniproject/pages/loadingPage.dart';
import 'package:delivery_miniproject/pages/statusPage.dart';
import 'package:delivery_miniproject/pages/user/Trackingrider_receiver.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

import 'package:delivery_miniproject/pages/loginUserPage.dart';
import 'package:delivery_miniproject/pages/user/profilePage.dart';
import 'package:delivery_miniproject/pages/user/sendProductPage.dart';

class ReceiveProductPage extends StatefulWidget {
  const ReceiveProductPage({super.key});

  @override
  State<ReceiveProductPage> createState() => _ReceiveProductPageState();
}

class _ReceiveProductPageState extends State<ReceiveProductPage> {
  final int _currentIndex = 0; // 0 = รับสินค้า, 1 = ส่งสินค้า
  final GetStorage box = GetStorage();
  String? phone;

  @override
  void initState() {
    super.initState();
    phone = box.read('phone');
  }

  void _onMenuItemSelected(BuildContext context, String value) {
    switch (value) {
      case 'profile':
        Get.to(() => const Profilepage());
        break;
      case 'logout':
        Get.offAll(() => const LoadingPage());
        break;
    }
  }

  // --- ฟังก์ชันสำหรับแปลง status และ date (เหมือนกับหน้า SendProductPage) ---
  Map<String, dynamic> _getStatusInfo(int status) {
    switch (status) {
      case 1:
        return {'text': 'รอไรเดอร์มารับ', 'color': Colors.deepOrange};
      case 2:
        return {'text': 'กำลังไปรับของ', 'color': Colors.blue};
      case 3:
        return {'text': 'กำลังนำส่ง', 'color': Colors.purple};
      case 4:
        return {'text': 'รับสำเร็จ', 'color': Colors.green};
      default:
        return {'text': 'รออัพเดตสถานะ', 'color': Colors.grey};
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'รับสินค้า',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple[400],
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (item) => _onMenuItemSelected(context, item),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'profile',
                child: Text('โปรไฟล์'),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('ออกจากระบบ'),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: Colors.white,
          ),
          const SizedBox(width: 8),
        ],
      ),
      // --- vvv CHANGED: เปลี่ยน body เป็นโครงสร้างใหม่ที่ดึงข้อมูลจาก Firebase vvv ---
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Align items
              children: [
                const Text(
                  'รายการ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: Icon(
                    Icons.map_outlined,
                    size: 18,
                    color: Colors.deepPurple,
                  ),
                  label: const Text(
                    'ติดตามไรเดอร์',
                    style: TextStyle(color: Colors.deepPurple),
                  ),
                  onPressed: () {
                    Get.to(() => Trackingrider_receiver());
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ), // Adjust padding
                    // Add border or background if desired
                    // side: BorderSide(color: Colors.deepPurple),
                    // backgroundColor: Colors.deepPurple.withOpacity(0.1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Product')
                  .where(
                    'receiverPhone',
                    isEqualTo: phone,
                  ) // ค้นหาจากเบอร์ผู้รับ
                  .orderBy('sendDate', descending: true)
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
                            Icons.local_shipping_outlined,
                            size: 60,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'ไม่มีสินค้าที่คุณต้องรับ',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final products = snapshot.data!.docs;

                return ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: products.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final productDoc = products[index];
                    final data = productDoc.data() as Map<String, dynamic>;

                    final statusInfo = _getStatusInfo(data['status'] ?? 0);
                    final timestamp = data['sendDate'] as Timestamp?;
                    final dateString = timestamp != null
                        ? _formatDate(timestamp)
                        : 'ไม่มีข้อมูลวันที่';

                    return _buildProductCard(
                      productId: productDoc.id,
                      productName: data['itemName'] ?? 'ไม่มีชื่อสินค้า',
                      senderName:
                          data['senderName'] ??
                          'N/A', // เปลี่ยนเป็นข้อมูลผู้ส่ง
                      deliveryDate: dateString,
                      address: data['receiverAddress'] ?? 'N/A',
                      status: statusInfo['text'],
                      statusColor: statusInfo['color'],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      // --- ^^^ CHANGED ^^^ ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 1) {
            Get.off(
              () => const SendProductPage(),
              transition: Transition.noTransition,
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.download),
            label: 'รับสินค้า',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.upload), label: 'ส่งสินค้า'),
        ],
      ),
    );
  }

  // --- vvv CHANGED: Widget นี้ถูกแก้ไขเล็กน้อยเพื่อแสดงข้อมูลผู้ส่ง vvv ---
  Widget _buildProductCard({
    required String productId,
    required String productName,
    required String senderName, // เปลี่ยนจาก receiverName
    required String deliveryDate,
    required String address,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.archive_outlined,
                color: Colors.orange,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 14),
              children: [
                const TextSpan(
                  text: 'ผู้ส่ง: ', // เปลี่ยนข้อความ
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: senderName), // ใช้ตัวแปร senderName
              ],
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 14),
              children: [
                const TextSpan(
                  text: 'วันที่จัดส่ง: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: deliveryDate),
              ],
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 14),
              children: [
                const TextSpan(
                  text: 'ที่อยู่: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: address),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ปุ่มติดตามพัสดุ
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Get.to(
                  () => StatusPage(
                    productId: productId,
                    userRole: UserRole.receiver,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ติดตามพัสดุ',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ปุ่มดูข้อมูลไรเดอร์
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.deepPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ดูข้อมูลไรเดอร์',
                style: TextStyle(color: Colors.deepPurple),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
