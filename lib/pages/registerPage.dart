import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker picker = ImagePicker();
  XFile? pickedImage;
  File? savedFile;
  Image? image;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

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

  Future<String?> uploadImageToFirebase(XFile image, String phone) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        "images/$phone/${DateTime.now().millisecondsSinceEpoch}.jpg",
      );
      await storageRef.putFile(File(image.path));
      String downloadURL = await storageRef.getDownloadURL();
      log("✅ Upload success: $downloadURL");
      return downloadURL;
    } catch (e) {
      log("Upload error: $e");
      return null;
    }
  }

  Future<void> _pickImage(BuildContext context) async {
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
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  setState(() {
                    pickedImage = image;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูปด้วยกล้อง'),
              onTap: () async {
                Navigator.pop(ctx);
                image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  log(image!.path.toString());
                  setState(() {});
                } else {
                  log('No Image');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildForm({required bool isUser}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          InkWell(
            onTap: () => _pickImage(context),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: CircleAvatar(
                radius: 70,
                backgroundColor: Colors.white,
                backgroundImage: pickedImage != null
                    ? FileImage(File(pickedImage!.path))
                    : null,
                child: pickedImage == null
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
          _buildTextField(Icons.home, "ที่อยู่", controller: addressController),
          const SizedBox(height: 15),
          Text("คุณมีบัญชีแล้ว?", style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 10),
          SizedBox(
            width: 360,
            child: ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    phoneController.text.isEmpty ||
                    passwordController.text.isEmpty ||
                    addressController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("กรุณากรอกข้อมูลให้ครบ")),
                  );
                  return;
                }

                String? imageUrl;
                String phone = phoneController.text;

                if (pickedImage != null) {
                  imageUrl = await uploadImageToFirebase(pickedImage!, phone);
                }

                var data = {
                  'name': nameController.text,
                  'phone': phone,
                  'password': passwordController.text,
                  'address': addressController.text,
                  'imageUrl': imageUrl ?? "",
                  'createdAt': FieldValue.serverTimestamp(),
                };

                var db = FirebaseFirestore.instance;
                try {
                  if (isUser) {
                    await db.collection('User').doc(phone).set(data);
                  } else {
                    await db.collection('Rider').doc(phone).set(data);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("สมัครสมาชิกสำเร็จ")),
                  );
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
