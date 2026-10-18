import '../ui/app_bottom_nav.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  String _emergencyContactName = '';
  String _emergencyContactPhone = '';
  bool _isLoadingContact = true;

  Timer? _holdTimer;
  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  bool _isSosActivated = false;
  bool _isLongPressing = false;

  static const Color primaryBlue = Color(0xFF2161F5);
  static const Color green = Color(0xFF00B956);
  static const Color red = Color(0xFFE53935);
  static const Color darkNavy = Color(0xFF0B2545);
  static const Color lightBackground = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadEmergencyContact();
  }

  // ============================================================
  // EMERGENCY CONTACT
  // ============================================================

  Future<void> _loadEmergencyContact() async {
    if (mounted) {
      setState(() {
        _isLoadingContact = true;
      });
    }

    try {
      final response = await ApiService.getEmergencyContact();

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _emergencyContactName =
              data['emergency_contact_name']?.toString() ?? '';
          _emergencyContactPhone =
              data['emergency_contact_phone']?.toString() ?? '';
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load emergency contact.')),
      );
    }

    if (!mounted) return;

    setState(() {
      _isLoadingContact = false;
    });
  }

  Future<bool> _saveEmergencyContact({
    required String name,
    required String phone,
  }) async {
    try {
      final response = await ApiService.updateEmergencyContact(
        name: name,
        phone: phone,
      );

      if (!mounted) return false;

      if (response.statusCode == 200) {
        setState(() {
          _emergencyContactName = name;
          _emergencyContactPhone = phone;
        });

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  void _showEmergencyContactDialog() {
    final nameController = TextEditingController(text: _emergencyContactName);

    final phoneController = TextEditingController(text: _emergencyContactPhone);

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;

        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setDialogState,
              ) {
                return AlertDialog(
                  title: Text(
                    _emergencyContactName.isEmpty
                        ? 'Add Emergency Contact'
                        : 'Edit Emergency Contact',
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          enabled: !isSaving,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Contact Name',
                            prefixIcon: Icon(Icons.person_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: phoneController,
                          enabled: !isSaving,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSaving
                          ? null
                          : () {
                              Navigator.pop(dialogContext);
                            },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final phone = phoneController.text.trim();

                              if (name.isEmpty || phone.isEmpty) {
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter both name and phone number.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                isSaving = true;
                              });

                              final saved = await _saveEmergencyContact(
                                name: name,
                                phone: phone,
                              );

                              if (!dialogContext.mounted) return;

                              if (saved) {
                                Navigator.pop(dialogContext);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Emergency contact saved successfully.',
                                    ),
                                  ),
                                );
                              } else {
                                setDialogState(() {
                                  isSaving = false;
                                });

                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to save emergency contact.',
                                    ),
                                  ),
                                );
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                );
              },
        );
      },
    ).then((_) {
      nameController.dispose();
      phoneController.dispose();
    });
  }

  // ============================================================
  // PHONE CALLS
  // ============================================================

  Future<void> _callEmergencyContact({
    BuildContext? dialogContext,
    bool continueTo999 = false,
  }) async {
    if (_emergencyContactPhone.isEmpty) {
      _showEmergencyContactDialog();
      return;
    }

    final uri = Uri(scheme: 'tel', path: _emergencyContactPhone);

    if (dialogContext != null && dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }

    try {
      if (!await launchUrl(uri)) throw Exception('Dialler unavailable');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open phone dialler.')),
      );

      return;
    }

    if (!continueTo999) return;

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    _showCall999Dialog();
  }

  void _showCall999Dialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Call Emergency Services?'),
          content: const Text(
            'If the situation is serious, call 999 for emergency assistance.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _deactivateSos();
              },
              child: const Text("I Don't Need 999"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);

                final uri = Uri(scheme: 'tel', path: '999');

                try {
                  if (!await launchUrl(uri)) {
                    throw Exception('Dialler unavailable');
                  }
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to open phone dialler.'),
                    ),
                  );
                }
              },
              child: const Text('Call 999'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SOS
  // ============================================================

  void _showSosActivationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (_emergencyContactPhone.isEmpty) {
          return AlertDialog(
            title: const Text('Emergency SOS Activated'),
            content: const Text(
              'No emergency contact has been added. '
              'Please add an emergency contact first.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _deactivateSos();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showEmergencyContactDialog();
                },
                child: const Text('Add Contact'),
              ),
            ],
          );
        }

        return AlertDialog(
          title: const Text('Emergency SOS Activated'),
          content: Text('Would you like to call $_emergencyContactName first?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _deactivateSos();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                _callEmergencyContact(
                  dialogContext: dialogContext,
                  continueTo999: true,
                );
              },
              child: const Text('Call Emergency Contact'),
            ),
          ],
        );
      },
    );
  }

  void _activateSos() {
    setState(() {
      _isSosActivated = true;
      _isLongPressing = false;
    });

    _showSosActivationDialog();
  }

  void _deactivateSos() {
    if (!mounted) return;

    setState(() {
      _isSosActivated = false;
      _isLongPressing = false;
    });
  }

  void _onSosLongPressStart() {
    setState(() {
      _isLongPressing = true;
    });

    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      if (_isLongPressing && !_isSosActivated) {
        _activateSos();
      }
    });
  }

  void _onSosLongPressEnd() {
    _holdTimer?.cancel();
    if (!_isSosActivated && mounted) {
      setState(() {
        _isLongPressing = false;
      });
    }
  }

  // ============================================================
  // SHARE LOCATION
  // ============================================================

  Future<void> _shareLocation() async {
    if (_emergencyContactPhone.isEmpty) {
      _showEmergencyContactDialog();
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        final openSettings = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Location Services Disabled'),
              content: const Text(
                'Please enable location services to share '
                'your current location.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            );
          },
        );

        if (openSettings == true) {
          await Geolocator.openLocationSettings();
        }

        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission was denied.')),
        );

        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        final openSettings = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text(
                'Location permission has been permanently denied. '
                'Please enable it in your phone settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            );
          },
        );

        if (openSettings == true) {
          await Geolocator.openAppSettings();
        }

        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      final latitude = position.latitude;
      final longitude = position.longitude;

      final mapsLink =
          'https://www.google.com/maps/search/?api=1'
          '&query=$latitude,$longitude';

      final message = Uri.encodeComponent(
        'I may need assistance. Here is my current location:\n'
        '$mapsLink',
      );

      final smsUri = Uri(
        scheme: 'sms',
        path: _emergencyContactPhone,
        queryParameters: {'body': Uri.decodeComponent(message)},
      );

      try {
        await launchUrl(smsUri);
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open messaging app.')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to retrieve your location.')),
      );
    }
  }

  // ============================================================
  // EMERGENCY CONTACT CARD
  // ============================================================

  Widget _buildEmergencyContactCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.contact_emergency_rounded,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Emergency Contact',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: darkNavy,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isLoadingContact
                    ? null
                    : _showEmergencyContactDialog,
                icon: const Icon(Icons.edit_rounded),
                color: primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoadingContact)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_emergencyContactName.isEmpty ||
              _emergencyContactPhone.isEmpty)
            const Text(
              'No emergency contact added yet.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            )
          else ...[
            Text(
              _emergencyContactName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: darkNavy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _emergencyContactPhone,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // SOS BUTTON
  // ============================================================

  Widget _buildSosButton() {
    return GestureDetector(
      onTapDown: (_) {
        _onSosLongPressStart();
      },
      onTapUp: (_) {
        _onSosLongPressEnd();
      },
      onTapCancel: _onSosLongPressEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 210,
        height: 210,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isSosActivated ? red : const Color(0xFFFFE8E8),
          border: Border.all(color: red, width: 5),
          boxShadow: [
            BoxShadow(
              color: red.withValues(alpha: _isLongPressing ? 0.35 : 0.15),
              blurRadius: _isLongPressing ? 30 : 15,
              spreadRadius: _isLongPressing ? 8 : 3,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sos_rounded,
                size: 64,
                color: _isSosActivated ? Colors.white : red,
              ),
              const SizedBox(height: 8),
              Text(
                _isSosActivated ? 'SOS ACTIVE' : 'SOS',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: _isSosActivated ? Colors.white : red,
                ),
              ),
              if (!_isSosActivated)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Hold for 3 seconds',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMERGENCY ACTION
  // ============================================================

  Widget _buildEmergencyAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 25),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: darkNavy,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigationBar() {
    return const AppBottomNav(index: 3);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: lightBackground,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Emergency SOS',
          style: TextStyle(color: darkNavy, fontWeight: FontWeight.bold),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Column(
            children: [
              const Text(
                'Emergency Assistance',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: darkNavy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hold the SOS button for 3 seconds to activate emergency mode.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 25),

              _buildSosButton(),

              const SizedBox(height: 28),

              if (_isSosActivated)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8E8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: red.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: red),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'SOS mode is active. Emergency actions are available below.',
                          style: TextStyle(
                            color: red,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              _buildEmergencyContactCard(),

              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Emergency Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: darkNavy,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _buildEmergencyAction(
                icon: Icons.phone_rounded,
                title: 'Call Emergency Contact',
                subtitle: _emergencyContactPhone.isEmpty
                    ? 'Add an emergency contact first'
                    : 'Call $_emergencyContactName',
                iconColor: green,
                onTap: _callEmergencyContact,
              ),

              const SizedBox(height: 10),

              _buildEmergencyAction(
                icon: Icons.location_on_rounded,
                title: 'Share My Location',
                subtitle: _emergencyContactPhone.isEmpty
                    ? 'Add an emergency contact first'
                    : 'Send your current location by SMS',
                iconColor: primaryBlue,
                onTap: _shareLocation,
              ),

              const SizedBox(height: 10),

              _buildEmergencyAction(
                icon: Icons.phone_in_talk_rounded,
                title: 'Call 999',
                subtitle: 'Contact Malaysian emergency services',
                iconColor: red,
                onTap: _showCall999Dialog,
              ),

              const SizedBox(height: 25),

              const Text(
                'Only use SOS during a genuine emergency.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}
