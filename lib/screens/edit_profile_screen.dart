import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentImagePath;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentImagePath,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late String _imagePath;
  XFile? _selectedImageFile;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _imagePath = widget.currentImagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      imageQuality: 50,
    );
    if (image != null) {
      setState(() {
        _imagePath = image.path;
        _selectedImageFile = image;
      });
    }
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('data:image')) {
      return MemoryImage(base64Decode(path.split(',').last));
    } else if (path.startsWith('http')) {
      return NetworkImage(path);
    } else if (path.startsWith('assets/')) {
      return AssetImage(path);
    } else {
      if (kIsWeb) {
        return NetworkImage(path);
      } else {
        return FileImage(File(path));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C0A),
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF050806), Color(0xFF0D1411), Color(0xFF080C0A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _isUploading ? null : _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: _getImageProvider(_imagePath),
                            fit: BoxFit.cover,
                          ),
                          color: const Color(0xFF111A16),
                          border: Border.all(
                            color: const Color(0xFF2C6B46),
                            width: 2,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2C6B46),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _nameController,
                  enabled: !_isUploading,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF1ED760)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isUploading
                        ? null
                        : () async {
                            setState(() {
                              _isUploading = true;
                            });

                            String finalImagePath = _imagePath;

                            if (_selectedImageFile != null) {
                              try {
                                final prefs = await SharedPreferences.getInstance();
                                final empId = prefs.getString('employee_id') ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';
                                
                                if (kIsWeb) {
                                  // On Web, Firebase Storage often hangs due to CORS issues.
                                  // Fallback to storing compressed base64 directly in RTDB.
                                  final bytes = await _selectedImageFile!.readAsBytes();
                                  final base64Image = base64Encode(bytes);
                                  finalImagePath = 'data:image/jpeg;base64,$base64Image';
                                } else {
                                  final storageRef = FirebaseStorage.instance.ref().child('profile_images/$empId.jpg');
                                  await storageRef.putFile(File(_selectedImageFile!.path));
                                  finalImagePath = await storageRef.getDownloadURL();
                                }
                              } catch (e) {
                                debugPrint('Upload failed: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to upload image: $e')),
                                  );
                                  setState(() {
                                    _isUploading = false;
                                  });
                                }
                                return;
                              }
                            }

                            if (context.mounted) {
                              Navigator.pop(context, {
                                'name': _nameController.text,
                                'imagePath': finalImagePath,
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C6B46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
