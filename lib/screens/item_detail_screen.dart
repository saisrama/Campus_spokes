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
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));
  double _totalCost = 0;
  double _durationInHours = 2.0;

  User? currentUser = FirebaseAuth.instance.currentUser;
  String? _bookingId;
  String? _bookingStatus = 'none';
  DateTime? _scheduledStartTime;
  DateTime? _scheduledEndTime;

  final TextEditingController _reviewController = TextEditingController();
  int _selectedRating = 5;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

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

  Future<void> _bookItem() async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please log in to book items.")));
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      var ref = await FirebaseFirestore.instance.collection('bookings').add({
        'userId': currentUser!.uid,
        'renterName': currentUser!.displayName ?? 'User',
        'renterPhone': currentUser!.phoneNumber ?? '',
        'itemId': widget.itemId,
        'itemData': widget.data,
        'ownerId': widget.data['ownerId'],
        'type': 'item',
        'status': 'booked',
        'scheduledStartTime': Timestamp.fromDate(_startTime),
        'scheduledEndTime': Timestamp.fromDate(_endTime),
        'estimatedDurationHours': _durationInHours,
        'basePrice': widget.data['basePrice'],
        'hourlyPrice': widget.data['hourlyPrice'],
        'estimatedCost': _totalCost,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);

        setState(() {
          _bookingId = ref.id;
          _bookingStatus = 'booked';
          _scheduledStartTime = _startTime;
          _scheduledEndTime = _endTime;
        });

        final startFmt = DateFormat('MMM d, h:mm a').format(_startTime);
        final endFmt = DateFormat('MMM d, h:mm a').format(_endTime);
        final msg = "Hi ${widget.data['ownerName']}, I have booked your item '${widget.data['itemName']}' on RentX for $startFmt - $endFmt. Please coordinate pick-up at ${widget.data['location']} Bhavan.";

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SuccessScreen(
              type: SuccessType.itemRental,
              itemName: widget.data['itemName'] ?? 'Item',
              ownerName: widget.data['ownerName'] ?? 'Owner',
              ownerPhone: widget.data['ownerPhone'] ?? '',
              startTime: startFmt,
              endTime: endFmt,
              totalCost: _totalCost,
              whatsappMessage: msg,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Booking Failed: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }


  Future<void> _contactOwnerOnWhatsApp() async {
    String? phone = widget.data['ownerPhone'];
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Owner phone number not provided.")));
      return;
    }
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    String startFmt = DateFormat('h:mm a').format(_startTime);
    String endFmt = DateFormat('h:mm a').format(_endTime);
    String msg = "Hi ${widget.data['ownerName']}, I have booked your item '${widget.data['itemName']}' on RentX for $startFmt - $endFmt. My room is ${widget.data['roomNumber'] ?? 'N/A'}. Please coordinate pick-up at ${widget.data['location']} Bhavan.";

    final Uri url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch WhatsApp")));
      }
    }
  }

  Future<void> _startSession() async {
    if (_bookingId == null) return;
    await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
      'status': 'started',
      'startTime': FieldValue.serverTimestamp(),
    });
    setState(() => _bookingStatus = 'started');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rental Session Started!"), backgroundColor: kSurface1));
    }
  }

  Future<void> _endSession() async {
    if (_bookingId == null) return;
    await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
      'status': 'completed',
      'endTime': FieldValue.serverTimestamp(),
      'finalCost': _totalCost,
    });
    setState(() => _bookingStatus = 'completed');
    _showPaymentDialog();
  }

  void _showPaymentDialog() {
    String upi = widget.data['ownerUpiId'] ?? 'N/A';
    String ownerName = widget.data['ownerName'] ?? 'Owner';
    String itemName = widget.data['itemName'] ?? 'Item';
    double amount = _totalCost;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: kSurface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kBorder)),
        title: Row(
          children: const [
            Icon(Icons.account_balance_wallet_outlined, color: kAccentGreen, size: 24),
            SizedBox(width: 10),
            Text("Payment Details", style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
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
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("TOTAL AMOUNT DUE", style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("₹${amount.toStringAsFixed(0)}", style: const TextStyle(color: kAccentGreen, fontSize: 26, fontWeight: FontWeight.bold)),
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
                await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({'status': 'completed'});
              }
              if (mounted) setState(() => _bookingStatus = 'none');
              if (mounted) Navigator.pop(dialogCtx);

              String cleanPhone = (widget.data['ownerPhone'] ?? '').replaceAll(RegExp(r'[^0-9]'), '');
              if (cleanPhone.isNotEmpty) {
                if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
                  cleanPhone = '91$cleanPhone';
                }
                String msg = "Hi $ownerName, I have completed the payment of ₹${amount.toStringAsFixed(0)} for renting your *$itemName* on RentX.\n\n"
                    "📋 *Rental Payment Summary:*\n"
                    "• Item: $itemName\n"
                    "• Duration: ${_durationInHours.toStringAsFixed(1)} hrs\n"
                    "• Amount Paid: ₹${amount.toStringAsFixed(0)}\n\n"
                    "Please verify the payment. Thank you!";
                final Uri url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}");
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }

              _showReviewDialog();
            },
            child: const Text("I HAVE COMPLETED PAYMENT", style: TextStyle(fontWeight: FontWeight.bold)),
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
          backgroundColor: kSurface1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kBorder)),
          title: const Text("Rate Your Experience", style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
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
                    onPressed: () => setDialogState(() => _selectedRating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reviewController,
                style: const TextStyle(color: kTextPrimary),
                decoration: rentXInputDecoration("Review", hint: "Leave feedback for item/owner..."),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Skip", style: TextStyle(color: kTextDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kTextPrimary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('items').doc(widget.itemId).collection('reviews').add({
                  'userId': currentUser?.uid,
                  'userName': currentUser?.displayName ?? 'Anonymous',
                  'rating': _selectedRating,
                  'comment': _reviewController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thank you for your feedback!"), backgroundColor: kSurface1));
              },
              child: const Text("Submit", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
      img = Image.network(url, height: 260, width: double.infinity, fit: BoxFit.cover);
    } else {
      try {
        img = Image.memory(base64Decode(url), height: 260, width: double.infinity, fit: BoxFit.cover);
      } catch (_) {
        img = Container(height: 260, color: kSurface1, child: const Icon(Icons.broken_image, size: 80, color: kTextDim));
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
      return Container(
        height: 240,
        color: kSurface1,
        child: const Center(child: Icon(Icons.inventory_2_outlined, size: 60, color: kTextDim)),
      );
    }

    if (urls.length == 1) {
      return _buildSingleImage(urls.first, 0);
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _pageController,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (context, index) => _buildSingleImage(urls[index], index),
          ),
        ),
        // Carousel Indicators
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
        // Slide Count Badge
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "${_currentImageIndex + 1}/${urls.length}",
              style: const TextStyle(color: kTextPrimary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String itemName = widget.data['itemName'] ?? 'Item Details';
    String itemType = widget.data['itemType'] ?? 'General';
    String location = widget.data['location'] ?? 'Campus';
    String ownerName = widget.data['ownerName'] ?? 'Student Owner';
    String description = widget.data['description'] ?? 'No extra details provided.';
    int basePrice = widget.data['basePrice'] ?? 20;
    int hourlyPrice = widget.data['hourlyPrice'] ?? 7;

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: rentXAppBar(context, itemName, subtitle: "$itemType • $location Bhavan"),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gallery
            _buildImageGallery(),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Badge Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(itemName, style: const TextStyle(color: kTextPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Owner: $ownerName • $location Bhavan", style: const TextStyle(color: kTextMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                      rentXBadge(itemType, color: kAccentCyan),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Pricing Cards
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
                              const Text("For first 2 hours", style: TextStyle(color: kTextMuted, fontSize: 11)),
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
                  const SizedBox(height: 20),

                  // Description
                  rentXSectionLabel("DESCRIPTION & NOTES"),
                  rentXCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(description, style: const TextStyle(color: kTextMuted, fontSize: 13, height: 1.5)),
                  ),
                  const SizedBox(height: 24),

                  // Active Booking Banner / Time Picker / Actions
                  if (_bookingStatus == 'booked') ...[
                    rentXCard(
                      borderColor: kAccentCyan,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.bookmark_added_outlined, color: kAccentCyan),
                            SizedBox(width: 8),
                            Text("BOOKING CONFIRMED", style: TextStyle(color: kAccentCyan, fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 8),
                          if (_scheduledStartTime != null)
                            Text("Slot: ${DateFormat('h:mm a').format(_scheduledStartTime!)} - ${DateFormat('h:mm a').format(_scheduledEndTime!)}",
                              style: const TextStyle(color: kTextPrimary, fontSize: 13)),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(child: OutlinedButton(
                              onPressed: _contactOwnerOnWhatsApp,
                              style: OutlinedButton.styleFrom(foregroundColor: kAccentGreen, side: const BorderSide(color: kAccentGreen)),
                              child: const Text("WhatsApp"),
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: ElevatedButton(
                              onPressed: _startSession,
                              style: ElevatedButton.styleFrom(backgroundColor: kAccentCyan, foregroundColor: Colors.black),
                              child: const Text("Start Session", style: TextStyle(fontWeight: FontWeight.bold)),
                            )),
                          ]),
                        ],
                      ),
                    ),
                  ] else if (_bookingStatus == 'started') ...[
                    rentXCard(
                      borderColor: kAccentGreen,
                      child: Column(
                        children: [
                          const Row(children: [
                            Icon(Icons.play_circle_fill, color: kAccentGreen),
                            SizedBox(width: 8),
                            Text("RENTAL IN PROGRESS", style: TextStyle(color: kAccentGreen, fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 14),
                          rentXButton(label: "END SESSION & PAY", onTap: _endSession, color: kAccentGreen),
                        ],
                      ),
                    ),
                  ] else ...[
                    rentXSectionLabel("SELECT RENTAL DURATION"),
                    rentXCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectTime(true),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("START TIME", style: TextStyle(color: kTextDim, fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(DateFormat('h:mm a').format(_startTime), style: const TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              Container(height: 30, width: 1, color: kBorder),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: InkWell(
                                    onTap: () => _selectTime(false),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("END TIME", style: TextStyle(color: kTextDim, fontSize: 10, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(DateFormat('h:mm a').format(_endTime), style: const TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          rentXDivider(),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Duration: ${_durationInHours.toStringAsFixed(1)} hrs", style: const TextStyle(color: kTextMuted, fontSize: 13)),
                                Text("Total: ₹${_totalCost.toStringAsFixed(0)}", style: const TextStyle(color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    rentXButton(
                      label: "BOOK THIS ITEM NOW",
                      onTap: _bookItem,
                      icon: Icons.check_circle_outline,
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
