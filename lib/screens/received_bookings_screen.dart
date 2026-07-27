import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'ride_details_screen.dart';

class ReceivedBookingsScreen extends StatelessWidget {
  const ReceivedBookingsScreen({super.key});

  Future<void> _launchWhatsApp(BuildContext context, String phone, String message) async {
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!clean.startsWith('91') && clean.length == 10) clean = '91$clean';
    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open WhatsApp"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: kBgColor,
        appBar: AppBar(
          backgroundColor: kBgColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: kTextPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Received Bookings", style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              Text("Bookings on your listings", style: TextStyle(color: kTextMuted, fontSize: 11)),
            ],
          ),
          bottom: const TabBar(
            labelColor: kTextPrimary,
            unselectedLabelColor: kTextDim,
            indicatorColor: kTextPrimary,
            tabs: [
              Tab(icon: Icon(Icons.pedal_bike, size: 18), text: "Cycles"),
              Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: "Rentals"),
              Tab(icon: Icon(Icons.shopping_bag_outlined, size: 18), text: "Purchases"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BookingTabView(
              type: 'cycle',
              userId: user?.uid,
              onContactCustomer: (ctx, phone, name, bookingData) {
                final itemName = bookingData['cycleData']?['modelName'] ?? 'Cycle';
                final status = bookingData['status'] ?? 'booked';
                final msg = "Hi ${bookingData['renterName'] ?? name}, I've received your booking request for \"$itemName\" on RentX. Status: ${status.toUpperCase()}. Let me know when you'd like to collect.";
                _launchWhatsApp(ctx, phone, msg);
              },
            ),
            _BookingTabView(
              type: 'item',
              userId: user?.uid,
              onContactCustomer: (ctx, phone, name, bookingData) {
                final itemName = bookingData['itemData']?['itemName'] ?? 'Item';
                final status = bookingData['status'] ?? 'booked';
                final msg = "Hi ${bookingData['renterName'] ?? name}, I've received your rental booking for \"$itemName\" on RentX. Status: ${status.toUpperCase()}. Please coordinate pick-up at the scheduled time.";
                _launchWhatsApp(ctx, phone, msg);
              },
            ),
            _BookingTabView(
              type: 'purchase',
              userId: user?.uid,
              onContactCustomer: (ctx, phone, name, bookingData) {
                final itemName = bookingData['itemName'] ?? bookingData['saleItemData']?['itemName'] ?? 'Item';
                final price = bookingData['price'] ?? bookingData['saleItemData']?['price'] ?? 0;
                final location = bookingData['location'] ?? bookingData['saleItemData']?['location'] ?? 'campus';
                final msg = "Hi ${bookingData['renterName'] ?? name}, I received your interest in buying \"$itemName\" (₹$price) on RentX. You can collect it from $location Bhavan. Let's arrange a time!";
                _launchWhatsApp(ctx, phone, msg);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingTabView extends StatelessWidget {
  final String type; // 'cycle', 'item', 'purchase'
  final String? userId;
  final void Function(BuildContext ctx, String phone, String name, Map<String, dynamic> bookingData) onContactCustomer;

  const _BookingTabView({
    required this.type,
    required this.userId,
    required this.onContactCustomer,
  });

  @override
  Widget build(BuildContext context) {
    // One stream for all bookings owned by this user, filtered client-side by type
    final stream = FirebaseFirestore.instance
        .collection('bookings')
        .where('ownerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: kAccentRed)));
        }

        final allDocs = snapshot.data?.docs ?? [];

        // Filter by type client-side
        List<QueryDocumentSnapshot> docs;
        if (type == 'purchase') {
          docs = allDocs.where((d) {
            final m = d.data() as Map<String, dynamic>;
            return m['type'] == 'purchase' || m.containsKey('saleItemId');
          }).toList();
        } else if (type == 'cycle') {
          docs = allDocs.where((d) {
            final m = d.data() as Map<String, dynamic>;
            return m['type'] == 'cycle' || (m.containsKey('cycleId') && !m.containsKey('saleItemId'));
          }).toList();
        } else {
          // item rentals
          docs = allDocs.where((d) {
            final m = d.data() as Map<String, dynamic>;
            return m['type'] == 'item' || (m.containsKey('itemId') && !m.containsKey('saleItemId'));
          }).toList();
        }

        if (docs.isEmpty) {
          return rentXEmptyState(
            icon: type == 'cycle'
                ? Icons.pedal_bike
                : type == 'item'
                    ? Icons.inventory_2_outlined
                    : Icons.shopping_bag_outlined,
            message: type == 'purchase'
                ? "No purchase requests"
                : "No ${type == 'cycle' ? 'cycle' : 'item rental'} bookings",
            subMessage: type == 'purchase'
                ? "When students want to buy your listed items, requests will appear here."
                : "When students book your ${type == 'cycle' ? 'cycles' : 'items'}, requests will appear here.",
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final booking = docs[index].data() as Map<String, dynamic>;
            final bookingId = docs[index].id;
            final status = booking['status'] ?? 'unknown';
            final renterId = booking['userId'] ?? '';

            String listingName;
            if (type == 'cycle') {
              listingName = booking['cycleData']?['modelName'] ?? 'Cycle';
            } else if (type == 'item') {
              listingName = booking['itemData']?['itemName'] ?? 'Item';
            } else {
              listingName = booking['itemName'] ?? booking['saleItemData']?['itemName'] ?? 'Item';
            }

            DateTime? createdAt;
            if (booking['createdAt'] != null) {
              createdAt = (booking['createdAt'] as Timestamp).toDate();
            }

            Color statusColor = kTextMuted;
            if (status == 'booked' || status == 'started') statusColor = kAccentCyan;
            if (status == 'payment_pending') statusColor = kAccentOrange;
            if (status.contains('cancelled')) statusColor = kAccentRed;

            IconData typeIcon = type == 'cycle'
                ? Icons.pedal_bike
                : type == 'item'
                    ? Icons.inventory_2_outlined
                    : Icons.shopping_bag_outlined;

            return FutureBuilder<DocumentSnapshot>(
              future: renterId.isNotEmpty
                  ? FirebaseFirestore.instance.collection('users').doc(renterId).get()
                  : FirebaseFirestore.instance.collection('users').doc('__nonexistent__').get(),
              builder: (context, userSnapshot) {
                String renterName = booking['renterName'] ?? "Customer";
                String renterPhone = '';

                if (userSnapshot.connectionState == ConnectionState.done && userSnapshot.data != null) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                  if (userData != null) {
                    renterName = userData['displayName'] ?? renterName;
                    renterPhone = userData['phone'] ?? userData['phoneNumber'] ?? '';
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: kSurface1,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      // Main info tile
                      ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        onTap: type != 'purchase'
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RideDetailsScreen(booking: booking, bookingId: bookingId),
                                  ),
                                )
                            : null,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Icon(typeIcon, color: statusColor, size: 22),
                        ),
                        title: Text(
                          listingName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 13, color: kTextMuted),
                                  const SizedBox(width: 4),
                                  Text(renterName, style: const TextStyle(color: kTextMuted, fontSize: 12)),
                                ],
                              ),
                              if (type == 'purchase') ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.currency_rupee, size: 13, color: kAccentOrange),
                                    Text(
                                      "${booking['price'] ?? booking['saleItemData']?['price'] ?? 0}",
                                      style: const TextStyle(color: kAccentOrange, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.location_on_outlined, size: 13, color: kTextMuted),
                                    Text(
                                      "${booking['location'] ?? 'Campus'} Bhavan",
                                      style: const TextStyle(color: kTextMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                const SizedBox(height: 3),
                                if (booking['scheduledStartTime'] != null)
                                  Text(
                                    "📅 ${DateFormat('MMM d, h:mm a').format((booking['scheduledStartTime'] as Timestamp).toDate())}",
                                    style: const TextStyle(color: kTextDim, fontSize: 11),
                                  ),
                              ],
                              const SizedBox(height: 3),
                              Text(
                                createdAt != null ? "Requested: ${DateFormat('MMM dd • hh:mm a').format(createdAt)}" : "",
                                style: const TextStyle(color: kTextDim, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        trailing: rentXBadge(status.toUpperCase(), color: statusColor),
                      ),

                      // Contact Customer button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF25D366)),
                              foregroundColor: const Color(0xFF25D366),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.chat, size: 16),
                            label: Text(
                              "Contact ${type == 'purchase' ? 'Buyer' : 'Customer'} on WhatsApp",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: () {
                              final phone = renterPhone.isNotEmpty
                                  ? renterPhone
                                  : booking['renterPhone'] ?? '';
                              if (phone.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Customer phone number not available"),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }
                              onContactCustomer(context, phone, renterName, booking);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
