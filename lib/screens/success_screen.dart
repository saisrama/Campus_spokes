import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

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

    // Sequence: check pops in, then details fade in
    _checkController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _fadeController.forward();
    });

    // Start countdown for WhatsApp redirect
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
    String phone = widget.ownerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!phone.startsWith('91') && phone.length == 10) phone = '91$phone';
    if (phone.isEmpty) { _close(); return; }
    final msg = _buildWhatsappMessage();
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (mounted) _close();
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
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
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                    border: Border.all(color: const Color(0xFF22C55E), width: 2),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF22C55E),
                    size: 64,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── SUCCESS HEADING ──
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Text(
                      '$_typeLabel Confirmed!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        textStyle: const TextStyle(
                          color: Color(0xFFFAFAFA),
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "We're connecting you with the owner.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF71717A), fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── DETAILS CARD ──
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: Color(0xFF27272A)),
                      const SizedBox(height: 14),
                      _detailRow('Owner', widget.ownerName),
                      if (widget.startTime != null) ...[
                        const SizedBox(height: 10),
                        _detailRow('From', widget.startTime!),
                      ],
                      if (widget.endTime != null) ...[
                        const SizedBox(height: 10),
                        _detailRow('Until', widget.endTime!),
                      ],
                      if (widget.totalCost != null) ...[
                        const SizedBox(height: 10),
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

              // ── COUNTDOWN + WHATSAPP BUTTON ──
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
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
                          const Icon(Icons.timer_outlined, color: Color(0xFF71717A), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Redirecting to WhatsApp in $_countdown...',
                            style: const TextStyle(color: Color(0xFF71717A), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () {
                        _timer?.cancel();
                        _openWhatsApp();
                      },
                      icon: const Icon(Icons.open_in_new, color: Colors.black, size: 20),
                      label: const Text(
                        'Open WhatsApp Now',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        _timer?.cancel();
                        _close();
                      },
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(color: Color(0xFF52525B), fontSize: 13),
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
