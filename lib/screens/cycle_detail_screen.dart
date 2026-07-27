import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_image_viewer.dart';
import 'success_screen.dart';


class CycleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String cycleId;
  final DateTime? initialStartTime;
  final DateTime? initialEndTime;

  const CycleDetailScreen({
    super.key,
    required this.data, 
    required this.cycleId,
    this.initialStartTime,
    this.initialEndTime,
  });

  @override
  _CycleDetailScreenState createState() => _CycleDetailScreenState();
}

class _CycleDetailScreenState extends State<CycleDetailScreen> {
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));
  double _totalCost = 0;
  double _durationInHours = 2.0;

  User? currentUser = FirebaseAuth.instance.currentUser;
  String? _bookingId;
  String? _bookingStatus = 'none';
  DateTime? _rideStartTime;
  DateTime? _scheduledStartTime;
  DateTime? _scheduledEndTime;
  bool _isNoShow = false;

  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  final TextEditingController _reviewController = TextEditingController();

  List<String> get _allImageUrls {
    if (widget.data['imageUrls'] is List && (widget.data['imageUrls'] as List).isNotEmpty) {
      return List<String>.from(widget.data['imageUrls']);
    }
    if ((widget.data['imageUrl'] ?? '').isNotEmpty) {
      return [widget.data['imageUrl']];
    }
    return [];
  }

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
          _endTime = _startTime.add(const Duration(hours: 2));
       }
    } else {
       _endTime = _startTime.add(const Duration(hours: 2));
    }

    _calculateCost();
    _checkActiveBooking();
  }

  Future<void> _checkActiveBooking() async {
    if (currentUser == null) return;
    
    var query = await FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: currentUser!.uid)
        .where('cycleId', isEqualTo: widget.cycleId)
        .where('status', whereIn: ['booked', 'started', 'payment_pending'])
        .get();

    if (query.docs.isNotEmpty) {
      var doc = query.docs.first;
      var data = doc.data();
      String status = data['status'];
      bool isNoShowDoc = data['isNoShow'] ?? false;
      
      DateTime? startTimeStamp;
      DateTime? scheduledStartX;
      DateTime? scheduledEndX;
      
      if (data['startTime'] != null) startTimeStamp = (data['startTime'] as Timestamp).toDate();
      if (data.containsKey('scheduledStartTime')) {
          scheduledStartX = (data['scheduledStartTime'] as Timestamp).toDate();
      }
      if (data.containsKey('scheduledEndTime')) {
          scheduledEndX = (data['scheduledEndTime'] as Timestamp).toDate();
      }

      if (status == 'booked' && scheduledEndX != null && DateTime.now().isAfter(scheduledEndX)) {
          await FirebaseFirestore.instance.collection('bookings').doc(doc.id).update({
            'status': 'no_show',
            'isNoShow': true,
          });

          if (mounted) {
            setState(() {
              _bookingId = doc.id;
              _bookingStatus = 'no_show';
              _isNoShow = true;
            });
          }
          return;
      }

      if (mounted) {
        setState(() {
          _bookingId = doc.id;
          _bookingStatus = status;
          _rideStartTime = startTimeStamp;
          _scheduledStartTime = scheduledStartX;
          _scheduledEndTime = scheduledEndX;
          _isNoShow = isNoShowDoc;

          if (scheduledStartX != null) _startTime = scheduledStartX;
          if (scheduledEndX != null) _endTime = scheduledEndX;
          _calculateCost();
        });
      }
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
      _totalCost = basePrice.toDouble() + (extraHours * hourlyPrice);
    }
  }

  Future<void> _selectTime(bool isStart) async {
    DateTime initial = isStart ? _startTime : _endTime;
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: kTextPrimary, surface: kSurface1),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        DateTime now = DateTime.now();
        DateTime newDate = DateTime(now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);
        if (isStart) {
          _startTime = newDate;
          if (_endTime.isBefore(_startTime)) {
            _endTime = _startTime.add(const Duration(hours: 2));
          }
        } else {
          _endTime = newDate;
          if (_endTime.isBefore(_startTime)) {
            _endTime = _startTime.add(const Duration(hours: 1));
          }
        }
        _calculateCost();
      });
    }
  }

  Future<void> _createBooking() async {
    try {
      var ref = await FirebaseFirestore.instance.collection('bookings').add({
        'userId': currentUser!.uid,
        'ownerId': widget.data['ownerId'],
        'cycleId': widget.cycleId,
        'status': 'booked',
        'createdAt': FieldValue.serverTimestamp(),
        'basePrice': widget.data['basePrice'], 
        'hourlyPrice': widget.data['hourlyPrice'],
        'cycleData': widget.data, 
        'ownerName': widget.data['ownerName'] ?? 'Student',
        'ownerPhone': widget.data['ownerPhone'] ?? 'N/A',
        'scheduledStartTime': _startTime,
        'scheduledEndTime': _endTime,
      });

      _scheduledStartTime = _startTime;
      _scheduledEndTime = _endTime;

      DateTime nextAvailable = _scheduledEndTime!.add(const Duration(minutes: 30));
      await FirebaseFirestore.instance.collection('cycles').doc(widget.cycleId).update({
        'nextAvailableTime': nextAvailable,
      });

      if (mounted) {
        setState(() {
          _bookingId = ref.id;
          _bookingStatus = 'booked';
        });

        final startTimeStr = DateFormat('MMM d, h:mm a').format(_startTime);
        final endTimeStr = DateFormat('MMM d, h:mm a').format(_endTime);
        final message = "Hi ${widget.data['ownerName'] ?? 'there'}, I just reserved your cycle *${widget.data['modelName']}* on *RentX*.\n\n"
            "*Time:* $startTimeStr to $endTimeStr\n"
            "*Estimated Cost:* ₹${_totalCost.toStringAsFixed(0)}\n\nPlease confirm availability.";

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SuccessScreen(
              type: SuccessType.cycleRental,
              itemName: widget.data['modelName'] ?? 'Cycle',
              ownerName: widget.data['ownerName'] ?? 'Owner',
              ownerPhone: widget.data['ownerPhone'] ?? '',
              startTime: startTimeStr,
              endTime: endTimeStr,
              totalCost: _totalCost,
              whatsappMessage: message,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Booking failed: $e"), backgroundColor: Colors.redAccent));
    }
  }


  void _openFullScreenViewer(int initialIndex) {
    final urls = _allImageUrls;
    if (urls.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(imageUrls: urls, initialIndex: initialIndex),
      ),
    );
  }

  Widget _buildSingleImage(String url, int index) {
    Widget img;
    if (url.startsWith('http')) {
      img = Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: kSurface1, child: const Icon(Icons.pedal_bike, size: 80, color: kTextDim)));
    } else {
      try {
        img = Image.memory(base64Decode(url), fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: kSurface1, child: const Icon(Icons.broken_image, size: 80, color: kTextDim)));
      } catch (_) {
        img = Container(color: kSurface1, child: const Icon(Icons.error_outline, size: 80, color: kTextDim));
      }
    }
    return GestureDetector(
      onTap: () => _openFullScreenViewer(index),
      child: img,
    );
  }

  Widget _buildImageGallery() {
    final urls = _allImageUrls;
    if (urls.isEmpty) {
      return Container(height: 280, color: kSurface1, child: const Center(child: Icon(Icons.pedal_bike, size: 80, color: kTextDim)));
    }
    if (urls.length == 1) return _buildSingleImage(urls.first, 0);

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: urls.length,
          onPageChanged: (i) => setState(() => _currentImageIndex = i),
          itemBuilder: (context, index) => _buildSingleImage(urls[index], index),
        ),
        Positioned(
          bottom: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: urls.asMap().entries.map((entry) {
              return Container(
                width: _currentImageIndex == entry.key ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _currentImageIndex == entry.key ? kTextPrimary : kTextPrimary.withValues(alpha: 0.4),
                ),
              );
            }).toList(),
          ),
        ),
        Positioned(
          top: 12, right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(12)),
            child: Text("${_currentImageIndex + 1}/${urls.length}", style: const TextStyle(color: kTextPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String modelName = widget.data['modelName'] ?? 'Cycle Details';
    String location = widget.data['location'] ?? 'Campus';
    String ownerName = widget.data['ownerName'] ?? 'Owner';
    String gearType = widget.data['gearType'] ?? 'Single Geared';
    int basePrice = widget.data['basePrice'] ?? 20;
    int hourlyPrice = widget.data['hourlyPrice'] ?? 7;

    return Scaffold(
      backgroundColor: kBgColor,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: kBgColor,
                  expandedHeight: 280,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildImageGallery(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(modelName, style: const TextStyle(color: kTextPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text("Owner: $ownerName • Parked at $location", style: const TextStyle(color: kTextMuted, fontSize: 13)),
                                ],
                              ),
                            ),
                            rentXBadge(gearType, color: kAccentCyan),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              child: rentXCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("BASE PRICE", style: TextStyle(color: kTextDim, fontSize: 10, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text("₹$basePrice", style: const TextStyle(color: kTextPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                                    const Text("First 2 hours", style: TextStyle(color: kTextMuted, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: rentXCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("HOURLY RATE", style: TextStyle(color: kTextDim, fontSize: 10, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text("₹$hourlyPrice/hr", style: const TextStyle(color: kTextPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                                    const Text("After 2 hours", style: TextStyle(color: kTextMuted, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        rentXSectionLabel("TIME SLOT"),
                        if (_bookingStatus == 'none') ...[
                          rentXCard(
                            child: Row(
                              children: [
                                Expanded(child: _buildTimeBox("START", _startTime, () => _selectTime(true))),
                                const SizedBox(width: 12),
                                Expanded(child: _buildTimeBox("END", _endTime, () => _selectTime(false))),
                              ],
                            ),
                          ),
                        ] else ...[
                          rentXCard(
                            borderColor: kAccentCyan,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_bookingStatus == 'started' ? "Ride In Progress" : "Booking Reserved", style: const TextStyle(color: kAccentCyan, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Start: ${DateFormat('h:mm a').format(_startTime)}", style: const TextStyle(color: kTextPrimary, fontSize: 13)),
                                    Text("End: ${DateFormat('h:mm a').format(_endTime)}", style: const TextStyle(color: kTextPrimary, fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        rentXCard(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("ESTIMATED COST", style: TextStyle(color: kTextMuted, fontSize: 13)),
                              Text("₹${_totalCost.toStringAsFixed(0)}", style: const TextStyle(color: kAccentGreen, fontSize: 22, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: kSurface1,
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: rentXButton(
              label: _bookingStatus == 'none' ? "BOOK RIDE NOW" : (_bookingStatus == 'booked' ? "START RIDE" : "END RIDE & PAY"),
              onTap: _bookingStatus == 'none' ? _createBooking : null,
              icon: Icons.pedal_bike,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String label, DateTime time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kTextDim, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(DateFormat('h:mm a').format(time), style: const TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(DateFormat('MMM d').format(time), style: const TextStyle(color: kTextMuted, fontSize: 11)),
        ],
      ),
    );
  }
}