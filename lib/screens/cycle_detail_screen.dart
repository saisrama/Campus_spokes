import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _isCancellation = false;
  double? _cancellationFee;

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
    
    try {
      var query = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: currentUser!.uid)
          .get();

      var activeDocs = query.docs.where((doc) {
        var d = doc.data();
        return d['cycleId'] == widget.cycleId &&
            ['booked', 'started', 'payment_pending'].contains(d['status']);
      }).toList();

      if (activeDocs.isNotEmpty) {
        var doc = activeDocs.first;
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
            _isCancellation = data['isCancellation'] ?? false;
            _cancellationFee = (data['cancellationFee'] is num) ? (data['cancellationFee'] as num).toDouble() : null;

            if (scheduledStartX != null) _startTime = scheduledStartX;
            if (scheduledEndX != null) _endTime = scheduledEndX;
            _calculateCost();
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking active booking: $e");
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
          if (newDate.isBefore(DateTime.now().subtract(const Duration(minutes: 2)))) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Start time cannot be in the past."), backgroundColor: Colors.redAccent),
            );
            return;
          }
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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      var ref = await FirebaseFirestore.instance.collection('bookings').add({
        'userId': currentUser!.uid,
        'renterName': currentUser!.displayName ?? 'User',
        'ownerId': widget.data['ownerId'],
        'cycleId': widget.cycleId,
        'type': 'cycle',
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
      FirebaseFirestore.instance.collection('cycles').doc(widget.cycleId).update({
        'nextAvailableTime': nextAvailable,
      });

      if (mounted) {
        Navigator.pop(context);

        setState(() {
          _bookingId = ref.id;
          _bookingStatus = 'booked';
        });

        final startTimeStr = DateFormat('MMM d, h:mm a').format(_startTime);
        final endTimeStr = DateFormat('MMM d, h:mm a').format(_endTime);
        final message = "Hi ${widget.data['ownerName'] ?? 'there'}, I just reserved your cycle *${widget.data['modelName']}* on *RentX*.\n\n"
            "*Time:* $startTimeStr to $endTimeStr\n"
            "*Estimated Cost:* ₹${_totalCost.toStringAsFixed(0)}\n\nPlease confirm availability.";

        Navigator.push(
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
              bookingId: ref.id,
              cycleId: widget.cycleId,
              cycleData: widget.data,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Booking failed: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _startRide() async {
    if (_bookingId == null) return;

    // No-Show Check: If scheduled end time has passed, block ride start and trigger No-Show payment
    if (_scheduledEndTime != null && DateTime.now().isAfter(_scheduledEndTime!)) {
      try {
        await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
          'status': 'payment_pending',
          'isNoShow': true,
          'finalCost': _totalCost,
          'noShowAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() => _bookingStatus = 'payment_pending');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Booking slot expired (No Show). Full slot charge applies."),
              backgroundColor: Colors.redAccent,
            ),
          );
          _showPaymentDialog();
        }
      } catch (e) {
        debugPrint("No show error: $e");
      }
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
        'status': 'started',
        'startTime': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          _bookingStatus = 'started';
          _rideStartTime = DateTime.now();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ride Started! Safe riding."), backgroundColor: kSurface1),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to start ride: $e"), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _endRide() async {
    if (_bookingId == null) return;
    try {
      await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
        'status': 'completed',
        'endTime': FieldValue.serverTimestamp(),
        'finalCost': _totalCost,
      });
      if (mounted) {
        setState(() => _bookingStatus = 'completed');
        _showPaymentDialog();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to end ride: $e"), backgroundColor: Colors.redAccent));
    }
  }

  void _showPaymentDialog({bool isCancellation = false, double? cancelAmount}) {
    String upi = widget.data['ownerUpiId'] ?? widget.data['upiId'] ?? 'N/A';
    String ownerName = widget.data['ownerName'] ?? 'Owner';
    String modelName = widget.data['modelName'] ?? 'Cycle';
    double amount = isCancellation ? (cancelAmount ?? (_totalCost * 0.5)) : _totalCost;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: kSurface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kBorder)),
        title: Row(
          children: [
            Icon(isCancellation ? Icons.cancel_outlined : Icons.account_balance_wallet_outlined, color: isCancellation ? Colors.redAccent : kAccentGreen, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isCancellation ? "Cancellation Fee" : "Payment Details",
                style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isCancellation ? Colors.redAccent.withValues(alpha: 0.3) : const Color(0xFF27272A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isCancellation ? "CANCELLATION FEE DUE (50%)" : "TOTAL AMOUNT DUE", style: TextStyle(color: isCancellation ? Colors.redAccent : kTextMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("₹${amount.toStringAsFixed(0)}", style: TextStyle(color: isCancellation ? Colors.redAccent : kAccentGreen, fontSize: 26, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text("OWNER UPI ID", style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        upi,
                        style: const TextStyle(color: kAccentCyan, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: kTextPrimary, size: 20),
                      tooltip: "Copy UPI ID",
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: upi));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Copied '$upi' to clipboard!"), backgroundColor: kSurface1),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── PAY VIA UPI BUTTON ──
              ElevatedButton.icon(
                onPressed: () async {
                  if (upi.isEmpty || upi == 'N/A') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("UPI ID is not provided by owner.")),
                    );
                    return;
                  }

                  final cleanUpi = upi.trim();
                  final cleanName = Uri.encodeComponent(ownerName);
                  final amtStr = amount.toStringAsFixed(2);
                  final uriString = "upi://pay?pa=$cleanUpi&pn=$cleanName&am=$amtStr&cu=INR&tn=RentX%20Payment";
                  final uri = Uri.parse(uriString);

                  try {
                    bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!launched) {
                      await Clipboard.setData(ClipboardData(text: cleanUpi));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("UPI ID ($cleanUpi) copied! Open GPay or PhonePe to pay."), backgroundColor: kAccentGreen),
                        );
                      }
                    }
                  } catch (e) {
                    await Clipboard.setData(ClipboardData(text: cleanUpi));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("UPI ID ($cleanUpi) copied to clipboard! Paste in your UPI app."), backgroundColor: kAccentGreen),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.payment, color: Colors.black, size: 20),
                label: const Text("Pay via Any UPI App", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),

              const SizedBox(height: 10),

              // ── COPY UPI ID BUTTON ──
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: upi));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("UPI ID '$upi' copied to clipboard!"), backgroundColor: kSurface1),
                  );
                },
                icon: const Icon(Icons.content_copy, color: kTextPrimary, size: 18),
                label: const Text("Copy UPI ID Only", style: TextStyle(color: kTextPrimary, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kBorder),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kTextPrimary,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (_bookingId != null) {
                await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
                  'status': isCancellation ? 'cancelled' : 'completed',
                  'finalCost': amount,
                });
              }
              if (mounted) setState(() => _bookingStatus = isCancellation ? 'cancelled' : 'none');
              if (mounted) Navigator.pop(dialogCtx);

              String cleanPhone = (widget.data['ownerPhone'] ?? '').replaceAll(RegExp(r'[^0-9]'), '');
              if (cleanPhone.isNotEmpty) {
                if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
                  cleanPhone = '91$cleanPhone';
                }
                String msg;
                if (isCancellation) {
                  msg = "Hi $ownerName, I have completed the cancellation fee payment of ₹${amount.toStringAsFixed(0)} for renting your cycle *$modelName* on RentX.\n\n"
                      "📋 *Cancellation Fee Payment Summary:*\n"
                      "• Cycle: $modelName\n"
                      "• Cancellation Fee (50%): ₹${amount.toStringAsFixed(0)}\n\n"
                      "Please verify the payment. Thank you!";
                } else {
                  msg = "Hi $ownerName, I have completed the payment of ₹${amount.toStringAsFixed(0)} for renting your cycle *$modelName* on RentX.\n\n"
                      "📋 *Rental Payment Summary:*\n"
                      "• Cycle: $modelName\n"
                      "• Duration: ${_durationInHours.toStringAsFixed(1)} hrs\n"
                      "• Amount Paid: ₹${amount.toStringAsFixed(0)}\n\n"
                      "Please verify the payment. Thank you!";
                }
                final Uri url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}");
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isCancellation ? "Cancellation Fee Payment Sent! Thank you." : "Payment Marked Complete! Thank you."),
                    backgroundColor: kSurface1,
                  ),
                );
              }
            },
            child: Text(isCancellation ? "I HAVE PAID CANCELLATION FEE" : "I HAVE COMPLETED PAYMENT", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                rentXButton(
                  label: _bookingStatus == 'none'
                      ? "BOOK RIDE NOW"
                      : (_bookingStatus == 'booked' ? "START RIDE NOW" : (_bookingStatus == 'started' ? "END RIDE & PAY" : "PAYMENT PENDING")),
                  onTap: _bookingStatus == 'none'
                      ? _showBookingConfirmationDialog
                      : (_bookingStatus == 'booked'
                          ? _startRide
                          : (_bookingStatus == 'started' ? _endRide : (_bookingStatus == 'payment_pending'
                              ? () {
                                  if (_isCancellation) {
                                    _showPaymentDialog(isCancellation: true, cancelAmount: _cancellationFee);
                                  } else {
                                    _showPaymentDialog();
                                  }
                                }
                              : null))),
                  icon: Icons.pedal_bike,
                ),
                if (_bookingStatus == 'booked') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        foregroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text("CANCEL BOOKING (50% Fee)", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _cancelBooking,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingConfirmationDialog() {
    final startTimeStr = DateFormat('MMM d, h:mm a').format(_startTime);
    final endTimeStr = DateFormat('MMM d, h:mm a').format(_endTime);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: kTextDim, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Confirm Ride Booking",
              style: TextStyle(color: kTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "Please review the rental terms before confirming.",
              style: TextStyle(color: kTextMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // SUMMARY CARD
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kBgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.data['modelName'] ?? 'Cycle', style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text("₹${_totalCost.toStringAsFixed(0)}", style: const TextStyle(color: kAccentGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Slot: $startTimeStr - $endTimeStr", style: const TextStyle(color: kTextMuted, fontSize: 11)),
                      Text("Duration: ${_durationInHours.toStringAsFixed(1)} hrs", style: const TextStyle(color: kTextMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // POLICY POINTS
            const Text("DISCLAIMER & POLICY", style: TextStyle(color: kAccentCyan, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            _buildPolicyPoint("No-Show", "Failure to start ride by end time results in full charge of reserved slot."),
            const SizedBox(height: 6),
            _buildPolicyPoint("Late Returns", "Charged at 2x the hourly rate for delays beyond the booked slot."),
            const SizedBox(height: 6),
            _buildPolicyPoint("Cancellation Fee", "Cancellation fee is 50% of the booking fee."),
            const SizedBox(height: 6),
            _buildPolicyPoint("Liability", "RentX facilitates connections only. We are not responsible for accidents, damages, or disputes."),
            const SizedBox(height: 6),
            _buildPolicyPoint("Disputes", "All financial or physical disputes must be resolved directly between Owner and Renter."),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTextPrimary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_circle, size: 20),
                label: const Text("AGREE & CONFIRM BOOKING", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _createBooking();
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelBooking() async {
    if (_bookingId == null) return;

    // Check if cancellation is allowed (must be more than 1 hour before scheduled start)
    if (_scheduledStartTime != null && DateTime.now().isAfter(_scheduledStartTime!.subtract(const Duration(hours: 1)))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cancellation not allowed less than 1 hour before the scheduled start time."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    double cancellationFee = _totalCost * 0.5;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kBorder)),
        title: const Text("Cancel Ride Booking?", style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Are you sure you want to cancel this booking?",
              style: TextStyle(color: kTextMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Cancellation Fee (50%): ₹${cancellationFee.toStringAsFixed(0)}",
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("BACK", style: TextStyle(color: kTextDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("CONFIRM CANCEL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
        'status': 'payment_pending',
        'isCancellation': true,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationFee': cancellationFee,
        'finalCost': cancellationFee,
      });
      if (mounted) {
        setState(() => _bookingStatus = 'payment_pending');
        _showPaymentDialog(isCancellation: true, cancelAmount: cancellationFee);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error cancelling booking: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildPolicyPoint(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("• ", style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.bold)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: kTextMuted, fontSize: 11, height: 1.35),
              children: [
                TextSpan(text: "$title: ", style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
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