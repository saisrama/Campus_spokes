e import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'ride_details_screen.dart';

class PaymentHistoryScreen extends StatelessWidget {
  final String myUserId = FirebaseAuth.instance.currentUser!.uid;

  PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: rentXAppBar(context, "Payment History", subtitle: "Your completed transactions"),
      body: Column(
        children: [
          // Disclaimer Banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kAccentAmber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAccentAmber.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: kAccentAmber, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Disclaimer: Records bookings confirmed within the app. Assumes peer-to-peer UPI transactions were completed. Numbers may be inaccurate if payments failed.",
                    style: TextStyle(color: kTextMuted, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2));
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: kAccentRed)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return rentXEmptyState(icon: Icons.receipt_long_outlined, message: "No transactions yet", subMessage: "Completed rides will appear here.");
                }

                final allDocs = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTime = aData['createdAt'] != null ? (aData['createdAt'] as Timestamp).toDate() : DateTime(2000);
                    final bTime = bData['createdAt'] != null ? (bData['createdAt'] as Timestamp).toDate() : DateTime(2000);
                    return bTime.compareTo(aTime);
                  });
                final myTransactions = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String status = data['status'] ?? '';
                  final bool isFinished = status == 'completed' || status == 'cancelled';
                  final bool isMine = data['userId'] == myUserId || data['ownerId'] == myUserId;
                  return isFinished && isMine;
                }).toList();

                if (myTransactions.isEmpty) {
                  return rentXEmptyState(icon: Icons.receipt_long_outlined, message: "No transactions yet", subMessage: "Completed rides will appear here.");
                }

                double totalIncome = 0;
                double totalExpense = 0;
                for (final doc in myTransactions) {
                  final data = doc.data() as Map<String, dynamic>;
                  final fc = data['finalCost'];
                  final cf = data['cancellationFee'];
                  final double finalCost = (fc is num) ? fc.toDouble() : (double.tryParse(fc.toString()) ?? 0);
                  final double cancelFee = (cf is num) ? cf.toDouble() : (double.tryParse(cf.toString()) ?? 0);
                  final double amount = finalCost > 0 ? finalCost : cancelFee;
                  if (data['ownerId'] == myUserId) {
                    totalIncome += amount;
                  } else {
                    totalExpense += amount;
                  }
                }

                return Column(children: [
                  // Summary row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(children: [
                      Expanded(child: _summaryCard("Total Received", totalIncome, kAccentGreen)),
                      const SizedBox(width: 12),
                      Expanded(child: _summaryCard("Total Spent", totalExpense, kAccentRed)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  rentXDivider(),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      itemCount: myTransactions.length,
                      itemBuilder: (context, index) {
                        final data = myTransactions[index].data() as Map<String, dynamic>;
                        final bool isIncome = data['ownerId'] == myUserId;
                        final String status = data['status'];
                        final bool isCancelled = status == 'cancelled';
                        final fc = data['finalCost'];
                        final cf = data['cancellationFee'];
                        final double finalCost = (fc is num) ? fc.toDouble() : (double.tryParse(fc.toString()) ?? 0);
                        final double cancelFee = (cf is num) ? cf.toDouble() : (double.tryParse(cf.toString()) ?? 0);
                        final double amount = finalCost > 0 ? finalCost : cancelFee;

                        Timestamp? timestamp = isCancelled ? data['cancelledAt'] : data['endTime'];
                        timestamp ??= data['createdAt'];
                        final String dateStr = timestamp != null
                            ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
                            : "Unknown Date";

                        String title = isIncome ? "Payment Received" : "Ride Paid";
                        if (isCancelled) title = isIncome ? "Cancellation Fee Received" : "Cancelled Ride";

                        final Color amountColor = isIncome ? kAccentGreen : kAccentRed;

                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsScreen(booking: data, bookingId: myTransactions[index].id))),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: kSurface1,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: kBorder),
                            ),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: amountColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isCancelled ? Icons.cancel_outlined : (isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
                                  color: amountColor, size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(title, style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(dateStr, style: const TextStyle(color: kTextDim, fontSize: 12)),
                              ])),
                              Text(
                                "${isIncome ? '+' : '-'} ₹${amount.toStringAsFixed(0)}",
                                style: TextStyle(color: amountColor, fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Text(title, style: const TextStyle(color: kTextDim, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text("₹${amount.toStringAsFixed(0)}", style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}