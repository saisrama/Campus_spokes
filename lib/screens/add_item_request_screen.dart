import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddItemRequestScreen extends StatefulWidget {
  final String requestType; // 'rent' or 'buy'
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
  Color get _accentColor => _isRent ? Colors.indigoAccent : Colors.orangeAccent;

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
        'requestType': widget.requestType, // 'rent' or 'buy'
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request posted! Sellers will reach out if they can help."), backgroundColor: _accentColor),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(_isRent ? "Request to Rent" : "Request to Buy"),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: _isSubmitting
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _accentColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      Icon(_isRent ? Icons.inventory_2_outlined : Icons.shopping_bag_outlined, color: _accentColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          _isRent ? "Post a Rental Request" : "Post a Buy Request",
                          style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRent ? "Tell others what you want to rent. Owners with matching items will contact you." : "Tell others what you want to buy. Sellers will reach out if they have it.",
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: _isRent ? "What do you want to rent?" : "What do you want to buy?",
                      hintText: "e.g. Badminton Racket, Scientific Calculator",
                      prefixIcon: Icon(Icons.search, color: _accentColor),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                    onSaved: (v) => _title = v!.trim(),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _categories.contains(_category) ? _category : _categories.first,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: "Category", prefixIcon: Icon(Icons.category, color: _accentColor)),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) { if (val != null) setState(() => _category = val); },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _isRent ? "Maximum Budget (₹ / 2hrs)" : "Maximum Budget (₹)",
                      hintText: "e.g. 50",
                      prefixIcon: Icon(Icons.currency_rupee, color: _accentColor),
                    ),
                    onSaved: (v) => _budget = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Additional Details (optional)",
                      hintText: "Mention specific model, required duration, preferred condition, etc.",
                      prefixIcon: Icon(Icons.notes, color: _accentColor),
                    ),
                    onSaved: (v) => _description = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 28),

                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("POST REQUEST", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
