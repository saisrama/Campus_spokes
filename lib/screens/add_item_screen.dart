import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

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
    "Electronics", "Sports Goods", "Books & Study Material",
    "Lab & Tech Tools", "Hostel & Appliances", "Others"
  ];

  final List<String> _locations = [
    "Buddh", "Vishwakarma", "Valmiki", "Vyas", "Shankar",
    "Ram", "Krishna", "Gandhi", "Gautam", "Malviya", "Meera", "Ganga"
  ];

  // Multi-image support
  final List<XFile> _newImages = [];
  List<String> _existingImageUrls = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.itemData != null) {
      final d = widget.itemData!;
      itemName = d['itemName'] ?? d['modelName'] ?? '';
      itemType = d['itemType'] ?? 'Electronics';
      location = d['location'] ?? 'Buddh';
      upiId = d['ownerUpiId'] ?? '';
      basePrice = d['basePrice'] ?? 20;
      hourlyPrice = d['hourlyPrice'] ?? 7;
      description = d['description'] ?? '';
      ownerPhone = d['ownerPhone'] ?? '';
      roomNumber = d['roomNumber'] ?? '';

      // Backward compat: load existing images
      if (d['imageUrls'] is List) {
        _existingImageUrls = List<String>.from(d['imageUrls']);
      } else if ((d['imageUrl'] ?? '').isNotEmpty) {
        _existingImageUrls = [d['imageUrl']];
      }
    }
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 25, maxWidth: 800);
    if (picked.isNotEmpty) {
      setState(() => _newImages.addAll(picked));
    }
  }

  Future<List<String>> _encodeAllImages() async {
    List<String> urls = List.from(_existingImageUrls);
    for (final img in _newImages) {
      try {
        final bytes = await img.readAsBytes();
        urls.add(base64Encode(bytes));
      } catch (_) {}
    }
    return urls;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_newImages.isEmpty && _existingImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload at least one photo."), backgroundColor: Colors.redAccent));
      return;
    }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Accept the terms to list your item."), backgroundColor: Colors.redAccent));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: kBorder)),
        title: const Text("Confirm Details", style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Item: $itemName", style: const TextStyle(color: kTextMuted)),
            Text("Category: $itemType", style: const TextStyle(color: kTextMuted)),
            Text("Collect From: $location Bhavan", style: const TextStyle(color: kTextMuted)),
            Text("Base Price: ₹$basePrice | Hourly: ₹$hourlyPrice", style: const TextStyle(color: kTextMuted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Edit", style: TextStyle(color: kTextDim))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _uploadAndSave(); },
            style: ElevatedButton.styleFrom(backgroundColor: kTextPrimary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Confirm & List", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAndSave() async {
    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final allImages = await _encodeAllImages();
      // Use first image as primary for backward compat
      final primaryUrl = allImages.isNotEmpty ? allImages.first : '';

      final payload = {
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
        'imageUrl': primaryUrl,
        'imageUrls': allImages,
      };

      if (widget.itemId != null) {
        await FirebaseFirestore.instance.collection('items').doc(widget.itemId).update(payload);
      } else {
        await FirebaseFirestore.instance.collection('items').add({
          ...payload,
          'ownerId': user.uid,
          'isAvailable': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.itemId != null ? "Item updated!" : "Item listed successfully!"), backgroundColor: kSurface1));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: rentXAppBar(context,
        widget.itemId != null ? "Edit Item Listing" : "List an Item",
        subtitle: "Campus rental marketplace",
      ),
      body: _isUploading
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2),
              SizedBox(height: 16),
              Text("Saving your listing...", style: TextStyle(color: kTextMuted)),
            ]))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── MULTI-IMAGE SECTION ──
                  rentXSectionLabel("ITEM PHOTOS"),
                  _buildImageGrid(),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: const Text("Add Photos"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kTextMuted,
                      side: const BorderSide(color: kBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── ITEM DETAILS ──
                  rentXSectionLabel("ITEM DETAILS"),
                  TextFormField(
                    initialValue: itemName,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration("Item Name", hint: "e.g., Badminton Racket, Scientific Calculator"),
                    validator: (v) => v == null || v.trim().isEmpty ? "Enter item name" : null,
                    onSaved: (v) => itemName = v!.trim(),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _itemTypes.contains(itemType) ? itemType : _itemTypes.first,
                    dropdownColor: kSurface2,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration("Category"),
                    items: _itemTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) { if (v != null) setState(() => itemType = v); },
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _locations.contains(location) ? location : _locations.first,
                    dropdownColor: kSurface2,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration("Collect From (Bhavan)"),
                    items: _locations.map((l) => DropdownMenuItem(value: l, child: Text("$l Bhavan"))).toList(),
                    onChanged: (v) { if (v != null) setState(() => location = v); },
                  ),
                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: roomNumber,
                        style: const TextStyle(color: kTextPrimary),
                        decoration: rentXInputDecoration("Room No."),
                        validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                        onSaved: (v) => roomNumber = v!.trim(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: ownerPhone,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: kTextPrimary),
                        decoration: rentXInputDecoration("Phone No."),
                        validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                        onSaved: (v) => ownerPhone = v!.trim(),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  TextFormField(
                    initialValue: upiId,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration("UPI ID", hint: "username@upi"),
                    validator: (v) => v == null || v.trim().isEmpty ? "Enter UPI ID" : null,
                    onSaved: (v) => upiId = v!.trim(),
                  ),
                  const SizedBox(height: 20),

                  // ── PRICING ──
                  rentXSectionLabel("PRICING"),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: basePrice.toString(),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: kTextPrimary),
                        decoration: rentXInputDecoration("Base Price (₹)", hint: "First 2 hrs"),
                        validator: (v) => int.tryParse(v ?? '') == null ? "Invalid" : null,
                        onSaved: (v) => basePrice = int.parse(v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: hourlyPrice.toString(),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: kTextPrimary),
                        decoration: rentXInputDecoration("Hourly Rate (₹)", hint: "After 2 hrs"),
                        validator: (v) => int.tryParse(v ?? '') == null ? "Invalid" : null,
                        onSaved: (v) => hourlyPrice = int.parse(v!),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  TextFormField(
                    initialValue: description,
                    maxLines: 3,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration("Description & Condition", hint: "Mention condition, accessories included, pick-up notes..."),
                    onSaved: (v) => description = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 24),

                  // ── TERMS ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: kSurface1, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
                    child: CheckboxListTile(
                      value: _acceptedTerms,
                      onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                      title: const Text(
                        "I confirm I own this item and agree to keep it in good working order for renters.",
                        style: TextStyle(color: kTextMuted, fontSize: 12),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: kTextPrimary,
                      checkColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),

                  rentXButton(
                    label: widget.itemId != null ? "UPDATE LISTING" : "LIST ITEM NOW",
                    onTap: _submitForm,
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildImageGrid() {
    final totalCount = _existingImageUrls.length + _newImages.length;
    if (totalCount == 0) {
      return GestureDetector(
        onTap: _pickImages,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: kSurface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder, style: BorderStyle.solid),
          ),
          child: const Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_photo_alternate_outlined, size: 40, color: kTextDim),
              SizedBox(height: 8),
              Text("Tap to add photos", style: TextStyle(color: kTextDim, fontSize: 13)),
              SizedBox(height: 4),
              Text("Multiple photos supported", style: TextStyle(color: kTextDim, fontSize: 11)),
            ]),
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Existing images
          ..._existingImageUrls.asMap().entries.map((entry) {
            final idx = entry.key;
            final url = entry.value;
            Widget img;
            if (url.startsWith('http')) {
              img = Image.network(url, fit: BoxFit.cover);
            } else {
              try { img = Image.memory(base64Decode(url), fit: BoxFit.cover); }
              catch (_) { img = const Icon(Icons.broken_image, color: kTextDim); }
            }
            return _imageThumb(img, onRemove: () => setState(() => _existingImageUrls.removeAt(idx)));
          }),
          // Newly picked images
          ..._newImages.asMap().entries.map((entry) {
            final idx = entry.key;
            final file = entry.value;
            return FutureBuilder<Uint8List>(
              future: file.readAsBytes(),
              builder: (_, snap) {
                final img = snap.hasData ? Image.memory(snap.data!, fit: BoxFit.cover) : const Center(child: CircularProgressIndicator(strokeWidth: 1));
                return _imageThumb(img, onRemove: () => setState(() => _newImages.removeAt(idx)));
              },
            );
          }),
          // Add more button
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: 110,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: kSurface1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: const Icon(Icons.add, color: kTextDim, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageThumb(Widget image, {required VoidCallback onRemove}) {
    return Stack(
      children: [
        Container(
          width: 110,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
          clipBehavior: Clip.antiAlias,
          child: image,
        ),
        Positioned(
          top: 4,
          right: 14,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
