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
  bool _isCancellation = false;
  double? _cancellationFee;

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
        _isCancellation = data['isCancellation'] ?? false;
        _cancellationFee = (data['cancellationFee'] is num) ? (data['cancellationFee'] as num).toDouble() : null;
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

    // No-Show Check: If scheduled end time has passed, block session start and trigger No-Show payment
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
            const SnackBar(content: Text("Booking slot expired (No Show). Full slot charge applies."), backgroundColor: Colors.redAccent),
          );
          _showPaymentDialog();
        }
      } catch (e) {
        debugPrint("No show error: $e");
      }
      return;
    }

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

  void _showPaymentDialog({bool isCancellation = false, double? cancelAmount}) {
    String upi = widget.data['ownerUpiId'] ?? widget.data['upiId'] ?? 'N/A';
    String ownerName = widget.data['ownerName'] ?? 'Owner';
    String itemName = widget.data['itemName'] ?? 'Item';
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
                  msg = "Hi $ownerName, I have completed the cancellation fee payment of ₹${amount.toStringAsFixed(0)} for renting your *$itemName* on RentX.\n\n"
                      "📋 *Cancellation Fee Payment Summary:*\n"
                      "• Item: $itemName\n"
                      "• Cancellation Fee (50%): ₹${amount.toStringAsFixed(0)}\n\n"
                      "Please verify the payment. Thank you!";
                } else {
                  msg = "Hi $ownerName, I have completed the payment of ₹${amount.toStringAsFixed(0)} for renting your *$itemName* on RentX.\n\n"
                      "📋 *Rental Payment Summary:*\n"
                      "• Item: $itemName\n"
                      "• Duration: ${_durationInHours.toStringAsFixed(1)} hrs\n"
                      "• Amount Paid: ₹${amount.toStringAsFixed(0)}\n\n"
                      "Please verify the payment. Thank you!";
                }
                final Uri url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}");
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }

              if (!isCancellation) {
                _showReviewDialog();
              }
            },
            child: Text(isCancellation ? "I HAVE PAID CANCELLATION FEE" : "I HAVE COMPLETED PAYMENT", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                // Recalculate average rating and reviewCount on parent item document
                try {
                  final reviewsSnap = await FirebaseFirestore.instance
                      .collection('items')
                      .doc(widget.itemId)
                      .collection('reviews')
                      .get();
                  final allRatings = reviewsSnap.docs
                      .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0.0)
                      .toList();
                  final count = allRatings.length;
                  final avg = count > 0
                      ? allRatings.reduce((a, b) => a + b) / count
                      : 0.0;
                  await FirebaseFirestore.instance.collection('items').doc(widget.itemId).update({
                    'averageRating': double.parse(avg.toStringAsFixed(1)),
                    'reviewCount': count,
                  });
                } catch (e) {
                  debugPrint("Error updating review aggregates: $e");
                }
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
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectTime(true),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("START TIME", style: TextStyle(color: kTextDim, fontSize: 10, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        Text(DateFormat('h:mm a').format(_startTime), style: const TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Container(height: 40, width: 1, color: kBorder),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: InkWell(
                                      onTap: () => _selectTime(false),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("END TIME", style: TextStyle(color: kTextDim, fontSize: 10, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 6),
                                          Text(DateFormat('h:mm a').format(_endTime), style: const TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Divider(color: kBorder, height: 1),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 4),
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
                      label: _bookingStatus == 'none'
                          ? "BOOK THIS ITEM NOW"
                          : (_bookingStatus == 'booked' ? "START RENTAL SESSION" : (_bookingStatus == 'started' ? "END RENTAL & PAY" : "PAYMENT PENDING")),
                      onTap: _bookingStatus == 'none'
                          ? _showBookingConfirmationDialog
                          : (_bookingStatus == 'payment_pending'
                              ? () {
                                  if (_isCancellation) {
                                    _showPaymentDialog(isCancellation: true, cancelAmount: _cancellationFee);
                                  } else {
                                    _showPaymentDialog();
                                  }
                                }
                              : null),
                      icon: Icons.check_circle_outline,
                    ),
                    if (_bookingStatus == 'booked') ...[
                      const SizedBox(height: 12),
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
                  const SizedBox(height: 40),

                  // Reviews Section (below the duration box)
                  _buildReviewsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingConfirmationDialog() {
    final startFmt = DateFormat('MMM d, h:mm a').format(_startTime);
    final endFmt = DateFormat('MMM d, h:mm a').format(_endTime);

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
              "Confirm Item Rental Booking",
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
                      Text(widget.data['itemName'] ?? 'Item', style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text("₹${_totalCost.toStringAsFixed(0)}", style: const TextStyle(color: kAccentGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Slot: $startFmt - $endFmt", style: const TextStyle(color: kTextMuted, fontSize: 11)),
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
                  _bookItem();
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
    double cancellationFee = _totalCost * 0.5;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kBorder)),
        title: const Text("Cancel Item Booking?", style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
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

  // ── Reviews Section ──
  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        rentXSectionLabel("REVIEWS"),
        rentXCard(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('items')
                .doc(widget.itemId)
                .collection('reviews')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text("Error loading reviews", style: TextStyle(color: kTextMuted));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kAccentCyan));
              }

              final docs = List<DocumentSnapshot>.from(snapshot.data?.docs ?? []);
              final int reviewCount = docs.length;

              double avgRating = 0.0;
              if (reviewCount > 0) {
                final double totalRating = docs.fold(0.0, (sum, doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  return sum + ((data?['rating'] as num?)?.toDouble() ?? 0.0);
                });
                avgRating = totalRating / reviewCount;
              }

              docs.sort((a, b) {
                final aTime = (a.data() as Map<String, dynamic>?)?['createdAt'] as Timestamp?;
                final bTime = (b.data() as Map<String, dynamic>?)?['createdAt'] as Timestamp?;
                if (aTime == null || bTime == null) return 0;
                return bTime.compareTo(aTime);
              });
              final reviews = docs;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Average Rating Summary
                  Row(
                    children: [
                      Text(
                        avgRating > 0 ? avgRating.toStringAsFixed(1) : "0.0",
                        style: const TextStyle(color: kTextPrimary, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(5, (index) {
                              if (index < avgRating.floor()) {
                                return const Icon(Icons.star, color: Colors.amber, size: 20);
                              } else if (index < avgRating) {
                                return const Icon(Icons.star_half, color: Colors.amber, size: 20);
                              } else {
                                return const Icon(Icons.star_border, color: Colors.amber, size: 20);
                              }
                            }),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$reviewCount review${reviewCount == 1 ? '' : 's'}",
                            style: const TextStyle(color: kTextMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (reviews.isEmpty)
                    const Text("No reviews yet. Be the first to review!", style: TextStyle(color: kTextMuted, fontSize: 13))
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: reviews.length,
                      separatorBuilder: (context, index) => const Divider(color: kBorder, height: 1),
                      itemBuilder: (context, index) {
                        final review = reviews[index].data() as Map<String, dynamic>;
                        final rating = (review['rating'] as num?)?.toInt() ?? 0;
                        final userName = review['userName'] ?? 'Anonymous';
                        final comment = review['comment'] ?? '';
                        final createdAt = review['createdAt'] as Timestamp?;
                        final dateStr = createdAt != null
                            ? DateFormat('MMM d, y').format(createdAt.toDate())
                            : '';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(userName, style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                  if (dateStr.isNotEmpty)
                                    Text(dateStr, style: const TextStyle(color: kTextDim, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: List.generate(5, (i) {
                                  return Icon(
                                    i < rating ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 14,
                                  );
                                }),
                              ),
                              if (comment.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(comment, style: const TextStyle(color: kTextMuted, fontSize: 13, height: 1.4)),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
