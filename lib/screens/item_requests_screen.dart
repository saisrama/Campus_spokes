import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
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
    final userId = reqData['userId'];
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    String phone = '';
    if (userDoc.exists) {
      phone = (userDoc.data() as Map<String, dynamic>)['phoneNumber'] ?? '';
    }

    final title = reqData['title'] ?? 'item';
    final budget = reqData['budget'];
    final typeLabel = reqData['requestType'] == 'rent' ? 'rent' : 'buy';
    final msg = "Hi ${reqData['userName']}, I saw your request to $typeLabel \"$title\" on RentX. I have it available${budget != null && budget.isNotEmpty ? ' within your budget of ₹$budget' : ''}. Let me know if you're interested!";

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
        const SnackBar(content: Text("Could not contact — phone number not available"), backgroundColor: kSurface1),
      );
    }
  }

  Future<void> _toggleUpvote(String reqId, List<dynamic> currentUpvotes) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to upvote."), backgroundColor: kSurface1),
      );
      return;
    }
    final uid = user!.uid;
    final reqRef = FirebaseFirestore.instance.collection('item_requests').doc(reqId);

    if (currentUpvotes.contains(uid)) {
      // Remove upvote
      await reqRef.update({
        'upvotedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      // Add upvote
      await reqRef.update({
        'upvotedBy': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Widget _buildRequestList(String typeFilter) {
    Query query = FirebaseFirestore.instance
        .collection('item_requests')
        .where('status', isEqualTo: 'open');

    if (typeFilter != 'all') {
      query = query.where('requestType', isEqualTo: typeFilter);
    }

    // 2-week expiry threshold (14 days ago)
    final DateTime twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: kAccentRed)));
        }

        final rawDocs = snapshot.data!.docs;

        // Filter out expired items (> 14 days old) & delete them in Firestore asynchronously
        // Sort by createdAt descending in Dart (avoids Firestore composite index requirement)
        final docs = rawDocs.where((doc) {
          final req = doc.data() as Map<String, dynamic>;
          final createdAt = req['createdAt'] != null ? (req['createdAt'] as Timestamp).toDate() : null;
          if (createdAt != null && createdAt.isBefore(twoWeeksAgo)) {
            // Delete expired request from Firestore
            FirebaseFirestore.instance.collection('item_requests').doc(doc.id).delete();
            return false;
          }
          return true;
        }).toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] != null ? (aData['createdAt'] as Timestamp).toDate() : DateTime(2000);
            final bTime = bData['createdAt'] != null ? (bData['createdAt'] as Timestamp).toDate() : DateTime(2000);
            return bTime.compareTo(aTime); // descending
          });

        if (docs.isEmpty) {
          return rentXEmptyState(
            icon: Icons.inbox_outlined,
            message: typeFilter == 'rent' ? "No rent requests yet" : typeFilter == 'buy' ? "No buy requests yet" : "No open requests yet",
            subMessage: "Students looking for specific items will post here.",
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
            final createdAt = req['createdAt'] != null ? (req['createdAt'] as Timestamp).toDate() : null;
            final upvotedBy = (req['upvotedBy'] is List) ? List<String>.from(req['upvotedBy']) : <String>[];
            final upvoteCount = upvotedBy.length;
            final hasUpvoted = user != null && upvotedBy.contains(user!.uid);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: kSurface1,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        rentXBadge(
                          isRent ? "WANT TO RENT" : "WANT TO BUY",
                          color: isRent ? kAccentCyan : kAccentOrange,
                        ),
                        const SizedBox(width: 8),
                        rentXBadge(req['category'] ?? 'General', color: kTextMuted),
                        const Spacer(),
                        if (isOwn)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: kAccentRed, size: 20),
                            tooltip: "Delete Request",
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: kSurface1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kBorder)),
                                  title: const Text("Delete Request?", style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: kTextDim))),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: kAccentRed))),
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
                    Text(req['title'] ?? '', style: const TextStyle(color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                    if ((req['description'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(req['description'], style: const TextStyle(color: kTextMuted, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: kTextDim),
                        const SizedBox(width: 4),
                        Text(req['userName'] ?? 'Student', style: const TextStyle(color: kTextDim, fontSize: 12)),
                        if ((req['budget'] ?? '').isNotEmpty) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.currency_rupee, size: 14, color: kTextDim),
                          Text("Budget: ₹${req['budget']}", style: const TextStyle(color: kTextDim, fontSize: 12)),
                        ],
                        const Spacer(),
                        if (createdAt != null)
                          Text(DateFormat('MMM d').format(createdAt), style: const TextStyle(color: kTextDim, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── UPVOTE & OFFER ROW ──
                    Row(
                      children: [
                        // Upvote Button
                        InkWell(
                          onTap: () => _toggleUpvote(reqId, upvotedBy),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: hasUpvoted ? kAccentCyan.withValues(alpha: 0.15) : kSurface2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: hasUpvoted ? kAccentCyan : kBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '+',
                                  style: TextStyle(
                                    color: hasUpvoted ? kAccentCyan : kTextMuted,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$upvoteCount Me Too',
                                  style: TextStyle(
                                    color: hasUpvoted ? kAccentCyan : kTextMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Offer Button
                        if (!isOwn)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.black),
                              label: Text(
                                isRent ? "Offer to Rent" : "Offer to Sell",
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRent ? kAccentCyan : kAccentOrange,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () => _contactRequester(req),
                            ),
                          ),
                      ],
                    ),
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
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        title: const Text("RentX • Requests Board", style: TextStyle(fontWeight: FontWeight.bold, color: kTextPrimary, fontSize: 19)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kTextPrimary,
          labelColor: kTextPrimary,
          unselectedLabelColor: kTextDim,
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
            label: const Text("Request to Rent", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            icon: const Icon(Icons.add, color: Colors.black),
            backgroundColor: kAccentCyan,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'buy_req',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemRequestScreen(requestType: 'buy'))),
            label: const Text("Request to Buy", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            icon: const Icon(Icons.add, color: Colors.black),
            backgroundColor: kAccentOrange,
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
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return rentXEmptyState(
            icon: Icons.post_add,
            message: "No requests posted yet",
            subMessage: "Post a request when looking for specific items.",
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final req = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final reqId = snapshot.data!.docs[index].id;
            final isRent = req['requestType'] == 'rent';
            final upvotedBy = (req['upvotedBy'] is List) ? List<String>.from(req['upvotedBy']) : <String>[];

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: kSurface1,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isRent ? kAccentCyan : kAccentOrange).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(isRent ? Icons.inventory_2_outlined : Icons.shopping_bag_outlined, color: isRent ? kAccentCyan : kAccentOrange),
                ),
                title: Text(req['title'] ?? '', style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isRent ? "To Rent • ${req['category']}" : "To Buy • ${req['category']}", style: const TextStyle(color: kTextMuted, fontSize: 12)),
                  Text("Upvotes / Me Too: ${upvotedBy.length}", style: const TextStyle(color: kAccentCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: kAccentRed),
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
