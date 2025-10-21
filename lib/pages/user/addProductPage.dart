import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:longdo_maps_api3_flutter/longdo_maps_api3_flutter.dart';
import 'package:flutter/foundation.dart';

// --- Use the same AddressModel for consistency ---
class AddressModel {
  String id;
  String address;
  double latitude;
  double longitude;
  String label;

  AddressModel({
    required this.id,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.label = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'label': label,
    };
  }

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id'] ?? '',
      address: map['address'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      label: map['label'] ?? '',
    );
  }
}

class Addproductpage extends StatefulWidget {
  final String senderPhoneNumber;
  const Addproductpage({super.key, required this.senderPhoneNumber});

  @override
  State<Addproductpage> createState() => _AddproductpageState();
}

class _AddproductpageState extends State<Addproductpage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // --- Controllers for TextFields ---
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  // --- ADDED: Controllers for product info ---
  final _productNameController = TextEditingController();
  final _productDetailsController = TextEditingController();

  // --- State Variables ---
  bool _isSearching = false; // สำหรับตอนค้นหา
  bool _isSaving = false; // สำหรับตอนบันทึก
  String? _searchError;
  AddressModel? _receiverAddress;
  String _receiverName = '';
  String _receiverId = '';

  // --- Map Variables ---
  final _mapController = GlobalKey<LongdoMapState>();
  bool _isMapReady = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    // --- ADDED: Dispose new controllers ---
    _productNameController.dispose();
    _productDetailsController.dispose();
    super.dispose();
  }

  /// Search for a receiver by phone number and fetch their default address
  Future<void> _searchReceiver() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _searchError = null;
      _receiverAddress = null;
      _receiverName = '';
      _receiverId = '';
      _addressController.clear();
    });

    try {
      final userDoc = await _firestore
          .collection('User')
          .doc(phoneNumber)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _receiverName = userData['name'] ?? 'ไม่พบชื่อ';
        _receiverId = userDoc.id; // Store receiver's ID

        final defaultAddressId = userData['defaultAddressId'] as String?;

        if (defaultAddressId != null && defaultAddressId.isNotEmpty) {
          final addressDoc = await userDoc.reference
              .collection('addresses')
              .doc(defaultAddressId)
              .get();

          if (addressDoc.exists) {
            final address = AddressModel.fromMap(addressDoc.data()!);
            setState(() {
              _receiverAddress = address;
              _addressController.text = '${address.label}\n${address.address}';
            });
            _updateMapLocation();
          } else {
            setState(() => _searchError = 'ไม่พบที่อยู่เริ่มต้น');
          }
        } else {
          setState(
            () => _searchError = 'ผู้ใช้ยังไม่ได้ตั้งค่าที่อยู่เริ่มต้น',
          );
        }
      } else {
        setState(() => _searchError = 'ไม่พบผู้ใช้จากเบอร์โทรนี้');
      }
    } catch (e) {
      setState(() => _searchError = 'เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  /// Update the map's location and marker when an address is found
  Future<void> _updateMapLocation() async {
    if (_isMapReady && _receiverAddress != null) {
      await _mapController.currentState?.call("Overlays.clear");

      // Set map location
      await _mapController.currentState?.call(
        "location",
        args: [
          {
            'lon': _receiverAddress!.longitude,
            'lat': _receiverAddress!.latitude,
          },
          true,
        ],
      );

      // Add a short delay to ensure the map has moved before zooming
      await Future.delayed(const Duration(milliseconds: 500));

      // Set zoom level
      await _mapController.currentState?.call("zoom", args: [16, true]);

      // Add marker
      var marker = Longdo.LongdoObject(
        "Marker",
        args: [
          {
            'lon': _receiverAddress!.longitude,
            'lat': _receiverAddress!.latitude,
          },
          {
            'title': _receiverAddress!.label.isNotEmpty
                ? _receiverAddress!.label
                : 'ที่อยู่ผู้รับ',
            'detail': _receiverAddress!.address,
          },
        ],
      );
      await _mapController.currentState?.call("Overlays.add", args: [marker]);
    }
  }

  /// Save the new shipment to the 'Product' collection in Firebase
  Future<void> _saveShipment() async {
    // --- ADDED: Validate the form first ---
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_receiverAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาค้นหาและเลือกผู้รับก่อน')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Fetch sender's data
      final senderDoc = await _firestore
          .collection('User')
          .doc(widget.senderPhoneNumber)
          .get();
      if (!senderDoc.exists) {
        throw Exception('ไม่พบข้อมูลผู้ส่ง');
      }
      final senderData = senderDoc.data() as Map<String, dynamic>;

      // 1.1 Fetch sender's default address
      final senderDefaultAddressId = senderData['defaultAddressId'] as String?;
      if (senderDefaultAddressId == null || senderDefaultAddressId.isEmpty) {
        throw Exception('ผู้ส่งยังไม่ได้ตั้งค่าที่อยู่เริ่มต้น');
      }
      final senderAddressDoc = await senderDoc.reference
          .collection('addresses')
          .doc(senderDefaultAddressId)
          .get();
      if (!senderAddressDoc.exists) {
        throw Exception('ไม่พบที่อยู่เริ่มต้นของผู้ส่ง');
      }
      final senderAddress = AddressModel.fromMap(senderAddressDoc.data()!);

      // 2. Prepare the data to be saved
      final productData = {
        'receiverName': _receiverName,
        'receiverPhone': _phoneController.text.trim(),
        'receiverAddress': _receiverAddress!.address,
        'receiverLat': _receiverAddress!.latitude,
        'receiverLng': _receiverAddress!.longitude,

        'senderName': senderData['name'] ?? 'N/A',
        'senderPhone': widget.senderPhoneNumber,
        'senderAddress': senderAddress.address,
        'senderLat': senderAddress.latitude,
        'senderLng': senderAddress.longitude,

        // --- ADDED: Save product info ---
        'itemName': _productNameController.text.trim(),
        'itemDescription': _productDetailsController.text.trim(),

        // --- CHANGED: Renamed to createdAt for consistency ---
        'sendDate': FieldValue.serverTimestamp(),

        'status': 1,
      };

      // --- vvv ADDED: Diagnostic logging ---
      debugPrint("--- Preparing to save data ---");
      debugPrint("Data being sent to Firebase: $productData");
      // --- ^^^ ADDED: Diagnostic logging ^^^ ---

      // 3. Save to the 'Product' collection
      await _firestore.collection('Product').add(productData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เพิ่มรายการส่งสินค้าสำเร็จ!')),
      );

      // Go back to the previous page after successful save
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เพิ่มรายการส่งสินค้า'),
        backgroundColor: Colors.deepPurple[400],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'ค้นหาจากเบอร์โทร',
                    hintText: 'กรอกเบอร์โทรผู้รับ',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchReceiver,
                    ),
                  ),
                  onFieldSubmitted: (_) => _searchReceiver(),
                ),
                const SizedBox(height: 8),

                if (_isSearching)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),

                if (_searchError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _searchError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                if (_receiverAddress != null) _buildReceiverInfo(),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (_receiverAddress == null || _isSaving)
                      ? null
                      : _saveShipment,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.deepPurple[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('เพิ่ม', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiverInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'ผู้รับ: $_receiverName',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _addressController,
          readOnly: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'ที่อยู่',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Color(0xFFEFE6FF),
          ),
        ),
        const SizedBox(height: 16),
        // --- ADDED: Product Info TextFields ---
        TextFormField(
          controller: _productNameController,
          decoration: const InputDecoration(labelText: 'ชื่อสินค้า'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'กรุณากรอกชื่อสินค้า';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _productDetailsController,
          decoration: const InputDecoration(labelText: 'รายละเอียดสินค้า'),
        ),
        const SizedBox(height: 16),
        const Text(
          'พิกัดผู้รับ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LongdoMapWidget(
              apiKey: "ba51dc98b3fd0dd3bb1ab2224a3e36d1",
              key: _mapController,
              eventName: [
                IJavascriptChannel(
                  name: "ready",
                  onMessageReceived: (message) {
                    if (kDebugMode) print('🗺️ Map is ready for product page');
                    setState(() => _isMapReady = true);
                    _updateMapLocation();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
