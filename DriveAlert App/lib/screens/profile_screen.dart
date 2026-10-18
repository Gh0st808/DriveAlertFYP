import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color primaryBlue = Color(0xFF2161F5);
  static const Color darkNavy = Color(0xFF0B2545);
  static const Color lightBackground = Color(0xFFF8FAFC);

  String _name = '';
  String _email = '';
  String _phone = '';
  String _vehicle = '';

  String? _profileImageUrl;

  bool _monitoringActive = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final profileResponse = await ApiService.getProfile();
      final accountResponse = await ApiService.getCurrentUser();
      final statusResponse = await ApiService.monitorStatus();

      if (profileResponse.statusCode != 200 ||
          accountResponse.statusCode != 200) {
        throw Exception('Failed to load profile.');
      }

      final profileData =
          jsonDecode(profileResponse.body) as Map<String, dynamic>;

      final accountData =
          jsonDecode(accountResponse.body) as Map<String, dynamic>;

      String? imageUrl;

      final profilePicture = profileData['profile_picture']?.toString();

      if (profilePicture != null && profilePicture.isNotEmpty) {
        if (profilePicture.startsWith('http')) {
          imageUrl = profilePicture;
        } else {
          imageUrl =
              '${ApiService.baseUrl.replaceAll('/api', '')}$profilePicture';
        }
      }

      final vehicle = profileData['vehicle_model']?.toString() ?? '';
      final monitoring =
          statusResponse.statusCode == 200 &&
          jsonDecode(statusResponse.body)['monitoring'] == true;
      if (!mounted) return;

      setState(() {
        _name = profileData['full_name']?.toString() ?? '';
        _email = accountData['email']?.toString() ?? '';
        _phone = profileData['phone_number']?.toString() ?? '';
        _vehicle = vehicle;
        _profileImageUrl = imageUrl;
        _monitoringActive = monitoring;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load profile information.')),
      );
    }
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );

    if (mounted && result == true) {
      await _loadProfile();
    }
  }

  Widget _buildProfileImage() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 44,
        backgroundColor: const Color(0xFFE1EBFF),
        backgroundImage: NetworkImage(_profileImageUrl!),
        onBackgroundImageError: (_, _) {},
        child: null,
      );
    }

    return const CircleAvatar(
      radius: 44,
      backgroundColor: Color(0xFFE1EBFF),
      child: Icon(Icons.person_rounded, color: primaryBlue, size: 48),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: darkNavy,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    Color valueColor = darkNavy,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE1EBFF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? 'Not set' : value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: value.isEmpty ? const Color(0xFF94A3B8) : valueColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          _buildProfileImage(),
          const SizedBox(height: 14),
          Text(
            _name.isEmpty ? 'DriveAlert User' : _name,
            style: const TextStyle(
              color: darkNavy,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'DriveAlert User',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8EF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle_rounded, color: Color(0xFF00B956), size: 8),
                SizedBox(width: 6),
                Text(
                  'Account Active',
                  style: TextStyle(
                    color: Color(0xFF008A40),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      appBar: AppBar(
        backgroundColor: lightBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: darkNavy,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: darkNavy,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : RefreshIndicator(
              onRefresh: _loadProfile,
              color: primaryBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                child: Column(
                  children: [
                    _buildProfileCard(),

                    const SizedBox(height: 20),

                    _buildSectionTitle('Personal Information'),

                    const SizedBox(height: 10),

                    _buildInfoCard(
                      icon: Icons.person_outline_rounded,
                      title: 'Name',
                      value: _name,
                    ),

                    const SizedBox(height: 9),

                    _buildInfoCard(
                      icon: Icons.email_rounded,
                      title: 'Email',
                      value: _email,
                    ),

                    const SizedBox(height: 9),

                    _buildInfoCard(
                      icon: Icons.phone_rounded,
                      title: 'Phone',
                      value: _phone,
                    ),

                    const SizedBox(height: 20),

                    _buildSectionTitle('Driving Information'),

                    const SizedBox(height: 10),

                    _buildInfoCard(
                      icon: Icons.directions_car_rounded,
                      title: 'Vehicle',
                      value: _vehicle,
                    ),

                    const SizedBox(height: 9),

                    _buildInfoCard(
                      icon: Icons.monitor_heart_rounded,
                      title: 'Monitoring',
                      value: _monitoringActive ? 'Active' : 'Off',
                      valueColor: _monitoringActive
                          ? const Color(0xFF00B956)
                          : const Color(0xFF64748B),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _openEditProfile,
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
