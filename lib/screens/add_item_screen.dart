import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class AddItemScreen extends StatefulWidget {
  final Map<String, dynamic>? itemData;
  final String? itemId;

  const AddItemScreen({super.key, this.itemData, this.itemId});

  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  String itemName = '';
  String itemType = 'Electronics';
  String location = 'Buddh';
  String upiId = '';
  int basePrice = 20;
  int hourlyPrice = 7;
  String description = '';
  String ownerPhone = '';
  String roomNumber = '';
  bool _isUploading = false;
  bool _acceptedTerms = false;

  final List<String> _itemTypes = [
    "Electronics",
    "Sports Goods",
    "Books & Study Material",
    "Lab & Tech Tools",
    "Hostel & Appliances",
    "Others"
  ];

  final List<String> _locations = [
    "Buddh",
    "Vishwakarma",
    "Valmiki",
    "Vyas",
    "Shankar",
    "Ram",
    "Krishna",
    "Gandhi",
    "Gautam",
    "Malviya",
    "Meera",
    "Ganga"
  ];

  XFile? _pickedFile;
  final picker = ImagePicker();
  String _uploadedImageUrl = "";

  @override
  void initState() {
    super.initState();
    if (widget.itemData != null) {
      itemName = widget.itemData!['itemName'] ?? widget.itemData!['modelName'] ?? '';
      itemType = widget.itemData!['itemType'] ?? 'Electronics';
      location = widget.itemData!['location'] ?? 'Buddh';
      upiId = widget.itemData!['ownerUpiId'] ?? '';
      basePrice = widget.itemData!['basePrice'] ?? 20;
      hourlyPrice = widget.itemData!['hourlyPrice'] ?? 7;
      description = widget.itemData!['description'] ?? '';
      ownerPhone = widget.itemData!['ownerPhone'] ?? '';
      roomNumber = widget.itemData!['roomNumber'] ?? '';
      _uploadedImageUrl = widget.itemData!['imageUrl'] ?? '';
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 20,
      maxWidth: 600,
    );

    if (pickedFile != null) {
      setState(() {
        _pickedFile = pickedFile;
      });
    }
  }

  Future<String> _uploadImage() async {
    if (_pickedFile == null) return _uploadedImageUrl;

    try {
      List<int> imageBytes = await _pickedFile!.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      return base64Image;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Image Encoding Failed: $e")));
      return _uploadedImageUrl;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_pickedFile == null && _uploadedImageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please upload an image of your item."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You must accept the Terms and Conditions to list your item."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text("Confirm Details", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text("Item: $itemName", style: TextStyle(color: Colors.white70)),
              Text("Category: $itemType", style: TextStyle(color: Colors.white70)),
              Text("Collect From: $location", style: TextStyle(color: Colors.white70)),
              Text("Phone: $ownerPhone", style: TextStyle(color: Colors.white70)),
              Text("UPI: $upiId", style: TextStyle(color: Colors.white70)),
              SizedBox(height: 10),
              Text("Base Price: ₹$basePrice", style: TextStyle(color: Colors.white70)),
              Text("Hourly Price: ₹$hourlyPrice", style: TextStyle(color: Colors.white70)),
              SizedBox(height: 10),
              Text("Is everything correct?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Edit", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadAndSave();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
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
      String finalImageUrl = await _uploadImage();

      if (widget.itemId != null) {
        await FirebaseFirestore.instance.collection('items').doc(widget.itemId).update({
          'ownerName': user!.displayName,
          'ownerPhone': ownerPhone,
          'roomNumber': roomNumber,
          'ownerUpiId': upiId,
          'itemName': itemName,
          'itemType': itemType,
          'location': location,
          'basePrice': basePrice,
          'hourlyPrice': hourlyPrice,
          'description': description,
          'imageUrl': finalImageUrl,
        });
      } else {
        await FirebaseFirestore.instance.collection('items').add({
          'ownerId': user!.uid,
          'ownerName': user.displayName,
          'ownerPhone': ownerPhone,
          'roomNumber': roomNumber,
          'ownerUpiId': upiId,
          'itemName': itemName,
          'itemType': itemType,
          'location': location,
          'basePrice': basePrice,
          'hourlyPrice': hourlyPrice,
          'description': description,
          'imageUrl': finalImageUrl,
          'isAvailable': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      setState(() => _isUploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.itemId != null ? "Item updated successfully!" : "Item listed successfully!")),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save item: $e")));
    }
  }

  Widget _buildImagePreview() {
    if (_pickedFile != null) {
      return FutureBuilder<Uint8List>(
        future: _pickedFile!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(snapshot.data!, width: double.infinity, height: 200, fit: BoxFit.cover);
          }
          return Container(height: 200, color: Colors.grey[900], child: Center(child: CircularProgressIndicator()));
        },
      );
    } else if (_uploadedImageUrl.isNotEmpty) {
      if (_uploadedImageUrl.startsWith('http')) {
        return Image.network(_uploadedImageUrl, width: double.infinity, height: 200, fit: BoxFit.cover);
      }
      try {
        return Image.memory(base64Decode(_uploadedImageUrl), width: double.infinity, height: 200, fit: BoxFit.cover);
      } catch (_) {}
    }
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 40, color: Colors.white54),
            SizedBox(height: 8),
            Text("Tap to upload item photo", style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text(widget.itemId != null ? "Edit Item Listing" : "List an Item"),
        backgroundColor: Color(0xFF1E1E1E),
      ),
      body: _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigoAccent),
                  SizedBox(height: 16),
                  Text("Saving item...", style: TextStyle(color: Colors.white)),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(20),
                children: [
                  // Image Section
                  GestureDetector(
                    onTap: _pickImage,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildImagePreview(),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Item Name
                  TextFormField(
                    initialValue: itemName,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Item Name",
                      hintText: "e.g., Badminton Racket, Scientific Calculator",
                      prefixIcon: Icon(Icons.inventory, color: Colors.indigoAccent),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? "Enter item name" : null,
                    onSaved: (v) => itemName = v!.trim(),
                  ),
                  SizedBox(height: 16),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: _itemTypes.contains(itemType) ? itemType : _itemTypes.first,
                    dropdownColor: Color(0xFF1E1E1E),
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Item Category / Type",
                      prefixIcon: Icon(Icons.category, color: Colors.indigoAccent),
                    ),
                    items: _itemTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => itemType = val);
                    },
                  ),
                  SizedBox(height: 16),

                  // Collect From Location Dropdown
                  DropdownButtonFormField<String>(
                    value: _locations.contains(location) ? location : _locations.first,
                    dropdownColor: Color(0xFF1E1E1E),
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Collect From (Bhavan)",
                      prefixIcon: Icon(Icons.location_on, color: Colors.indigoAccent),
                    ),
                    items: _locations.map((loc) {
                      return DropdownMenuItem(value: loc, child: Text(loc));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => location = val);
                    },
                  ),
                  SizedBox(height: 16),

                  // Room Number & Phone Number
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: roomNumber,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Room No.",
                            prefixIcon: Icon(Icons.meeting_room, color: Colors.indigoAccent),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                          onSaved: (v) => roomNumber = v!.trim(),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: ownerPhone,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Phone No.",
                            prefixIcon: Icon(Icons.phone, color: Colors.indigoAccent),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                          onSaved: (v) => ownerPhone = v!.trim(),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // UPI ID
                  TextFormField(
                    initialValue: upiId,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "UPI ID (for receiving payment)",
                      hintText: "e.g., username@upi",
                      prefixIcon: Icon(Icons.payment, color: Colors.indigoAccent),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? "Enter UPI ID" : null,
                    onSaved: (v) => upiId = v!.trim(),
                  ),
                  SizedBox(height: 16),

                  // Pricing
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: basePrice.toString(),
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Base Price (₹)",
                            helperText: "For first 2 hrs",
                            prefixIcon: Icon(Icons.currency_rupee, color: Colors.indigoAccent),
                          ),
                          validator: (v) => int.tryParse(v ?? '') == null ? "Invalid" : null,
                          onSaved: (v) => basePrice = int.parse(v!),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: hourlyPrice.toString(),
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Hourly Rate (₹)",
                            helperText: "After 2 hrs",
                            prefixIcon: Icon(Icons.more_time, color: Colors.indigoAccent),
                          ),
                          validator: (v) => int.tryParse(v ?? '') == null ? "Invalid" : null,
                          onSaved: (v) => hourlyPrice = int.parse(v!),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Description
                  TextFormField(
                    initialValue: description,
                    maxLines: 3,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Item Description & Condition",
                      hintText: "Mention condition, accessories included, pick-up notes...",
                      prefixIcon: Icon(Icons.description, color: Colors.indigoAccent),
                    ),
                    onSaved: (v) => description = v?.trim() ?? '',
                  ),
                  SizedBox(height: 20),

                  // Terms & Conditions Checkbox
                  CheckboxListTile(
                    value: _acceptedTerms,
                    onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
                    title: Text(
                      "I accept the terms and agree to keep the item in good working order for renters.",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.indigoAccent,
                  ),
                  SizedBox(height: 20),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      widget.itemId != null ? "UPDATE ITEM" : "LIST ITEM NOW",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
