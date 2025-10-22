import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_miniproject/pages/user/addAddressPage.dart'; // <-- เพิ่ม Import AddressModel
import 'package:delivery_miniproject/pages/user/rceiveProductPage.dart';
import 'package:delivery_miniproject/pages/user/sendProductPage.dart';
import 'package:flutter/material.dart';
// import 'package:get/get_connect/http/src/utils/utils.dart'; // ไม่ได้ใช้ ลบออกได้
import 'package:get/route_manager.dart';
import 'package:get_storage/get_storage.dart';

class Profilepage extends StatefulWidget {
  const Profilepage({super.key});

  @override
  State<Profilepage> createState() => _ProfilepageState();
}

class _ProfilepageState extends State<Profilepage> {
  final int _currentIndex =
      0; // Index ของ BottomNavigationBar (อาจจะต้องปรับตามต้องการ)
  GetStorage box = GetStorage();
  String? phone;
  Map<String, dynamic>? userData; // เปลี่ยนเป็น nullable
  // --- NEW: State variables for default address ---
  AddressModel? _defaultAddress;
  bool _isLoadingAddress = true; // เริ่มต้นให้โหลดก่อน

  @override
  void initState() {
    super.initState();
    phone = box.read('phone');
    if (phone != null) {
      fetchUserProfileAndAddress(phone!);
    } else {
      // Handle case where phone number is not found in storage
      setState(() {
        _isLoadingAddress = false; // Stop loading if phone is null
      });
      print("Error: Phone number not found in GetStorage.");
    }
  }

  // --- CHANGED: Renamed function and added address fetching logic ---
  Future<void> fetchUserProfileAndAddress(String phone) async {
    final db = FirebaseFirestore.instance;
    setState(() {
      _isLoadingAddress = true; // Start loading
      userData = null;
      _defaultAddress = null;
    });

    try {
      // 1. Fetch User Data
      DocumentSnapshot userDoc = await db
          .collection('User')
          .doc(phone)
          .get(); // Use doc() directly if phone is the ID

      if (userDoc.exists && userDoc.data() != null) {
        userData = userDoc.data() as Map<String, dynamic>;
        print("User data: $userData");

        // 2. Fetch Default Address using defaultAddressId from userData
        final defaultAddressId = userData?['defaultAddressId'] as String?;
        if (defaultAddressId != null && defaultAddressId.isNotEmpty) {
          final addressDoc = await db
              .collection('User')
              .doc(phone)
              .collection('addresses')
              .doc(defaultAddressId)
              .get();

          if (addressDoc.exists && addressDoc.data() != null) {
            _defaultAddress = AddressModel.fromMap(addressDoc.data()!);
            print("Default address: ${_defaultAddress?.toMap()}");
          } else {
            print(
              "Default address document (ID: $defaultAddressId) not found.",
            );
          }
        } else {
          print("defaultAddressId not found or empty in user data.");
        }
      } else {
        print("User document not found for phone: $phone");
      }
    } catch (e) {
      print("Error fetching user profile or address: $e");
    } finally {
      // Update UI after fetching (whether successful or not)
      if (mounted) {
        setState(() {
          _isLoadingAddress = false; // Stop loading
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // --- CHANGED: Added back button (optional but recommended) ---
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        // automaticallyImplyLeading: false, // Commented out to allow back button
        centerTitle: true,
        title: const Text(
          'โปรไฟล์',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple[400],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Profile Info Section ---
            Padding(
              padding: const EdgeInsets.all(24.0),
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
                          // Use ?? to provide default value if userData is null
                          'ชื่อผู้ใช้: ${userData?['name'] ?? 'กำลังโหลด...'}',
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
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            print('แก้ไขโปรไฟล์');
                            // Navigate to Edit Profile Page here
                          },
                          icon: Icon(Icons.edit),
                          label: Text('แก้ไขโปรไฟล์'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.blueAccent,
                            padding: EdgeInsets.symmetric(
                              horizontal: 40, // Reduced padding
                              vertical: 12, // Reduced padding
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

            // --- Address Section ---
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 15.0, // Increased vertical padding
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // --- CHANGED: Updated Card content ---
                  Card(
                    elevation: 2, // Added slight elevation
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      // Added padding inside card
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.home_work_outlined, // Changed icon
                                color: Colors.deepPurple,
                                size: 30, // Adjusted size
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'ที่อยู่ที่ใช้อยู่', // Changed title
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(), // Divider inside card
                          const SizedBox(height: 12),
                          // Display loading, address, or 'not set' message
                          _isLoadingAddress
                              ? const Center(child: CircularProgressIndicator())
                              : _defaultAddress != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _defaultAddress!.label.isNotEmpty
                                          ? _defaultAddress!.label
                                          : "ไม่มีป้ายกำกับ", // Handle empty label
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _defaultAddress!.address,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'ยังไม่ได้ตั้งค่าที่อยู่เริ่มต้น',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                          const SizedBox(height: 16),
                          Center(
                            child: SizedBox(
                              width: double.infinity, // Make button wider
                              child: ElevatedButton.icon(
                                // Changed to ElevatedButton.icon
                                icon: const Icon(Icons.map_outlined, size: 18),
                                label: const Text(
                                  'จัดการที่อยู่',
                                  style: TextStyle(color: Colors.white),
                                ),
                                onPressed: () {
                                  if (phone != null) {
                                    Get.to(
                                      () => AddAddressPage(
                                        userPhoneNumber: phone!,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ), // Added padding
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex:
            _currentIndex, // Use _currentIndex for profile page (adjust if needed)
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 1) {
            // Navigate to SendProductPage using GetX for consistency
            Get.off(
              () => const SendProductPage(),
              transition: Transition.noTransition,
            );
          } else if (index == 0) {
            Get.off(
              () => const ReceiveProductPage(),
              transition: Transition.noTransition,
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.download,
            ), // Consider changing icon for profile e.g., Icons.person
            label:
                'รับสินค้า', // Consider changing label to 'โปรไฟล์' if this is the profile tab
          ),
          BottomNavigationBarItem(icon: Icon(Icons.upload), label: 'ส่งสินค้า'),
        ],
      ),
    );
  }
}
