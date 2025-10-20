import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddAddressPage extends StatefulWidget {
  final String userPhoneNumber;

  const AddAddressPage({super.key, required this.userPhoneNumber});

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  final String longdoMapApiKey = 'ba51dc98b3fd0dd3bb1ab2224a3e36d1';

  late final WebViewController _webViewController;
  final TextEditingController _searchController = TextEditingController();

  String _selectedAddress = 'ยังไม่ได้เลือกตำแหน่งบนแผนที่';
  double? _latitude;
  double? _longitude;
  bool _isSaving = false;
  bool _isPageFinished =
      false; // เพิ่ม flag เพื่อติดตามว่าหน้าเว็บโหลดเสร็จหรือยัง

  @override
  void initState() {
    super.initState();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      // --- จุดแก้ไข: เพิ่ม "ตัวดักฟัง" เพื่อดีบักการทำงานของ WebView ---
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Log นี้จะแสดงความคืบหน้าในการโหลดหน้าเว็บ
            debugPrint('[WebView] กำลังโหลด... (progress : $progress%)');
          },
          onPageFinished: (String url) {
            // Log นี้จะบอกเราว่าหน้าเว็บโหลดเสร็จสมบูรณ์แล้ว
            debugPrint('[WebView] โหลดหน้าเว็บเสร็จแล้ว: $url');
            setState(() {
              _isPageFinished = true;
            });
          },
          onWebResourceError: (WebResourceError error) {
            // Log นี้สำคัญมาก! มันจะบอกเราว่ามี Error ในการโหลดทรัพยากรหรือไม่ (เช่น script ของแผนที่)
            debugPrint('''
[WebView] เกิดข้อผิดพลาดในการโหลดทรัพยากร:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          ''');
          },
        ),
      )
      ..addJavaScriptChannel(
        'LongdoMapChannel',
        onMessageReceived: (JavaScriptMessage message) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final data = jsonDecode(message.message);
              setState(() {
                _selectedAddress = data['address'] ?? 'ไม่สามารถระบุที่อยู่ได้';
                _latitude = data['lat'];
                _longitude = data['lon'];
                _searchController.text = _selectedAddress;
              });
            }
          });
        },
      )
      ..loadHtmlString(_buildMapHtml());
  }

  String _buildMapHtml() {
    // โค้ด HTML/JS ที่แก้ไขแล้ว (เปลี่ยนไปใช้ mousedown event)
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="initial-scale=1.0, user-scalable=no" />
        <style type="text/css">
          html { height: 100% }
          body { height: 100%; margin: 0; padding: 0 }
          #map { height: 100% }
        </style>
        <script src="https://api.longdo.com/map/?key=$longdoMapApiKey"></script>
        <script>
          let map;
          let marker;

          function init() {
            try {
              map = new longdo.Map({
                placeholder: document.getElementById('map'),
                language: 'th'
              });
              map.location({ lon: 100.5018, lat: 13.7563 }, true);
              map.zoom(12, true);

              marker = new longdo.Marker(
                  { lon: 100.5018, lat: 13.7563 },
                  { visible: false } 
              );
              map.Overlays.add(marker);

              // --- ⭐️⭐️ จุดแก้ไขที่ 1 (ครั้งใหม่) ⭐️⭐️ ---
              // ลบ map.Event.bind('click', ...) ตัวเก่าทิ้ง
              // แล้วเปลี่ยนมาใช้ 'mousedown' ซึ่งจะให้พิกัดที่แน่นอน
              map.Event.bind('mousedown', function(mouseEvent) {
                try {
                  // ตรวจสอบว่ามีพิกัดส่งมาหรือไม่
                  if (mouseEvent && mouseEvent.lonlat) {
                    
                    // ตรวจสอบว่าเราคลิกบนหมุด (overlay) หรือไม่
                    map.Overlays.get(mouseEvent, function(overlay) {
                      // ถ้าไม่ได้คลิกบนหมุด (overlay) ให้ปักหมุดใหม่
                      if (!overlay) {
                        updateMarkerAndSendData(mouseEvent.lonlat.lon, mouseEvent.lonlat.lat);
                      }
                      // ถ้าคลิกบนหมุด (overlay) ก็ไม่ต้องทำอะไร
                    });
                  }
                } catch (e) {
                    console.error('Map mousedown error:', e);
                }
              });
              // --- จบจุดแก้ไข ---

            } catch (e) {
              console.error('Error during map initialization:', e);
            }
          }

          function updateMarkerAndSendData(lon, lat) {
              try {
                // --- ⭐️⭐️ จุดแก้ไขที่ 2 (เพิ่มความรัดกุม) ⭐️⭐️ ---
                // เพิ่มการตรวจสอบ isNaN (Not a Number)
                if (typeof lon !== 'number' || typeof lat !== 'number' || isNaN(lon) || isNaN(lat)) {
                  console.error('updateMarkerAndSendData received invalid or NaN lon/lat:', lon, lat);
                  return;
                }
                // --- จบจุดแก้ไข ---

                const location = { lon: lon, lat: lat };
                marker.location(location);
                marker.visible = true;
                map.location(location, true); // ย้ายแผนที่ไปที่หมุด

                map.Search.address(location, function(results) {
                    let addressText = 'ไม่พบที่อยู่';
                    if (results && results.length > 0) {
                      const r = results[0];
                      addressText = [r.subdistrict, r.district, r.province, r.postcode].filter(Boolean).join(' ');
                    }
                    
                    const data = {
                        lon: lon,
                        lat: lat,
                        address: addressText,
                    };
                    LongdoMapChannel.postMessage(JSON.stringify(data));
                });

              } catch (error) {
                console.error('updateMarkerAndSendData Error:', error);
              }
          }

          function searchAddress(keyword) {
            try {
              map.Search.search(keyword, {
                  area: map.location()
              }, function(results) {
                  if (results.data && results.data.length > 0) {
                    const firstResult = results.data[0];
                    updateMarkerAndSendData(firstResult.lon, firstResult.lat);
                  } else {
                    alert('ไม่พบสถานที่ที่ค้นหา');
                  }
              });
            } catch (error) {
              console.error('searchAddress Error:', error);
            }
          }
        </script>
      </head>
      <body onload="init();">
        <div id="map"></div>
      </body>
      </html>
    ''';
  }

  void _searchOnMap() {
    // อนุญาตให้ค้นหาได้ต่อเมื่อหน้าเว็บโหลดเสร็จแล้วเท่านั้น
    if (_searchController.text.isNotEmpty && _isPageFinished) {
      _webViewController.runJavaScript(
        'searchAddress("${_searchController.text}")',
      );
    } else {
      debugPrint('[App] การค้นหาถูกบล็อก เพราะ WebView ยังไม่พร้อม');
    }
  }

  Future<void> _saveAddressToFirebase() async {
    if (_latitude == null || _longitude == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final String userPhoneNumber = widget.userPhoneNumber;

      final addressData = {
        'address': _selectedAddress,
        'location': GeoPoint(_latitude!, _longitude!),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('User')
          .doc(userPhoneNumber)
          .collection('addresses')
          .add(addressData);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกที่อยู่สำเร็จ!')));

      if (mounted) {
        Navigator.pop(context, addressData);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
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
            child: TextField(
              controller: _searchController,
              onSubmitted: (value) => _searchOnMap(),
              decoration: InputDecoration(
                hintText: 'ค้นหาจากชื่อสถานที่หรือที่อยู่...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchOnMap,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _webViewController),
                // แสดง Indicator ขณะที่หน้าเว็บยังโหลดไม่เสร็จ
                if (!_isPageFinished)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          _buildAddressDetailsPanel(),
        ],
      ),
    );
  }

  Widget _buildAddressDetailsPanel() {
    return Card(
      margin: const EdgeInsets.all(0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ตำแหน่งที่เลือก',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedAddress,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            if (_latitude != null && _longitude != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'พิกัด: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: (_latitude != null && !_isSaving)
                  ? _saveAddressToFirebase
                  : null,
              icon: const Icon(Icons.save),
              label: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.0,
                      ),
                    )
                  : const Text('บันทึกที่อยู่'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
