import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'ride_details_screen.dart';

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({super.key});

  IconData _getStatusIcon(String status, {bool isItem = false}) {
    switch (status.toLowerCase()) {
      case 'completed': return Icons.check_circle_outline;
      case 'active': case 'started': return isItem ? Icons.inventory_2_outlined : Icons.pedal_bike;
      case 'booked': return Icons.bookmark_added_outlined;
      case 'cancelled': case 'owner_cancelled': return Icons.cancel_outlined;
      default: return Icons.history;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return kAccentGreen;
      case 'active': case 'started': return kAccentCyan;
      case 'booked': return kAccentViolet;
      case 'cancelled': case 'owner_cancelled': return kAccentRed;
      default: return kTextMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: rentXAppBar(context, "Rides & Rentals", subtitle: "Your activity history"),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: user?.uid)
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
              icon: Icons.history,
              message: "No rides or item rentals yet",
              subMessage: "Your active and past rentals will show up here.",
            );
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var booking = docs[index].data() as Map<String, dynamic>;
              var itemData = booking['itemData'] as Map<String, dynamic>?;
              var cycleData = booking['cycleData'] as Map<String, dynamic>?;

              String title = "Rental Session";
              if (itemData != null && itemData['itemName'] != null) {
                title = itemData['itemName'];
              } else if (cycleData != null && cycleData['modelName'] != null) {
                title = cycleData['modelName'];
              } else if (booking.containsKey('itemId')) {
                title = "Item Rental";
              } else {
                title = "Cycle Ride";
              }

              String status = booking['status'] ?? 'Unknown';
              DateTime? date;
              if (booking['createdAt'] != null) {
                date = (booking['createdAt'] as Timestamp).toDate();
              }

              double cost = (booking['finalCost'] ?? booking['basePrice'] ?? 0).toDouble();
              bool isItem = booking.containsKey('itemId');

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
                        builder: (_) => RideDetailsScreen(booking: booking, bookingId: docs[index].id),
                      ),
                    );
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.3)),
                    ),
                    child: Icon(_getStatusIcon(status, isItem: isItem), color: _getStatusColor(status), size: 22),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "₹${cost.toStringAsFixed(0)}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          date != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(date) : "Unknown Date",
                          style: const TextStyle(color: kTextDim, fontSize: 12),
                        ),
                        rentXBadge(status.toUpperCase(), color: _getStatusColor(status)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
