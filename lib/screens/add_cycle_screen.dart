import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

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
  bool _acceptedTerms = false;

  final List<String> _gearOptions = ["Single Geared", "Geared"];
  final List<String> _parkingLocations = [
    "VK Back Gate", "Mess 2", "VM Cycle Parking", "Mess 1",
    "Ganga/Meera Parking", "SAC/Malviya Parking"
  ];

  // Multi-image support
  final List<XFile> _newImages = [];
  List<String> _existingImageUrls = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.cycleData != null) {
      final d = widget.cycleData!;
      modelName = d['modelName'] ?? '';
      location = d['location'] ?? 'VK Back Gate';
      upiId = d['ownerUpiId'] ?? '';
      basePrice = d['basePrice'] ?? 20;
      hourlyPrice = d['hourlyPrice'] ?? 7;
      description = d['description'] ?? '';
      ownerPhone = d['ownerPhone'] ?? '';
      roomNumber = d['roomNumber'] ?? '';
      gearType = d['gearType'] ?? 'Single Geared';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload at least one photo of your cycle."), backgroundColor: Colors.redAccent));
      return;
    }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must accept the Terms & Conditions."), backgroundColor: Colors.redAccent));
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
            Text("Model: $modelName", style: const TextStyle(color: kTextMuted)),
            Text("Gear: $gearType", style: const TextStyle(color: kTextMuted)),
            Text("Parked at: $location", style: const TextStyle(color: kTextMuted)),
            Text("Base: ₹$basePrice | Hourly: ₹$hourlyPrice", style: const TextStyle(color: kTextMuted)),
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
        'modelName': modelName,
        'location': location,
        'basePrice': basePrice,
        'hourlyPrice': hourlyPrice,
        'description': description,
        'gearType': gearType,
        'imageUrl': primaryUrl,
        'imageUrls': allImages,
      };

      if (widget.cycleId != null) {
        await FirebaseFirestore.instance.collection('cycles').doc(widget.cycleId).update(payload);
      } else {
        await FirebaseFirestore.instance.collection('cycles').add({
          ...payload,
          'ownerId': user.uid,
          'isAvailable': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: kBorder)),
        title: const Text("Owner Terms & Conditions", style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            "1. You confirm that you are the verified owner of this cycle.\n"
            "2. You agree to maintain the cycle in good working condition.\n"
            "3. You create this listing at your own risk. RentX acts only as a connector.\n"
            "4. You are responsible for verifying the cycle condition after each ride.\n"
            "5. Any disputes regarding damage are to be resolved directly with the renter.\n"
            "6. Incorrect or misleading information may lead to account suspension.",
            style: TextStyle(color: kTextMuted, height: 1.6),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close", style: TextStyle(color: kTextPrimary))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: rentXAppBar(context,
        widget.cycleId != null ? "Edit Cycle" : "List Your Cycle",
        subtitle: "RentX Campus Cycle Rentals",
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
                  rentXSectionLabel("CYCLE PHOTOS"),
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

                  // ── CYCLE DETAILS ──
                  rentXSectionLabel("CYCLE DETAILS"),
                  TextFormField(
                    initialValue: modelName,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration("Cycle Model", hint: "e.g., Hercules Roadeo, Firefox Gravity"),
                    validator: (v) => v == null || v.trim().isEmpty ? "Enter model name" : null,
                    onSaved: (v) => modelName = v!.trim(),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _gearOptions.contains(gearType) ? gearType : _gearOptions.first,
                    dropdownColor: kSurface2,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration("Gear Type"),
                    items: _gearOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) { if (v != null) setState(() => gearType = v); },
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _parkingLocations.contains(location) ? location : _parkingLocations.first,
                    dropdownColor: kSurface2,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration("Parked At"),
                    items: _parkingLocations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) { if (v != null) setState(() => location = v); },
                  ),
                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(child: TextFormField(
                      initialValue: ownerPhone,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: const TextStyle(color: kTextPrimary),
                      decoration: rentXInputDecoration("Phone No."),
                      validator: (v) => (v ?? '').length != 10 ? "Must be 10 digits" : null,
                      onSaved: (v) => ownerPhone = v!.trim(),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      initialValue: roomNumber,
                      style: const TextStyle(color: kTextPrimary),
                      decoration: rentXInputDecoration("Room No.", hint: "e.g. B-304"),
                      validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                      onSaved: (v) => roomNumber = v!.trim(),
                    )),
                  ]),
                  const SizedBox(height: 12),

                  TextFormField(
                    initialValue: upiId,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration("UPI ID", hint: "name@oksbi"),
                    validator: (v) => !(v ?? '').contains('@') ? "Invalid UPI ID" : null,
                    onSaved: (v) => upiId = v!.trim(),
                  ),
                  const SizedBox(height: 20),

                  // ── PRICING ──
                  rentXSectionLabel("PRICING"),
                  Row(children: [
                    Expanded(child: TextFormField(
                      initialValue: basePrice.toString(),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      style: const TextStyle(color: kTextPrimary),
                      decoration: rentXInputDecoration("Base Price (₹)", hint: "First 2 hrs"),
                      validator: (v) {
                        final p = int.tryParse(v ?? '');
                        if (p == null || p < 10 || p > 50) return "₹10–50 only";
                        return null;
                      },
                      onSaved: (v) => basePrice = int.parse(v!),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      initialValue: hourlyPrice.toString(),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      style: const TextStyle(color: kTextPrimary),
                      decoration: rentXInputDecoration("Hourly Rate (₹)", hint: "After 2 hrs"),
                      validator: (v) {
                        final p = int.tryParse(v ?? '');
                        if (p == null || p < 7 || p > 20) return "₹7–20 only";
                        return null;
                      },
                      onSaved: (v) => hourlyPrice = int.parse(v!),
                    )),
                  ]),
                  const SizedBox(height: 12),

                  TextFormField(
                    initialValue: description,
                    maxLines: 3,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration("Additional Notes", hint: "Describe the cycle's condition, accessories, etc."),
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
                      title: const Text("I accept the Terms & Conditions", style: TextStyle(color: kTextMuted, fontSize: 13)),
                      subtitle: GestureDetector(
                        onTap: _showTermsDialog,
                        child: const Text("Read Owner T&C", style: TextStyle(color: kAccentCyan, fontSize: 12, decoration: TextDecoration.underline, decorationColor: kAccentCyan)),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: kTextPrimary,
                      checkColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),

                  rentXButton(
                    label: widget.cycleId != null ? "UPDATE CYCLE" : "LIST MY CYCLE",
                    onTap: _isUploading ? null : _submitForm,
                    icon: Icons.pedal_bike,
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