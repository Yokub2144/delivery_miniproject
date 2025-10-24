import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_miniproject/pages/user/addAddressPage.dart';
import 'package:path/path.dart' as p;
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:delivery_miniproject/pages/loginRiderPage.dart';
import 'package:delivery_miniproject/pages/loginUserPage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: SignUpPage(), debugShowCheckedModeBanner: false);
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker picker = ImagePicker();
  final cloudinary = CloudinaryPublic(
    'dzicj4dci',
    'flutter_unsigned',
    cache: false,
  );
  XFile? image;
  File? savedFile;
  File? imgProfile;
  File? imgCar;
  String? imgProfileUrl;
  String? imgCarUrl;
  String? _selectedAddress;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController carRegController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(
    BuildContext context, {
    required bool isProfile,
  }) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากแกลเลอรี'),
              onTap: () async {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.gallery, isProfile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูปด้วยกล้อง'),
              onTap: () async {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.camera, isProfile);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source, bool isProfile) async {
    // --- ส่วนเลือกรูป (เหมือนโค้ดเดิมของคุณ) ---
    final XFile? image = await picker.pickImage(source: source);

    if (image == null) {
      log('ผู้ใช้ยกเลิกการเลือกรูป');
      return; // ออกจากฟังก์ชันถ้าไม่ได้เลือกรูป
    }

    final Directory tempDir = await getApplicationDocumentsDirectory();

    // 1. รับนามสกุลไฟล์ (.jpg, .png)
    final String fileExtension = p.extension(image.name);

    // 2. สร้างชื่อไฟล์ใหม่ที่ปลอดภัย (ใช้เวลาปัจจุบัน กันชื่อซ้ำ)
    final String newFileName =
        '${DateTime.now().millisecondsSinceEpoch}$fileExtension';

    // 3. สร้าง File object ด้วยชื่อใหม่
    final File file = File('${tempDir.path}/$newFileName');

    // 4. เซฟไฟล์ XFile (image) ไปยัง path ใหม่
    await image.saveTo(file.path);
    // --- ส่วนอัปโหลดไป Cloudinary (ส่วนที่เพิ่มใหม่) ---
    log('กำลังอัปโหลดรูปไป Cloudinary...');
    // (คุณอาจจะอยากแสดง Loading indicator ตรงนี้)

    try {
      final CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      // อัปโหลดสำเร็จ!
      log('อัปโหลดสำเร็จ: ${response.secureUrl}');

      // 8. เก็บ Secure URL ที่ได้มา แทนการเก็บ File
      setState(() {
        if (isProfile) {
          imgProfileUrl = response.secureUrl; // เก็บ URL
        } else {
          imgCarUrl = response.secureUrl; // เก็บ URL
        }
      });
    } catch (e) {
      log('อัปโหลดล้มเหลว: $e');
      // (ควรแสดงข้อความ Error ให้ผู้ใช้รู้)
    }

    // (ซ่อน Loading indicator)
  }

  Widget buildForm({required bool isUser}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          InkWell(
            onTap: () => _pickImage(context, isProfile: true),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: CircleAvatar(
                radius: 70,
                backgroundColor: Colors.white,
                backgroundImage: imgProfileUrl != null
                    ? NetworkImage(imgProfileUrl!) // ใช้อันนี้
                    : null,
                child:
                    imgProfileUrl ==
                        null // ใช้อันนี้
                    ? Icon(Icons.camera_alt, color: Colors.grey[700])
                    : null,
              ),
            ),
          ),

          const SizedBox(height: 20),
          _buildTextField(Icons.person, "ชื่อ", controller: nameController),
          const SizedBox(height: 15),
          _buildTextField(
            Icons.phone,
            "เบอร์โทรศัพท์",
            controller: phoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            Icons.lock,
            "รหัสผ่าน",
            controller: passwordController,
            obscure: true,
          ),

          const SizedBox(height: 15),
          if (!isUser) ...[
            SizedBox(
              width: 360,
              child: TextField(
                readOnly: true,
                onTap: () => _pickImage(context, isProfile: false),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.file_upload),
                  hintText: "กรุณาเลือกรูปรถ",
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // แสดงรูปถ้ามี
            if (imgCarUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imgCarUrl!,
                  width: 200,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 15),
            _buildTextField(
              Icons.motorcycle,
              "ทะเบียนรถ",
              controller: carRegController,
            ),
          ],
          Text("คุณมีบัญชีแล้ว?", style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 10),
          SizedBox(
            width: 360,
            child: ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    phoneController.text.isEmpty ||
                    passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("กรุณากรอกข้อมูลให้ครบ")),
                  );
                  return;
                }

                String phone = phoneController.text;

                var db = FirebaseFirestore.instance;
                try {
                  if (isUser) {
                    var data = {
                      'name': nameController.text,
                      'phone': phone,
                      'password': passwordController.text,
                      'imageUrl': imgProfileUrl ?? '',
                      'createdAt': FieldValue.serverTimestamp(),
                    };
                    await db.collection('User').doc(phone).set(data);
                  } else {
                    var data = {
                      'name': nameController.text,
                      'phone': phone,
                      'password': passwordController.text,
                      'imageUrl': imgProfileUrl ?? '',
                      'carImageUrl': imgCarUrl ?? '',
                      'imageUrl': imgProfileUrl ?? '',
                      'carRegistration': carRegController.text,

                      'createdAt': FieldValue.serverTimestamp(),
                    };
                    await db.collection('Rider').doc(phone).set(data);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("สมัครสมาชิกสำเร็จ")),
                  );
                  if (isUser) {
                    Get.to(LoginUserPage());
                  } else {
                    Get.to(LoginRiderPage());
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("เกิดข้อผิดพลาด: ${e.toString()}")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFAEB9F4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text("สมัครสมาชิก"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    IconData icon,
    String hint, {
    bool obscure = false,
    TextInputType? keyboardType,
    TextEditingController? controller,
  }) {
    return SizedBox(
      width: 360,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          hintText: hint,
          filled: true,
          fillColor: Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.35,
                child: Image.asset(
                  "assets/images/Group48.png",
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF8FA2FF),
                  labelColor: const Color(0xFF2A3159),
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: "ผู้ใช้ระบบ"),
                    Tab(text: "ไรเดอร์"),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              SingleChildScrollView(child: buildForm(isUser: true)),
              SingleChildScrollView(child: buildForm(isUser: false)),
            ],
          ),
        ),
      ),
    );
  }
}

// Sticky TabBar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
