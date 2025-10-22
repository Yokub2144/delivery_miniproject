import 'package:delivery_miniproject/pages/user/trackingRider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

import 'package:delivery_miniproject/pages/loginUserPage.dart';
import 'package:delivery_miniproject/pages/user/addProductPage.dart';
import 'package:delivery_miniproject/pages/user/profilePage.dart';
import 'package:delivery_miniproject/pages/user/rceiveProductPage.dart';
import 'package:delivery_miniproject/pages/statusPage.dart'; // <-- 1. Import StatusPage and UserRole

class SendProductPage extends StatefulWidget {
  const SendProductPage({super.key});

  @override
  State<SendProductPage> createState() => _SendProductPageState();
}

class _SendProductPageState extends State<SendProductPage> {
  final int _currentIndex = 1; // เริ่มที่ส่งสินค้า
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
        Get.to(const Profilepage());
        break;
      case 'logout':
        Get.offAll(
          () => const LoginUserPage(),
        ); // ใช้ offAll เพื่อเคลียร์หน้าก่อนหน้า
        break;
    }
  }

  Map<String, dynamic> _getStatusInfo(int status) {
    switch (status) {
      case 1:
        return {'text': 'รอไรเดอร์มารับ', 'color': Colors.deepOrange};
      case 2:
        return {'text': 'กำลังไปรับของ', 'color': Colors.blue};
      case 3:
        return {'text': 'กำลังนำส่ง', 'color': Colors.purple};
      case 4:
        return {'text': 'ส่งสำเร็จ', 'color': Colors.green};
      default:
        return {'text': 'ไม่ทราบสถานะ', 'color': Colors.grey};
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
          'ส่งสินค้า',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- vvv CHANGED: Added Row for Title and Button vvv ---
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
                    Get.to(() => Trackingrider());
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
            // --- ^^^ CHANGED ^^^ ---
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Product')
                  .where('senderPhone', isEqualTo: phone)
                  .orderBy('sendDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  // Print the detailed error to the console for debugging
                  print("Firestore Stream Error: ${snapshot.error}");
                  print("Stack trace: ${snapshot.stackTrace}");
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
                            'ยังไม่มีรายการส่งสินค้า',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          Text(
                            'กดปุ่ม + เพื่อเพิ่มรายการใหม่',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final products = snapshot.data!.docs;

                // --- CHANGED: Use Column + map instead of ListView.separated ---
                return Column(
                  children: products.map((productDoc) {
                    final data = productDoc.data() as Map<String, dynamic>;
                    final statusInfo = _getStatusInfo(data['status'] ?? 0);
                    final timestamp = data['sendDate'] as Timestamp?;
                    final dateString = timestamp != null
                        ? _formatDate(timestamp)
                        : 'ไม่มีข้อมูลวันที่';

                    // Add some spacing between cards manually
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildProductCard(
                        productId: productDoc.id,
                        productName: data['itemName'] ?? 'ไม่มีชื่อสินค้า',
                        receiverName: data['receiverName'] ?? 'N/A',
                        deliveryDate: dateString,
                        address: data['receiverAddress'] ?? 'N/A',
                        status: statusInfo['text'],
                        statusColor: statusInfo['color'],
                      ),
                    );
                  }).toList(),
                );
                // --- END CHANGE ---
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (phone != null) {
            Get.to(() => Addproductpage(senderPhoneNumber: phone!));
          }
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
            Get.off(
              () => const ReceiveProductPage(),
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

  Widget _buildProductCard({
    required String productId,
    required String productName,
    required String receiverName,
    required String deliveryDate,
    required String address,
    required String status,
    required Color statusColor,
  }) {
    // --- REMOVED: margin from Container ---
    return Container(
      // margin: const EdgeInsets.only(bottom: 16.0), // Removed margin
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.archive_outlined,
                color: Colors.orange,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                // This Expanded is correctly placed inside a Row
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
                  text: 'ผู้รับ: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: receiverName),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Get.to(
                  () => StatusPage(
                    productId: productId,
                    userRole: UserRole.sender, // Sender role for this page
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
        ],
      ),
    );
  }
}
