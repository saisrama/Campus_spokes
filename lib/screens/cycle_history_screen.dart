import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CycleHistoryScreen extends StatelessWidget {
  final String cycleId;
  final Map<String, dynamic> cycleData;

  CycleHistoryScreen({required this.cycleId, required this.cycleData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(cycleData['modelName'] ?? "Cycle History"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('cycleId', isEqualTo: cycleId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No bookings yet.", style: TextStyle(color: Colors.grey)),
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
              String userId = booking['userId'];
              String status = booking['status'] ?? 'unknown';
              bool isOngoing = ['booked', 'started', 'payment_pending', 'end_requested'].contains(status);
              
              Timestamp? startTime = booking['startTime'];
              Timestamp? endTime = booking['endTime'];
              double cost = (booking['finalCost'] ?? 0).toDouble();

              // NO-SHOW Handling
              bool isNoShow = booking['isNoShow'] ?? false;
              String statusLabel = isOngoing ? "ONGOING RIDE" : "COMPLETED";
              Color labelColor = isOngoing ? Colors.blue : Colors.green;
              
              if (isNoShow) {
                 statusLabel = "NO SHOW";
                 labelColor = Colors.redAccent;
              }

              return Card(
                color: isOngoing ? Colors.blue.withOpacity(0.1) : Color(0xFF1E1E1E),
                margin: EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isOngoing ? BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER: STATUS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: labelColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (!isOngoing)
                            Text(
                              "₹${cost.toStringAsFixed(0)}",
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                        ],
                      ),
                      Divider(color: Colors.white12),

                      // RENTER DETAILS (Fetch from Users collection)
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return Text("Loading Renter...", style: TextStyle(color: Colors.grey, fontSize: 12));
                          }
                          
                          String renterName = "Unknown User";
                          String renterPhone = "N/A";
                          String renterId = "N/A";

                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                            renterName = userData['displayName'] ?? "Unknown User";
                            renterPhone = userData['phoneNumber'] ?? "N/A";
                            renterId = userData['studentId'] ?? "N/A";
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(Icons.person, renterName),
                              _buildInfoRow(Icons.badge, "ID: $renterId"),
                              _buildInfoRow(Icons.phone, renterPhone),
                            ],
                          );
                        },
                      ),
                      
                      SizedBox(height: 8),
                      // TIME DETAILS
                      if (startTime != null)
                        _buildInfoRow(Icons.access_time, "Start: ${DateFormat('MMM d, h:mm a').format(startTime.toDate())}"),
                      if (endTime != null)
                        _buildInfoRow(Icons.flag, "End:   ${DateFormat('MMM d, h:mm a').format(endTime.toDate())}"),
                      
                      if(isOngoing && startTime != null) ...[
                         SizedBox(height: 4),
                         Text("Ride is still ongoing...", style: TextStyle(color: Colors.blueAccent, fontStyle: FontStyle.italic, fontSize: 12)),
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}
