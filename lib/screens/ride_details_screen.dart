import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class RideDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  final String bookingId;

  RideDetailsScreen({required this.booking, required this.bookingId});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  late String _status;
  double? _finalCost;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _status = widget.booking['status'] ?? 'unknown';
    _finalCost = widget.booking['finalCost'] != null ? (widget.booking['finalCost']).toDouble() : null;
  }

  /// Calculate cost for actual ride duration using the same formula as cycle_detail_screen
  double _calculateCostForDuration(double hours) {
    int basePrice = (widget.booking['basePrice'] ?? widget.booking['cycleData']?['basePrice'] ?? 20).toInt();
    int hourlyPrice = (widget.booking['hourlyPrice'] ?? widget.booking['cycleData']?['hourlyPrice'] ?? 10).toInt();

    if (hours <= 0) return 0;
    if (hours <= 2) return basePrice.toDouble();
    double extraHours = hours - 2;
    return basePrice + (extraHours.ceil() * hourlyPrice).toDouble();
  }

  Future<void> _ownerCancelBooking() async {
    // For 'booked' status — ride never started, no charge
    bool confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Cancel This Booking?", style: TextStyle(color: Colors.white)),
        content: Text(
          "The renter will not be charged since the ride was never started.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("BACK", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("CANCEL BOOKING", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).update({
        'status': 'owner_cancelled',
        'endTime': FieldValue.serverTimestamp(),
        'finalCost': 0,
        'ownerCancelledAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _status = 'owner_cancelled';
        _finalCost = 0;
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Booking cancelled. Renter was not charged."), backgroundColor: Colors.orange),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _ownerEndRide() async {
    // For 'started' status — calculate cost for actual time used
    DateTime now = DateTime.now();
    DateTime? rideStartTime;

    if (widget.booking['startTime'] != null) {
      rideStartTime = (widget.booking['startTime'] as Timestamp).toDate();
    } else if (widget.booking['scheduledStartTime'] != null) {
      rideStartTime = (widget.booking['scheduledStartTime'] as Timestamp).toDate();
    }

    if (rideStartTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cannot determine ride start time."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    double hoursUsed = now.difference(rideStartTime).inMinutes / 60.0;
    double cost = _calculateCostForDuration(hoursUsed);
    String durationText = hoursUsed < 1 
        ? "${now.difference(rideStartTime).inMinutes} minutes" 
        : "${hoursUsed.toStringAsFixed(1)} hours";

    bool confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("End This Ride?", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Ride duration: $durationText", style: TextStyle(color: Colors.white70)),
            SizedBox(height: 12),
            Text(
              "Cost: ₹${cost.toStringAsFixed(0)}",
              style: TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "The renter will be charged for the time used.",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("BACK", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("END RIDE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).update({
        'status': 'payment_pending',
        'endTime': FieldValue.serverTimestamp(),
        'finalCost': cost,
        'ownerEndedAt': FieldValue.serverTimestamp(),
        'ownerEnded': true,
      });

      setState(() {
        _status = 'payment_pending';
        _finalCost = cost;
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ride ended. Renter owes ₹${cost.toStringAsFixed(0)}."), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String cycleId = widget.booking['cycleId'];
    String ownerId = widget.booking['ownerId'];
    String userId = widget.booking['userId'];
    
    // Dynamic Logic: Who is viewing?
    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    bool isOwnerViewing = currentUserId == ownerId;
    
    String targetUserId = isOwnerViewing ? userId : ownerId;
    String targetUserLabel = isOwnerViewing ? "Renter Details" : "Owner Details";
    
    Timestamp? startTime = widget.booking['startTime'];
    Timestamp? endTime = widget.booking['endTime'];
    double cost = _finalCost ?? (widget.booking['finalCost'] ?? 0).toDouble();

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
                color: _status == 'completed' ? Colors.green.withOpacity(0.1) : 
                       (_status == 'cancelled' || _status == 'owner_cancelled' ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _status == 'completed' ? Colors.green : 
                                   (_status == 'cancelled' || _status == 'owner_cancelled' ? Colors.red : Colors.blue)),
              ),
              child: Column(
                children: [
                  Text(
                    _status == 'completed' ? "RIDE COMPLETED" : 
                    (_status == 'cancelled' ? "RIDE CANCELLED" : 
                    (_status == 'owner_cancelled' ? "CANCELLED BY OWNER" :
                    (_status == 'payment_pending' ? "PAYMENT PENDING" : "RIDE ONGOING"))),
                    style: TextStyle(
                      color: _status == 'completed' ? Colors.green : 
                             (_status == 'cancelled' || _status == 'owner_cancelled' ? Colors.red : Colors.blue),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (_status == 'completed' || _status == 'payment_pending') ...[
                    SizedBox(height: 8),
                    Text(
                      "Total Cost: ₹${cost.toStringAsFixed(0)}",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ] else if (_status == 'cancelled') ...[
                    SizedBox(height: 8),
                    Text(
                      "Cancellation Fee: ₹${(widget.booking['cancellationFee'] ?? widget.booking['finalCost'] ?? 0).toString()}",
                      style: TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ] else if (_status == 'owner_cancelled') ...[
                    SizedBox(height: 8),
                    Text(
                      "No charge — cancelled by owner",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ]
                ],
              ),
            ),
            SizedBox(height: 20),

            // LISTING DETAILS
            Text(widget.booking.containsKey('itemId') ? "Item Details" : "Cycle Details", style: TextStyle(color: Colors.grey, fontSize: 14)),
            SizedBox(height: 8),
            FutureBuilder<DocumentSnapshot>(
              future: widget.booking.containsKey('itemId')
                  ? FirebaseFirestore.instance.collection('items').doc(widget.booking['itemId']).get()
                  : FirebaseFirestore.instance.collection('cycles').doc(cycleId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return LinearProgressIndicator();
                
                String listingName = "Unknown Item/Cycle";
                String imageUrl = "";
                String location = "Unknown Location";

                if (snapshot.hasData && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  listingName = data['itemName'] ?? data['modelName'] ?? "Unknown Listing";
                  imageUrl = data['imageUrl'] ?? "";
                  location = data['location'] ?? "Unknown Location";
                } else if (widget.booking['itemData'] != null) {
                  var data = widget.booking['itemData'];
                  listingName = data['itemName'] ?? "Item";
                  imageUrl = data['imageUrl'] ?? "";
                  location = data['location'] ?? "Campus";
                } else if (widget.booking['cycleData'] != null) {
                  var data = widget.booking['cycleData'];
                  listingName = data['modelName'] ?? "Cycle";
                  imageUrl = data['imageUrl'] ?? "";
                  location = data['location'] ?? "Campus";
                } else {
                    return Text("Listing information no longer available.");
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
                            Text(listingName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                   if (widget.booking['renterName'] != null) name = widget.booking['renterName'];
                   if (widget.booking['renterPhone'] != null) phone = widget.booking['renterPhone'];
                } else {
                   // Viewing Owner
                   if (widget.booking['ownerName'] != null) name = widget.booking['ownerName'];
                   if (widget.booking['ownerPhone'] != null) phone = widget.booking['ownerPhone'];
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
                    if (_status == 'cancelled' || _status == 'owner_cancelled')
                       _buildInfoRow(Icons.cancel, "Cancelled At", widget.booking['cancelledAt'] != null ? DateFormat('MMM d, h:mm a').format((widget.booking['cancelledAt'] as Timestamp).toDate()) : 
                          (widget.booking['ownerCancelledAt'] != null ? DateFormat('MMM d, h:mm a').format((widget.booking['ownerCancelledAt'] as Timestamp).toDate()) : "Just now"))
                    else
                       _buildInfoRow(Icons.flag, "End Time", endTime != null ? DateFormat('MMM d, h:mm a').format(endTime.toDate()) : "Ongoing"),
                  ],
                ),
              ),
            ),

            // OWNER ACTION BUTTON
            if (isOwnerViewing && (_status == 'booked' || _status == 'started')) ...[
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isProcessing 
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_status == 'started' ? Icons.stop_circle : Icons.cancel, color: Colors.white),
                  label: Text(
                    _status == 'started' ? "END RIDE" : "CANCEL BOOKING",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: _isProcessing ? null : () {
                    if (_status == 'started') {
                      _ownerEndRide();
                    } else {
                      _ownerCancelBooking();
                    }
                  },
                ),
              ),
            ],

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
