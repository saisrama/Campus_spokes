import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class RideDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String bookingId;

  RideDetailsScreen({required this.booking, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    String cycleId = booking['cycleId'];
    String ownerId = booking['ownerId'];
    String userId = booking['userId'];
    String status = booking['status'] ?? 'unknown';
    
    // Dynamic Logic: Who is viewing?
    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    bool isOwnerViewing = currentUserId == ownerId;
    
    String targetUserId = isOwnerViewing ? userId : ownerId;
    String targetUserLabel = isOwnerViewing ? "Renter Details" : "Owner Details";
    
    Timestamp? startTime = booking['startTime'];
    Timestamp? endTime = booking['endTime'];
    double cost = (booking['finalCost'] ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(title: Text("Ride Details")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STATUS BANNER
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: status == 'completed' ? Colors.green.withOpacity(0.1) : 
                       (status == 'cancelled' ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: status == 'completed' ? Colors.green : 
                                   (status == 'cancelled' ? Colors.red : Colors.blue)),
              ),
              child: Column(
                children: [
                  Text(
                    status == 'completed' ? "RIDE COMPLETED" : 
                    (status == 'cancelled' ? "RIDE CANCELLED" : "RIDE ONGOING"),
                    style: TextStyle(
                      color: status == 'completed' ? Colors.green : 
                             (status == 'cancelled' ? Colors.red : Colors.blue),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (status == 'completed') ...[
                    SizedBox(height: 8),
                    Text(
                      "Total Cost: ₹${cost.toStringAsFixed(0)}",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ] else if (status == 'cancelled') ...[
                    SizedBox(height: 8),
                    Text(
                      "Cancellation Fee: ₹${(booking['cancellationFee'] ?? booking['finalCost'] ?? 0).toString()}",
                      style: TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ]
                ],
              ),
            ),
            SizedBox(height: 20),

            // CYCLE DETAILS
            Text("Cycle Details", style: TextStyle(color: Colors.grey, fontSize: 14)),
            SizedBox(height: 8),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('cycles').doc(cycleId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return LinearProgressIndicator();
                
                String cycleName = "Unknown Cycle";
                String imageUrl = "";
                String location = "Unknown Location";

                if (snapshot.hasData && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  cycleName = data['modelName'] ?? "Unknown Cycle";
                  imageUrl = data['imageUrl'] ?? "";
                  location = data['location'] ?? "Unknown Location";
                } else {
                    // Fallback to booking data if cycle is deleted
                    // In a real app we would store snapshot in booking
                    return Text("Cycle information no longer available.");
                }

                return Card(
                  color: Color(0xFF1E1E1E),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          child: _buildImage(
                            imageUrl, 
                            height: 150, 
                            width: double.infinity, 
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cycleName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.grey),
                                SizedBox(width: 4),
                                Text(location, style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: 20),

            // USER DETAILS (Dynamic: Owner or Renter)
            Text(targetUserLabel, style: TextStyle(color: Colors.grey, fontSize: 14)),
            SizedBox(height: 8),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(targetUserId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return LinearProgressIndicator();
                
                String name = "Unknown User";
                String phone = "N/A";
                String studentId = "N/A"; 

                // 1. Try to use Snapshot Data from Booking (Fallback/Default)
                if (isOwnerViewing) {
                   // Viewing Renter
                   if (booking['renterName'] != null) name = booking['renterName'];
                   if (booking['renterPhone'] != null) phone = booking['renterPhone'];
                } else {
                   // Viewing Owner
                   if (booking['ownerName'] != null) name = booking['ownerName'];
                   if (booking['ownerPhone'] != null) phone = booking['ownerPhone'];
                }

                // 2. Overwrite with Live Data if available
                if (snapshot.hasData && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  name = data['displayName'] ?? name;
                  phone = data['phoneNumber'] ?? phone;
                  studentId = data['studentId'] ?? studentId;
                }

                return Card(
                  color: Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.person, "Name", name),
                        Divider(color: Colors.white12),
                        _buildInfoRow(Icons.phone, "Phone", phone),
                        Divider(color: Colors.white12),
                        _buildInfoRow(Icons.badge, "Student ID", studentId),
                      ],
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 20),

            // TIMING DETAILS
            Text("Ride Timeline", style: TextStyle(color: Colors.grey, fontSize: 14)),
            SizedBox(height: 8),
            Card(
              color: Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.play_circle_fill, "Start Time", startTime != null ? DateFormat('MMM d, h:mm a').format(startTime.toDate()) : "Not Started"),
                    Divider(color: Colors.white12),
                    if (status == 'cancelled')
                       _buildInfoRow(Icons.cancel, "Cancelled At", booking['cancelledAt'] != null ? DateFormat('MMM d, h:mm a').format((booking['cancelledAt'] as Timestamp).toDate()) : "Unknown")
                    else
                       _buildInfoRow(Icons.flag, "End Time", endTime != null ? DateFormat('MMM d, h:mm a').format(endTime.toDate()) : "Ongoing"),
                  ],
                ),
              ),
            ),
             SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildImage(String? imageUrl, {double? width, double? height, double iconSize = 50}) {
     if (imageUrl == null || imageUrl.isEmpty) {
        return Container(
          width: width, height: height,
          color: Colors.grey[850],
          child: Center(child: Icon(Icons.directions_bike, size: iconSize, color: Colors.white24)),
        );
     }

     if (imageUrl.startsWith('http')) {
        return Image.network(
          imageUrl,
          width: width, height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
             width: width, height: height,
             color: Colors.grey[850],
             child: Center(child: Icon(Icons.directions_bike, size: iconSize, color: Colors.white24)),
          ),
        );
     }

     try {
       // Base64
       return Image.memory(
         base64Decode(imageUrl),
         width: width, height: height,
         fit: BoxFit.cover,
         errorBuilder: (context, error, stackTrace) => Container(
             width: width, height: height,
             color: Colors.grey[850],
             child: Center(child: Icon(Icons.broken_image, size: iconSize, color: Colors.white24)),
          ),
       );
     } catch (e) {
        return Container(
          width: width, height: height,
          color: Colors.grey[850],
          child: Center(child: Icon(Icons.error, size: iconSize, color: Colors.white24)),
        );
     }
  }
}
