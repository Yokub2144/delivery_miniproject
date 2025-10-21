import 'dart:convert';
import 'dart:async';
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
  final map = GlobalKey<LongdoMapState>();

  List<AddressModel> addresses = [];
  Map<String, AddressModel> markerIdToAddress = {};
  Map<String, dynamic> addressIdToMarkerObject = {};

  // --- vvv นี่คือตัวแปรสำหรับ "เลือก" ที่อยู่ vvv ---
  AddressModel? _selectedAddress;
  // --- ^^^ นี่คือตัวแปรสำหรับ "เลือก" ที่อยู่ ^^^ ---

  bool isLoading = false;
  bool isMapReady = false;

  final TextEditingController addressSearchController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController labelController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  List<dynamic> searchSuggestions = [];
  bool showSuggestions = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    addressSearchController.addListener(_onSearchChanged);
    searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    addressSearchController.removeListener(_onSearchChanged);
    searchFocusNode.removeListener(_onFocusChanged);
    addressSearchController.dispose();
    addressController.dispose();
    labelController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!searchFocusNode.hasFocus && mounted) {
      // ซ่อนคำแนะนำเมื่อออกจาก focus (หลังจาก delay เล็กน้อย)
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            showSuggestions = false;
          });
        }
      });
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (addressSearchController.text.isEmpty) {
      if (mounted) {
        setState(() {
          searchSuggestions = [];
          showSuggestions = false;
        });
      }
      map.currentState?.call("Search.clear");
      return;
    }

    // Debounce เพื่อไม่ให้เรียก API บ่อยเกินไป
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (isMapReady && addressSearchController.text.length >= 2) {
        _getSuggestions(addressSearchController.text);
      }
    });
  }

  Future<void> _getSuggestions(String keyword) async {
    if (!isMapReady) return;

    try {
      if (kDebugMode) {
        print('🔍 Getting suggestions for: "$keyword"');
      }

      // ใช้วิธีง่ายๆ - เรียก Search.suggest แล้วใช้ event 'suggest' ที่มีอยู่แล้ว
      await map.currentState?.call("Search.suggest", args: [keyword]);

      if (kDebugMode) {
        print('📥 Suggest API called');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting suggestions: $e');
      }
    }
  }

  void _handleSuggestResult(dynamic message) {
    try {
      if (kDebugMode) {
        print('📨 Suggest result received');
        print('Raw message: ${message.message}');
      }

      final jsonObj = json.decode(message.message);
      final data = jsonObj['data'];

      if (kDebugMode) {
        print('Parsed data type: ${data.runtimeType}');
        print('Data content: $data');
      }

      if (data != null && data is List) {
        if (kDebugMode) {
          print('✅ Suggestions count: ${data.length}');
        }

        if (mounted) {
          setState(() {
            searchSuggestions = data;
            showSuggestions = data.isNotEmpty && searchFocusNode.hasFocus;
          });
        }
      } else {
        if (kDebugMode) {
          print('⚠️ No suggestions data or wrong format');
        }
        if (mounted) {
          setState(() {
            searchSuggestions = [];
            showSuggestions = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling suggest result: $e');
      }
    }
  }

  void _selectSuggestion(dynamic suggestion) {
    try {
      final String? name = suggestion['w'];
      final double? lat = suggestion['lat']?.toDouble();
      final double? lon = suggestion['lon']?.toDouble();

      if (kDebugMode) {
        print('Selected: $name at ($lat, $lon)');
      }

      if (name != null) {
        addressSearchController.text = name;
      }

      // ซ่อนรายการแนะนำและยกเลิก focus
      if (mounted) {
        setState(() {
          showSuggestions = false;
          searchSuggestions = [];
        });
      }
      searchFocusNode.unfocus();

      // เลื่อนแผนที่ไปยังตำแหน่งที่เลือก
      if (lat != null && lon != null && isMapReady) {
        map.currentState?.call(
          "location",
          args: [
            {'lon': lon, 'lat': lat},
            true,
          ],
        );

        Future.delayed(const Duration(milliseconds: 400), () {
          map.currentState?.call("zoom", args: [16, true]);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error selecting suggestion: $e');
      }
    }
  }

  void _handleSearchResult(dynamic message) {
    try {
      if (kDebugMode) {
        print('📨 Search result received');
        print('Raw message: ${message.message}');
      }

      final jsonObj = json.decode(message.message);
      final data = jsonObj['data'];

      if (data != null && data is List && data.isNotEmpty) {
        if (kDebugMode) {
          print('✅ Search results count: ${data.length}');
        }

        final firstResult = data[0];
        final double? lat = firstResult['lat']?.toDouble();
        final double? lon = firstResult['lon']?.toDouble();

        if (lat != null && lon != null && isMapReady) {
          map.currentState?.call(
            "location",
            args: [
              {'lon': lon, 'lat': lat},
              true,
            ],
          );

          Future.delayed(const Duration(milliseconds: 400), () {
            map.currentState?.call("zoom", args: [16, true]);
          });
        }
      } else {
        if (kDebugMode) {
          print('⚠️ No search results');
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('ไม่พบผลการค้นหา')));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling search result: $e');
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }

    if (status.isGranted) {
      if (kDebugMode) {
        print('Location Permission Granted. Moving map...');
      }
      await Future.delayed(const Duration(milliseconds: 600));
      map.currentState?.call(
        "location",
        args: [Longdo.LongdoStatic("LocationMode", "Geolocation"), true],
      );
      await Future.delayed(const Duration(milliseconds: 600));
      await map.currentState?.call("zoom", args: [15, true]);
    } else {
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

  // --- vvv นี่คือฟังก์ชัน loadAddresses ที่แก้ไขแล้ว vvv ---
  Future<void> loadAddresses() async {
    try {
      if (!mounted) return;
      setState(() => isLoading = true);

      String? defaultId;

      // 1. อ่านข้อมูล User หลักก่อน เพื่อหาว่า defaultAddressId คืออะไร
      final userDoc = await _firestore
          .collection('User')
          .doc(widget.userPhoneNumber)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        // ดึงค่า defaultAddressId (อาจจะเป็น null ถ้ายังไม่เคยตั้ง)
        defaultId = userData['defaultAddressId'] as String?;
      }

      // 2. อ่านที่อยู่ทั้งหมดจาก sub-collection (เหมือนเดิม)
      final collection = await _firestore
          .collection('User')
          .doc(widget.userPhoneNumber)
          .collection('addresses')
          .get();

      final loadedAddresses = collection.docs
          .map((doc) => AddressModel.fromMap(doc.data()))
          .toList();

      AddressModel? defaultAddress;
      if (defaultId != null) {
        try {
          // 3. ค้นหาที่อยู่เริ่มต้นจากในลิสต์ที่โหลดมา
          defaultAddress = loadedAddresses.firstWhere(
            (address) => address.id == defaultId,
          );
        } catch (e) {
          // เกิดกรณีที่ defaultId มี แต่ที่อยู่ถูกลบไปแล้ว
          if (kDebugMode) {
            print('Default address ID $defaultId not found in sub-collection.');
          }
          defaultAddress = null;
        }
      }

      if (mounted) {
        setState(() {
          addresses = loadedAddresses;
          // 4. ตั้งค่า _selectedAddress เป็นที่อยู่เริ่มต้นที่เจอ
          _selectedAddress = defaultAddress;
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
  // --- ^^^ นี่คือฟังก์ชัน loadAddresses ที่แก้ไขแล้ว ^^^ ---

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

        final markerIdRaw = marker["\$id"];
        if (markerIdRaw != null) {
          final markerIdString = markerIdRaw.toString();
          markerIdToAddress[markerIdString] = address;
          addressIdToMarkerObject[address.id] = marker;
        }
      }

      if (kDebugMode) {
        print('--- addMarkersToMap complete ---');
        print('Total markers: ${addressIdToMarkerObject.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding markers: $e');
      }
    }
  }

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
          // --- vvv เมื่อเพิ่มที่อยู่ใหม่ ให้เลือกที่อยู่นั้นทันที vvv ---
          _selectedAddress = newAddress;
          // --- ^^^ เมื่อเพิ่มที่อยู่ใหม่ ให้เลือกที่อยู่นั้นทันที ^^^ ---
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

    // ซ่อนคำแนะนำ
    if (mounted) {
      setState(() {
        showSuggestions = false;
      });
    }
    searchFocusNode.unfocus();

    try {
      if (isMapReady) {
        if (kDebugMode) {
          print('🔍 Searching for: "${addressSearchController.text}"');
        }

        // ใช้ executeScript เพื่อเรียก JavaScript โดยตรง
        final script =
            '''
          (function() {
            var search = new longdo.Search();
            
            search.search('${addressSearchController.text}', function(data) {
              if (data && data.data) {
                SearchResult.postMessage(JSON.stringify({data: data.data}));
              }
            });
          })();
        ''';

        await map.currentState?.call("executeScript", args: [script]);

        if (kDebugMode) {
          print('📥 Search script executed');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Search error: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
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
          // --- vvv ถ้าลบที่อยู่ที่กำลังเลือก ให้ยกเลิกการเลือก vvv ---
          if (_selectedAddress?.id == addressId) {
            _selectedAddress = null;
          }
          // --- ^^^ ถ้าลบที่อยู่ที่กำลังเลือก ให้ยกเลิกการเลือก ^^^ ---
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
                    focusNode: searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'ค้นหาที่อยู่...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: addressSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                addressSearchController.clear();
                                map.currentState?.call("Search.clear");
                                setState(() {
                                  searchSuggestions = [];
                                  showSuggestions = false;
                                });
                              },
                            )
                          : null,
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
            child: Stack(
              children: [
                LongdoMapWidget(
                  apiKey: "ba51dc98b3fd0dd3bb1ab2224a3e36d1",
                  key: map,
                  eventName: [
                    IJavascriptChannel(
                      name: "ready",
                      onMessageReceived: (message) {
                        if (kDebugMode) {
                          print('🗺️ Map is ready');
                        }
                        if (mounted) {
                          setState(() {
                            isMapReady = true;
                          });
                        }
                        // --- vvv เรียก loadAddresses ที่แก้ไขแล้ว vvv ---
                        loadAddresses();
                        // --- ^^^ เรียก loadAddresses ที่แก้ไขแล้ว ^^^ ---
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
                    // Channel สำหรับรับผลการ suggest
                    IJavascriptChannel(
                      name: "SuggestResult",
                      onMessageReceived: (message) {
                        if (kDebugMode) {
                          print('🎯 SuggestResult received!');
                        }
                        _handleSuggestResult(message);
                      },
                    ),
                    // Channel สำหรับรับผลการ search
                    IJavascriptChannel(
                      name: "SearchResult",
                      onMessageReceived: (message) {
                        if (kDebugMode) {
                          print('🎯 SearchResult received!');
                        }
                        _handleSearchResult(message);
                      },
                    ),
                  ],
                ),
                // แสดงรายการคำแนะนำ
                if (showSuggestions && searchSuggestions.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 12,
                    right: 12,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: searchSuggestions.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (context, index) {
                            final suggestion = searchSuggestions[index];
                            final String name = suggestion['w'] ?? '';
                            final String? detail = suggestion['d'];

                            return InkWell(
                              onTap: () => _selectSuggestion(suggestion),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.deepPurple[400],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (detail != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              detail,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
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
                // --- vvv นี่คือ ListView.builder ที่แก้ไขแล้ว vvv ---
                : ListView.builder(
                    itemCount: addresses.length,
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      // ตรวจสอบว่ารายการนี้ถูกเลือกหรือไม่
                      final isSelected =
                          _selectedAddress != null &&
                          _selectedAddress!.id == address.id;

                      return InkWell(
                        onTap: () async {
                          // 1. ตั้งค่าที่อยู่ท่ีเลือก
                          setState(() {
                            _selectedAddress = address;
                          });

                          if (!isMapReady) return;

                          final markerObject =
                              addressIdToMarkerObject[address.id];
                          if (markerObject == null) return;

                          try {
                            // 2. ย้ายแผนที่และแสดง popup (เหมือนเดิม)
                            await map.currentState?.call("Popup.hide");
                            await map.currentState?.call(
                              "location",
                              args: [
                                {
                                  'lon': address.longitude,
                                  'lat': address.latitude,
                                },
                                true,
                              ],
                            );
                            await Future.delayed(
                              const Duration(milliseconds: 600),
                            );
                            await map.currentState?.call(
                              "zoom",
                              args: [15, true],
                            );
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
                              print('Error: $e');
                            }
                          }
                        },
                        child: Card(
                          // 3. เปลี่ยนสีพื้นหลังถ้าถูกเลือก
                          color: isSelected ? Colors.deepPurple[100] : null,
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
                            // 4. เพิ่มไอคอนติ๊กถูกถ้าถูกเลือก
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: Colors.deepPurple[400],
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
            // --- ^^^ นี่คือ ListView.builder ที่แก้ไขแล้ว ^^^ ---
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
                // --- vvv นี่คือปุ่ม "เสร็จสิ้น" ที่แก้ไขแล้ว vvv ---
                onPressed: () async {
                  if (_selectedAddress != null) {
                    try {
                      // 1. อัปเดต 'defaultAddressId' ในเอกสาร User
                      await _firestore
                          .collection('User')
                          .doc(widget.userPhoneNumber)
                          .update({'defaultAddressId': _selectedAddress!.id});

                      if (mounted) {
                        // 2. Pop กลับไปหน้าเดิมพร้อมส่ง AddressModel ที่เลือก
                        Navigator.pop(context, _selectedAddress);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('เกิดข้อผิดพลาดในการบันทึก: $e'),
                          ),
                        );
                      }
                    }
                  } else {
                    // ถ้ายังไม่เลือก ให้แจ้งเตือน
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('กรุณาเลือกหรือเพิ่มที่อยู่ก่อน'),
                      ),
                    );
                  }
                },
                // --- ^^^ นี่คือปุ่ม "เสร็จสิ้น" ที่แก้ไขแล้ว ^^^ ---
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
