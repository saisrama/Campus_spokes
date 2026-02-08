import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; 
import 'ride_details_screen.dart'; 

class PaymentHistoryScreen extends StatelessWidget {
  final String myUserId = FirebaseAuth.instance.currentUser!.uid;

  PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Payment History"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- THE DISCLAIMER BANNER ---
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15), // Low opacity yellow for caution
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Disclaimer: This history records bookings confirmed within the app. It assumes all peer-to-peer UPI transactions were successfully completed between students. These numbers might be inaccurate if payments failed.",
                    style: TextStyle(color: Colors.amber[100], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          // --- THE TRANSACTION LIST ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  // REMOVED .where('status'...) to avoid Index Requirement
                  // MUST use a field that exists on ALL docs including cancelled ones
                  // Cancelled docs might not have 'endTime' set
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
                
                if (snapshot.hasError) {
                  return Center(child: Text("Error loading history: ${snapshot.error}", style: TextStyle(color: Colors.red)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                   return Center(child: Text("No transactions yet.", style: TextStyle(color: Colors.grey)));
                }

                var allDocs = snapshot.data!.docs;
                
                // Client-side Filter:
                // 1. My ID (Owner or Renter)
                // 2. Status 'completed' OR 'cancelled'
                var myTransactions = allDocs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String status = data['status'] ?? '';
                  bool isFinished = status == 'completed' || status == 'cancelled';
                  bool isMine = data['userId'] == myUserId || data['ownerId'] == myUserId;
                  // Only show cancelled if there's a fee (finalCost > 0 or cancellationFee > 0)
                  if (status == 'cancelled') {
                     var fc = data['finalCost'];
                     var cf = data['cancellationFee'];
                     double finalCost = (fc is num) ? fc.toDouble() : (double.tryParse(fc.toString()) ?? 0);
                     double cancelFee = (cf is num) ? cf.toDouble() : (double.tryParse(cf.toString()) ?? 0);
                     
                     if (finalCost <= 0 && cancelFee <= 0) {
                        // Optional: Show 0 amount cancellations too?
                        // User specifically said "cancelled amount... not going up", implies they expect an amount.
                        // But showing it even if 0 confirms the cancellation.
                        // return true; 
                     }
                  }
                  return isFinished && isMine;
                }).toList();

                if (myTransactions.isEmpty) {
                  return Center(child: Text("No transactions yet.", style: TextStyle(color: Colors.grey)));
                }

                // CALCULATE TOTALS
                double totalIncome = 0;
                double totalExpense = 0;

                for (var doc in myTransactions) {
                  var data = doc.data() as Map<String, dynamic>;
                  // Fallback for cancellation
                  var fc = data['finalCost'];
                  var cf = data['cancellationFee'];
                  double finalCost = (fc is num) ? fc.toDouble() : (double.tryParse(fc.toString()) ?? 0);
                  double cancelFee = (cf is num) ? cf.toDouble() : (double.tryParse(cf.toString()) ?? 0);
                  double amount = finalCost > 0 ? finalCost : cancelFee;
                  
                  if (data['ownerId'] == myUserId) {
                    totalIncome += amount;
                  } else {
                    totalExpense += amount;
                  }
                }

                return Column(
                  children: [
                    // SUMMARY CARDS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard("Total Received", totalIncome, Colors.green),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard("Total Spent", totalExpense, Colors.red),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: Colors.grey[800]),
                    
                    // LIST
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.only(bottom: 20),
                        itemCount: myTransactions.length,
                        itemBuilder: (context, index) {
                          var data = myTransactions[index].data() as Map<String, dynamic>;
                    
                    bool isIncome = data['ownerId'] == myUserId;
                    // Handle Cancellation Context
                    String status = data['status'];
                    bool isCancelled = status == 'cancelled';
                    
                    var fc = data['finalCost'];
                    var cf = data['cancellationFee'];
                    double finalCost = (fc is num) ? fc.toDouble() : (double.tryParse(fc.toString()) ?? 0);
                    double cancelFee = (cf is num) ? cf.toDouble() : (double.tryParse(cf.toString()) ?? 0);
                    double amount = finalCost > 0 ? finalCost : cancelFee;

                    Timestamp? timestamp = isCancelled ? data['cancelledAt'] : data['endTime'];
                    // Fallback if null
                    if (timestamp == null) timestamp = data['createdAt'];

                    String dateStr = timestamp != null 
                        ? DateFormat('MMM d, h:mm a').format(timestamp.toDate()) 
                        : "Unknown Date";
                    
                    String title = isIncome ? "Payment Received" : "Ride Paid";
                    if (isCancelled) {
                       title = isIncome ? "Cancellation Fee Received" : "Cancelled Ride";
                    }

                    return Card(
                      color: Color(0xFF1E1E1E),
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsScreen(booking: data, bookingId: myTransactions[index].id)));
                        },
                        leading: CircleAvatar(
                          backgroundColor: isIncome ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                          child: Icon(
                            isCancelled ? Icons.cancel_presentation : (isIncome ? Icons.arrow_downward : Icons.arrow_upward),
                            color: isIncome ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(
                          title, 
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                        ),
                        subtitle: Text(dateStr, style: TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: Text(
                          "${isIncome ? '+' : '-'} ₹${amount.toStringAsFixed(0)}",
                          style: TextStyle(
                            color: isIncome ? Colors.green : Colors.red,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: Colors.grey, fontSize: 12)),
          SizedBox(height: 4),
          Text(
            "₹${amount.toStringAsFixed(0)}", 
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }
}