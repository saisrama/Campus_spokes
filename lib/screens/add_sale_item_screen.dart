import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

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
    "Electronics", "Sports Goods", "Books & Study Material",
    "Lab & Tech Tools", "Hostel & Appliances", "Clothing & Accessories", "Others"
  ];

  final List<String> _locations = [
    "Buddh", "Vishwakarma", "Valmiki", "Vyas", "Shankar",
    "Ram", "Krishna", "Gandhi", "Gautam", "Malviya", "Meera", "Ganga"
  ];

  final List<String> _conditions = ["Brand New", "Like New", "Good", "Fair", "For Parts"];

  // Multi-image support
  final List<XFile> _newImages = [];
  List<String> _existingImageUrls = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.itemData != null) {
      final d = widget.itemData!;
      itemName = d['itemName'] ?? '';
      itemType = d['itemType'] ?? 'Electronics';
      location = d['location'] ?? 'Buddh';
      upiId = d['ownerUpiId'] ?? '';
      price = d['price'] ?? 100;
      description = d['description'] ?? '';
      ownerPhone = d['ownerPhone'] ?? '';
      roomNumber = d['roomNumber'] ?? '';
      condition = d['condition'] ?? 'Good';

      if (d['imageUrls'] is List) {
        _existingImageUrls = List<String>.from(d['imageUrls']);
      } else if ((d['imageUrl'] ?? '').isNotEmpty) {
        _existingImageUrls = [d['imageUrl']];
      }
    }
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 25, maxWidth: 800);
    if (picked.isNotEmpty) setState(() => _newImages.addAll(picked));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add at least one photo."), backgroundColor: Colors.redAccent));
      return;
    }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please accept the terms."), backgroundColor: Colors.redAccent));
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
            Text("Condition: $condition", style: const TextStyle(color: kTextMuted)),
            Text("Price: ₹$price", style: const TextStyle(color: kTextMuted)),
            Text("Collect From: $location Bhavan", style: const TextStyle(color: kTextMuted)),
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
      final primaryUrl = allImages.isNotEmpty ? allImages.first : '';

      final payload = {
        'ownerName': user.displayName,
        'ownerPhone': ownerPhone,
        'roomNumber': roomNumber,
        'ownerUpiId': upiId,
        'itemName': itemName,
        'itemType': itemType,
        'location': location,
        'price': price,
        'description': description,
        'condition': condition,
        'imageUrl': primaryUrl,
        'imageUrls': allImages,
      };

      if (widget.itemId != null) {
        await FirebaseFirestore.instance.collection('sale_items').doc(widget.itemId).update(payload);
      } else {
        await FirebaseFirestore.instance.collection('sale_items').add({
          ...payload,
          'ownerId': user.uid,
          'isSold': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.itemId != null ? "Listing updated!" : "Item listed for sale!"), backgroundColor: kSurface1));
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
        widget.itemId != null ? "Edit Sale Listing" : "Sell an Item",
        subtitle: "Campus buy & sell marketplace",
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
                  // ── PHOTOS ──
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
                    decoration: rentXInputDecoration("Item Name", hint: "e.g., iPhone Charger, Guitar"),
                    validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
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
                    value: _conditions.contains(condition) ? condition : _conditions.first,
                    dropdownColor: kSurface2,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration("Condition"),
                    items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) { if (v != null) setState(() => condition = v); },
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
                    Expanded(child: TextFormField(
                      initialValue: roomNumber,
                      style: const TextStyle(color: kTextPrimary),
                      decoration: rentXInputDecoration("Room No."),
                      validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                      onSaved: (v) => roomNumber = v!.trim(),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      initialValue: ownerPhone,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: kTextPrimary),
                      decoration: rentXInputDecoration("Phone No."),
                      validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                      onSaved: (v) => ownerPhone = v!.trim(),
                    )),
                  ]),
                  const SizedBox(height: 12),

                  TextFormField(
                    initialValue: upiId,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration("UPI ID", hint: "username@upi"),
                    validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                    onSaved: (v) => upiId = v!.trim(),
                  ),
                  const SizedBox(height: 20),

                  // ── PRICING ──
                  rentXSectionLabel("SELLING PRICE"),
                  TextFormField(
                    initialValue: price.toString(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration("Asking Price (₹)", hint: "e.g., 500"),
                    validator: (v) => int.tryParse(v ?? '') == null ? "Invalid price" : null,
                    onSaved: (v) => price = int.parse(v!),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    initialValue: description,
                    maxLines: 3,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration("Description", hint: "Mention condition, included accessories, reason for selling..."),
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
                        "I confirm this item is mine to sell and all details are accurate.",
                        style: TextStyle(color: kTextMuted, fontSize: 12),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: kTextPrimary,
                      checkColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),

                  rentXButton(
                    label: widget.itemId != null ? "UPDATE LISTING" : "LIST FOR SALE",
                    onTap: _submitForm,
                    icon: Icons.sell_outlined,
                    color: kAccentOrange,
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
          decoration: BoxDecoration(color: kSurface1, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
          child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_photo_alternate_outlined, size: 40, color: kTextDim),
            SizedBox(height: 8),
            Text("Tap to add photos", style: TextStyle(color: kTextDim, fontSize: 13)),
            SizedBox(height: 4),
            Text("Multiple photos supported", style: TextStyle(color: kTextDim, fontSize: 11)),
          ])),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._existingImageUrls.asMap().entries.map((e) {
            Widget img;
            if (e.value.startsWith('http')) {
              img = Image.network(e.value, fit: BoxFit.cover);
            } else {
              try { img = Image.memory(base64Decode(e.value), fit: BoxFit.cover); }
              catch (_) { img = const Icon(Icons.broken_image, color: kTextDim); }
            }
            return _imageThumb(img, onRemove: () => setState(() => _existingImageUrls.removeAt(e.key)));
          }),
          ..._newImages.asMap().entries.map((e) => FutureBuilder<Uint8List>(
            future: e.value.readAsBytes(),
            builder: (_, snap) {
              final img = snap.hasData ? Image.memory(snap.data!, fit: BoxFit.cover) : const Center(child: CircularProgressIndicator(strokeWidth: 1));
              return _imageThumb(img, onRemove: () => setState(() => _newImages.removeAt(e.key)));
            },
          )),
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: 110,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: kSurface1, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
              child: const Icon(Icons.add, color: kTextDim, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageThumb(Widget image, {required VoidCallback onRemove}) {
    return Stack(children: [
      Container(
        width: 110,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        clipBehavior: Clip.antiAlias,
        child: image,
      ),
      Positioned(
        top: 4, right: 14,
        child: GestureDetector(
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), shape: BoxShape.circle),
            child: const Icon(Icons.close, color: Colors.white, size: 14),
          ),
        ),
      ),
    ]);
  }
}
