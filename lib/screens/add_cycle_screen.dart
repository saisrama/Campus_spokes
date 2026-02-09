import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart'; // Not needed for Base64

class AddCycleScreen extends StatefulWidget {
  final Map<String, dynamic>? cycleData;
  final String? cycleId;

  const AddCycleScreen({super.key, this.cycleData, this.cycleId});

  @override
  _AddCycleScreenState createState() => _AddCycleScreenState();
}

class _AddCycleScreenState extends State<AddCycleScreen> {
  final _formKey = GlobalKey<FormState>();
  String modelName = '';
  String location = 'VK Back Gate';
  String upiId = '';
  int basePrice = 20;
  int hourlyPrice = 7;
  String description = '';
  String ownerPhone = '';
  String roomNumber = '';
  String gearType = 'Single Geared'; 
  bool _isUploading = false;
  bool _acceptedTerms = false; // T&C State
  
  final List<String> _gearOptions = ["Single Geared", "Geared"];

  // Image Logic
  File? _imageFile;
  final picker = ImagePicker();
  // Using a more reliable placeholder service or empty string
  // Using a more reliable placeholder service or empty string
  String _uploadedImageUrl = "";  

  @override
  void initState() {
    super.initState();
    if (widget.cycleData != null) {
      modelName = widget.cycleData!['modelName'];
      location = widget.cycleData!['location'];
      upiId = widget.cycleData!['ownerUpiId'];
      basePrice = widget.cycleData!['basePrice'];
      hourlyPrice = widget.cycleData!['hourlyPrice'];
      description = widget.cycleData!['description'] ?? '';
      ownerPhone = widget.cycleData!['ownerPhone'] ?? '';
      roomNumber = widget.cycleData!['roomNumber'] ?? '';
      gearType = widget.cycleData!['gearType'] ?? 'Single Geared';
      _uploadedImageUrl = widget.cycleData!['imageUrl'] ?? _uploadedImageUrl;
    }
  } 

  Future<void> _pickImage() async {
    // COMPRESS IMAGE: Quality 20, Width 600 to keep string size low for Firestore
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 20, 
      maxWidth: 600
    );
    
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadImage() async {
    if (_imageFile == null) return _uploadedImageUrl;
    
    try {
      // CONVERT TO BASE64
      List<int> imageBytes = await _imageFile!.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      print("Base64 String Length: ${base64Image.length}");
      return base64Image;
    } catch (e) {
      print("Encoding Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Image Encoding Failed: $e")));
      return _uploadedImageUrl; // Fallback
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // VALIDATION: Check if image is provided
    if (_imageFile == null && (_uploadedImageUrl.isEmpty || !_uploadedImageUrl.startsWith('http') && _uploadedImageUrl.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please upload an image of your cycle."),
          backgroundColor: Colors.red,
        )
      );
      return;
    }

    // VALIDATION: Terms & Conditions
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You must accept the Terms and Conditions to list your cycle."),
          backgroundColor: Colors.red,
        )
      );
      return;
    }

    // SHOW CONFIRMATION DIALOG
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Details"),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text("Model: $modelName"),
              Text("Location: $location"),
              Text("Phone: $ownerPhone"),
              Text("UPI: $upiId"),
              SizedBox(height: 10),
              Text("Base Price: ₹$basePrice"),
              Text("Hourly Price: ₹$hourlyPrice"),
              SizedBox(height: 10),
              Text("Is everything correct?", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Cancel
            child: Text("Edit", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _uploadAndSave(); // Proceed to upload
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text("Confirm & List", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAndSave() async {
    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // Upload Image First
      String finalImageUrl = await _uploadImage();
      
      // Save to Firestore
      if (widget.cycleId != null) {
         // UPDATE EXISTING
         await FirebaseFirestore.instance.collection('cycles').doc(widget.cycleId).update({
          'ownerName': user!.displayName,
          'ownerPhone': ownerPhone,
          'roomNumber': roomNumber,
          'ownerUpiId': upiId,
          'modelName': modelName,
          'location': location,
          'basePrice': basePrice,
          'hourlyPrice': hourlyPrice,
          'description': description,
          'gearType': gearType,
          'imageUrl': finalImageUrl, 
         });
      } else {
        // CREATE NEW
        await FirebaseFirestore.instance.collection('cycles').add({
          'ownerId': user!.uid,
          'ownerName': user.displayName,
          'ownerPhone': ownerPhone,
          'roomNumber': roomNumber,
          'ownerUpiId': upiId,
          'modelName': modelName,
          'location': location,
          'basePrice': basePrice,
          'hourlyPrice': hourlyPrice,
          'description': description,
          'gearType': gearType,
          'imageUrl': finalImageUrl,
          'isAvailable': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pop(context); // Success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Owner Terms & Conditions"),
        content: SingleChildScrollView(
          child: Text(
            "1. You confirm that you are the verified owner of this cycle.\n"
            "2. You agree to maintain the cycle in good working condition.\n"
            "3. You create this listing at your own risk. Campus Spokes acts only as a connector.\n"
            "4. You responsible for verifying the cycle condition after each ride.\n"
            "5. Any disputes regarding damage are to be resolved directly with the renter.\n"
            "6. Incorrect or misleading information may lead to account suspension."
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.cycleId != null ? "Edit Cycle" : "List Your Cycle")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PHOTO UPLOAD AREA
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[700]!),
                    image: _imageFile != null 
                      ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                      : (_uploadedImageUrl.startsWith('http') 
                          ? DecorationImage(image: NetworkImage(_uploadedImageUrl), fit: BoxFit.cover)
                          : (_uploadedImageUrl.isNotEmpty 
                              ? DecorationImage(image: MemoryImage(base64Decode(_uploadedImageUrl)), fit: BoxFit.cover)
                              : null))
                  ),
                  child: _imageFile == null && !_uploadedImageUrl.startsWith('http') && _uploadedImageUrl.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 40, color: Colors.white),
                          SizedBox(height: 10),
                          Text("Tap to add photo", style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    : null,
                ),
              ),
              SizedBox(height: 20),

              // FIELDS
              TextFormField(
                initialValue: modelName,
                decoration: InputDecoration(labelText: "Cycle Model (e.g. Hercules Roadeo)", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Required" : null,
                onSaved: (v) => modelName = v!,
              ),
              SizedBox(height: 15),

              // GEAR TYPE DROPDOWN
              DropdownButtonFormField<String>(
                value: gearType,
                decoration: InputDecoration(
                  labelText: "Gear Type",
                  prefixIcon: Icon(Icons.settings, color: Colors.blue),
                  border: OutlineInputBorder(),
                ),
                items: _gearOptions.map((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    gearType = val!;
                  });
                },
              ),
              SizedBox(height: 15),

              TextFormField(
                initialValue: ownerPhone,
                decoration: InputDecoration(
                  labelText: "Your Phone Number", 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone, color: Colors.blue),
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (v) => v!.length != 10 ? "Must be exactly 10 digits" : null,
                onSaved: (v) => ownerPhone = v!,
              ),
              SizedBox(height: 15),

              TextFormField(
                initialValue: roomNumber,
                decoration: InputDecoration(
                  labelText: "Room Number (e.g. B-304)", 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.meeting_room, color: Colors.orange),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
                onSaved: (v) => roomNumber = v!,
              ),
              SizedBox(height: 15),

              TextFormField(
                initialValue: upiId,
                decoration: InputDecoration(
                  labelText: "Your UPI ID (e.g. name@oksbi)", 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee, color: Colors.green),
                  helperText: "Money will be sent directly here."
                ),
                validator: (v) => !v!.contains('@') ? "Invalid UPI ID" : null,
                onSaved: (v) => upiId = v!,
              ),
              SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: "Base Price (2hrs)", border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      initialValue: basePrice.toString(),
                      validator: (v) {
                        int? p = int.tryParse(v!);
                        if (p == null || p < 10 || p > 50) return "10-50 only";
                        return null;
                      },
                      onSaved: (v) => basePrice = int.parse(v!),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: "Hourly Rate", border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      initialValue: hourlyPrice.toString(),
                      validator: (v) {
                        int? p = int.tryParse(v!);
                        if (p == null || p < 7 || p > 20) return "7-20 only";
                        return null;
                      },
                      onSaved: (v) => hourlyPrice = int.parse(v!),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),

              DropdownButtonFormField<String>(
                initialValue: location,
                decoration: InputDecoration(labelText: "Parked At", border: OutlineInputBorder()),
                items: ["VK Back Gate", "Mess 2", "VM Cycle Parking", "Mess 1", "Ganga/Meera Parking"]
                    .map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) => setState(() => location = v!),
              ),

              SizedBox(height: 15),

              // TERMS & CONDITIONS CHECKBOX
              CheckboxListTile(
                value: _acceptedTerms,
                onChanged: (val) => setState(() => _acceptedTerms = val!),
                title: Text("I accept the Terms and Conditions", style: TextStyle(fontSize: 14)),
                subtitle: GestureDetector(
                  onTap: _showTermsDialog,
                  child: Text(
                    "Read Owner T&C",
                    style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                  ),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Colors.blue,
              ),

              SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  child: _isUploading ? CircularProgressIndicator() : Text(widget.cycleId != null ? "UPDATE CYCLE" : "LIST MY CYCLE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}