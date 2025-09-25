import 'package:flutter/material.dart';

class RiderMainPage extends StatefulWidget {
  const RiderMainPage({super.key});

  @override
  State<RiderMainPage> createState() => _RiderMainPageState();
}

class _RiderMainPageState extends State<RiderMainPage> {
  // A helper widget for the order card to make the code cleaner and reusable.
  Widget _buildOrderCard({
    required String firstItem,
    required String secondItem,
    required String pickupAddress,
    required String destinationAddress,
    required String driverName,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E6FA), // Light lavender color
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top section with items and driver profile
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text(
                          'สินค้าที่ต้องจัดส่ง',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.unarchive, color: Colors.brown),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      firstItem,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      secondItem,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Driver profile on the right
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD4AF37), // Gold color
                          width: 2,
                        ),
                      ),
                      child: const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey,
                        backgroundImage: NetworkImage(
                          'https://placehold.co/100x100/A9A9A9/FFFFFF?text=A',
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driverName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Divider line
          Container(height: 1.0, color: Colors.black26),
          const SizedBox(height: 16),
          // Pickup address section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Color(0xFF9370DB)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ที่อยู่รับสินค้า',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(pickupAddress),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Destination address section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ที่อยู่ปลายทาง',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(destinationAddress),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 'Accept Order' button
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Handle button press
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A5ACD),
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: const Text(
                  'รับออเดอร์',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          padding: const EdgeInsets.only(top: 30.0, left: 16.0, right: 16.0),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  SizedBox(width: 8),
                  Text(
                    'ไรเดอร์',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: const [
                  Icon(Icons.wifi, color: Colors.black),
                  SizedBox(width: 8),
                  Icon(Icons.battery_full, color: Colors.black),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User profile section
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE6E6FA),
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4AF37),
                        width: 4,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 35,
                      backgroundImage: NetworkImage(
                        'https://placehold.co/100x100/A9A9A9/FFFFFF?text=A',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'คุณสมชาย',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'โคบ 1234',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // "รายการออเดอร์" heading
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'รายการออเดอร์',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            // Order cards
            _buildOrderCard(
              firstItem: 'Iphone 13',
              secondItem: 'โน้ตบุ๊คเกมมิ่ง',
              pickupAddress:
                  '456 หมู่12 ต.บ้านดินดำ อ.กันทริชัย จ.มหาสารคาม 44150',
              destinationAddress:
                  '67/8 หมู่8 ต.ขามเรียง อ.กันทริชัย จ.มหาสารคาม 44150',
              driverName: 'คุณลภิพงศ์ ส่งดี',
            ),
            _buildOrderCard(
              firstItem: 'Ps5 slim',
              secondItem: 'โน้ตบุ๊คเกมมิ่ง',
              pickupAddress:
                  '123 หมู่12 ต.ท่าขอนยาง อ.กันทริชัย จ.มหาสารคาม 44150',
              destinationAddress:
                  '21/22 หมู่12 ต.ขามเรียง อ.กันทริชัย จ.มหาสารคาม 44150',
              driverName: 'Aof',
            ),
          ],
        ),
      ),
    );
  }
}
