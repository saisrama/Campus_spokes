import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class AddItemRequestScreen extends StatefulWidget {
  final String requestType;
  const AddItemRequestScreen({super.key, required this.requestType});

  @override
  State<AddItemRequestScreen> createState() => _AddItemRequestScreenState();
}

class _AddItemRequestScreenState extends State<AddItemRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  String _category = 'Electronics';
  String _budget = '';
  bool _isSubmitting = false;

  final List<String> _categories = [
    "Electronics", "Sports Goods", "Books & Study Material",
    "Lab & Tech Tools", "Hostel & Appliances", "Others"
  ];

  bool get _isRent => widget.requestType == 'rent';
  Color get _accentColor => _isRent ? kAccentCyan : kAccentOrange;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isSubmitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('item_requests').add({
        'userId': user!.uid,
        'userName': user.displayName ?? 'Student',
        'title': _title,
        'description': _description,
        'category': _category,
        'budget': _budget,
        'requestType': widget.requestType,
        'status': 'open',
        'upvotedBy': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Request posted! Others will reach out if they can help."),
          backgroundColor: kSurface1,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e"), backgroundColor: kSurface1),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: rentXAppBar(
        context,
        _isRent ? "Request to Rent" : "Request to Buy",
        subtitle: _isRent ? "Find items available on campus" : "Find items for sale on campus",
      ),
      body: _isSubmitting
          ? Center(child: CircularProgressIndicator(color: _accentColor, strokeWidth: 2))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Header Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _accentColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_isRent ? Icons.inventory_2_outlined : Icons.shopping_bag_outlined, color: _accentColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          _isRent ? "Post a Rental Request" : "Post a Buy Request",
                          style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isRent
                              ? "Owners with matching items will contact you."
                              : "Sellers will reach out if they have it.",
                          style: const TextStyle(color: kTextMuted, fontSize: 12),
                        ),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  rentXSectionLabel("ITEM NAME *"),
                  TextFormField(
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration(
                      _isRent ? "What do you want to rent?" : "What do you want to buy?",
                      hint: "e.g. Badminton Racket, Scientific Calculator",
                      prefix: Icon(Icons.search_rounded, color: _accentColor, size: 20),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                    onSaved: (v) => _title = v!.trim(),
                  ),
                  const SizedBox(height: 18),

                  rentXSectionLabel("CATEGORY"),
                  DropdownButtonFormField<String>(
                    initialValue: _categories.contains(_category) ? _category : _categories.first,
                    dropdownColor: kSurface1,
                    style: const TextStyle(color: kTextPrimary, fontSize: 14),
                    decoration: rentXInputDecoration(
                      "Category",
                      prefix: Icon(Icons.category_outlined, color: _accentColor, size: 20),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _category = val);
                    },
                  ),
                  const SizedBox(height: 18),

                  rentXSectionLabel("BUDGET (OPTIONAL)"),
                  TextFormField(
                    style: const TextStyle(color: kTextPrimary),
                    keyboardType: TextInputType.number,
                    decoration: rentXInputDecoration(
                      _isRent ? "Max Budget (₹ / 2 hrs)" : "Max Budget (₹)",
                      hint: "e.g. 50",
                      prefix: Icon(Icons.currency_rupee, color: _accentColor, size: 20),
                    ),
                    onSaved: (v) => _budget = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 18),

                  rentXSectionLabel("ADDITIONAL DETAILS (OPTIONAL)"),
                  TextFormField(
                    maxLines: 4,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: rentXInputDecoration(
                      "Description",
                      hint: "Mention specific model, required duration, preferred condition, etc.",
                      prefix: Icon(Icons.notes_rounded, color: _accentColor, size: 20),
                    ),
                    onSaved: (v) => _description = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 30),

                  rentXButton(
                    label: "POST REQUEST",
                    color: _accentColor,
                    onTap: _submit,
                    icon: Icons.send_rounded,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
