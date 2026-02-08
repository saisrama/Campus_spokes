import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'ride_details_screen.dart';

class RideHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text("Your Rides")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: user?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No rides yet.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var booking = docs[index].data() as Map<String, dynamic>;
              var cycleData = booking['cycleData'] ?? {}; 
              // Note: If cycleData wasn't saved in booking, we might need to fetch it or handle it. 
              // In our flow, we haven't explicitly saved cycleData to booking, only cycleId.
              // For a robust history, we should have saved a snapshot.
              // Let's assume for now we might need to fetch it or show generic info if missing.
              // To make this work immediately without complex joins, we'll try to use cycleId to fetch or just show ID/Status.
              // WAIT! cycle_detail_screen.dart didn't save cycleData snapshot. 
              // IMPROVEMENT: We should really save a snapshot of cycle details in booking for history purposes 
              // in case the cycle is deleted later. 
              // For now, let's try to display what we have and maybe fetch cycle details if possible, 
              // or just rely on IDs/Status if that's all we have. 
              // Actually, looking at previous code, we only saved 'cycleId'. 
              // Let's do a FutureBuilder for each card? No, that's heavy.
              // Let's just show Status, Date, Cost for now. Cycle Name might be missing if we didn't save it.
              
              // RETROACTIVE FIX: We should have saved 'modelName' in booking. 
              // Since we didn't, let's just show "Cycle Ride" and the Date/Cost.
              
              String status = booking['status'] ?? 'Unknown';
              DateTime? date;
              if (booking['createdAt'] != null) {
                date = (booking['createdAt'] as Timestamp).toDate();
              }
              
              double cost = (booking['finalCost'] ?? 0).toDouble();
              int rating = (booking['rating'] ?? 0).toInt();

              return Card(
                color: Color(0xFF1E1E1E),
                margin: EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsScreen(booking: booking, bookingId: docs[index].id)));
                  },
                  leading: CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
                  ),
                  title: Text(
                    date != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(date) : "Unknown Date",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Status: ${status.toUpperCase()}", style: TextStyle(
                        color: _getStatusColor(status), fontSize: 12, fontWeight: FontWeight.bold
                      )),
                      if (status == 'completed') ...[
                        Text("Cost: ₹${cost.toStringAsFixed(0)}", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        if (rating > 0) 
                          Row(children: List.generate(5, (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border, 
                            size: 12, color: Colors.amber
                          ))),
                      ] else if (status == 'cancelled') ...[
                         // Show fee if any
                         Text(
                           "Fee: ₹${(booking['cancellationFee'] ?? booking['finalCost'] ?? 0).toString()}", 
                           style: TextStyle(color: Colors.redAccent, fontSize: 12)
                         ),
                      ]
                    ],
                  ),
                  trailing: status == 'completed' 
                    ? Icon(Icons.check_circle, color: Colors.green)
                    : (status == 'cancelled' ? Icon(Icons.cancel, color: Colors.red) : Icon(Icons.incomplete_circle, color: Colors.amber)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    if (status == 'completed') return Icons.flag;
    if (status == 'started') return Icons.pedal_bike;
    if (status == 'booked') return Icons.bookmark;
    if (status == 'end_requested') return Icons.timer;
    if (status == 'cancelled') return Icons.cancel;
    return Icons.help;
  }

  Color _getStatusColor(String status) {
    if (status == 'completed') return Colors.green;
    if (status == 'started') return Colors.blue;
    if (status == 'booked') return Colors.orange;
    if (status == 'end_requested') return Colors.amber;
    if (status == 'cancelled') return Colors.red;
    return Colors.grey;
  }
}
