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
      for (var doc in shipmentSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final riderId = data?['riderId'] as String?;
        if (riderId != null && riderId.isNotEmpty) {
          riderIds.add(riderId);
        } else {
          print("Warning: Product ${doc.id} has no valid riderPhone");
        }
      }
      print("Active Rider IDs found: ${riderIds.toList()}");

      List<String> newRiderIds = riderIds.toList();
      List<String> currentSortedIds = List.from(_activeRiderIds)..sort();
      List<String> newSortedIds = List.from(newRiderIds)..sort();

      if (!ListEquality().equals(currentSortedIds, newSortedIds)) {
        print("Rider list changed. Updating state and listeners.");
        setState(() {
          _activeRiderIds = newRiderIds;
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
          }
        });
      } else {
        print("Rider list hasn't changed.");
        _listenToRiderLocations();
        _fetchInitialRiderData();
        if (_isMapReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _updateAllMarkers();
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

  // 2. Fetch initial rider data (name, phone, image) once
  Future<void> _fetchInitialRiderData() async {
    bool dataUpdated = false;

    for (String riderId in _activeRiderIds) {
      // Fetch only if data is missing or incomplete
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
              // Clean imageUrl - remove quotes if present
              String imageUrl = data['imageUrl'] ?? '';
              if (imageUrl.startsWith('"') && imageUrl.endsWith('"')) {
                imageUrl = imageUrl.substring(1, imageUrl.length - 1);
                print("Cleaned Image URL for $riderId: $imageUrl");
              }

              _riderData[riderId] = RiderInfo(
                id: riderId,
                name: data['name'] ?? 'ไม่พบชื่อ',
                phone: data['phone'] ?? riderId,
                imageUrl: imageUrl, // Use cleaned URL
                location: currentLocation, // Keep existing location if any
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
      setState(() {}); // Update UI with fetched names/phones/images
      if (_isMapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateAllMarkers(); // Update markers with new info
        });
      }
    } else if (!dataUpdated) {
      print("Initial rider data check complete, no changes needed.");
    }
  }

  // 3. Listen to location changes for each active rider
  void _listenToRiderLocations() {
    // Stop listening for riders who are no longer active
    _locationSubscriptions.keys
        .where((riderId) => !_activeRiderIds.contains(riderId))
        .toList() // Avoid concurrent modification
        .forEach((riderId) {
          _locationSubscriptions[riderId]?.cancel();
          _locationSubscriptions.remove(riderId);
          print("Stopped listening for rider: $riderId");
          _removeMarker(riderId); // Also remove their marker
        });

    // Start listening for newly active riders
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
                  riderName =
                      data['name'] ?? riderName; // Update name if changed
                  riderPhone =
                      data['phone'] ?? riderPhone; // Update phone if changed
                  // Clean and update imageUrl if changed
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
                    newLocation =
                        null; // Ensure location becomes null if data is bad
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
                    // Should ideally be handled by _fetchInitialRiderData first,
                    // but handle here just in case.
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
                    locationChanged = true; // Mark as changed to update marker
                  } else if (locationChanged || infoChanged) {
                    print(
                      "Updating state for $riderId, locationChanged: $locationChanged, infoChanged: $infoChanged",
                    );
                    setState(() {
                      riderInfo.location = newLocation;
                      riderInfo.name = riderName;
                      riderInfo.phone = riderPhone;
                      riderInfo.imageUrl = riderImageUrl; // Update cleaned URL
                    });
                  } else {
                    print("Listener: Data for $riderId hasn't changed.");
                  }

                  // Update marker only if map is ready and location/info changed
                  if (_isMapReady && (locationChanged || infoChanged)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _updateMarker(riderId);
                    });
                  }
                } else {
                  // Document doesn't exist or has no data
                  print(
                    "Listener: Rider document data not found for ID: $riderId",
                  );
                  // If we have existing data, set location to null
                  if (_riderData.containsKey(riderId)) {
                    bool needsUpdate = _riderData[riderId]!.location != null;
                    if (needsUpdate) {
                      setState(() {
                        _riderData[riderId]!.location = null;
                      });
                      if (_isMapReady) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _removeMarker(riderId); // Remove marker
                        });
                      }
                    }
                  }
                }
              },
              onError: (error) {
                print("Error listening to rider data for $riderId: $error");
                // Handle error, maybe remove marker or show error state
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

  // 4. Update or Add a single marker on the map
  void _updateMarker(String riderId) {
    if (!_isMapReady || !_riderData.containsKey(riderId)) {
      print(
        "Skipping marker update for $riderId. Pre-checks failed. Map ready: $_isMapReady, Data exists: ${_riderData.containsKey(riderId)}",
      );
      return;
    }

    final rider = _riderData[riderId]!;

    // If location is null, remove the marker
    if (rider.location == null) {
      print(
        "Skipping marker creation/update for $riderId because location is null.",
      );
      _removeMarker(riderId); // Ensure marker is removed
      return;
    }

    print(
      "Executing _updateMarker for $riderId at ${rider.location!.latitude}, ${rider.location!.longitude} with name ${rider.name}",
    );

    String markerTitle = rider.name != 'Loading...' ? rider.name : riderId;
    String cleanImageUrl = rider.imageUrl; // Original URL from Firestore

    String iconUrlToShow;
    if (cleanImageUrl.isNotEmpty &&
        cleanImageUrl.contains("res.cloudinary.com")) {
      String transformations = "w_30,h_30,c_fill,r_max,bo_2px_solid_rgb:673AB7";
      iconUrlToShow = cleanImageUrl.replaceFirst(
        "/upload/",
        "/upload/$transformations/",
      );
    } else if (cleanImageUrl.isNotEmpty) {
      // Non-Cloudinary URL - will likely appear large
      iconUrlToShow = cleanImageUrl;
    } else {
      // Fallback motorcycle icon
      iconUrlToShow =
          'https://map.longdo.com/mmmap/images/icons/motorcycle.png';
    }

    print("Using icon URL for $riderId: $iconUrlToShow");

    // Use standard "Marker"
    var marker = Longdo.LongdoObject(
      "Marker",
      args: [
        {'lon': rider.location!.longitude, 'lat': rider.location!.latitude},
        {
          'title': markerTitle,
          'detail': rider.phone != 'Loading...' ? rider.phone : '',
          'icon': {
            'url': iconUrlToShow, // Use the (potentially transformed) URL
            'width': 30, // Corresponds to the Cloudinary size
            'height': 30, // Corresponds to the Cloudinary size
            'offset': {'x': 15, 'y': 30}, // Anchor bottom-center
          },
          'data': {'riderId': riderId}, // Crucial for click handling
        },
      ],
    );

    try {
      // Remove existing marker before adding/updating
      if (_riderMarkers.containsKey(riderId)) {
        print("Attempting to remove existing marker for $riderId via call()");
        _mapController.currentState?.call(
          "Overlays.remove",
          args: [_riderMarkers[riderId]],
        );
        print("Removed existing marker for $riderId.");
      }
      // Add the new or updated marker
      print("Attempting to add marker for $riderId via call()");
      _mapController.currentState?.call("Overlays.add", args: [marker]);
      _riderMarkers[riderId] = marker; // Store reference to the new marker
      print("Marker added/updated successfully for $riderId");

      // Adjust map bounds only AFTER marker operation succeeds
      _adjustMapBounds();
    } catch (e) {
      print(
        "!!!!!!!! ERROR during map Overlays.remove or Overlays.add for $riderId: $e !!!!!!!!",
      );
      _riderMarkers.remove(riderId); // Clean up local reference on error
      if (e.toString().contains("SyntaxError")) {
        print(
          ">>>>> Potential JavaScript Syntax Error in marker args for $riderId <<<<<",
        );
      }
    }
  }

  // Helper to update all markers at once
  void _updateAllMarkers() {
    if (!_isMapReady) {
      print("Skipping _updateAllMarkers: Map not ready.");
      return;
    }
    print("Executing _updateAllMarkers for active IDs: $_activeRiderIds");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Remove markers that are no longer active first
      _riderMarkers.keys
          .where((key) => !_activeRiderIds.contains(key))
          .toList()
          .forEach(_removeMarker);
      // Then update markers for all active riders
      _activeRiderIds.forEach(_updateMarker);
    });
  }

  // 5. Remove a marker from the map
  void _removeMarker(String riderId) {
    if (!_isMapReady) {
      print("Skipping _removeMarker for $riderId: Map not ready.");
      // Still remove local reference even if map isn't ready
      _riderMarkers.remove(riderId);
      // If the removed rider was selected, clear selection
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
          args: [_riderMarkers[riderId]], // Use the stored marker reference
        );
        print("Successfully called Overlays.remove for $riderId.");
      } catch (e) {
        print(
          "!!!!!!!! ERROR during Overlays.remove for $riderId: $e !!!!!!!!",
        );
        // Log error but proceed to remove local reference
      } finally {
        _riderMarkers.remove(riderId); // Always remove local reference
        print("Removed marker reference locally for $riderId.");
        // If the removed rider was selected, clear selection
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

  // --- Adjust map bounds to show all markers ---
  void _adjustMapBounds() {
    if (!_isMapReady) {
      print("Skipping _adjustMapBounds: Map not ready.");
      return;
    }

    // Get valid locations from _riderData for CURRENTLY tracked markers
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

    print(
      "Found ${locations.length} valid locations among tracked markers for bounding.",
    );

    try {
      if (locations.length > 1) {
        print("Attempting to adjust map bounds for multiple riders.");
        _mapController.currentState?.call("bound", args: [locations]);
        // Optional: Zoom out slightly after bounding
        Future.delayed(const Duration(milliseconds: 700), () {
          if (_isMapReady && mounted) {
            try {
              print("Zooming out slightly after bounding.");
              _mapController.currentState?.call(
                "zoom",
                args: [-1],
              ); // Relative zoom out
            } catch (e) {
              print("Error zooming out: $e");
            }
          }
        });
      } else if (locations.length == 1) {
        print("Attempting to center map on the single rider.");
        _mapController.currentState?.call(
          "location",
          args: [locations[0], true], // Center with animation
        );
        // Optional: Set a specific zoom level for single rider
        Future.delayed(const Duration(milliseconds: 400), () {
          if (_isMapReady && mounted) {
            try {
              print("Zooming in on single rider.");
              _mapController.currentState?.call(
                "zoom",
                args: [16, true],
              ); // Zoom to level 16
            } catch (e) {
              print("Error zooming in: $e");
            }
          }
        });
      } else {
        // No valid markers to bound/center on
        print(
          "No valid locations found in _riderData for tracked markers to adjust bounds.",
        );
        // Optionally reset to default view if desired
        // try {
        //   print("Attempting to reset map view to default.");
        //   _mapController.currentState?.call("location", args: [{'lon': 100.5018, 'lat': 13.7563}, false]);
        //   _mapController.currentState?.call("zoom", args: [12, true]);
        // } catch (e) { print("!!!!!!!! ERROR resetting map view: $e !!!!!!!!"); }
      }
    } catch (e) {
      print("!!!!!!!! ERROR during map bound/location/zoom: $e !!!!!!!!");
    }
  }

  // 6. Handle clicks on markers
  void _handleOverlayClick(dynamic message) {
    try {
      // Safely get the message string, assuming it might be wrapped
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

      // Extract the custom data we stored ('data': {'riderId': riderId})
      final customData = clickedMarkerObject['data'];
      print(
        "Overlay clicked: ${clickedMarkerObject['title']} | Custom data: $customData",
      );

      if (customData is Map && customData.containsKey('riderId')) {
        final clickedRiderId = customData['riderId'] as String;

        // Check if we have data for this rider
        if (_riderData.containsKey(clickedRiderId)) {
          print("Selected rider: $clickedRiderId");
          final rider = _riderData[clickedRiderId]!;

          // --- [FIX] Set the flag *before* setState ---
          _justClickedOverlay = true;
          // Reset the flag shortly after
          Future.delayed(const Duration(milliseconds: 100), () {
            _justClickedOverlay = false;
          });
          // --- [END FIX] ---

          // Update the state to show the top info panel
          setState(() {
            _selectedRider = rider;
          });
        } else {
          print(
            "Clicked marker corresponds to an unknown rider ID: $clickedRiderId",
          );
          // Clear selection if rider data is missing
          if (mounted) setState(() => _selectedRider = null);
        }
      } else {
        print("Clicked overlay does not have riderId data.");
        // Clear selection if the clicked overlay isn't one of our riders
        if (_selectedRider != null) {
          if (mounted) setState(() => _selectedRider = null);
        }
      }
    } catch (e) {
      print("!!!!!!!! ERROR handling overlay click: $e !!!!!!!!");
      // Clear selection on error
      if (mounted) setState(() => _selectedRider = null);
    }
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
        // Use Stack to overlay info panel on map
        children: [
          LongdoMapWidget(
            apiKey: "ba51dc98b3fd0dd3bb1ab2224a3e36d1", // Use your API key
            key: _mapController,
            eventName: [
              IJavascriptChannel(
                name: "ready",
                onMessageReceived: (message) {
                  print('🗺️ Rider Tracking Map is ready');
                  if (!mounted) return;
                  setState(() => _isMapReady = true); // Set map ready flag
                  try {
                    print("Map Ready: Setting layer and zoom.");
                    _mapController.currentState?.call(
                      "Ui.Layer.set",
                      args: [Longdo.LongdoStatic('Layers', 'RASTER_POI')],
                    );
                    _mapController.currentState?.call(
                      "location",
                      args: [
                        {'lon': 100.5018, 'lat': 13.7563},
                        false,
                      ],
                    ); // Default location Bangkok
                    _mapController.currentState?.call(
                      "zoom",
                      args: [12, false],
                    ); // Default zoom

                    // Fetch riders slightly after map initialization
                    print(
                      "Map Ready: Triggering _fetchActiveRiders after delay.",
                    );
                    Future.delayed(const Duration(milliseconds: 500), () {
                      // Shorter delay might be okay
                      if (mounted) _fetchActiveRiders();
                    });
                  } catch (e) {
                    print("!!!!!!!! ERROR during map ready setup: $e !!!!!!!!");
                  }
                },
              ),
              IJavascriptChannel(
                name: "overlayClick",
                onMessageReceived: _handleOverlayClick, // Handles marker clicks
              ),
              IJavascriptChannel(
                name: "click", // Handles clicks on the map background
                onMessageReceived: (message) {
                  // Assume 'message' is JavaScriptMessage or similar
                  // --- [REVISED FIX] Directly access .message property ---
                  String messageString = ''; // Initialize empty string
                  try {
                    // Directly access .message and convert to string safely
                    // Use ?.toString() to handle null and ensure it's a string
                    messageString = message.message?.toString() ?? '';
                  } catch (e) {
                    // Fallback if accessing .message fails for *any* reason
                    messageString = message?.toString() ?? '';
                    print(
                      "Error accessing message.message directly, used message.toString(): $e",
                    );
                  }
                  // --- [END REVISED FIX] ---

                  // --- Flag check remains the same ---
                  if (_justClickedOverlay) {
                    print(
                      "Ignoring background click because an overlay was just clicked.",
                    );
                    return; // Stop processing this click
                  }
                  // --- End Flag check ---

                  // This part now only runs if it was a true background click

                  // (JSON checking remains the same)
                  bool clickedOnOverlay = false;
                  try {
                    // Check if the string looks like JSON before decoding
                    if (messageString.isNotEmpty &&
                        messageString.startsWith('{')) {
                      final jsonObj = json.decode(messageString);
                      // Check structure received from LongdoMap on click
                      if (jsonObj['data'] != null) {
                        final overlayDetails = jsonObj['data'];
                        // Check if our custom 'data' (containing riderId) exists
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
                    // If Error decoding, treat as background click
                  }

                  // Only clear selection if the click was NOT on an overlay
                  if (!clickedOnOverlay) {
                    print("Map background clicked, clearing selection.");
                    // Hide the map's built-in popup (if one is open)
                    try {
                      _mapController.currentState?.call("Popup.hide");
                    } catch (e) {
                      print("Error hiding popup on map click: $e");
                    }
                    // Hide the top info panel
                    if (_selectedRider != null) {
                      if (mounted) setState(() => _selectedRider = null);
                    }
                  } else {
                    // This case *shouldn't* normally happen if the flag logic works,
                    // but log it just in case.
                    print(
                      "Map click event likely on overlay ignored by flag logic.",
                    );
                  }
                },
              ),
            ],
          ),

          // --- Rider Info Panel (Top) ---
          if (_selectedRider != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildRiderInfoPanel(_selectedRider!),
            ),

          // --- Optional: Refresh Button ---
          Positioned(
            bottom: 80,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'refresh_button', // Use unique heroTag
              mini: true,
              onPressed: _fetchActiveRiders,
              backgroundColor: Colors.white,
              tooltip: "รีเฟรชรายการไรเดอร์",
              child: Icon(Icons.refresh, color: Colors.deepPurple),
            ),
          ),
          // --- Optional: Recenter Button ---
          Positioned(
            bottom: 130,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'recenter_button', // Use unique heroTag
              mini: true,
              onPressed: _adjustMapBounds,
              backgroundColor: Colors.white,
              tooltip: "แสดงไรเดอร์ทั้งหมด",
              child: Icon(Icons.center_focus_strong, color: Colors.deepPurple),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget to build the Rider Info Panel ---
  Widget _buildRiderInfoPanel(RiderInfo rider) {
    // Use original image URL for the panel, not the transformed one
    String panelImageUrl = rider.imageUrl;
    // Basic check if it's a Cloudinary URL to potentially use a larger version if needed
    // For now, just use the original one fetched.

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
                  ? NetworkImage(panelImageUrl) // Use original URL
                  : null,
              onBackgroundImageError: (_, __) {
                // Optional: Handle image load error, maybe show placeholder
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
                    overflow: TextOverflow
                        .ellipsis, // Prevent long names from breaking layout
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
                // Also hide the map popup if it's open
                try {
                  _mapController.currentState?.call("Popup.hide");
                } catch (e) {
                  print("Error hiding popup on panel close: $e");
                }
                // Hide the panel itself
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

  // --- End Rider Info Panel Widget ---
}

// Helper class for comparing lists (optional but good practice)
class ListEquality<E extends Comparable> {
  // Ensure E is Comparable for sort
  bool equals(List<E>? list1, List<E>? list2) {
    if (identical(list1, list2)) return true;
    if (list1 == null || list2 == null) return false;

    // Create sorted copies for comparison
    List<E> sortedList1 = List.from(list1)..sort();
    List<E> sortedList2 = List.from(list2)..sort();

    if (sortedList1.length != sortedList2.length) return false;

    for (int i = 0; i < sortedList1.length; i++) {
      if (sortedList1[i] != sortedList2[i]) return false;
    }
    return true;
  }
}
