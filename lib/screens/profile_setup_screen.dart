import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isEditing;

  ProfileSetupScreen({this.isEditing = false});

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
        'updatedAt': FieldValue.serverTimestamp(), // Track updates
      }, SetOptions(merge: true));

      if (widget.isEditing) {
        Navigator.pop(context); // Return to Profile Screen
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Profile Updated!")));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving profile: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? "Edit Profile" : "Complete Your Profile")),
      body: _isLoading && widget.isEditing // Show loader only if fetching initial data
          ? Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.isEditing ? "Update your details below." : "Please provide your details to continue.", style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 30),
                    
                    // PHONE NUMBER
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.number, // Numeric Keypad
                      maxLength: 10, // Limit to 10 chars
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly, // Only numbers
                      ],
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Phone Number",
                        prefixIcon: Icon(Icons.phone, color: Colors.white70),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Color(0xFF1E1E1E),
                        counterText: "", // Hide character counter
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Enter phone number";
                        if (val.length != 10) return "Phone number must be 10 digits";
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // STUDENT ID
                    TextFormField(
                      controller: _studentIdController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Student ID No.",
                        prefixIcon: Icon(Icons.badge, color: Colors.white70),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Color(0xFF1E1E1E),
                      ),
                      validator: (val) => val!.isEmpty ? "Enter Student ID" : null,
                    ),
                    SizedBox(height: 20),

                    // HOSTEL DROPDOWN
                    DropdownButtonFormField<String>(
                      value: _selectedHostel,
                      dropdownColor: Color(0xFF1E1E1E),
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Select Hostel",
                        prefixIcon: Icon(Icons.home, color: Colors.white70),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Color(0xFF1E1E1E),
                      ),
                      items: _hostels.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                      onChanged: (val) => setState(() => _selectedHostel = val),
                      validator: (val) => val == null ? "Please select your hostel" : null,
                    ),
                    SizedBox(height: 40),

                    // SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        onPressed: _isLoading ? null : _saveProfile,
                        child: _isLoading 
                          ? CircularProgressIndicator(color: Colors.black) 
                          : Text(widget.isEditing ? "UPDATE PROFILE" : "SAVE & CONTINUE", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
