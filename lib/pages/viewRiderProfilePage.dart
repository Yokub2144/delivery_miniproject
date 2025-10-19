import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_miniproject/pages/editRiderProfilePage.dart'; // Import หน้าแก้ไข

class ViewRiderProfilePage extends StatefulWidget {
  final String riderId;
  const ViewRiderProfilePage({super.key, required this.riderId});

  @override
  State<ViewRiderProfilePage> createState() => _ViewRiderProfilePageState();
}

class _ViewRiderProfilePageState extends State<ViewRiderProfilePage> {
  late final Stream<DocumentSnapshot> _riderStream;

  @override
  void initState() {
    super.initState();
    // 1. ตั้งค่า Stream ให้ดึงข้อมูลมาแสดง (เหมือนใน RiderMainPage)
    _riderStream = FirebaseFirestore.instance
        .collection('Rider')
        .doc(widget.riderId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('โปรไฟล์ของฉัน'),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          // 2. นี่คือปุ่ม "แก้ไข"
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              // 3. เมื่อกดปุ่มนี้ ให้ไปยังหน้า "แก้ไข"
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditRiderProfilePage(
                    riderId: widget.riderId, // ส่ง ID ไปยังหน้าแก้ไข
                  ),
                ),
              );
            },
          ),
        ],
      ),
      // 4. ใช้ StreamBuilder เพื่อแสดงข้อมูลแบบ Real-time
      body: StreamBuilder<DocumentSnapshot>(
        stream: _riderStream,
        builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('มีข้อผิดพลาด'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('ไม่พบข้อมูล'));
          }

          // ดึงข้อมูล
          Map<String, dynamic> data =
              snapshot.data!.data() as Map<String, dynamic>;
          String riderName = data['name'] ?? 'ไม่มีชื่อ';
          String carReg = data['carRegistration'] ?? 'ไม่มีทะเบียน';
          String address = data['address'] ?? 'ไม่มีที่อยู่';
          String phone = data['phone'] ?? widget.riderId;
          String profileImageUrl =
              data['imageUrl'] ?? 'https://placehold.co/100x100';

          // 5. แสดงผลข้อมูลแบบ "อ่านอย่างเดียว"
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 24),
                CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(profileImageUrl),
                ),
                SizedBox(height: 12),
                Text(
                  riderName,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 24),
                Divider(),
                ListTile(
                  leading: Icon(Icons.phone),
                  title: Text('เบอร์โทรศัพท์'),
                  subtitle: Text(phone),
                ),
                ListTile(
                  leading: Icon(Icons.home),
                  title: Text('ที่อยู่'),
                  subtitle: Text(address),
                ),
                ListTile(
                  leading: Icon(Icons.motorcycle),
                  title: Text('ทะเบียนรถ'),
                  subtitle: Text(carReg),
                ),
                Divider(),
              ],
            ),
          );
        },
      ),
    );
  }
}
