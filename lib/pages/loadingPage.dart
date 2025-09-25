import 'package:delivery_miniproject/pages/loginRiderPage.dart';
import 'package:delivery_miniproject/pages/loginUserPage.dart';
import 'package:delivery_miniproject/pages/registerPage.dart';
import 'package:flutter/material.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 600;
    final isTablet = screenWidth > 600;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB8C5FF), Color(0xFF9BB0FF), Color(0xFF8FA2FF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.08,
              vertical: screenHeight * 0.05,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Spacer(flex: isSmallScreen ? 1 : 2),

                Text(
                  "Delivery Man",
                  style: TextStyle(
                    fontSize: isTablet ? screenWidth * 0.08 : screenWidth * 0.1,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 4,
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: screenHeight * 0.05),

                Container(
                  width: isTablet ? screenWidth * 0.2 : screenWidth * 0.3,
                  height: isTablet ? screenWidth * 0.2 : screenWidth * 0.3,
                  constraints: BoxConstraints(
                    minWidth: 100,
                    minHeight: 100,
                    maxWidth: 200,
                    maxHeight: 200,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      "assets/images/Group48.png",
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF2A3159),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.delivery_dining,
                            size: isTablet ? 80 : 60,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                Spacer(flex: isSmallScreen ? 2 : 3),

                // ปุ่ม User
                Container(
                  width: isTablet ? screenWidth * 0.4 : screenWidth * 0.6,
                  constraints: BoxConstraints(minWidth: 200, maxWidth: 350),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginUserPage(),
                        ),
                      );
                    },
                    child: Text(
                      "User",
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF303F9F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.02,
                      ),
                      elevation: 5,
                    ),
                  ),
                ),

                SizedBox(height: screenHeight * 0.02),

                // ปุ่ม Rider
                Container(
                  width: isTablet ? screenWidth * 0.4 : screenWidth * 0.6,
                  constraints: BoxConstraints(minWidth: 200, maxWidth: 350),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginRiderPage(),
                        ),
                      );
                    },
                    child: Text(
                      "Rider",
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF303F9F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.02,
                      ),
                      elevation: 5,
                    ),
                  ),
                ),

                Spacer(flex: isSmallScreen ? 1 : 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
