import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/user_role.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class UserProfileSection extends StatefulWidget {
  final String username;
  final UserRole role;
  const UserProfileSection({super.key, required this.username, required this.role});

  @override
  State<UserProfileSection> createState() => _UserProfileSectionState();
}

class _UserProfileSectionState extends State<UserProfileSection> {
  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final users = prefs.getStringList('users') ?? [];
    final found = users.map((u) => jsonDecode(u)).firstWhere(
      (u) => u['username'] == widget.username && u['role'] == widget.role.name,
      orElse: () => null,
    );
    if (mounted) {
      setState(() {
        user = found;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    Uint8List? avatarBytes;
    if (user!['avatarBase64'] != null && user!['avatarBase64'].toString().isNotEmpty) {
      avatarBytes = base64Decode(user!['avatarBase64']);
    }
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundImage: avatarBytes != null
                          ? MemoryImage(avatarBytes)
                          : (user!['avatarUrl'] != null && user!['avatarUrl'].toString().isNotEmpty)
                              ? NetworkImage(user!['avatarUrl']) as ImageProvider
                              : null,
                      child: (avatarBytes == null && (user!['avatarUrl'] == null || user!['avatarUrl'].toString().isEmpty))
                          ? const Icon(Icons.person, size: 36)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickProfileImage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.camera_alt, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user!['fullName'] ?? '', style: Theme.of(context).textTheme.titleLarge),
                      Text('@${user!['username']} (${user!['role']})', style: const TextStyle(color: Colors.grey)),
                      if (user!['email'] != null && user!['email'].toString().isNotEmpty)
                        Text(user!['email'], style: const TextStyle(color: Colors.black87)),
                      if (user!['phone'] != null && user!['phone'].toString().isNotEmpty)
                        Text(user!['phone'], style: const TextStyle(color: Colors.black87)),
                      if (user!['address'] != null && user!['address'].toString().isNotEmpty)
                        Text(user!['address'], style: const TextStyle(color: Colors.black87)),
                      if (user!['bio'] != null && user!['bio'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(user!['bio'], style: const TextStyle(fontStyle: FontStyle.italic)),
                        ),
                      const SizedBox(height: 8),
                      if (user!['lastLogin'] != null && user!['lastLogin'].toString().isNotEmpty)
                        Text('Last login: ${user!['lastLogin']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (user!['createdAt'] != null && user!['createdAt'].toString().isNotEmpty)
                        Text('Joined: ${user!['createdAt']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (user!['status'] != null && user!['status'].toString().isNotEmpty)
                        Text('Status: ${user!['status']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      // Role-specific fields
                      if (user!['role'] == 'driver') ...[
                        if (user!['vehicleType'] != null && user!['vehicleType'].toString().isNotEmpty)
                          Text('Vehicle: ${user!['vehicleType']}', style: const TextStyle(color: Colors.black87)),
                        if (user!['licenseNumber'] != null && user!['licenseNumber'].toString().isNotEmpty)
                          Text('License: ${user!['licenseNumber']}', style: const TextStyle(color: Colors.black87)),
                      ],
                      if (user!['role'] == 'customer') ...[
                        if (user!['preferredPayment'] != null && user!['preferredPayment'].toString().isNotEmpty)
                          Text('Preferred Payment: ${user!['preferredPayment']}', style: const TextStyle(color: Colors.black87)),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Profile',
                  onPressed: () => _showEditProfileDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    String fullName = user?['fullName'] ?? '';
    String email = user?['email'] ?? '';
    String phone = user?['phone'] ?? '';
    String avatarUrl = user?['avatarUrl'] ?? '';
    String address = user?['address'] ?? '';
    String bio = user?['bio'] ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: fullName,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  onSaved: (value) => fullName = value ?? '',
                ),
                TextFormField(
                  initialValue: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your email';
                    if (!value.contains('@')) return 'Please enter a valid email';
                    return null;
                  },
                  onSaved: (value) => email = value ?? '',
                ),
                TextFormField(
                  initialValue: phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  onSaved: (value) => phone = value ?? '',
                ),
                TextFormField(
                  initialValue: address,
                  decoration: const InputDecoration(labelText: 'Address'),
                  onSaved: (value) => address = value ?? '',
                ),
                TextFormField(
                  initialValue: bio,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  onSaved: (value) => bio = value ?? '',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                // Update user in shared_preferences
                final prefs = await SharedPreferences.getInstance();
                final users = prefs.getStringList('users') ?? [];
                final userIndex = users.indexWhere((u) {
                  final uMap = jsonDecode(u);
                  return uMap['username'] == user!['username'] && uMap['role'] == user!['role'];
                });
                if (userIndex != -1) {
                  final updatedUser = Map<String, dynamic>.from(user!);
                  updatedUser['fullName'] = fullName;
                  updatedUser['email'] = email;
                  updatedUser['phone'] = phone;
                  updatedUser['avatarUrl'] = avatarUrl;
                  updatedUser['address'] = address;
                  updatedUser['bio'] = bio;
                  users[userIndex] = jsonEncode(updatedUser);
                  await prefs.setStringList('users', users);
                  setState(() {
                    user = updatedUser;
                  });
                }
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final base64Image = base64Encode(bytes);
      // Update user in shared_preferences
      final prefs = await SharedPreferences.getInstance();
      final users = prefs.getStringList('users') ?? [];
      final userIndex = users.indexWhere((u) {
        final uMap = jsonDecode(u);
        return uMap['username'] == user!['username'] && uMap['role'] == user!['role'];
      });
      if (userIndex != -1) {
        final updatedUser = Map<String, dynamic>.from(user!);
        updatedUser['avatarBase64'] = base64Image;
        users[userIndex] = jsonEncode(updatedUser);
        await prefs.setStringList('users', users);
        setState(() {
          user = updatedUser;
        });
      }
    }
  }
} 