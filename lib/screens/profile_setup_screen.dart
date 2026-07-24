import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isEditing;

  const ProfileSetupScreen({super.key, this.isEditing = false});

  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();
  String? _selectedHostel;
  bool _isLoading = false;

  final List<String> _hostels = [
    "Valmiki", "Vishwakarma", "Vyas", "Shankar", 
    "Ram", "Krishna", "Ganga", "Meera", 
    "Buddh", "Gandhi", "Gautam", "Malviya"
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        _phoneController.text = data['phoneNumber'] ?? '';
        _studentIdController.text = data['studentId'] ?? '';
        if (_hostels.contains(data['hostel'])) {
          _selectedHostel = data['hostel'];
        }
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'phoneNumber': _phoneController.text.trim(),
        'studentId': _studentIdController.text.trim(),
        'hostel': _selectedHostel,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      if (widget.isEditing) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!"), backgroundColor: kSurface1));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving profile: $e"), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: rentXAppBar(
        context,
        widget.isEditing ? "Edit Profile" : "Complete Profile",
        subtitle: "RentX Account Information",
      ),
      body: _isLoading && widget.isEditing
          ? const Center(child: CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEditing ? "Update your details below." : "Please provide your campus details to continue.",
                      style: const TextStyle(color: kTextMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    rentXSectionLabel("CONTACT & IDENTIFICATION"),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: kTextPrimary),
                      decoration: rentXInputDecoration("Phone Number", hint: "10-digit mobile number").copyWith(counterText: ""),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Enter phone number";
                        if (val.length != 10) return "Phone number must be 10 digits";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _studentIdController,
                      style: const TextStyle(color: kTextPrimary),
                      decoration: rentXInputDecoration("Student ID No.", hint: "e.g., 2023A7PS0001P"),
                      validator: (val) => val == null || val.trim().isEmpty ? "Enter Student ID" : null,
                    ),
                    const SizedBox(height: 16),

                    rentXSectionLabel("CAMPUS RESIDENCE"),
                    DropdownButtonFormField<String>(
                      value: _selectedHostel,
                      dropdownColor: kSurface2,
                      style: const TextStyle(color: kTextPrimary),
                      decoration: rentXInputDecoration("Select Hostel / Bhavan"),
                      items: _hostels.map((h) => DropdownMenuItem(value: h, child: Text("$h Bhavan"))).toList(),
                      onChanged: (val) => setState(() => _selectedHostel = val),
                      validator: (val) => val == null ? "Please select your hostel" : null,
                    ),
                    const SizedBox(height: 36),

                    rentXButton(
                      label: widget.isEditing ? "UPDATE PROFILE" : "SAVE & CONTINUE",
                      onTap: _saveProfile,
                      loading: _isLoading,
                      icon: Icons.check_circle_outline,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
