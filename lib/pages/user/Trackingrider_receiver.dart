import 'dart:async';
import 'dart:convert'; // Import dart:convert for json.decode
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart'; // Assuming you use GetStorage for phone
import 'package:longdo_maps_api3_flutter/longdo_maps_api3_flutter.dart';

class RiderInfo {
  final String id;
  String name;
  String phone;
  String imageUrl;
  GeoPoint? location;

  RiderInfo({
    required this.id,
    this.name = 'Loading...',
    this.phone = 'Loading...',
    this.imageUrl = '',
    this.location,
  });
}

class Trackingrider_receiver extends StatefulWidget {
  const Trackingrider_receiver({super.key});

  @override
  State<Trackingrider_receiver> createState() => _Trackingrider_receiverState();
}

class _Trackingrider_receiverState extends State<Trackingrider_receiver> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GetStorage box = GetStorage();
  String? receiverPhone;

  final _mapController = GlobalKey<LongdoMapState>();
  bool _isMapReady = false;

  List<String> _activeRiderIds = [];
  Map<String, RiderInfo> _riderData = {};
  Map<String, dynamic> _riderMarkers = {};
  Map<String, StreamSubscription> _locationSubscriptions = {};
  RiderInfo? _selectedRider;
  bool _justClickedOverlay = false;

  // --- State variables for shipment locations ---
  List<GeoPoint> _originLocations = [];
  List<GeoPoint> _destinationLocations = [];
  List<dynamic> _locationMarkerObjects = []; // To store Longdo.LongdoObject

  @override
  void initState() {
    super.initState();
    receiverPhone = box.read('phone');
    if (receiverPhone != null) {
      _fetchActiveRiders();
    } else {
      print("Error: Sender phone number not found.");
    }
  }

  @override
  void dispose() {
    _locationSubscriptions.forEach((key, subscription) {
      subscription.cancel();
    });
    super.dispose();
  }

  Future<void> _fetchActiveRiders() async {
    if (receiverPhone == null) return;
    print("Fetching active riders...");

    try {
      QuerySnapshot shipmentSnapshot = await _firestore
          .collection('Product')
          .where('receiverPhone', isEqualTo: receiverPhone)
          .where('status', whereIn: [2, 3])
          .get();

      Set<String> riderIds = {};
      Set<GeoPoint> newOriginLocations = {};
      Set<GeoPoint> newDestinationLocations = {};

      for (var doc in shipmentSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final riderId = data?['riderId'] as String?;
        if (riderId != null && riderId.isNotEmpty) {
          riderIds.add(riderId);
        } else {
          print("Warning: Product ${doc.id} has no valid riderPhone");
        }

        final senderLocation = data?['senderLocation'] as GeoPoint?;
        final receiverLocation = data?['receiverLocation'] as GeoPoint?;

        if (senderLocation != null) {
          newOriginLocations.add(senderLocation);
        }
        if (receiverLocation != null) {
          newDestinationLocations.add(receiverLocation);
        }
      }
      print("Active Rider IDs found: ${riderIds.toList()}");
      print(
        "Found ${newOriginLocations.length} origins and ${newDestinationLocations.length} destinations.",
      );

      List<String> newRiderIds = riderIds.toList();
      List<String> currentSortedIds = List.from(_activeRiderIds)..sort();
      List<String> newSortedIds = List.from(newRiderIds)..sort();

      bool locationsChanged =
          !_areGeoPointListsEqual(
            _originLocations,
            newOriginLocations.toList(),
          ) ||
          !_areGeoPointListsEqual(
            _destinationLocations,
            newDestinationLocations.toList(),
          );

      if (locationsChanged) {
        print("Locations list changed. Updating state.");
      }

      if (!ListEquality().equals(currentSortedIds, newSortedIds) ||
          locationsChanged) {
        print(
          "Rider list changed: ${!ListEquality().equals(currentSortedIds, newSortedIds)}, Locations changed: $locationsChanged. Updating...",
        );
        setState(() {
          _activeRiderIds = newRiderIds;
          _originLocations = newOriginLocations.toList();
          _destinationLocations = newDestinationLocations.toList();
          _riderData.removeWhere(
            (key, value) => !_activeRiderIds.contains(key),
          );
          _riderMarkers.keys
              .where((key) => !_activeRiderIds.contains(key))
              .toList()
              .forEach(_removeMarker);
          _locationSubscriptions.keys
              .where((key) => !_activeRiderIds.contains(key))
              .toList()
              .forEach((id) {
                _locationSubscriptions[id]?.cancel();
                _locationSubscriptions.remove(id);
                print("Stopped listening for rider: $id");
              });
          if (_selectedRider != null &&
              !_activeRiderIds.contains(_selectedRider!.id)) {
            _selectedRider = null;
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _listenToRiderLocations();
            _fetchInitialRiderData();
            if (_isMapReady) _updateLocationMarkers();
          }
        });
      } else {
        print("Rider list and locations haven't changed.");
        _listenToRiderLocations();
        _fetchInitialRiderData();
        if (_isMapReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateAllMarkers();
              _updateLocationMarkers();
            }
          });
        }
      }
    } catch (e) {
      print("Error fetching active shipments/riders: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการดึงข้อมูลไรเดอร์: $e')),
        );
      }
    }
  }

  Future<void> _fetchInitialRiderData() async {
    bool dataUpdated = false;

    for (String riderId in _activeRiderIds) {
      if (!_riderData.containsKey(riderId) ||
          _riderData[riderId]?.name == 'Loading...') {
        print("Fetching initial data for rider: $riderId");
        try {
          DocumentSnapshot riderDoc = await _firestore
              .collection('Rider')
              .doc(riderId)
              .get();
          if (riderDoc.exists) {
            final data = riderDoc.data() as Map<String, dynamic>;
            print(
              "Fetched data for $riderId: ${data['name']}, Image URL: ${data['imageUrl']}",
            );
            if (mounted) {
              GeoPoint? currentLocation = _riderData[riderId]?.location;
              String imageUrl = data['imageUrl'] ?? '';
              if (imageUrl.startsWith('"') && imageUrl.endsWith('"')) {
                imageUrl = imageUrl.substring(1, imageUrl.length - 1);
                print("Cleaned Image URL for $riderId: $imageUrl");
              }

              _riderData[riderId] = RiderInfo(
                id: riderId,
                name: data['name'] ?? 'ไม่พบชื่อ',
                phone: data['phone'] ?? riderId,
                imageUrl: imageUrl,
                location: currentLocation,
              );
              dataUpdated = true;
            }
          } else {
            print(
              "Rider document not found for $riderId during initial fetch.",
            );
            if (mounted &&
                (!_riderData.containsKey(riderId) ||
                    _riderData[riderId]?.name == 'Loading...')) {
              GeoPoint? currentLocation = _riderData[riderId]?.location;
              _riderData[riderId] = RiderInfo(
                id: riderId,
                name: 'Rider ไม่พบข้อมูล',
                phone: riderId,
                location: currentLocation,
              );
              dataUpdated = true;
            }
          }
        } catch (e) {
          print("Error fetching rider data for $riderId: $e");
          if (mounted &&
              (!_riderData.containsKey(riderId) ||
                  _riderData[riderId]?.name == 'Loading...')) {
            GeoPoint? currentLocation = _riderData[riderId]?.location;
            _riderData[riderId] = RiderInfo(
              id: riderId,
              name: 'Error Fetching',
              phone: 'Error',
              location: currentLocation,
            );
            dataUpdated = true;
          }
        }
      }
    }
    if (mounted && dataUpdated) {
      print(
        "Initial rider data fetched/updated, triggering setState and marker update.",
      );
      setState(() {});
      if (_isMapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateAllMarkers();
        });
      }
    } else if (!dataUpdated) {
      print("Initial rider data check complete, no changes needed.");
    }
  }

  void _listenToRiderLocations() {
    _locationSubscriptions.keys
        .where((riderId) => !_activeRiderIds.contains(riderId))
        .toList()
        .forEach((riderId) {
          _locationSubscriptions[riderId]?.cancel();
          _locationSubscriptions.remove(riderId);
          print("Stopped listening for rider: $riderId");
          _removeMarker(riderId);
        });

    for (String riderId in _activeRiderIds) {
      if (!_locationSubscriptions.containsKey(riderId)) {
        print("Starting listener for rider: $riderId");
        final subscription = _firestore
            .collection('Rider')
            .doc(riderId)
            .snapshots()
            .listen(
              (snapshot) {
                if (!mounted) return;

                GeoPoint? newLocation;
                String riderName = _riderData[riderId]?.name ?? 'Loading...';
                String riderPhone = _riderData[riderId]?.phone ?? 'Loading...';
                String riderImageUrl = _riderData[riderId]?.imageUrl ?? '';

                if (snapshot.exists && snapshot.data() != null) {
                  final data = snapshot.data() as Map<String, dynamic>;
                  final lat = data['currentLat'] as double?;
                  final lng = data['currentLng'] as double?;
                  riderName = data['name'] ?? riderName;
                  riderPhone = data['phone'] ?? riderPhone;
                  riderImageUrl = data['imageUrl'] ?? riderImageUrl;
                  if (riderImageUrl.startsWith('"') &&
                      riderImageUrl.endsWith('"')) {
                    riderImageUrl = riderImageUrl.substring(
                      1,
                      riderImageUrl.length - 1,
                    );
                  }

                  if (lat != null && lng != null) {
                    newLocation = GeoPoint(lat, lng);
                    print(
                      "Listener received location update for $riderId: $lat, $lng",
                    );
                  } else {
                    print(
                      "Listener: Location data (currentLat/currentLng) missing or invalid for $riderId",
                    );
                    newLocation = null;
                  }

                  RiderInfo? riderInfo = _riderData[riderId];
                  bool locationChanged =
                      (riderInfo?.location?.latitude != newLocation?.latitude ||
                      riderInfo?.location?.longitude != newLocation?.longitude);
                  bool infoChanged =
                      (riderInfo?.name != riderName ||
                      riderInfo?.phone != riderPhone ||
                      riderInfo?.imageUrl != riderImageUrl);

                  if (riderInfo == null) {
                    print(
                      "Listener: Rider data for $riderId not yet available, creating temporary entry.",
                    );
                    setState(
                      () => _riderData[riderId] = RiderInfo(
                        id: riderId,
                        name: riderName,
                        phone: riderPhone,
                        imageUrl: riderImageUrl,
                        location: newLocation,
                      ),
                    );
                    locationChanged = true;
                  } else if (locationChanged || infoChanged) {
                    print(
                      "Updating state for $riderId, locationChanged: $locationChanged, infoChanged: $infoChanged",
                    );
                    setState(() {
                      riderInfo.location = newLocation;
                      riderInfo.name = riderName;
                      riderInfo.phone = riderPhone;
                      riderInfo.imageUrl = riderImageUrl;
                    });
                  } else {
                    print("Listener: Data for $riderId hasn't changed.");
                  }

                  if (_isMapReady && (locationChanged || infoChanged)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _updateMarker(riderId);
                    });
                  }
                } else {
                  print(
                    "Listener: Rider document data not found for ID: $riderId",
                  );
                  if (_riderData.containsKey(riderId)) {
                    bool needsUpdate = _riderData[riderId]!.location != null;
                    if (needsUpdate) {
                      setState(() {
                        _riderData[riderId]!.location = null;
                      });
                      if (_isMapReady) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _removeMarker(riderId);
                        });
                      }
                    }
                  }
                }
              },
              onError: (error) {
                print("Error listening to rider data for $riderId: $error");
                if (mounted && _riderData.containsKey(riderId)) {
                  bool needsUpdate = _riderData[riderId]!.location != null;
                  if (needsUpdate) {
                    setState(() {
                      _riderData[riderId]!.location = null;
                    });
                    if (_isMapReady) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _removeMarker(riderId);
                      });
                    }
                  }
                }
              },
            );
        _locationSubscriptions[riderId] = subscription;
      }
    }
  }

  void _updateMarker(String riderId) {
    if (!_isMapReady || !_riderData.containsKey(riderId)) {
      print(
        "Skipping marker update for $riderId. Pre-checks failed. Map ready: $_isMapReady, Data exists: ${_riderData.containsKey(riderId)}",
      );
      return;
    }

    final rider = _riderData[riderId]!;

    if (rider.location == null) {
      print(
        "Skipping marker creation/update for $riderId because location is null.",
      );
      _removeMarker(riderId);
      return;
    }

    print(
      "Executing _updateMarker for $riderId at ${rider.location!.latitude}, ${rider.location!.longitude} with name ${rider.name}",
    );

    String markerTitle = rider.name != 'Loading...' ? rider.name : riderId;
    String cleanImageUrl = rider.imageUrl;

    String iconUrlToShow;
    if (cleanImageUrl.isNotEmpty &&
        cleanImageUrl.contains("res.cloudinary.com")) {
      String transformations = "w_30,h_30,c_fill,r_max,bo_2px_solid_rgb:673AB7";
      iconUrlToShow = cleanImageUrl.replaceFirst(
        "/upload/",
        "/upload/$transformations/",
      );
    } else if (cleanImageUrl.isNotEmpty) {
      iconUrlToShow = cleanImageUrl;
    } else {
      iconUrlToShow =
          'https://map.longdo.com/mmmap/images/icons/motorcycle.png';
    }

    print("Using icon URL for $riderId: $iconUrlToShow");

    var marker = Longdo.LongdoObject(
      "Marker",
      args: [
        {'lon': rider.location!.longitude, 'lat': rider.location!.latitude},
        {
          'title': markerTitle,
          'detail': rider.phone != 'Loading...' ? rider.phone : '',
          'icon': {
            'url': iconUrlToShow,
            'width': 30,
            'height': 30,
            'offset': {'x': 15, 'y': 30},
          },
          'data': {'riderId': riderId},
        },
      ],
    );

    try {
      if (_riderMarkers.containsKey(riderId)) {
        print("Attempting to remove existing marker for $riderId via call()");
        _mapController.currentState?.call(
          "Overlays.remove",
          args: [_riderMarkers[riderId]],
        );
        print("Removed existing marker for $riderId.");
      }
      print("Attempting to add marker for $riderId via call()");
      _mapController.currentState?.call("Overlays.add", args: [marker]);
      _riderMarkers[riderId] = marker;
      print("Marker added/updated successfully for $riderId");

      _adjustMapBounds();
    } catch (e) {
      print(
        "!!!!!!!! ERROR during map Overlays.remove or Overlays.add for $riderId: $e !!!!!!!!",
      );
      _riderMarkers.remove(riderId);
      if (e.toString().contains("SyntaxError")) {
        print(
          ">>>>> Potential JavaScript Syntax Error in marker args for $riderId <<<<<",
        );
      }
    }
  }

  void _updateAllMarkers() {
    if (!_isMapReady) {
      print("Skipping _updateAllMarkers: Map not ready.");
      return;
    }
    print("Executing _updateAllMarkers for active IDs: $_activeRiderIds");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _riderMarkers.keys
          .where((key) => !_activeRiderIds.contains(key))
          .toList()
          .forEach(_removeMarker);
      _activeRiderIds.forEach(_updateMarker);
    });
  }

  void _removeMarker(String riderId) {
    if (!_isMapReady) {
      print("Skipping _removeMarker for $riderId: Map not ready.");
      _riderMarkers.remove(riderId);
      if (_selectedRider?.id == riderId) {
        if (mounted) setState(() => _selectedRider = null);
      }
      return;
    }

    if (_riderMarkers.containsKey(riderId)) {
      print("Executing _removeMarker for $riderId");
      try {
        _mapController.currentState?.call(
          "Overlays.remove",
          args: [_riderMarkers[riderId]],
        );
        print("Successfully called Overlays.remove for $riderId.");
      } catch (e) {
        print(
          "!!!!!!!! ERROR during Overlays.remove for $riderId: $e !!!!!!!!",
        );
      } finally {
        _riderMarkers.remove(riderId);
        print("Removed marker reference locally for $riderId.");
        if (_selectedRider?.id == riderId) {
          if (mounted) setState(() => _selectedRider = null);
        }
      }
    } else {
      print(
        "Skipping _removeMarker for $riderId: Marker not found in local map.",
      );
    }
  }

  void _updateLocationMarkers() {
    if (!_isMapReady) {
      print("Skipping _updateLocationMarkers: Map not ready.");
      return;
    }
    print(
      "Executing _updateLocationMarkers for ${_originLocations.length} origins and ${_destinationLocations.length} destinations.",
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        for (var marker in _locationMarkerObjects) {
          _mapController.currentState?.call("Overlays.remove", args: [marker]);
        }
        _locationMarkerObjects.clear();
        print("Cleared old location markers.");

        for (var geo in _originLocations) {
          var marker = Longdo.LongdoObject(
            "Marker",
            args: [
              {'lon': geo.longitude, 'lat': geo.latitude},
              {
                'title': 'จุดรับสินค้า (ต้นทาง)',
                'detail': 'Pick-up Location',
                'icon': {
                  'url': 'https://map.longdo.com/mmmap/images/icons/store.png',
                  'width': 25,
                  'height': 25,
                  'offset': {'x': 12, 'y': 25},
                },
                'data': {'type': 'origin'},
              },
            ],
          );
          _mapController.currentState?.call("Overlays.add", args: [marker]);
          _locationMarkerObjects.add(marker);
        }
        print("Added ${_originLocations.length} origin markers.");

        for (var geo in _destinationLocations) {
          var marker = Longdo.LongdoObject(
            "Marker",
            args: [
              {'lon': geo.longitude, 'lat': geo.latitude},
              {
                'title': 'จุดส่งสินค้า (ปลายทาง)',
                'detail': 'Destination',
                'icon': {
                  'url': 'https://map.longdo.com/mmmap/images/icons/home.png',
                  'width': 25,
                  'height': 25,
                  'offset': {'x': 12, 'y': 25},
                },
                'data': {'type': 'destination'},
              },
            ],
          );
          _mapController.currentState?.call("Overlays.add", args: [marker]);
          _locationMarkerObjects.add(marker);
        }
        print("Added ${_destinationLocations.length} destination markers.");

        _adjustMapBounds();
      } catch (e) {
        print("!!!!!!!! ERROR during _updateLocationMarkers: $e !!!!!!!!");
      }
    });
  }

  void _adjustMapBounds() {
    if (!_isMapReady) {
      print("Skipping _adjustMapBounds: Map not ready.");
      return;
    }

    List<Map<String, double>> locations = [];
    _riderMarkers.keys.forEach((riderId) {
      if (_riderData.containsKey(riderId) &&
          _riderData[riderId]!.location != null) {
        locations.add({
          'lon': _riderData[riderId]!.location!.longitude,
          'lat': _riderData[riderId]!.location!.latitude,
        });
      }
    });

    for (var geo in _originLocations) {
      locations.add({'lon': geo.longitude, 'lat': geo.latitude});
    }
    for (var geo in _destinationLocations) {
      locations.add({'lon': geo.longitude, 'lat': geo.latitude});
    }

    print(
      "Found ${locations.length} valid locations (riders + places) for bounding.",
    );

    try {
      if (locations.length > 1) {
        print("Attempting to adjust map bounds for multiple points.");
        _mapController.currentState?.call("bound", args: [locations]);
        Future.delayed(const Duration(milliseconds: 700), () {
          if (_isMapReady && mounted) {
            try {
              print("Zooming out slightly after bounding.");
              _mapController.currentState?.call("zoom", args: [-1]);
            } catch (e) {
              print("Error zooming out: $e");
            }
          }
        });
      } else if (locations.length == 1) {
        print("Attempting to center map on the single point.");
        _mapController.currentState?.call(
          "location",
          args: [locations[0], true],
        );
        Future.delayed(const Duration(milliseconds: 400), () {
          if (_isMapReady && mounted) {
            try {
              print("Zooming in on single point.");
              _mapController.currentState?.call("zoom", args: [16, true]);
            } catch (e) {
              print("Error zooming in: $e");
            }
          }
        });
      } else {
        print("No valid locations found to adjust bounds.");
      }
    } catch (e) {
      print("!!!!!!!! ERROR during map bound/location/zoom: $e !!!!!!!!");
    }
  }

  void _handleOverlayClick(dynamic message) {
    try {
      String messageString = '';
      if (message is String) {
        messageString = message;
      } else if (message != null) {
        try {
          messageString = message.message?.toString() ?? '';
        } catch (e) {
          messageString = message.toString();
          print(
            "Could not access message.message, used message.toString(): $e",
          );
        }
      }

      final jsonObj = json.decode(messageString);
      final clickedMarkerObject = jsonObj['data'];
      if (clickedMarkerObject == null) return;

      final customData = clickedMarkerObject['data'];
      print(
        "Overlay clicked: ${clickedMarkerObject['title']} | Custom data: $customData",
      );

      if (customData is Map && customData.containsKey('riderId')) {
        final clickedRiderId = customData['riderId'] as String;

        if (_riderData.containsKey(clickedRiderId)) {
          print("Selected rider: $clickedRiderId");
          final rider = _riderData[clickedRiderId]!;

          _justClickedOverlay = true;
          Future.delayed(const Duration(milliseconds: 100), () {
            _justClickedOverlay = false;
          });

          setState(() {
            _selectedRider = rider;
          });
        } else {
          print(
            "Clicked marker corresponds to an unknown rider ID: $clickedRiderId",
          );
          if (mounted) setState(() => _selectedRider = null);
        }
      } else if (customData is Map && customData.containsKey('type')) {
        print("Location marker clicked: ${customData['type']}");
        _justClickedOverlay = true;
        Future.delayed(const Duration(milliseconds: 100), () {
          _justClickedOverlay = false;
        });
        if (_selectedRider != null) {
          setState(() {
            _selectedRider = null;
          });
        }
      } else {
        print("Clicked overlay does not have riderId or type data.");
        _justClickedOverlay = true;
        Future.delayed(const Duration(milliseconds: 100), () {
          _justClickedOverlay = false;
        });
        if (_selectedRider != null) {
          if (mounted) setState(() => _selectedRider = null);
        }
      }
    } catch (e) {
      print("!!!!!!!! ERROR handling overlay click: $e !!!!!!!!");
      if (mounted) setState(() => _selectedRider = null);
    }
  }

  bool _areGeoPointListsEqual(List<GeoPoint> list1, List<GeoPoint> list2) {
    if (list1.length != list2.length) return false;

    final set1 = list1.map((g) => "${g.latitude},${g.longitude}").toSet();
    final set2 = list2.map((g) => "${g.latitude},${g.longitude}").toSet();

    return set1.difference(set2).isEmpty && set2.difference(set1).isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ติดตามไรเดอร์'),
        backgroundColor: Colors.deepPurple[400],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          LongdoMapWidget(
            apiKey: "ba51dc98b3fd0dd3bb1ab2224a3e36d1",
            key: _mapController,
            eventName: [
              IJavascriptChannel(
                name: "ready",
                onMessageReceived: (message) {
                  print('🗺️ Rider Tracking Map is ready');
                  if (!mounted) return;
                  setState(() => _isMapReady = true);
                  try {
                    print("Map Ready: Setting layer.");
                    _mapController.currentState?.call(
                      "Ui.Layer.set",
                      args: [Longdo.LongdoStatic('Layers', 'RASTER_POI')],
                    );

                    // --- MODIFICATION: REMOVED Bangkok location ---
                    // No default location, will zoom when riders are fetched

                    print(
                      "Map Ready: Triggering _fetchActiveRiders after delay.",
                    );
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) _fetchActiveRiders();
                    });
                  } catch (e) {
                    print("!!!!!!!! ERROR during map ready setup: $e !!!!!!!!");
                  }
                },
              ),
              IJavascriptChannel(
                name: "overlayClick",
                onMessageReceived: _handleOverlayClick,
              ),
              IJavascriptChannel(
                name: "click",
                onMessageReceived: (message) {
                  String messageString = '';
                  try {
                    messageString = message.message?.toString() ?? '';
                  } catch (e) {
                    messageString = message?.toString() ?? '';
                    print(
                      "Error accessing message.message directly, used message.toString(): $e",
                    );
                  }

                  if (_justClickedOverlay) {
                    print(
                      "Ignoring background click because an overlay was just clicked.",
                    );
                    return;
                  }

                  bool clickedOnOverlay = false;
                  try {
                    if (messageString.isNotEmpty &&
                        messageString.startsWith('{')) {
                      final jsonObj = json.decode(messageString);
                      if (jsonObj['data'] != null) {
                        final overlayDetails = jsonObj['data'];
                        if (overlayDetails is Map &&
                            overlayDetails.containsKey('data')) {
                          clickedOnOverlay = true;
                        }
                      }
                    }
                  } catch (e) {
                    print(
                      "Error decoding click message or checking for overlay: $e",
                    );
                  }

                  if (!clickedOnOverlay) {
                    print("Map background clicked, clearing selection.");
                    try {
                      _mapController.currentState?.call("Popup.hide");
                    } catch (e) {
                      print("Error hiding popup on map click: $e");
                    }
                    if (_selectedRider != null) {
                      if (mounted) setState(() => _selectedRider = null);
                    }
                  } else {
                    print(
                      "Map click event likely on overlay ignored by flag logic.",
                    );
                  }
                },
              ),
            ],
          ),

          if (_selectedRider != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildRiderInfoPanel(_selectedRider!),
            ),

          Positioned(
            bottom: 80,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'refresh_button',
              mini: true,
              onPressed: _fetchActiveRiders,
              backgroundColor: Colors.white,
              tooltip: "รีเฟรชรายการไรเดอร์",
              child: Icon(Icons.refresh, color: Colors.deepPurple),
            ),
          ),

          // --- MODIFIED: Button to find rider(s) ---
          Positioned(
            bottom: 130, // Was 130
            right: 16,
            child: FloatingActionButton(
              heroTag: 'recenter_button',
              mini: true,
              onPressed: _adjustMapBounds, // Correct function
              backgroundColor: Colors.white,
              tooltip: "ไปที่ตำแหน่งไรเดอร์", // MODIFIED tooltip
              child: Icon(
                Icons.location_searching,
                color: Colors.deepPurple,
              ), // MODIFIED icon
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiderInfoPanel(RiderInfo rider) {
    String panelImageUrl = rider.imageUrl;

    return Material(
      elevation: 4.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        color: Colors.white,
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[200],
              backgroundImage: panelImageUrl.isNotEmpty
                  ? NetworkImage(panelImageUrl)
                  : null,
              onBackgroundImageError: (_, __) {
                print("Error loading image for panel: $panelImageUrl");
              },
              child: panelImageUrl.isEmpty
                  ? const Icon(Icons.person, size: 30, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rider.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'เบอร์: ${rider.phone}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.grey[600]),
              onPressed: () {
                print("Closing rider info panel via close button.");
                try {
                  _mapController.currentState?.call("Popup.hide");
                } catch (e) {
                  print("Error hiding popup on panel close: $e");
                }
                setState(() {
                  _selectedRider = null;
                });
              },
              tooltip: "ปิด",
            ),
          ],
        ),
      ),
    );
  }
}

class ListEquality<E extends Comparable> {
  bool equals(List<E>? list1, List<E>? list2) {
    if (identical(list1, list2)) return true;
    if (list1 == null || list2 == null) return false;

    List<E> sortedList1 = List.from(list1)..sort();
    List<E> sortedList2 = List.from(list2)..sort();

    if (sortedList1.length != sortedList2.length) return false;

    for (int i = 0; i < sortedList1.length; i++) {
      if (sortedList1[i] != sortedList2[i]) return false;
    }
    return true;
  }
}
