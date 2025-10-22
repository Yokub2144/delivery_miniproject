import 'dart:developer'; // For log()
import 'dart:io'; // Required for File
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; // Import Image Picker
import 'package:cloudinary_public/cloudinary_public.dart'; // Import Cloudinary
import 'package:path_provider/path_provider.dart'; // Import Path Provider
import 'package:path/path.dart' as p; // Import Path package

// Assuming UserRole is stored, replace with your actual logic
enum UserRole { sender, receiver, rider }

class StatusPage extends StatefulWidget {
  final String productId;
  final UserRole userRole; // Pass the user's role here

  const StatusPage({
    super.key,
    required this.productId,
    required this.userRole,
  });

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // REMOVED: FirebaseStorage instance
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // --- NEW: Initialize Cloudinary ---
  final cloudinary = CloudinaryPublic(
    'dzicj4dci', // Replace with your Cloudinary cloud name
    'flutter_unsigned', // Replace with your Cloudinary upload preset
    cache: false,
  );
  // --- END NEW ---

  // --- vvv Modified Function: Pick image, upload to Cloudinary, and update Firestore vvv ---
  Future<void> _pickAndUploadImage(int currentStatus) async {
    // Determine next status and photo key
    int nextStatus = currentStatus;
    String photoKey = '';
    bool requiresPhoto = false;

    if (widget.userRole == UserRole.sender && currentStatus == 0) {
      photoKey = '1';
      nextStatus = 1;
      requiresPhoto = true;
    } else if (widget.userRole == UserRole.rider && currentStatus == 1) {
      nextStatus = 2;
      requiresPhoto = false;
    } else if (widget.userRole == UserRole.rider && currentStatus == 2) {
      photoKey = '3';
      nextStatus = 3;
      requiresPhoto = true;
    } else if (widget.userRole == UserRole.rider && currentStatus == 3) {
      photoKey = '4';
      nextStatus = 4;
      requiresPhoto = true;
    } else {
      print("Invalid role/status for update or update not needed.");
      return;
    }

    String? downloadUrl; // Cloudinary URL

    // Pick image only if required
    if (requiresPhoto) {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);

      if (image == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ยกเลิกการถ่ายภาพ')));
        return;
      }

      setState(() => _isUploading = true);

      try {
        // --- NEW: Cloudinary Upload Logic ---
        final Directory tempDir = await getApplicationDocumentsDirectory();
        final String fileExtension = p.extension(image.name);
        final String newFileName =
            '${DateTime.now().millisecondsSinceEpoch}$fileExtension';
        final File file = File('${tempDir.path}/$newFileName');
        await image.saveTo(file.path);

        log('กำลังอัปโหลดรูปไป Cloudinary...');
        final CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            file.path,
            resourceType: CloudinaryResourceType.Image,
            // You might want a specific folder for status photos in Cloudinary
            // folder: 'status_photos/${widget.productId}',
          ),
        );
        downloadUrl = response.secureUrl;
        log('อัปโหลด Cloudinary สำเร็จ: $downloadUrl');
        // --- END NEW ---
      } catch (e) {
        print("Error uploading image to Cloudinary: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการอัพโหลดรูป: $e')),
        );
        setState(() => _isUploading = false);
        return;
      }
    } else {
      setState(
        () => _isUploading = true,
      ); // Still show loading for status update
    }

    // Update Firestore Status (and Cloudinary URL if applicable)
    try {
      await _updateStatus(
        nextStatus,
        photoKey.isNotEmpty ? photoKey : null,
        downloadUrl, // Pass Cloudinary URL
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requiresPhoto ? 'อัพเดทสถานะและรูปภาพสำเร็จ' : 'อัพเดทสถานะสำเร็จ',
          ),
        ),
      );
    } catch (e) {
      print("Error updating status in Firestore: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการอัพเดทสถานะ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
  // --- ^^^ Modified Function ^^^ ---

  // --- vvv Function to update Firestore document (No significant change needed) vvv ---
  Future<void> _updateStatus(
    int newStatus,
    String? photoKey,
    String? photoUrl, // This will now be the Cloudinary URL
  ) async {
    DocumentReference productRef = _firestore
        .collection('Product')
        .doc(widget.productId);
    Map<String, dynamic> updateData = {'status': newStatus};

    if (photoKey != null &&
        photoKey.isNotEmpty &&
        photoUrl != null &&
        photoUrl.isNotEmpty) {
      updateData['statusPhotos.$photoKey'] = photoUrl;
    }

    await productRef.update(updateData);
  }
  // --- ^^^ Function to update Firestore document ^^^ ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สถานะการจัดส่ง'),
        backgroundColor: Colors.deepPurple[400],
        foregroundColor: Colors.white, // Make back arrow white
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('Product')
            .doc(widget.productId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('ไม่พบข้อมูลสินค้า'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final currentStatus = data['status'] as int? ?? 0;
          final statusPhotos =
              data['statusPhotos'] as Map<String, dynamic>? ?? {};
          final senderName = data['senderName'] as String? ?? 'ผู้จัดส่ง';
          // Safely access riderInfo - check if it exists and is a map
          final riderInfo = data['riderInfo'] as Map<String, dynamic>?;
          final riderName = riderInfo?['displayName'] ?? 'ไรเดอร์';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch, // Make children stretch
              children: [
                _buildStepper(currentStatus),
                const SizedBox(height: 24),
                // Show sender photo section regardless of status > 0
                _buildStatusPhoto(
                  statusNumber: 1,
                  photoUrl: statusPhotos['1'],
                  label: 'รอไรเดอร์มารับ',
                  uploaderName: senderName,
                  uploaderRole: 'ผู้จัดส่ง',
                  currentStatus: currentStatus,
                ),
                // Show rider pickup photo if status >= 3
                _buildStatusPhoto(
                  statusNumber: 3,
                  photoUrl: statusPhotos['3'],
                  label: 'เข้ารับสินค้าแล้ว',
                  uploaderName: riderName,
                  uploaderRole: 'ไรเดอร์',
                  currentStatus: currentStatus,
                ),
                // Show rider delivery photo if status >= 4
                _buildStatusPhoto(
                  statusNumber: 4,
                  photoUrl: statusPhotos['4'],
                  label: 'จัดส่งสำเร็จ',
                  uploaderName: riderName,
                  uploaderRole: 'ไรเดอร์',
                  currentStatus: currentStatus,
                ),

                const SizedBox(height: 32),
                if (_shouldShowUpdateButton(currentStatus))
                  ElevatedButton.icon(
                    // Directly call _pickAndUploadImage
                    onPressed: _isUploading
                        ? null
                        : () => _pickAndUploadImage(currentStatus),
                    icon: _isUploading
                        ? Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(2.0),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        // Show camera icon only if the next step requires a photo
                        : Icon(
                            _getButtonIcon(currentStatus),
                            color: Colors.white,
                          ),
                    label: Text(
                      _isUploading
                          ? 'กำลังดำเนินการ...'
                          : _getButtonLabel(currentStatus),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper to determine if the update button should be shown
  bool _shouldShowUpdateButton(int currentStatus) {
    if (widget.userRole == UserRole.receiver)
      return false; // Receiver cannot update
    if (currentStatus >= 4) return false; // Already delivered

    if (widget.userRole == UserRole.sender && currentStatus == 0)
      return true; // Sender uploads for status 1
    if (widget.userRole == UserRole.rider &&
        (currentStatus == 1 || currentStatus == 2 || currentStatus == 3))
      return true; // Rider updates for status 2, 3, 4

    return false;
  }

  // --- vvv NEW: Helper to get button label based on role and status vvv ---
  String _getButtonLabel(int currentStatus) {
    if (widget.userRole == UserRole.sender && currentStatus == 0) {
      return 'ยืนยันพร้อมส่ง (ถ่ายรูป)';
    } else if (widget.userRole == UserRole.rider && currentStatus == 1) {
      return 'กดรับงาน'; // No photo needed
    } else if (widget.userRole == UserRole.rider && currentStatus == 2) {
      return 'ยืนยันรับสินค้า (ถ่ายรูป)';
    } else if (widget.userRole == UserRole.rider && currentStatus == 3) {
      return 'ยืนยันส่งสำเร็จ (ถ่ายรูป)';
    }
    return 'อัพเดทสถานะ'; // Default fallback
  }
  // --- ^^^ NEW: Helper to get button label ^^^ ---

  // --- vvv NEW: Helper to get button icon based on role and status vvv ---
  IconData _getButtonIcon(int currentStatus) {
    if (widget.userRole == UserRole.sender && currentStatus == 0) {
      return Icons.camera_alt;
    } else if (widget.userRole == UserRole.rider && currentStatus == 1) {
      return Icons.check_circle_outline; // Icon for accepting job
    } else if (widget.userRole == UserRole.rider && currentStatus == 2) {
      return Icons.camera_alt;
    } else if (widget.userRole == UserRole.rider && currentStatus == 3) {
      return Icons.camera_alt;
    }
    return Icons.update; // Default fallback
  }
  // --- ^^^ NEW: Helper to get button icon ^^^ ---

  // --- vvv Widget to build the status stepper (Refactored using IntrinsicHeight and Align) vvv ---
  Widget _buildStepper(int currentStatus) {
    final steps = [
      'รอไรเดอร์มารับ', // Status 1
      'ไรเดอร์รับงาน', // Status 2
      'รับของแล้ว', // Status 3
      'จัดส่งสำเร็จ', // Status 4
    ];
    const double iconSize = 30.0;

    List<Widget> stepperItems = [];
    for (int index = 0; index < steps.length; index++) {
      final statusNumber = index + 1;
      final isActive = currentStatus >= statusNumber;
      final isCurrent = currentStatus == statusNumber;
      final color = isActive ? Colors.deepPurple : Colors.grey[400];
      final icon = isActive
          ? Icons.check_circle
          : Icons.radio_button_off_outlined;

      // Add the Step Column
      stepperItems.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: iconSize),
            const SizedBox(height: 4),
            SizedBox(
              width: 40,
              child: Text(
                steps[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? Colors.deepPurple : Colors.grey[600],
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

      // Add the Connector Line (if not the last step)
      if (index < steps.length - 1) {
        stepperItems.add(
          Expanded(
            child: Align(
              // Align the container vertically center
              alignment: Alignment.center,
              child: Container(
                height: 2,
                // Adjust margin if needed, but Align should handle centering
                margin: const EdgeInsets.only(
                  bottom: 24.0,
                ), // Pushes line down relative to Column top
                color: currentStatus > statusNumber
                    ? Colors.deepPurple
                    : Colors.grey[300],
              ),
            ),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple[50],
        borderRadius: BorderRadius.circular(12),
      ),
      // Use IntrinsicHeight to ensure Row children align correctly vertically
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start, // Align Columns to the top
          children: stepperItems,
        ),
      ),
    );
  }
  // --- ^^^ Widget to build the status stepper (Refactored again) ^^^ ---

  // --- vvv Widget to display photo for a specific status vvv ---
  Widget _buildStatusPhoto({
    required int statusNumber,
    required String? photoUrl,
    required String label,
    required String uploaderName,
    required String uploaderRole,
    required int currentStatus,
  }) {
    // Determine if this section should be visible
    bool isVisible =
        currentStatus >= statusNumber ||
        (statusNumber == 1 && currentStatus >= 0);

    if (!isVisible) {
      return const SizedBox.shrink(); // Don't show future status photos yet
    }

    bool hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: uploaderRole == 'ไรเดอร์'
                    ? Colors.blue[300]
                    : Colors.orange[300], // Different colors
                child: Icon(
                  uploaderRole == 'ไรเดอร์'
                      ? Icons.directions_bike
                      : Icons.storefront,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uploaderName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                photoUrl!, // Safe to use ! because we checked hasPhoto
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[100],
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 40,
                          ),
                          Text(
                            "ไม่สามารถโหลดรูปภาพได้",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          else // Show placeholder if status is reached but no photo exists yet
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[300]!,
                ), // Add border to placeholder
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey[400],
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "ยังไม่มีรูปภาพสำหรับสถานะนี้",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- ^^^ Widget to display photo for a specific status ^^^ ---
}
