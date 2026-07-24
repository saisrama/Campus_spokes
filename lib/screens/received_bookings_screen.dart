import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'ride_details_screen.dart';

class ReceivedBookingsScreen extends StatelessWidget {
  const ReceivedBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: rentXAppBar(context, "Received Bookings", subtitle: "Bookings on your listed items & cycles"),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('ownerId', isEqualTo: user?.uid)
            .where('status', whereIn: ['booked', 'started', 'payment_pending', 'cancelled', 'owner_cancelled'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: kAccentRed)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return rentXEmptyState(
              icon: Icons.inbox_outlined,
              message: "No received bookings",
              subMessage: "When students book your listed items or cycles, requests will appear here.",
            );
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var booking = docs[index].data() as Map<String, dynamic>;
              String bookingId = docs[index].id;
              String status = booking['status'] ?? 'unknown';

              String listingName = booking['itemData']?['itemName'] ?? booking['cycleData']?['modelName'] ?? "Listing";
              bool isItem = booking.containsKey('itemId');
              String renterId = booking['userId'];

              DateTime? createdAt;
              if (booking['createdAt'] != null) {
                createdAt = (booking['createdAt'] as Timestamp).toDate();
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(renterId).get(),
                builder: (context, userSnapshot) {
                  String renterName = "Loading...";

                  if (userSnapshot.connectionState == ConnectionState.done) {
                    if (userSnapshot.hasData && userSnapshot.data!.exists) {
                      var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                      renterName = userData['displayName'] ?? "User";
                    } else {
                      renterName = booking['renterName'] ?? "Unknown User";
                    }
                  }

                  Color statusColor = kTextMuted;
                  if (status == 'booked' || status == 'started') statusColor = kAccentCyan;
                  if (status == 'payment_pending') statusColor = kAccentOrange;
                  if (status.contains('cancelled')) statusColor = kAccentRed;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: kSurface1,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorder),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RideDetailsScreen(booking: booking, bookingId: bookingId),
                          ),
                        );
                      },
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Icon(isItem ? Icons.inventory_2_outlined : Icons.pedal_bike, color: statusColor, size: 22),
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
                            Text("Renter: $renterName", style: const TextStyle(color: kTextMuted, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(
                              createdAt != null ? DateFormat('MMM dd • hh:mm a').format(createdAt) : "",
                              style: const TextStyle(color: kTextDim, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      trailing: rentXBadge(status.toUpperCase(), color: statusColor),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
