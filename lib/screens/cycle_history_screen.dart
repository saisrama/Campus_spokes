import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class CycleHistoryScreen extends StatelessWidget {
  final String cycleId;
  final Map<String, dynamic> cycleData;

  const CycleHistoryScreen({super.key, required this.cycleId, required this.cycleData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: rentXAppBar(
        context,
        cycleData['modelName'] ?? 'Cycle History',
        subtitle: 'Booking history for this cycle',
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('cycleId', isEqualTo: cycleId)
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
            return rentXEmptyState(icon: Icons.history, message: "No bookings yet", subMessage: "Booking history will appear here.");
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final booking = docs[index].data() as Map<String, dynamic>;
              final String userId = booking['userId'];
              final String status = booking['status'] ?? 'unknown';
              final bool isOngoing = ['booked', 'started', 'payment_pending', 'end_requested'].contains(status);
              final Timestamp? startTime = booking['startTime'];
              final Timestamp? endTime = booking['endTime'];
              final double cost = (booking['finalCost'] ?? 0).toDouble();
              final bool isNoShow = booking['isNoShow'] ?? false;

              String statusLabel = isOngoing ? "ONGOING" : "COMPLETED";
              Color labelColor = isOngoing ? kAccentCyan : kAccentGreen;
              if (isNoShow) { statusLabel = "NO SHOW"; labelColor = kAccentRed; }

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isOngoing ? kAccentCyan.withValues(alpha: 0.06) : kSurface1,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isOngoing ? kAccentCyan.withValues(alpha: 0.4) : kBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          rentXBadge(statusLabel, color: labelColor),
                          if (!isOngoing)
                            Text("₹${cost.toStringAsFixed(0)}", style: const TextStyle(color: kAccentGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      rentXDivider(),
                      const SizedBox(height: 8),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return const Text("Loading...", style: TextStyle(color: kTextDim, fontSize: 12));
                          }
                          String renterName = "Unknown User";
                          String renterPhone = "N/A";
                          String renterId = "N/A";
                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                            renterName = userData['displayName'] ?? "Unknown User";
                            renterPhone = userData['phoneNumber'] ?? "N/A";
                            renterId = userData['studentId'] ?? "N/A";
                          }
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _infoRow(Icons.person_outline, renterName),
                            _infoRow(Icons.badge_outlined, "ID: $renterId"),
                            _infoRow(Icons.phone_outlined, renterPhone),
                          ]);
                        },
                      ),
                      const SizedBox(height: 8),
                      if (startTime != null)
                        _infoRow(Icons.access_time_rounded, "Start: ${DateFormat('MMM d, h:mm a').format(startTime.toDate())}"),
                      if (endTime != null)
                        _infoRow(Icons.flag_outlined, "End:   ${DateFormat('MMM d, h:mm a').format(endTime.toDate())}"),
                      if (isOngoing && startTime != null) ...[
                        const SizedBox(height: 4),
                        Text("Ride is still ongoing...", style: TextStyle(color: kAccentCyan.withValues(alpha: 0.8), fontStyle: FontStyle.italic, fontSize: 12)),
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 14, color: kTextDim),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: kTextMuted, fontSize: 13)),
      ]),
    );
  }
}
