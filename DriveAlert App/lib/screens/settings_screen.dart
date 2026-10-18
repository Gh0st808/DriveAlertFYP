import '../services/user_message.dart';
import '../ui/assistant_bubble.dart';
import '../ui/app_bottom_nav.dart';
import '../services/notification_service.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ============================================================
  // DRIVEALERT COLOURS
  // ============================================================

  static const Color primaryBlue = Color(0xFF2161F5);
  static const Color darkNavy = Color(0xFF0B2545);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color background = Color(0xFFF8FAFC);
  static const Color lightBlue = Color(0xFFE1EBFF);

  // ============================================================
  // SETTINGS
  // ============================================================

  bool detectionEnabled = true;
  bool alertSoundEnabled = true;
  bool notificationsEnabled = false;
  bool _changingPush = false;
  bool _savingPreferences = false;

  double detectionSensitivity = 0.5;

  // ============================================================
  // ACCOUNT / DEVICE DATA
  // ============================================================

  String username = '';
  String email = '';

  List<dynamic> devices = [];

  bool isLoadingAccount = true;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  // ============================================================
  // LOAD ACCOUNT + DEVICE DATA
  // ============================================================

  Future<void> _loadAccountData() async {
    if (mounted) {
      setState(() {
        isLoadingAccount = true;
      });
    }

    try {
      // ----------------------------------------------------------
      // CURRENT USER
      // ----------------------------------------------------------

      var userResponse = await ApiService.getCurrentUser();

      if (userResponse.statusCode == 401) {
        final refreshed = await ApiService.refreshAccessToken();

        if (refreshed) {
          userResponse = await ApiService.getCurrentUser();
        }
      }

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);

        username = userData['username'] ?? '';
        email = userData['email'] ?? '';
        final profile = userData['profile'] ?? {};
        notificationsEnabled = profile['push_notifications_enabled'] == true;
        detectionEnabled = profile['detection_enabled'] ?? true;
        alertSoundEnabled = profile['alert_sound_enabled'] ?? true;
        detectionSensitivity = profile['sensitivity'] == 'Low'
            ? 0
            : profile['sensitivity'] == 'High'
            ? 1
            : 0.5;
      }

      // ----------------------------------------------------------
      // REGISTERED DEVICES
      // ----------------------------------------------------------

      var deviceResponse = await ApiService.getDevices();

      if (deviceResponse.statusCode == 401) {
        final refreshed = await ApiService.refreshAccessToken();

        if (refreshed) {
          deviceResponse = await ApiService.getDevices();
        }
      }

      if (deviceResponse.statusCode == 200) {
        devices = jsonDecode(deviceResponse.body);
      }

      if (!mounted) return;

      setState(() {
        isLoadingAccount = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLoadingAccount = false;
      });
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      bottomNavigationBar: _buildBottomNavigation(),
      floatingActionButton: const AssistantBubble(),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 105),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // HEADER
                  // ==================================================
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: darkNavy,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Manage your DriveAlert preferences',
                    style: TextStyle(fontSize: 13, color: secondaryText),
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // ACCOUNT
                  // ==================================================
                  _buildSectionTitle('Account'),

                  const SizedBox(height: 10),

                  _buildSettingsCard(
                    children: [
                      _buildNavigationTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Profile',
                        subtitle: isLoadingAccount
                            ? 'Loading account information...'
                            : username.isNotEmpty
                            ? '$username â€¢ $email'
                            : 'View your account information',
                        onTap: () {
                          Navigator.pushNamed(context, '/profile');
                        },
                      ),

                      _buildDivider(),

                      _buildNavigationTile(
                        icon: Icons.lock_outline_rounded,
                        title: 'Change Password',
                        subtitle: 'Update your account password',
                        onTap: () {
                          Navigator.pushNamed(context, '/change-password');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ==================================================
                  // REGISTERED DEVICES
                  // ==================================================
                  _buildSectionTitle('Registered Devices'),

                  const SizedBox(height: 10),

                  _buildSettingsCard(
                    children: [
                      if (isLoadingAccount)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: primaryBlue,
                            ),
                          ),
                        )
                      else if (devices.isEmpty)
                        _buildNavigationTile(
                          icon: Icons.devices_other_rounded,
                          title: 'No Device Registered',
                          subtitle: 'Register your DriveAlert Raspberry Pi',
                          onTap: _showRegisterDeviceDialog,
                        )
                      else ...[
                        for (int i = 0; i < devices.length; i++) ...[
                          _buildDeviceTile(devices[i]),
                          if (i < devices.length - 1) _buildDivider(),
                        ],

                        _buildDivider(),

                        _buildNavigationTile(
                          icon: Icons.add_circle_outline_rounded,
                          title: 'Register Another Device',
                          subtitle: 'Add another DriveAlert device',
                          onTap: _showRegisterDeviceDialog,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ==================================================
                  // DRIVING & DETECTION
                  // ==================================================
                  _buildSectionTitle('Driving & Detection'),

                  const SizedBox(height: 10),

                  _buildSettingsCard(
                    children: [
                      _buildSwitchTile(
                        icon: Icons.remove_red_eye_rounded,
                        title: 'Microsleep Detection',
                        subtitle: 'Enable real-time driver monitoring',
                        value: detectionEnabled,
                        onChanged: (value) =>
                            _savePreferences(detection: value),
                      ),

                      _buildDivider(),

                      _buildNavigationTile(
                        icon: Icons.tune_rounded,
                        title: 'Detection Sensitivity',
                        subtitle: _getSensitivityLabel(),
                        onTap: _showSensitivityDialog,
                      ),

                      _buildDivider(),

                      _buildSwitchTile(
                        icon: Icons.volume_up_rounded,
                        title: 'Alert Sound',
                        subtitle:
                            'Play the phone alarm when microsleep is detected',
                        value: alertSoundEnabled,
                        onChanged: (value) => _savePreferences(sound: value),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ==================================================
                  // NOTIFICATIONS
                  // ==================================================
                  _buildSectionTitle('Notifications'),

                  const SizedBox(height: 10),

                  _buildSettingsCard(
                    children: [
                      _buildSwitchTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Push Notifications',
                        subtitle: 'Receive recorded fatigue alerts on Android',
                        value: notificationsEnabled,
                        onChanged: (value) => _changePush(value),
                      ),

                      _buildDivider(),

                      _buildNavigationTile(
                        icon: Icons.notifications_active_rounded,
                        title: 'Notification Preferences',
                        subtitle: 'Manage permission and test delivery',
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/notification-settings',
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ==================================================
                  // PRIVACY & SECURITY
                  // ==================================================
                  _buildSectionTitle('Privacy & Security'),

                  const SizedBox(height: 10),

                  _buildSettingsCard(
                    children: [
                      _buildNavigationTile(
                        icon: Icons.privacy_tip_rounded,
                        title: 'Privacy',
                        subtitle: 'Manage your data and privacy',
                        onTap: () {
                          _showComingSoon(
                            'DriveAlert stores your account, journey details and warning history. Live camera images are not saved. Profile photos are saved only when you upload them. Optional notifications use a delivery service. Chat messages and any warning summary you choose to share go to our AI service. Video and contacts are not shared with the assistant.',
                          );
                        },
                      ),

                      _buildDivider(),

                      _buildNavigationTile(
                        icon: Icons.logout_rounded,
                        title: 'Sign Out',
                        subtitle: 'Sign out of your DriveAlert account',
                        iconColor: Colors.redAccent,
                        onTap: _showSignOutDialog,
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ==================================================
                  // ABOUT
                  // ==================================================
                  _buildSectionTitle('About'),

                  const SizedBox(height: 10),

                  _buildSettingsCard(
                    children: [
                      _buildNavigationTile(
                        icon: Icons.info_outline_rounded,
                        title: 'About DriveAlert',
                        subtitle: 'Learn more about DriveAlert',
                        onTap: () {
                          _showComingSoon(
                            'DriveAlert monitors eye closure and records fatigue warnings to help you review your journeys. It supports safer habits and does not replace your judgement or regular rest breaks.',
                          );
                        },
                      ),

                      _buildDivider(),

                      _buildNavigationTile(
                        icon: Icons.code_rounded,
                        title: 'Version',
                        subtitle: 'DriveAlert v1.0.0',
                        showArrow: false,
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // FOOTER
                  // ==================================================
                  const Center(
                    child: Text(
                      'DriveAlert',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: secondaryText,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Center(
                    child: Text(
                      'Drive safer. Stay alert.',
                      style: TextStyle(fontSize: 11, color: secondaryText),
                    ),
                  ),
                ],
              ),
            ),

            // ====================================================
            // FLOATING BOTTOM NAVIGATION
            // ====================================================
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: darkNavy,
      ),
    );
  }

  // ============================================================
  // DEVICE TILE
  // ============================================================

  Widget _buildDeviceTile(dynamic device) {
    final int? deviceId = device['id'];

    final String name = device['name'] ?? 'DriveAlert Device';

    final String registeredDeviceId = device['device_id'] ?? 'Unknown';

    final bool isActive = device['is_active'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          // --------------------------------------------------------
          // DEVICE ICON
          // --------------------------------------------------------
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: lightBlue,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.memory_rounded,
              color: primaryBlue,
              size: 21,
            ),
          ),

          const SizedBox(width: 14),

          // --------------------------------------------------------
          // DEVICE INFORMATION
          // --------------------------------------------------------
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: darkNavy,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  registeredDeviceId,
                  style: const TextStyle(fontSize: 11.5, color: secondaryText),
                ),

                const SizedBox(height: 5),

                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? Colors.green : Colors.grey,
                      ),
                    ),

                    const SizedBox(width: 5),

                    Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.green : secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --------------------------------------------------------
          // DELETE BUTTON
          // --------------------------------------------------------
          IconButton(
            tooltip: 'Delete device',
            onPressed: deviceId == null
                ? null
                : () {
                    _showDeleteDeviceDialog(
                      deviceId: deviceId,
                      deviceName: name,
                    );
                  },
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REGISTER DEVICE DIALOG
  // ============================================================

  void _showRegisterDeviceDialog() {
    final nameController = TextEditingController(
      text: 'DriveAlert Raspberry Pi',
    );

    // Empty by default so an existing device ID is not
    // accidentally registered again.
    final deviceIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isRegistering = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,

              title: const Text(
                'Register Device',
                style: TextStyle(color: darkNavy, fontWeight: FontWeight.bold),
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Device Name',
                      prefixIcon: Icon(Icons.devices_other_rounded),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: deviceIdController,
                    decoration: const InputDecoration(
                      labelText: 'Device ID',
                      hintText: 'e.g. DRIVEALERT-PI-003',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: isRegistering
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: secondaryText),
                  ),
                ),

                TextButton(
                  onPressed: isRegistering
                      ? null
                      : () async {
                          final name = nameController.text.trim();

                          final newDeviceId = deviceIdController.text.trim();

                          if (name.isEmpty || newDeviceId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter both device name and device ID.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );

                            return;
                          }

                          // ------------------------------------------------
                          // CHECK FOR DUPLICATE DEVICE ID LOCALLY
                          // ------------------------------------------------

                          final duplicate = devices.any(
                            (device) =>
                                device['device_id']?.toString().toLowerCase() ==
                                newDeviceId.toLowerCase(),
                          );

                          if (duplicate) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'This device is already registered.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );

                            return;
                          }

                          // ------------------------------------------------
                          // IMPORTANT:
                          // Capture NavigatorState and ScaffoldMessengerState
                          // BEFORE the async gap.
                          // ------------------------------------------------

                          final navigator = Navigator.of(dialogContext);

                          final messenger = ScaffoldMessenger.of(context);

                          setDialogState(() {
                            isRegistering = true;
                          });

                          try {
                            final response = await ApiService.createDevice(
                              name: name,
                              deviceId: newDeviceId,
                            );

                            if (!mounted) return;

                            if (response.statusCode == 201) {
                              navigator.pop();

                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Device registered successfully.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );

                              _loadAccountData();
                            } else {
                              setDialogState(() {
                                isRegistering = false;
                              });

                              String message = 'Failed to register device.';

                              try {
                                final data = jsonDecode(response.body);

                                if (data is Map) {
                                  if (data['device_id'] is List) {
                                    message = data['device_id'][0].toString();
                                  } else if (data['detail'] != null) {
                                    message = data['detail'].toString();
                                  }
                                }
                              } catch (_) {}

                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(UserMessage.from(message)),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;

                            setDialogState(() {
                              isRegistering = false;
                            });

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Unable to register your device. Please try again.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  child: isRegistering
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryBlue,
                          ),
                        )
                      : const Text(
                          'Register',
                          style: TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // DELETE DEVICE DIALOG
  // ============================================================

  void _showDeleteDeviceDialog({
    required int deviceId,
    required String deviceName,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isDeleting = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,

              title: const Text(
                'Delete Device?',
                style: TextStyle(color: darkNavy, fontWeight: FontWeight.bold),
              ),

              content: Text(
                'Are you sure you want to remove "$deviceName" from your account?\n\nThis will unregister the device from DriveAlert.',
                style: const TextStyle(color: secondaryText, height: 1.4),
              ),

              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: secondaryText),
                  ),
                ),

                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          // ------------------------------------------------
                          // Capture these BEFORE await.
                          // ------------------------------------------------

                          final navigator = Navigator.of(dialogContext);

                          final messenger = ScaffoldMessenger.of(context);

                          setDialogState(() {
                            isDeleting = true;
                          });

                          try {
                            var response = await ApiService.deleteDevice(
                              deviceId,
                            );

                            // ------------------------------------------------
                            // Refresh JWT if necessary.
                            // ------------------------------------------------

                            if (response.statusCode == 401) {
                              final refreshed =
                                  await ApiService.refreshAccessToken();

                              if (refreshed) {
                                response = await ApiService.deleteDevice(
                                  deviceId,
                                );
                              }
                            }

                            if (!mounted) return;

                            if (response.statusCode == 204 ||
                                response.statusCode == 200) {
                              navigator.pop();

                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Device removed successfully.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );

                              _loadAccountData();
                            } else {
                              setDialogState(() {
                                isDeleting = false;
                              });

                              String message = 'Failed to remove device.';

                              try {
                                final data = jsonDecode(response.body);

                                if (data is Map && data['detail'] != null) {
                                  message = data['detail'].toString();
                                }
                              } catch (_) {}

                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(UserMessage.from(message)),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;

                            setDialogState(() {
                              isDeleting = false;
                            });

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Unable to remove your device. Please try again.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.redAccent,
                          ),
                        )
                      : const Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // SETTINGS CARD
  // ============================================================

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(children: children),
    );
  }

  // ============================================================
  // NAVIGATION TILE
  // ============================================================

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    bool showArrow = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: lightBlue,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: iconColor ?? primaryBlue, size: 21),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: darkNavy,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),

            if (showArrow)
              const Icon(
                Icons.chevron_right_rounded,
                color: secondaryText,
                size: 21,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SWITCH TILE
  // ============================================================

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: lightBlue,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: primaryBlue, size: 21),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: darkNavy,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: secondaryText),
                ),
              ],
            ),
          ),

          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: primaryBlue,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 72),
      child: Divider(height: 1, thickness: 0.7, color: Color(0xFFE8EDF5)),
    );
  }

  // ============================================================
  // SENSITIVITY LABEL
  // ============================================================

  String _getSensitivityLabel() =>
      _getSensitivityLabelForValue(detectionSensitivity);

  // ============================================================
  // SENSITIVITY DIALOG
  // ============================================================

  void _showSensitivityDialog() {
    double temporaryValue = detectionSensitivity;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,

              title: const Text(
                'Detection Sensitivity',
                style: TextStyle(color: darkNavy, fontWeight: FontWeight.bold),
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getSensitivityLabelForValue(temporaryValue),
                    style: const TextStyle(
                      color: primaryBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Slider(
                    value: temporaryValue,
                    min: 0,
                    max: 1,
                    divisions: 2,
                    activeColor: primaryBlue,
                    label: _getSensitivityLabelForValue(temporaryValue),
                    onChanged: (value) {
                      setDialogState(() {
                        temporaryValue = value;
                      });
                    },
                  ),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Low',
                        style: TextStyle(fontSize: 12, color: secondaryText),
                      ),
                      Text(
                        'High',
                        style: TextStyle(fontSize: 12, color: secondaryText),
                      ),
                    ],
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: secondaryText),
                  ),
                ),

                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _savePreferences(sensitivity: temporaryValue);
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // SENSITIVITY VALUE LABEL
  // ============================================================

  String _getSensitivityLabelForValue(double value) {
    if (value <= 0.25) return 'Low';
    if (value <= 0.75) return 'Medium';
    return 'High';
  }

  // ============================================================
  // COMING SOON MESSAGE
  // ============================================================

  Future<void> _savePreferences({
    bool? detection,
    bool? sound,
    double? sensitivity,
  }) async {
    if (_savingPreferences) return;
    _savingPreferences = true;
    try {
      final value = sensitivity ?? detectionSensitivity;
      final response = await ApiService.savePreferences({
        'detection_enabled': detection ?? detectionEnabled,
        'alert_sound_enabled': sound ?? alertSoundEnabled,
        'sensitivity': _getSensitivityLabelForValue(value),
      });
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          detectionEnabled = detection ?? detectionEnabled;
          alertSoundEnabled = sound ?? alertSoundEnabled;
          detectionSensitivity = value;
        });
        _showComingSoon(
          'Preferences saved. Open Monitor to confirm the device state.',
        );
      } else {
        _showComingSoon(ApiService.errorText(response));
      }
    } catch (_) {
      if (mounted) _showComingSoon('Unable to save preferences.');
    } finally {
      _savingPreferences = false;
    }
  }

  Future<void> _changePush(bool enabled) async {
    if (_changingPush) return;
    _changingPush = true;
    try {
      String message;
      if (enabled) {
        message = await NotificationService.enable();
      } else {
        await NotificationService.disable();
        message = 'Push notifications disabled.';
      }
      if (!mounted) return;
      setState(() {
        notificationsEnabled = enabled;
      });
      _showComingSoon(message);
    } catch (error) {
      if (mounted) {
        _showComingSoon(UserMessage.from(error));
      }
    } finally {
      _changingPush = false;
    }
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,

          title: const Text(
            'Sign Out',
            style: TextStyle(color: darkNavy, fontWeight: FontWeight.bold),
          ),

          content: const Text(
            'Are you sure you want to sign out?',
            style: TextStyle(color: secondaryText),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: secondaryText),
              ),
            ),

            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await NotificationService.beforeLogout();
                if (!mounted) return;

                ApiService.accessToken = null;
                ApiService.refreshToken = null;

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // FLOATING BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return const AppBottomNav(index: 4);
  }

  // ============================================================
  // NAVIGATION ITEM
  // ============================================================
}
