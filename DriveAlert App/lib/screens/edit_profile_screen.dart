import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _vehicleController = TextEditingController();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  String? _profileImageUrl;

  bool _monitoringActive = false;

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  // =========================
  // Load Profile
  // =========================

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profileResponse = await ApiService.getProfile();

      final accountResponse = await ApiService.getCurrentUser();

      final statusResponse = await ApiService.monitorStatus();

      if (profileResponse.statusCode != 200) {
        throw Exception('Failed to load profile.');
      }

      if (accountResponse.statusCode != 200) {
        throw Exception('Failed to load account.');
      }

      final profileData = profileResponse.body.isNotEmpty
          ? _decodeJson(profileResponse.body)
          : <String, dynamic>{};

      final accountData = accountResponse.body.isNotEmpty
          ? _decodeJson(accountResponse.body)
          : <String, dynamic>{};

      if (!mounted) return;
      _nameController.text = profileData['full_name'] ?? '';

      _phoneController.text = profileData['phone_number'] ?? '';

      _emailController.text = accountData['email'] ?? '';

      _profileImageUrl = profileData['profile_picture'];

      _vehicleController.text = profileData['vehicle_model'] ?? '';
      _monitoringActive =
          statusResponse.statusCode == 200 &&
          jsonDecode(statusResponse.body)['monitoring'] == true;
    } catch (e) {
      _errorMessage = 'Unable to load your profile.';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  dynamic _decodeJson(String body) {
    try {
      return _jsonDecode(body);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  dynamic _jsonDecode(String body) {
    return const JsonDecoder().convert(body);
  }

  // =========================
  // Pick Image
  // =========================

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    } catch (e) {
      _showMessage('Unable to select image.', isError: true);
    }
  }

  // =========================
  // Save Profile
  // =========================

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();

    final email = _emailController.text.trim();

    final phone = _phoneController.text.trim();

    final vehicle = _vehicleController.text.trim();

    if (name.isEmpty) {
      _showMessage('Please enter your full name.', isError: true);
      return;
    }

    if (email.isEmpty) {
      _showMessage('Please enter your email.', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // =========================
      // Update Account
      // =========================

      final profileResponse = await ApiService.updateProfile(
        fullName: name,
        phoneNumber: phone,
        profilePicture: _selectedImage,
        vehicleModel: vehicle,
        email: email,
      );

      if (profileResponse.statusCode < 200 ||
          profileResponse.statusCode >= 300) {
        throw Exception('Failed to update profile.');
      }

      // =========================
      // Update Vehicle
      // =========================

      if (!mounted) {
        return;
      }

      _showMessage('Profile updated successfully.');

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Unable to save profile changes.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // =========================
  // Message
  // =========================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // =========================
  // Profile Image
  // =========================

  Widget _buildProfileImage() {
    if (_selectedImage != null) {
      return CircleAvatar(
        radius: 55,
        backgroundImage: MemoryImage(_selectedImageBytes!),
      );
    }

    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 55,
        backgroundImage: NetworkImage(_profileImageUrl!),
      );
    }

    return const CircleAvatar(
      radius: 55,
      child: Icon(Icons.person_rounded, size: 55),
    );
  }

  // =========================
  // Text Field
  // =========================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2161F5), width: 2),
        ),
      ),
    );
  }

  // =========================
  // Monitoring Card
  // =========================

  Widget _buildMonitoringCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _monitoringActive
            ? const Color(0xFFE8F8EF)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _monitoringActive
                  ? const Color(0xFF00B956)
                  : const Color(0xFF94A3B8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _monitoringActive
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Driving Monitoring',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _monitoringActive ? 'Currently Active' : 'Currently Off',
                  style: TextStyle(
                    color: _monitoringActive
                        ? const Color(0xFF00B956)
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _monitoringActive
                  ? const Color(0xFF00B956)
                  : const Color(0xFF94A3B8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _monitoringActive ? 'ACTIVE' : 'OFF',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // Build
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        foregroundColor: const Color(0xFF0B2545),
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_rounded,
                      size: 50,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadProfile,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile picture
                  Center(
                    child: Stack(
                      children: [
                        _buildProfileImage(),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2161F5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Center(
                    child: TextButton(
                      onPressed: _pickImage,
                      child: const Text('Change Profile Picture'),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B2545),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_rounded,
                  ),

                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Driving Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B2545),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _vehicleController,
                    label: 'Vehicle',
                    icon: Icons.directions_car_rounded,
                  ),

                  const SizedBox(height: 18),

                  _buildMonitoringCard(),

                  const SizedBox(height: 32),

                  // Save
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2161F5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Cancel
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              Navigator.pop(context);
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0B2545),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
