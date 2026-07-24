import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class ItemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String itemId;
  final DateTime? initialStartTime;
  final DateTime? initialEndTime;

  const ItemDetailScreen({
    super.key,
    required this.data,
    required this.itemId,
    this.initialStartTime,
    this.initialEndTime,
  });

  @override
  _ItemDetailScreenState createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(Duration(hours: 2));
  double _totalCost = 0;
  double _durationInHours = 2.0;

  User? currentUser = FirebaseAuth.instance.currentUser;
  String? _bookingId;
  String? _bookingStatus = 'none'; // none, booked, started, payment_pending, completed
  DateTime? _scheduledStartTime;
  DateTime? _scheduledEndTime;

  final TextEditingController _reviewController = TextEditingController();
  int _selectedRating = 5;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _startTime = now;

    if (widget.initialStartTime != null) {
      _startTime = widget.initialStartTime!;
    }
    if (widget.initialEndTime != null) {
      _endTime = widget.initialEndTime!;
      if (_endTime.isBefore(_startTime)) {
        _endTime = _startTime.add(Duration(hours: 2));
      }
    } else {
      _endTime = _startTime.add(Duration(hours: 2));
    }

    _calculateCost();
    _checkActiveBooking();
  }

  Future<void> _checkActiveBooking() async {
    if (currentUser == null) return;

    var query = await FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: currentUser!.uid)
        .where('itemId', isEqualTo: widget.itemId)
        .where('status', whereIn: ['booked', 'started', 'payment_pending'])
        .get();

    if (query.docs.isNotEmpty) {
      var doc = query.docs.first;
      var data = doc.data();
      setState(() {
        _bookingId = doc.id;
        _bookingStatus = data['status'];
        if (data['scheduledStartTime'] != null) {
          _scheduledStartTime = (data['scheduledStartTime'] as Timestamp).toDate();
        }
        if (data['scheduledEndTime'] != null) {
          _scheduledEndTime = (data['scheduledEndTime'] as Timestamp).toDate();
        }
      });
    }
  }

  void _calculateCost() {
    int basePrice = widget.data['basePrice'] ?? 20;
    int hourlyPrice = widget.data['hourlyPrice'] ?? 7;

    double minutes = _endTime.difference(_startTime).inMinutes.toDouble();
    if (minutes < 0) minutes = 0;
    _durationInHours = minutes / 60.0;

    if (_durationInHours <= 2.0) {
      _totalCost = basePrice.toDouble();
    } else {
      double extraHours = (_durationInHours - 2.0);
      int extraHoursCeil = extraHours.ceil();
      _totalCost = (basePrice + (extraHoursCeil * hourlyPrice)).toDouble();
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (picked != null) {
      DateTime now = DateTime.now();
      DateTime newStart = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      if (newStart.isBefore(now.subtract(Duration(minutes: 5)))) {
        newStart = newStart.add(Duration(days: 1));
      }
      setState(() {
        _startTime = newStart;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(Duration(hours: 2));
        }
        _calculateCost();
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endTime),
    );
    if (picked != null) {
      DateTime newEnd = DateTime(_startTime.year, _startTime.month, _startTime.day, picked.hour, picked.minute);
      if (newEnd.isBefore(_startTime)) {
        newEnd = newEnd.add(Duration(days: 1));
      }
      setState(() {
        _endTime = newEnd;
        _calculateCost();
      });
    }
  }

  Future<void> _createBooking() async {
    try {
      var ref = await FirebaseFirestore.instance.collection('bookings').add({
        'userId': currentUser!.uid,
        'renterName': currentUser!.displayName ?? 'Student',
        'ownerId': widget.data['ownerId'],
        'itemId': widget.itemId,
        'itemType': 'generic',
        'status': 'booked',
        'createdAt': FieldValue.serverTimestamp(),
        'basePrice': widget.data['basePrice'],
        'hourlyPrice': widget.data['hourlyPrice'],
        'itemData': widget.data,
        'cycleData': {
          'modelName': widget.data['itemName'],
          'location': widget.data['location'],
          'gearType': widget.data['itemType'],
          'imageUrl': widget.data['imageUrl'],
        },
        'ownerName': widget.data['ownerName'] ?? 'Student',
        'ownerPhone': widget.data['ownerPhone'] ?? 'N/A',
        'scheduledStartTime': _startTime,
        'scheduledEndTime': _endTime,
      });

      setState(() {
        _bookingId = ref.id;
        _bookingStatus = 'booked';
        _scheduledStartTime = _startTime;
        _scheduledEndTime = _endTime;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Item Reserved Successfully!")),
      );

      _openWhatsApp();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Booking Failed: $e")));
    }
  }

  Future<void> _openWhatsApp() async {
    String phone = widget.data['ownerPhone'] ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Owner phone number not provided")));
      return;
    }
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    String startFmt = DateFormat('h:mm a').format(_startTime);
    String endFmt = DateFormat('h:mm a').format(_endTime);
    String msg = "Hi ${widget.data['ownerName']}, I have booked your item '${widget.data['itemName']}' on Campus Spokes for $startFmt - $endFmt. My room is ${widget.data['roomNumber'] ?? 'N/A'}. Please coordinate pick-up at ${widget.data['location']} Bhavan.";

    final Uri url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not launch WhatsApp")));
    }
  }

  Future<void> _startSession() async {
    if (_bookingId == null) return;
    await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
      'status': 'started',
      'startTime': FieldValue.serverTimestamp(),
    });
    setState(() => _bookingStatus = 'started');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rental Session Started!")));
  }

  Future<void> _endSession() async {
    if (_bookingId == null) return;
    await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
      'status': 'payment_pending',
      'endTime': FieldValue.serverTimestamp(),
      'finalCost': _totalCost,
    });
    setState(() => _bookingStatus = 'payment_pending');
    _showPaymentDialog();
  }

  void _showPaymentDialog() {
    String upi = widget.data['ownerUpiId'] ?? 'N/A';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text("Payment Details", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total Amount: ₹${_totalCost.toStringAsFixed(0)}", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text("Owner UPI ID:", style: TextStyle(color: Colors.grey, fontSize: 12)),
            SelectableText(upi, style: TextStyle(color: Colors.indigoAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text("Please send payment via GPay/PhonePe/Paytm to the UPI ID above.", style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
                'status': 'completed',
                'paymentConfirmed': true,
              });
              Navigator.pop(context);
              setState(() => _bookingStatus = 'completed');
              _showReviewDialog();
            },
            child: Text("I Have Paid", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReviewDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Color(0xFF1E1E1E),
          title: Text("Rate Your Experience", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () {
                      setDialogState(() => _selectedRating = index + 1);
                    },
                  );
                }),
              ),
              TextField(
                controller: _reviewController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Leave feedback for the item/owner...",
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Skip", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('items').doc(widget.itemId).collection('reviews').add({
                  'userId': currentUser?.uid,
                  'userName': currentUser?.displayName ?? 'Anonymous',
                  'rating': _selectedRating,
                  'comment': _reviewController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Thank you for your feedback!")));
              },
              child: Text("Submit", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(height: 250, color: Colors.grey[900], child: Icon(Icons.inventory_2, size: 80, color: Colors.white24));
    }
    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl, height: 250, width: double.infinity, fit: BoxFit.cover);
    }
    try {
      return Image.memory(base64Decode(imageUrl), height: 250, width: double.infinity, fit: BoxFit.cover);
    } catch (_) {
      return Container(height: 250, color: Colors.grey[900], child: Icon(Icons.broken_image, size: 80, color: Colors.white24));
    }
  }

  @override
  Widget build(BuildContext context) {
    String itemName = widget.data['itemName'] ?? 'Item';
    String itemType = widget.data['itemType'] ?? 'General';
    String location = widget.data['location'] ?? 'Campus';
    int basePrice = widget.data['basePrice'] ?? 20;
    int hourlyPrice = widget.data['hourlyPrice'] ?? 7;
    String description = widget.data['description'] ?? 'No description provided.';
    String ownerName = widget.data['ownerName'] ?? 'Student';
    String roomNumber = widget.data['roomNumber'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text(itemName),
        backgroundColor: Color(0xFF1E1E1E),
      ),
      body: ListView(
        children: [
          _buildImage(widget.data['imageUrl']),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(itemName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(16)),
                      child: Text(itemType, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.indigoAccent, size: 18),
                    SizedBox(width: 6),
                    Text("Collect From: $location Bhavan (Room $roomNumber)", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, color: Colors.indigoAccent, size: 18),
                    SizedBox(width: 6),
                    Text("Owner: $ownerName", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
                Divider(color: Colors.white24, height: 32),

                // Rates & Description
                Text("Pricing Structure", style: TextStyle(color: Colors.indigoAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text("• Base Rate: ₹$basePrice for first 2 hours", style: TextStyle(color: Colors.white, fontSize: 14)),
                Text("• Hourly Rate: ₹$hourlyPrice / hour after 2 hours", style: TextStyle(color: Colors.white, fontSize: 14)),
                SizedBox(height: 16),
                Text("Description", style: TextStyle(color: Colors.indigoAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text(description, style: TextStyle(color: Colors.white70, fontSize: 14)),
                Divider(color: Colors.white24, height: 32),

                // Time Slot Selector
                if (_bookingStatus == 'none') ...[
                  Text("Select Duration", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.access_time, color: Colors.indigoAccent),
                          label: Text("Start: ${DateFormat('h:mm a').format(_startTime)}", style: TextStyle(color: Colors.white)),
                          onPressed: _selectStartTime,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.access_time_filled, color: Colors.indigoAccent),
                          label: Text("End: ${DateFormat('h:mm a').format(_endTime)}", style: TextStyle(color: Colors.white)),
                          onPressed: _selectEndTime,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Estimated Total", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text("${_durationInHours.toStringAsFixed(1)} hours rental", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        Text("₹${_totalCost.toStringAsFixed(0)}", style: TextStyle(color: Colors.indigoAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text("RESERVE ITEM NOW", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],

                // Active Booking Management
                if (_bookingStatus == 'booked') ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.amber),
                            SizedBox(width: 8),
                            Text("Item Reserved!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text("Contact the owner on WhatsApp to pick up the item at ${location} Bhavan.", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.chat, color: Colors.white),
                                label: Text("WhatsApp Owner"),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                onPressed: _openWhatsApp,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.play_arrow, color: Colors.white),
                                label: Text("Start Session"),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                                onPressed: _startSession,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],

                if (_bookingStatus == 'started') ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timer, color: Colors.blue),
                            SizedBox(width: 8),
                            Text("Rental In Progress", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text("Return item to owner when finished and tap 'End Rental Session'.", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.stop, color: Colors.white),
                            label: Text("END RENTAL SESSION"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: EdgeInsets.symmetric(vertical: 14)),
                            onPressed: _endSession,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_bookingStatus == 'payment_pending') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showPaymentDialog,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: EdgeInsets.symmetric(vertical: 16)),
                      child: Text("VIEW PAYMENT INFO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],

                Divider(color: Colors.white24, height: 40),

                // Reviews Section
                Text("Reviews & Ratings", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('items')
                      .doc(widget.itemId)
                      .collection('reviews')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return CircularProgressIndicator(color: Colors.indigoAccent);
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Text("No reviews yet for this item.", style: TextStyle(color: Colors.grey));
                    }
                    var reviews = snapshot.data!.docs;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: reviews.length,
                      itemBuilder: (context, index) {
                        var rev = reviews[index].data() as Map<String, dynamic>;
                        return Container(
                          margin: EdgeInsets.only(bottom: 10),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(rev['userName'] ?? 'Anonymous', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  Row(
                                    children: List.generate(5, (i) {
                                      return Icon(
                                        i < (rev['rating'] ?? 5) ? Icons.star : Icons.star_border,
                                        color: Colors.amber,
                                        size: 16,
                                      );
                                    }),
                                  )
                                ],
                              ),
                              if ((rev['comment'] ?? '').isNotEmpty) ...[
                                SizedBox(height: 4),
                                Text(rev['comment'], style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ]
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
