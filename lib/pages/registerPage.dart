import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget buildForm({required bool isUser}) {
    return Column(
      children: [
        SizedBox(height: 20),
        InkWell(
          onTap: () async {
            final image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              log(image!.path.toString());
            } else {
              log('No Image');
            }
          },
          child: Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2), // ขอบสีดำ
            ),
            child: CircleAvatar(
              radius: 70,
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              child: Icon(Icons.camera_alt, color: Colors.grey[700]),
            ),
          ),
        ),

        SizedBox(height: 20),

        SizedBox(
          width: 360,
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.person),
              hintText: "ชื่อ",
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(height: 15),
        SizedBox(
          width: 360,
          child: TextField(
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.phone),
              hintText: "เบอร์โทรศัพท์",
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        SizedBox(height: 15),
        SizedBox(
          width: 360,
          child: TextField(
            obscureText: true,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.lock),
              hintText: "รหัสผ่าน",
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        SizedBox(height: 15),
        SizedBox(
          width: 360,
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.home),
              hintText: "ที่อยู่",
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        SizedBox(height: 15),
        Text("คุณมีบัญชีแล้ว?", style: TextStyle(color: Colors.grey[600])),
        SizedBox(height: 10),
        SizedBox(
          width: 360,
          child: ElevatedButton(
            onPressed: () {},
            child: Text("สมัครสมาชิก"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFAEB9F4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
        SizedBox(height: 0),
      ],
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
              child: Container(
                width: double.infinity,
                height:
                    MediaQuery.of(context).size.height *
                    0.35, // ปรับให้สูงพอดีกับหน้าจอ
                child: Image.asset(
                  "assets/images/Group48.png",
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover, // ใช้ cover ให้เต็มพื้นที่
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: Color(0xFF8FA2FF),
                  labelColor: Color(0xFF2A3159),
                  unselectedLabelColor: Colors.grey,
                  tabs: [
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

// สำหรับทำ TabBar ให้ sticky
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
