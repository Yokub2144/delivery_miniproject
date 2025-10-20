import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditRiderProfilePage extends StatefulWidget {
  final String riderId;
  const EditRiderProfilePage({super.key, required this.riderId});

  @override
  State<EditRiderProfilePage> createState() => _EditRiderProfilePageState();
}

class _EditRiderProfilePageState extends State<EditRiderProfilePage> {
  // สร้าง Controllers สำหรับเก็บค่าในฟอร์ม
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _carRegController = TextEditingController();

  bool _isLoading = true; // สถานะสำหรับดึงข้อมูล
  String _profileImageUrl = ''; // เก็บ URL รูปภาพ

  @override
  void initState() {
    super.initState();
    // 1. เมื่อหน้าโหลด ให้ดึงข้อมูลปัจจุบันมาแสดงในฟอร์ม
    _fetchRiderData();
  }

  Future<void> _fetchRiderData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Rider')
          .doc(widget.riderId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        // 2. นำข้อมูลที่ได้มากรอกลงใน Controllers
        _nameController.text = data['name'] ?? '';
        _addressController.text = data['address'] ?? '';
        _carRegController.text = data['carRegistration'] ?? '';
        _profileImageUrl =
            data['imageUrl'] ?? 'https://placehold.co/100x100'; // เก็บ URL รูป

        setState(() {
          _isLoading = false; // ดึงข้อมูลเสร็จแล้ว
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการดึงข้อมูล: $e')),
      );
    }
  }

  // 3. ฟังก์ชันสำหรับบันทึกข้อมูล
  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 4. อัปเดตเฉพาะ field ที่เราต้องการ
      await FirebaseFirestore.instance
          .collection('Rider')
          .doc(widget.riderId)
          .update({
            'name': _nameController.text,
            'address': _addressController.text,
            'carRegistration': _carRegController.text,
            // (หมายเหตุ: การแก้ไขรูปภาพต้องใช้ Firebase Storage ซึ่งซับซ้อนกว่านี้)
          });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('อัปเดตโปรไฟล์สำเร็จ')));
      Navigator.pop(context); // กลับไปหน้า RiderMainPage
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  @override
  void dispose() {
    // 5. อย่าลืม dispose controllers
    _nameController.dispose();
    _addressController.dispose();
    _carRegController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('แก้ไขโปรไฟล์'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            ) // แสดง loading ขณะดึงข้อมูล
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // --- ส่วนแสดงรูปโปรไฟล์ (ยังแก้ไขไม่ได้) ---
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(_profileImageUrl),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: เพิ่ม Logic การเปลี่ยนรูปภาพ
                      // นี่คือจุดที่คุณต้องใช้ image_picker และ firebase_storage
                      // ซึ่งเป็นขั้นตอนที่ซับซ้อนครับ
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'ฟังก์ชันเปลี่ยนรูปภาพยังไม่พร้อมใช้งาน',
                          ),
                        ),
                      );
                    },
                    child: Text('เปลี่ยนรูปโปรไฟล์'),
                  ),
                  const SizedBox(height: 24),

                  // --- ฟอร์มแก้ไขข้อมูล ---
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'ชื่อ',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'ที่อยู่',
                      prefixIcon: Icon(Icons.home),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _carRegController,
                    decoration: InputDecoration(
                      labelText: 'ทะเบียนรถ',
                      prefixIcon: Icon(Icons.motorcycle),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- ปุ่มบันทึก ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _updateProfile, // เรียกฟังก์ชันบันทึก
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A5ACD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'บันทึกการเปลี่ยนแปลง',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
