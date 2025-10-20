import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_miniproject/pages/user/addAddressPage.dart';
import 'package:delivery_miniproject/pages/user/sendProductPage.dart';
import 'package:flutter/material.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:get/route_manager.dart';
import 'package:get_storage/get_storage.dart';

class Profilepage extends StatefulWidget {
  const Profilepage({super.key});

  @override
  State<Profilepage> createState() => _ProfilepageState();
}

class _ProfilepageState extends State<Profilepage> {
  int _currentIndex = 0;
  GetStorage box = GetStorage();
  String? phone;
  var userData;
  @override
  void initState() {
    super.initState();
    phone = box.read('phone');
    fetchUserProfile(phone!);
  }

  void fetchUserProfile(String phone) async {
    final db = FirebaseFirestore.instance;
    try {
      QuerySnapshot snapshot = await db
          .collection('User')
          .where('phone', isEqualTo: phone)
          .get();
      if (snapshot.docs.isNotEmpty) {
        userData = snapshot.docs.first.data() as Map<String, dynamic>;
        print("user data: $userData");
        setState(() {});
      }
    } catch (e) {
      print("Error fetching user profile: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'โปรไฟล์',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple[400],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        // 1. ย้าย Padding ออกจาก SingleChildScrollView มาไว้ที่ลูกแทน
        // padding: const EdgeInsets.all(24.0), <-- ย้ายไปข้างใน

        // 2. หุ้มทุกอย่างด้วย Column
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // จัดทุกส่วนให้ชิดซ้าย
          children: [
            // --- ส่วนที่ 1: ข้อมูลโปรไฟล์ (โค้ดเดิมของคุณ) ---
            Padding(
              padding: const EdgeInsets.all(
                24.0,
              ), // 3. เอา Padding มาใส่ให้ Row นี้
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 3,
                          blurRadius: 7,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.network(
                        userData?['imageUrl'] ??
                            'https://www.pngall.com/wp-content/uploads/5/Profile-PNG-High-Quality-Image.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.person,
                              size: 80,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ชื่อผู้ใช้: ${userData?['name'] ?? 'ไม่ระบุชื่อ'}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'เบอร์โทรศัพท์: ${phone ?? 'ไม่มีข้อมูล'}',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'ที่อยู่: ${userData?['address'] ?? 'ไม่มีข้อมูล'}',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            print('แก้ไขโปรไฟล์');
                          },
                          icon: Icon(Icons.edit),
                          label: Text('แก้ไขโปรไฟล์'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.blueAccent,
                            padding: EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(thickness: 1, height: 16, indent: 24, endIndent: 24),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 5.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ที่อยู่การจัดส่ง',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ButtonTheme(
                          child: TextButton(
                            onPressed: () {
                              Get.to(
                                () => AddAddressPage(userPhoneNumber: phone!),
                              );
                              print('แก้ไขที่อยู่การจัดส่ง');
                            },
                            child: Text('เพิ่มที่อยู่'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24), // เพิ่มที่ว่างด้านล่างสุด
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 1) {
            Get.to(SendProductPage());
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
}
