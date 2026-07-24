import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_item_request_screen.dart';

class ItemRequestsScreen extends StatefulWidget {
  final String initialTab; // 'rent' or 'buy' or 'all'
  const ItemRequestsScreen({super.key, this.initialTab = 'all'});

  @override
  State<ItemRequestsScreen> createState() => _ItemRequestsScreenState();
}

class _ItemRequestsScreenState extends State<ItemRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab == 'rent' ? 0 : widget.initialTab == 'buy' ? 1 : 0;
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _contactRequester(Map<String, dynamic> reqData) async {
    // Fetch user's phone from Firestore
    final userId = reqData['userId'];
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    String phone = '';
    if (userDoc.exists) {
      phone = (userDoc.data() as Map<String, dynamic>)['phoneNumber'] ?? '';
    }

    final title = reqData['title'] ?? 'item';
    final budget = reqData['budget'];
    final typeLabel = reqData['requestType'] == 'rent' ? 'rent' : 'buy';
    final msg = "Hi ${reqData['userName']}, I saw your request to $typeLabel \"$title\" on Campus Spokes. I have it available${budget != null && budget.isNotEmpty ? ' within your budget of ₹$budget' : ''}. Let me know if you're interested!";

    if (phone.isNotEmpty) {
      String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) cleanPhone = '91$cleanPhone';
      final Uri url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}");
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not contact — phone number not available")),
      );
    }
  }

  Widget _buildRequestList(String typeFilter) {
    Query query = FirebaseFirestore.instance
        .collection('item_requests')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true);

    if (typeFilter != 'all') {
      query = query.where('requestType', isEqualTo: typeFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox_outlined, size: 60, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  typeFilter == 'rent' ? "No rent requests yet." : typeFilter == 'buy' ? "No buy requests yet." : "No open requests yet.",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final req = docs[index].data() as Map<String, dynamic>;
            final reqId = docs[index].id;
            final isRent = req['requestType'] == 'rent';
            final isOwn = req['userId'] == user?.uid;
            final createdAt = req['createdAt'] != null ? (req['createdAt'] as dynamic).toDate() as DateTime : null;

            return Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isRent ? Colors.indigoAccent.withValues(alpha: 0.2) : Colors.orangeAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isRent ? "WANT TO RENT" : "WANT TO BUY",
                            style: TextStyle(
                              color: isRent ? Colors.indigoAccent : Colors.orangeAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                          child: Text(req['category'] ?? 'General', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                        ),
                        const Spacer(),
                        if (isOwn)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            tooltip: "Delete Request",
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E1E),
                                  title: const Text("Delete Request?", style: TextStyle(color: Colors.white)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await FirebaseFirestore.instance.collection('item_requests').doc(reqId).delete();
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(req['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    if ((req['description'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(req['description'], style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(req['userName'] ?? 'Student', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      if ((req['budget'] ?? '').isNotEmpty) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.currency_rupee, size: 14, color: Colors.grey),
                        Text("Budget: ₹${req['budget']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                      const Spacer(),
                      if (createdAt != null)
                        Text(DateFormat('MMM d').format(createdAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ]),
                    if (!isOwn) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.chat, size: 16, color: Colors.white),
                          label: Text(
                            isRent ? "I Can Offer This for Rent" : "I Have This for Sale",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isRent ? Colors.indigoAccent : Colors.orangeAccent,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _contactRequester(req),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Item Requests Board"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.indigoAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: "Want to Rent"),
            Tab(icon: Icon(Icons.shopping_bag_outlined, size: 18), text: "Want to Buy"),
            Tab(icon: Icon(Icons.list_alt, size: 18), text: "My Requests"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestList('rent'),
          _buildRequestList('buy'),
          _buildMyRequests(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'rent_req',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemRequestScreen(requestType: 'rent'))),
            label: const Text("Request to Rent"),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.indigoAccent,
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'buy_req',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemRequestScreen(requestType: 'buy'))),
            label: const Text("Request to Buy"),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.orangeAccent,
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildMyRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('item_requests')
          .where('userId', isEqualTo: user?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.post_add, size: 60, color: Colors.grey),
                const SizedBox(height: 12),
                const Text("You haven't posted any requests yet.", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemRequestScreen(requestType: 'rent'))),
                    child: const Text("Request Rent", style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemRequestScreen(requestType: 'buy'))),
                    child: const Text("Request Buy", style: TextStyle(color: Colors.white)),
                  ),
                ]),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final req = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final reqId = snapshot.data!.docs[index].id;
            final isRent = req['requestType'] == 'rent';

            return Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isRent ? Colors.indigoAccent : Colors.orangeAccent).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(isRent ? Icons.inventory_2_outlined : Icons.shopping_bag_outlined, color: isRent ? Colors.indigoAccent : Colors.orangeAccent),
                ),
                title: Text(req['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isRent ? "To Rent • ${req['category']}" : "To Buy • ${req['category']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if ((req['budget'] ?? '').isNotEmpty) Text("Budget: ₹${req['budget']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => FirebaseFirestore.instance.collection('item_requests').doc(reqId).delete(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
