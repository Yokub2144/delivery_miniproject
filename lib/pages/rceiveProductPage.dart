import 'package:delivery_miniproject/pages/sendProductPage.dart';
import 'package:flutter/material.dart';

class ReceiveProductPage extends StatefulWidget {
  const ReceiveProductPage({super.key});

  @override
  State<ReceiveProductPage> createState() => _ReceiveProductPageState();
}

class _ReceiveProductPageState extends State<ReceiveProductPage> {
  int _currentIndex = 0; // 0 = รับสินค้า, 1 = ส่งสินค้า

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'รับสินค้า',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple[400],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'รายการ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildReceiveCard(),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 1) {
            // ไปหน้า SendProductPage
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SendProductPage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.download),
            label: 'รับสินค้า',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.upload), label: 'ส่งสินค้า'),
        ],
      ),
    );
  }

  Widget _buildReceiveCard() {
    return Column(
      children: [
        _buildProductCard(
          productName: 'Ps5 slim',
          receiverName: 'Yo Suwat',
          deliveryDate: '24/09/2025',
          address: '123 หมู่12 ต.ท่ายาง อ.กันทรวิชัย จ.มหาสารคาม 44150',
          status: 'กำลังนำส่งสินค้า',
          statusColor: Colors.purple,
          isFirst: true,
        ),
        _buildProductCard(
          productName: 'โน๊ตบุ๊คเกมมิ่ง',
          receiverName: 'กมลทิพย์ ส่งดี',
          deliveryDate: '24/09/2025',
          address: '456 หมู่12 ต.บ้านดินดำ อ.กันทรวิชัย จ.มหาสารคาม 44150',
          status: 'กำลังนำส่งสินค้า',
          statusColor: Colors.purple,
          isFirst: false,
        ),
      ],
    );
  }

  Widget _buildProductCard({
    required String productName,
    required String receiverName,
    required String deliveryDate,
    required String address,
    required String status,
    required Color statusColor,
    required bool isFirst,
  }) {
    return Container(
      margin: EdgeInsets.only(top: isFirst ? 0 : 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.archive_outlined,
                color: Colors.orange,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 14),
              children: [
                const TextSpan(
                  text: 'ผู้รับ: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: receiverName),
              ],
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 14),
              children: [
                const TextSpan(
                  text: 'วันที่จัดส่ง: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: deliveryDate),
              ],
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 14),
              children: [
                const TextSpan(
                  text: 'ที่อยู่: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: address),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ปุ่มติดตามพัสดุ
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ติดตามพัสดุ',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ปุ่มดูข้อมูลไรเดอร์
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.deepPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ดูข้อมูลไรเดอร์',
                style: TextStyle(color: Colors.deepPurple),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
