import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
        SizedBox(height: 40),
        Text(
          "ล็อกอิน",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 30),

        SizedBox(
          width: 360,
          child: TextField(
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.phone),
              hintText: "เบอร์โทรศัพท์",
              filled: true,
              fillColor: Color(0xFFE8E8E8),
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
              fillColor: Color(0xFFE8E8E8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        SizedBox(height: 30),

        SizedBox(
          width: 360,
          child: ElevatedButton(
            onPressed: () {},
            child: Text(
              "เข้าสู่ระบบ",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4B68FF), // สีฟ้าเข้มตามรูป
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),

        SizedBox(height: 15),

        SizedBox(
          width: 360,
          child: ElevatedButton(
            onPressed: () {},
            child: Text(
              "สมัครสมาชิก",
              style: TextStyle(
                color: Color.fromARGB(255, 247, 248, 250),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFAEB9F4), // สีฟ้าอ่อนตามรูป
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),

        SizedBox(height: 20),
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
