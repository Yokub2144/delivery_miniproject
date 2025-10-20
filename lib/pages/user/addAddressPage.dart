import 'dart:convert';
import 'package:longdo_maps_api3_flutter/longdo_maps_api3_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

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

class AddAddressPage extends StatefulWidget {
  final String userPhoneNumber;
  const AddAddressPage({super.key, required this.userPhoneNumber});

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Use a GlobalKey to interact with the LongdoMapWidget state
  final map = GlobalKey<LongdoMapState>();

  List<AddressModel> addresses = [];
  // This map links the JavaScript marker ID to our AddressModel for easy lookup
  Map<String, AddressModel> markerIdToAddress = {};
  // This map links our AddressModel ID to the JavaScript marker object
  Map<String, dynamic> addressIdToMarkerObject = {};

  bool isLoading = false;
  bool isMapReady = false;

  final TextEditingController addressSearchController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController labelController = TextEditingController();

  List<dynamic> searchSuggestions = [];
  bool showSuggestions = false;
  @override
  void initState() {
    super.initState();
    addressSearchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    addressSearchController.removeListener(_onSearchChanged);
    addressSearchController.dispose();
    addressController.dispose();
    labelController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (addressSearchController.text.isEmpty) {
      if (mounted) {
        setState(() {
          searchSuggestions = [];
          showSuggestions = false;
        });
      }
      // ใช้คำสั่ง Search.clear จากรูป
      map.currentState?.call("Search.clear");
      return;
    }

    // ค้นหาเมื่อพร้อม และพิมพ์อย่างน้อย 2 ตัวอักษร
    if (isMapReady && addressSearchController.text.length > 2) {
      _getSuggestions(addressSearchController.text);
    }
  }

  Future<void> _getSuggestions(String keyword) async {
    try {
      await map.currentState?.call("Search.suggest", args: [keyword]);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting suggestions: $e');
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      // ขออนุญาต
      status = await Permission.location.request();
    }

    if (status.isGranted) {
      // ถ้าได้รับอนุญาตแล้ว สั่งให้แผนที่ไปที่ตำแหน่งปัจจุบัน
      if (kDebugMode) {
        print('Location Permission Granted. Moving map...');
      }
      map.currentState?.call(
        "location",
        args: [Longdo.LongdoStatic("LocationMode", "Geolocation"), true],
      );
    } else {
      // ถ้าไม่อนุญาต (isDenied, isPermanentlyDenied)
      if (kDebugMode) {
        print('Location Permission Denied.');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('คุณไม่ได้อนุญาตให้เข้าถึงตำแหน่ง')),
        );
      }
    }
  }

  Future<void> loadAddresses() async {
    try {
      if (!mounted) return;
      setState(() => isLoading = true);
      final collection = await _firestore
          .collection('User')
          .doc(widget.userPhoneNumber)
          .collection('addresses')
          .get();

      final loadedAddresses = collection.docs
          .map((doc) => AddressModel.fromMap(doc.data()))
          .toList();

      if (mounted) {
        setState(() {
          addresses = loadedAddresses;
        });
      }

      if (isMapReady) {
        addMarkersToMap();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดที่อยู่: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> addMarkersToMap() async {
    try {
      await map.currentState?.call("Overlays.clear");
      markerIdToAddress.clear();
      addressIdToMarkerObject.clear();

      for (var address in addresses) {
        var marker = Longdo.LongdoObject(
          "Marker",
          args: [
            {'lon': address.longitude, 'lat': address.latitude},
            {
              'title': address.label.isNotEmpty ? address.label : 'ที่อยู่',
              'detail': address.address,
            },
          ],
        );
        await map.currentState?.call("Overlays.add", args: [marker]);

        // Store the link between the generated JS marker ID and our data model
        final markerIdRaw = marker["\$id"];
        if (markerIdRaw != null) {
          final markerIdString = markerIdRaw.toString();
          markerIdToAddress[markerIdString] = address;
          // Store the marker object itself for later reference
          addressIdToMarkerObject[address.id] = marker;
        } else {
          // ถ้ายัง null อยู่ ให้แสดง Error ใน console
          if (kDebugMode) {
            print('!!! Error: Marker ID is NULL for address ${address.id}');
          }
        }
        if (kDebugMode) {
          print('--- addMarkersToMap complete ---');
          print('Total addresses: ${addresses.length}');
          print('Total markers in map: ${addressIdToMarkerObject.length}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding markers: $e');
      }
    }
  }

  // Using `dynamic` for the message parameter to bypass the 'Undefined class' error,
  // which might be related to the project's specific environment or dependencies.
  void _handleMapClick(dynamic message) {
    final jsonObj = json.decode(message.message);
    final data = jsonObj['data'];
    if (data == null) return;

    final double lat = data['lat']?.toDouble() ?? 0.0;
    final double lon = data['lon']?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เพิ่มที่อยู่'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'พิกัด: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อที่อยู่ (เช่น บ้าน, ที่ทำงาน)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ที่อยู่โดยละเอียด',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              addressController.clear();
              labelController.clear();
              Navigator.pop(context);
            },
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () async {
              if (addressController.text.isNotEmpty) {
                await addAddress(
                  lat,
                  lon,
                  addressController.text,
                  labelController.text,
                );
                addressController.clear();
                labelController.clear();
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('กรุณากรอกที่อยู่')),
                );
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  void _handleOverlayClick(dynamic message) {
    final jsonObj = json.decode(message.message);
    final clickedMarkerObject = jsonObj['data'];
    if (clickedMarkerObject == null) return;

    final markerIdRaw = clickedMarkerObject['\$id'];
    if (markerIdRaw == null) return;
    final markerIdString = markerIdRaw.toString();
    final addressToDelete = markerIdToAddress[markerIdString];
    if (addressToDelete == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
          'คุณต้องการลบที่อยู่ "${addressToDelete.label.isNotEmpty ? addressToDelete.label : 'ที่อยู่'}" หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              map.currentState?.call(
                "Overlays.remove",
                args: [clickedMarkerObject],
              );
              deleteAddress(addressToDelete.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
  }

  Future<void> addAddress(
    double latitude,
    double longitude,
    String address,
    String label,
  ) async {
    try {
      final newAddress = AddressModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        address: address,
        latitude: latitude,
        longitude: longitude,
        label: label,
      );

      await _firestore
          .collection('User')
          .doc(widget.userPhoneNumber)
          .collection('addresses')
          .doc(newAddress.id)
          .set(newAddress.toMap());

      if (mounted) {
        setState(() {
          addresses.add(newAddress);
        });
      }

      if (isMapReady) {
        var marker = Longdo.LongdoObject(
          "Marker",
          args: [
            {'lon': longitude, 'lat': latitude},
            {'title': label.isNotEmpty ? label : 'ที่อยู่', 'detail': address},
          ],
        );
        map.currentState?.call("Overlays.add", args: [marker]);
        final markerIdRaw = marker["\$id"];
        if (markerIdRaw != null) {
          final markerIdString = markerIdRaw.toString();
          markerIdToAddress[markerIdString] = newAddress;
          addressIdToMarkerObject[newAddress.id] = marker;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('บันทึกที่อยู่สำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการเพิ่มที่อยู่: $e')),
        );
      }
    }
  }

  Future<void> searchAddress() async {
    if (addressSearchController.text.isEmpty) return;
    try {
      if (isMapReady) {
        map.currentState?.call(
          "Search.search",
          args: [addressSearchController.text],
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ค้นหาไม่พบ: $e')));
      }
    }
  }

  Future<void> deleteAddress(String addressId) async {
    try {
      await _firestore
          .collection('User')
          .doc(widget.userPhoneNumber)
          .collection('addresses')
          .doc(addressId)
          .delete();

      markerIdToAddress.removeWhere((key, value) => value.id == addressId);
      addressIdToMarkerObject.remove(addressId);
      if (mounted) {
        setState(() {
          addresses.removeWhere((address) => address.id == addressId);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบที่อยู่สำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'เพิ่มที่อยู่',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple[400],
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: addressSearchController,
                    decoration: InputDecoration(
                      hintText: 'ค้นหาที่อยู่...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (value) => searchAddress(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: searchAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple[400],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: LongdoMapWidget(
              apiKey:
                  "ba51dc98b3fd0dd3bb1ab2224a3e36d1", // ใส่ API Key ของคุณที่นี่
              key: map,
              eventName: [
                IJavascriptChannel(
                  name: "ready",
                  onMessageReceived: (message) {
                    setState(() {
                      isMapReady = true;
                    });
                    loadAddresses();
                    // Set initial location to user's current location
                    _requestLocationPermission();
                  },
                ),
                IJavascriptChannel(
                  name: "click",
                  onMessageReceived: _handleMapClick,
                ),
                IJavascriptChannel(
                  name: "overlayClick",
                  onMessageReceived: _handleOverlayClick,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.deepPurple[50],
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.deepPurple),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'จิ้มบนแผนที่เพื่อเพิ่มที่อยู่ หรือแตะหมุดเพื่อลบ',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : addresses.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('ยังไม่มีที่อยู่ที่บันทึก'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: addresses.length,
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      return InkWell(
                        onTap: () async {
                          if (!isMapReady) {
                            if (kDebugMode) {
                              print('แผนที่ยังไม่พร้อม');
                            }
                            return;
                          }

                          final markerObject =
                              addressIdToMarkerObject[address.id];

                          if (markerObject == null) {
                            if (kDebugMode) {
                              print(
                                'Error: ไม่พบ marker object สำหรับ ${address.id}',
                              );
                            }
                            return;
                          }

                          try {
                            // 1. ปิด Popup ทั้งหมดก่อน
                            await map.currentState?.call("Popup.hide");

                            // 2. เลื่อนแผนที่ไปยังตำแหน่ง (ใช้ LdMap หรือ location)
                            await map.currentState?.call(
                              "location",
                              args: [
                                {
                                  'lon': address.longitude,
                                  'lat': address.latitude,
                                },
                                true, // animate
                              ],
                            );

                            // 3. รอให้เลื่อนเสร็จก่อนซูม
                            await Future.delayed(
                              const Duration(milliseconds: 600),
                            );

                            // 4. ซูม
                            await map.currentState?.call(
                              "zoom",
                              args: [15, true],
                            ); // เพิ่มระดับซูม

                            // 5. รอให้ซูมเสร็จก่อนเปิด popup
                            await Future.delayed(
                              const Duration(milliseconds: 400),
                            );

                            if (mounted) {
                              map.currentState?.objectCall(
                                markerObject,
                                "popup",
                              );
                            }
                          } catch (e) {
                            if (kDebugMode) {
                              print('Error เลื่อนแผนที่: $e');
                            }
                          }
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple[400],
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              address.label.isNotEmpty
                                  ? address.label
                                  : 'ที่อยู่ ${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              address.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple[400],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context, addresses);
                },
                child: const Text(
                  'เสร็จสิ้น',
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
}
