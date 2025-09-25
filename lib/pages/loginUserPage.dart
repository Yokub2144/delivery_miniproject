import 'package:delivery_miniproject/pages/loginRiderPage.dart';
import 'package:delivery_miniproject/pages/registerPage.dart';
import 'package:flutter/material.dart';

class LoginUserPage extends StatelessWidget {
  const LoginUserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ส่วน Header
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.35,
              child: Stack(
                children: [
                  Image.asset(
                    "assets/images/Group48.png",
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 40,
                    left: 10,
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // แถบ "ผู้ใช้ระบบ" และ "ไรเดอร์"
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(
                vertical: 2 * MediaQuery.of(context).size.height * 0.01,
                horizontal: 30,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ผู้ใช้ระบบ
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginUserPage(),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          "ผู้ใช้ระบบ",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 0, 0, 0),
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          height: 2,
                          width: 100,
                          color: Colors.black, // เส้นใต้ active
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 50),

                  // ไรเดอร์
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginRiderPage(),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          "ไรเดอร์",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          height: 2,
                          width: 100,
                          color: Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 0.03 * MediaQuery.of(context).size.height),

            // ฟอร์มล็อกอิน
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  Text(
                    "ล็อกอิน ",
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 0.03 * MediaQuery.of(context).size.height),

                  // เบอร์โทรศัพท์
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.phone),
                      hintText: "เบอร์โทรศัพท์",
                      hintStyle: TextStyle(fontSize: 18),
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 0.020 * MediaQuery.of(context).size.height),

                  // รหัสผ่าน
                  TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock),
                      hintText: "รหัสผ่าน",
                      hintStyle: TextStyle(fontSize: 18),
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  SizedBox(height: 0.05 * MediaQuery.of(context).size.height),

                  // ปุ่มเข้าสู่ระบบ
                  SizedBox(
                    width: double.infinity,
                    height: 0.07 * MediaQuery.of(context).size.height,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF303F9F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {},
                      child: Text(
                        "เข้าสู่ระบบ",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 0.01 * MediaQuery.of(context).size.height),

                  // ปุ่มสมัครสมาชิก
                  SizedBox(
                    width: double.infinity,
                    height: 0.07 * MediaQuery.of(context).size.height,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF8E9DFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                RegisterPage(), // หน้าเป้าหมาย
                          ),
                        );
                      },
                      child: Text(
                        "สมัครสมาชิก",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
