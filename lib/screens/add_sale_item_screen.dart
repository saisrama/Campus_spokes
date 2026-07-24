import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class AddSaleItemScreen extends StatefulWidget {
  final Map<String, dynamic>? itemData;
  final String? itemId;

  const AddSaleItemScreen({super.key, this.itemData, this.itemId});

  @override
  State<AddSaleItemScreen> createState() => _AddSaleItemScreenState();
}

class _AddSaleItemScreenState extends State<AddSaleItemScreen> {
  final _formKey = GlobalKey<FormState>();
  String itemName = '';
  String itemType = 'Electronics';
  String location = 'Buddh';
  String upiId = '';
  int price = 100;
  String description = '';
  String ownerPhone = '';
  String roomNumber = '';
  String condition = 'Good';
  bool _isUploading = false;
  bool _acceptedTerms = false;

  final List<String> _itemTypes = [
    "Electronics",
    "Sports Goods",
    "Books & Study Material",
    "Lab & Tech Tools",
    "Hostel & Appliances",
    "Clothing & Accessories",
    "Others"
  ];

  final List<String> _locations = [
    "Buddh", "Vishwakarma", "Valmiki", "Vyas", "Shankar",
    "Ram", "Krishna", "Gandhi", "Gautam", "Malviya", "Meera", "Ganga"
  ];

  final List<String> _conditions = ["Brand New", "Like New", "Good", "Fair", "For Parts"];

  XFile? _pickedFile;
  final picker = ImagePicker();
  String _uploadedImageUrl = "";

  @override
  void initState() {
    super.initState();
    if (widget.itemData != null) {
      itemName = widget.itemData!['itemName'] ?? '';
      itemType = widget.itemData!['itemType'] ?? 'Electronics';
      location = widget.itemData!['location'] ?? 'Buddh';
      upiId = widget.itemData!['ownerUpiId'] ?? '';
      price = widget.itemData!['price'] ?? 100;
      description = widget.itemData!['description'] ?? '';
      ownerPhone = widget.itemData!['ownerPhone'] ?? '';
      roomNumber = widget.itemData!['roomNumber'] ?? '';
      condition = widget.itemData!['condition'] ?? 'Good';
      _uploadedImageUrl = widget.itemData!['imageUrl'] ?? '';
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 20, maxWidth: 600);
    if (pickedFile != null) setState(() => _pickedFile = pickedFile);
  }

  Future<String> _uploadImage() async {
    if (_pickedFile == null) return _uploadedImageUrl;
    try {
      List<int> imageBytes = await _pickedFile!.readAsBytes();
      return base64Encode(imageBytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Image Encoding Failed: $e")));
      return _uploadedImageUrl;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_pickedFile == null && _uploadedImageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload an image."), backgroundColor: Colors.red));
      return;
    }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please accept the terms."), backgroundColor: Colors.red));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Confirm Details", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: ListBody(children: [
            Text("Item: $itemName", style: const TextStyle(color: Colors.white70)),
            Text("Category: $itemType", style: const TextStyle(color: Colors.white70)),
            Text("Condition: $condition", style: const TextStyle(color: Colors.white70)),
            Text("Price: ₹$price", style: const TextStyle(color: Colors.white70)),
            Text("Collect From: $location Bhavan (Room $roomNumber)", style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            const Text("Is everything correct?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Edit", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _uploadAndSave(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text("Confirm & List", style: TextStyle(color: Colors.white)),
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

      final data = {
        'ownerName': user!.displayName,
        'ownerPhone': ownerPhone,
        'roomNumber': roomNumber,
        'ownerUpiId': upiId,
        'itemName': itemName,
        'itemType': itemType,
        'condition': condition,
        'location': location,
        'price': price,
        'description': description,
        'imageUrl': finalImageUrl,
      };

      if (widget.itemId != null) {
        await FirebaseFirestore.instance.collection('sale_items').doc(widget.itemId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('sale_items').add({
          ...data,
          'ownerId': user.uid,
          'isSold': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      setState(() => _isUploading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.itemId != null ? "Listing updated!" : "Item listed for sale!")),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  Widget _buildImagePreview() {
    if (_pickedFile != null) {
      return FutureBuilder<Uint8List>(
        future: _pickedFile!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) return Image.memory(snapshot.data!, width: double.infinity, height: 200, fit: BoxFit.cover);
          return Container(height: 200, color: Colors.grey[900], child: const Center(child: CircularProgressIndicator()));
        },
      );
    } else if (_uploadedImageUrl.isNotEmpty) {
      if (_uploadedImageUrl.startsWith('http')) return Image.network(_uploadedImageUrl, width: double.infinity, height: 200, fit: BoxFit.cover);
      try { return Image.memory(base64Decode(_uploadedImageUrl), width: double.infinity, height: 200, fit: BoxFit.cover); } catch (_) {}
    }
    return Container(
      height: 180,
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
      child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_a_photo, size: 40, color: Colors.white54),
        SizedBox(height: 8),
        Text("Tap to upload item photo", style: TextStyle(color: Colors.white54)),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(widget.itemId != null ? "Edit Sale Listing" : "Sell an Item"),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: _isUploading
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(color: Colors.orangeAccent),
              SizedBox(height: 16),
              Text("Saving...", style: TextStyle(color: Colors.white)),
            ]))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: ClipRRect(borderRadius: BorderRadius.circular(16), child: _buildImagePreview()),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    initialValue: itemName, style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Item Name", hintText: "e.g. Scientific Calculator, PS5 Controller", prefixIcon: Icon(Icons.sell_outlined, color: Colors.orangeAccent)),
                    validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                    onSaved: (v) => itemName = v!.trim(),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _itemTypes.contains(itemType) ? itemType : _itemTypes.first,
                    dropdownColor: const Color(0xFF1E1E1E), style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Category", prefixIcon: Icon(Icons.category, color: Colors.orangeAccent)),
                    items: _itemTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) { if (val != null) setState(() => itemType = val); },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _conditions.contains(condition) ? condition : _conditions.first,
                    dropdownColor: const Color(0xFF1E1E1E), style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Item Condition", prefixIcon: Icon(Icons.verified, color: Colors.orangeAccent)),
                    items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) { if (val != null) setState(() => condition = val); },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _locations.contains(location) ? location : _locations.first,
                    dropdownColor: const Color(0xFF1E1E1E), style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Collect From (Bhavan)", prefixIcon: Icon(Icons.location_on, color: Colors.orangeAccent)),
                    items: _locations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (val) { if (val != null) setState(() => location = val); },
                  ),
                  const SizedBox(height: 16),

                  Row(children: [
                    Expanded(child: TextFormField(
                      initialValue: roomNumber, style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Room No.", prefixIcon: Icon(Icons.meeting_room, color: Colors.orangeAccent)),
                      validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                      onSaved: (v) => roomNumber = v!.trim(),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      initialValue: ownerPhone, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Phone No.", prefixIcon: Icon(Icons.phone, color: Colors.orangeAccent)),
                      validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                      onSaved: (v) => ownerPhone = v!.trim(),
                    )),
                  ]),
                  const SizedBox(height: 16),

                  TextFormField(
                    initialValue: upiId, style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "UPI ID (for receiving payment)", hintText: "username@upi", prefixIcon: Icon(Icons.payment, color: Colors.orangeAccent)),
                    validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                    onSaved: (v) => upiId = v!.trim(),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    initialValue: price.toString(), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Selling Price (₹)", prefixIcon: Icon(Icons.currency_rupee, color: Colors.orangeAccent)),
                    validator: (v) => int.tryParse(v ?? '') == null ? "Invalid price" : null,
                    onSaved: (v) => price = int.parse(v!),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    initialValue: description, maxLines: 3, style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Description", hintText: "Mention specifications, age, reason for selling...", prefixIcon: Icon(Icons.description, color: Colors.orangeAccent)),
                    onSaved: (v) => description = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 20),

                  CheckboxListTile(
                    value: _acceptedTerms,
                    onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
                    title: const Text("I confirm this item belongs to me and is accurately described.", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      widget.itemId != null ? "UPDATE LISTING" : "LIST FOR SALE",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
