import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'landing_screen.dart';

enum SuccessType { cycleRental, itemRental, purchase }

class SuccessScreen extends StatefulWidget {
  final SuccessType type;
  final String itemName;
  final String ownerName;
  final String ownerPhone;
  final String? startTime;
  final String? endTime;
  final double? totalCost;
  final String? whatsappMessage;
  final String? bookingId;
  final String? cycleId;
  final Map<String, dynamic>? cycleData;

  const SuccessScreen({
    super.key,
    required this.type,
    required this.itemName,
    required this.ownerName,
    required this.ownerPhone,
    this.startTime,
    this.endTime,
    this.totalCost,
    this.whatsappMessage,
    this.bookingId,
    this.cycleId,
    this.cycleData,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  int _countdown = 5;
  Timer? _timer;
  bool _hasRedirected = false;
  bool _isStartingRide = false;
  bool _rideStarted = false;

  String get _typeLabel {
    switch (widget.type) {
      case SuccessType.cycleRental:
        return 'Cycle Rental';
      case SuccessType.itemRental:
        return 'Rental';
      case SuccessType.purchase:
        return 'Purchase Request';
    }
  }

  IconData get _typeIcon {
    switch (widget.type) {
      case SuccessType.cycleRental:
        return Icons.pedal_bike_outlined;
      case SuccessType.itemRental:
        return Icons.inventory_2_outlined;
      case SuccessType.purchase:
        return Icons.shopping_bag_outlined;
    }
  }

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _checkController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _fadeController.forward();
    });

    // Start 5 second countdown for WhatsApp redirect
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_countdown <= 1) {
        t.cancel();
        _openWhatsApp();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    _fadeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _buildWhatsappMessage() {
    if (widget.whatsappMessage != null) return widget.whatsappMessage!;

    switch (widget.type) {
      case SuccessType.cycleRental:
        return "Hi ${widget.ownerName}, I just booked your cycle *${widget.itemName}* on RentX.\n\n"
            "*Time:* ${widget.startTime ?? 'N/A'} → ${widget.endTime ?? 'N/A'}\n"
            "*Estimated Cost:* ₹${widget.totalCost?.toStringAsFixed(0) ?? 'N/A'}\n\n"
            "Please confirm availability!";
      case SuccessType.itemRental:
        return "Hi ${widget.ownerName}, I have booked your item *${widget.itemName}* on RentX.\n\n"
            "*Time:* ${widget.startTime ?? 'N/A'} → ${widget.endTime ?? 'N/A'}\n"
            "*Estimated Cost:* ₹${widget.totalCost?.toStringAsFixed(0) ?? 'N/A'}\n\n"
            "Please confirm pick-up details!";
      case SuccessType.purchase:
        return "Hi ${widget.ownerName}, I'm interested in buying your *${widget.itemName}* listed on RentX for ₹${widget.totalCost?.toStringAsFixed(0) ?? 'N/A'}. Can we arrange a meeting?";
    }
  }

  Future<void> _openWhatsApp() async {
    _timer?.cancel();
    if (mounted) setState(() => _hasRedirected = true);

    String phone = widget.ownerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!phone.startsWith('91') && phone.length == 10) phone = '91$phone';
    if (phone.isEmpty) return;

    final msg = _buildWhatsappMessage();
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    // Screen remains active — no Navigator.pop()!
  }

  Future<void> _startRideNow() async {
    if (widget.bookingId == null || widget.bookingId!.isEmpty) {
      _goToHome();
      return;
    }

    setState(() => _isStartingRide = true);

    try {
      await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).update({
        'status': 'started',
        'startTime': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isStartingRide = false;
          _rideStarted = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ride Started! Safe riding."), backgroundColor: Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStartingRide = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to start ride: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LandingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),

              // ── ANIMATED CHECK CIRCLE ──
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _rideStarted
                        ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                        : const Color(0xFF16A34A).withValues(alpha: 0.12),
                    border: Border.all(
                      color: _rideStarted ? const Color(0xFF38BDF8) : const Color(0xFF22C55E),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _rideStarted ? Icons.directions_bike_rounded : Icons.check_rounded,
                    color: _rideStarted ? const Color(0xFF38BDF8) : const Color(0xFF22C55E),
                    size: 58,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── SUCCESS HEADING ──
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Text(
                      _rideStarted ? 'Ride Active!' : '$_typeLabel Confirmed!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        textStyle: const TextStyle(
                          color: Color(0xFFFAFAFA),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _rideStarted
                          ? "Your timer is now running. Enjoy your ride!"
                          : "We're connecting you with the owner.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF71717A), fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── DETAILS CARD ──
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF09090B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_typeIcon, color: const Color(0xFF22C55E), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              widget.itemName,
                              style: const TextStyle(
                                color: Color(0xFFFAFAFA),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF27272A)),
                      const SizedBox(height: 12),
                      _detailRow('Owner', widget.ownerName),
                      if (widget.startTime != null) ...[
                        const SizedBox(height: 8),
                        _detailRow('From', widget.startTime!),
                      ],
                      if (widget.endTime != null) ...[
                        const SizedBox(height: 8),
                        _detailRow('Until', widget.endTime!),
                      ],
                      if (widget.totalCost != null) ...[
                        const SizedBox(height: 8),
                        _detailRow(
                          widget.type == SuccessType.purchase ? 'Price' : 'Est. Cost',
                          '₹${widget.totalCost!.toStringAsFixed(0)}',
                          highlight: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ── ACTION CONTROLS ──
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    // WhatsApp Status Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181B),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFF27272A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _hasRedirected ? Icons.chat_bubble_outline : Icons.timer_outlined,
                            color: _hasRedirected ? const Color(0xFF22C55E) : const Color(0xFF71717A),
                            size: 15,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _hasRedirected
                                ? 'Opened WhatsApp'
                                : 'Redirecting to WhatsApp in $_countdown...',
                            style: TextStyle(
                              color: _hasRedirected ? const Color(0xFF22C55E) : const Color(0xFF71717A),
                              fontSize: 12,
                              fontWeight: _hasRedirected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Primary WhatsApp Button
                    ElevatedButton.icon(
                      onPressed: _openWhatsApp,
                      icon: const Icon(Icons.open_in_new, color: Colors.black, size: 18),
                      label: Text(
                        _hasRedirected ? 'Re-open WhatsApp' : 'Open WhatsApp Now',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Start Ride Button (for cycle rentals)
                    if (widget.type == SuccessType.cycleRental && !_rideStarted) ...[
                      ElevatedButton.icon(
                        onPressed: _isStartingRide ? null : _startRideNow,
                        icon: _isStartingRide
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                        label: Text(
                          _isStartingRide ? "Starting Ride..." : "START RIDE NOW",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Back to Home Button
                    TextButton.icon(
                      onPressed: _goToHome,
                      icon: const Icon(Icons.home_outlined, color: Color(0xFFA1A1AA), size: 18),
                      label: const Text(
                        'Back to Campus Home',
                        style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF71717A), fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: highlight ? const Color(0xFF22C55E) : const Color(0xFFFAFAFA),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
