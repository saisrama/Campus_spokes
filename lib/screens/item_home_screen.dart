import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_item_screen.dart';
import 'item_detail_screen.dart';
import 'landing_screen.dart';
import 'profile_screen.dart';
import 'item_requests_screen.dart';
import 'add_item_request_screen.dart';

class ItemHomeScreen extends StatefulWidget {
  const ItemHomeScreen({super.key});

  @override
  State<ItemHomeScreen> createState() => _ItemHomeScreenState();
}

class _ItemHomeScreenState extends State<ItemHomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<String> _searchQuery = ValueNotifier('');

  // Filter state
  List<String> _selectedCategories = [];
  List<String> _selectedLocations = [];
  String _sortBy = 'default'; // 'default', 'price_asc', 'price_desc', 'newest'

  final List<String> _categories = [
    "Electronics",
    "Sports Goods",
    "Books & Study Material",
    "Lab & Tech Tools",
    "Hostel & Appliances",
    "Others"
  ];

  final List<String> _locations = [
    "Buddh",
    "Vishwakarma",
    "Valmiki",
    "Vyas",
    "Shankar",
    "Ram",
    "Krishna",
    "Gandhi",
    "Gautam",
    "Malviya",
    "Meera",
    "Ganga"
  ];

  DateTime? _selectedStartTime;
  DateTime? _selectedEndTime;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _selectedStartTime = now;
    _selectedEndTime = now.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  int get _activeFilterCount =>
      _selectedCategories.length + _selectedLocations.length + (_sortBy != 'default' ? 1 : 0);

  Future<void> _selectTimeSlot() async {
    final DateTime now = DateTime.now();
    final DateTime initialStart = _selectedStartTime ?? now;
    final DateTime initialEnd = _selectedEndTime ?? now.add(const Duration(hours: 2));

    if (!mounted) return;
    final TimeOfDay? pickedStartTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialStart),
      helpText: 'SELECT START TIME',
    );

    if (pickedStartTime == null || !mounted) return;

    final TimeOfDay? pickedEndTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialEnd),
      helpText: 'SELECT END TIME',
    );

    if (pickedEndTime == null) return;

    DateTime startDateTime = DateTime(now.year, now.month, now.day, pickedStartTime.hour, pickedStartTime.minute);
    DateTime endDateTime = DateTime(now.year, now.month, now.day, pickedEndTime.hour, pickedEndTime.minute);

    if (startDateTime.isBefore(now.subtract(const Duration(minutes: 5)))) {
      startDateTime = startDateTime.add(const Duration(days: 1));
      endDateTime = endDateTime.add(const Duration(days: 1));
    }
    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }

    setState(() {
      _selectedStartTime = startDateTime;
      _selectedEndTime = endDateTime;
    });
  }

  void _openFilterSortSheet() {
    // Temporary state within sheet
    List<String> tempCategories = List.from(_selectedCategories);
    List<String> tempLocations = List.from(_selectedLocations);
    String tempSort = _sortBy;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Filter & Sort",
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                tempCategories.clear();
                                tempLocations.clear();
                                tempSort = 'default';
                              });
                            },
                            child: const Text("Clear All", style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        children: [
                          // SORT BY
                          const Text("SORT BY", style: TextStyle(color: Colors.indigoAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _sortChip('Default', 'default', tempSort, (v) => setSheetState(() => tempSort = v)),
                              _sortChip('Price: Low to High', 'price_asc', tempSort, (v) => setSheetState(() => tempSort = v)),
                              _sortChip('Price: High to Low', 'price_desc', tempSort, (v) => setSheetState(() => tempSort = v)),
                              _sortChip('Newest First', 'newest', tempSort, (v) => setSheetState(() => tempSort = v)),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // CATEGORY
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("CATEGORY", style: TextStyle(color: Colors.indigoAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                              if (tempCategories.isNotEmpty)
                                GestureDetector(
                                  onTap: () => setSheetState(() => tempCategories.clear()),
                                  child: const Text("Clear", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: _categories.map((cat) {
                              final selected = tempCategories.contains(cat);
                              return FilterChip(
                                label: Text(cat),
                                selected: selected,
                                onSelected: (val) {
                                  setSheetState(() {
                                    if (val) {
                                      tempCategories.add(cat);
                                    } else {
                                      tempCategories.remove(cat);
                                    }
                                  });
                                },
                                selectedColor: Colors.indigoAccent,
                                backgroundColor: const Color(0xFF2C2C44),
                                labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 13),
                                checkmarkColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                side: BorderSide(color: selected ? Colors.indigoAccent : Colors.white24),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // COLLECT FROM
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("COLLECT FROM BHAVAN", style: TextStyle(color: Colors.indigoAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                              if (tempLocations.isNotEmpty)
                                GestureDetector(
                                  onTap: () => setSheetState(() => tempLocations.clear()),
                                  child: const Text("Clear", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: _locations.map((loc) {
                              final selected = tempLocations.contains(loc);
                              return FilterChip(
                                label: Text(loc),
                                selected: selected,
                                onSelected: (val) {
                                  setSheetState(() {
                                    if (val) {
                                      tempLocations.add(loc);
                                    } else {
                                      tempLocations.remove(loc);
                                    }
                                  });
                                },
                                selectedColor: Colors.white,
                                backgroundColor: const Color(0xFF2C2C44),
                                labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 13),
                                checkmarkColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                side: BorderSide(color: selected ? Colors.white : Colors.white24),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                    // Apply Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategories = List.from(tempCategories);
                              _selectedLocations = List.from(tempLocations);
                              _sortBy = tempSort;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigoAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text("Apply Filters", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _sortChip(String label, String value, String current, Function(String) onTap) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.indigoAccent : const Color(0xFF2C2C44),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.indigoAccent : Colors.white24),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      ),
    );
  }

  Widget _buildTimeFilter() {
    String startText = _selectedStartTime != null ? DateFormat('h:mm a (MMM d)').format(_selectedStartTime!) : 'Select';
    String endText = _selectedEndTime != null ? DateFormat('h:mm a (MMM d)').format(_selectedEndTime!) : 'Select';

    double durationHrs = 0;
    if (_selectedStartTime != null && _selectedEndTime != null) {
      durationHrs = _selectedEndTime!.difference(_selectedStartTime!).inMinutes / 60.0;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.schedule, color: Colors.indigoAccent, size: 18),
                  SizedBox(width: 6),
                  Text("Rental Time Slot", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              GestureDetector(
                onTap: _selectTimeSlot,
                child: const Text("Change", style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("START", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(startText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white38, size: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("END", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(endText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (durationHrs > 0) ...[
            const SizedBox(height: 6),
            Text(
              "Duration: ${durationHrs.toStringAsFixed(1)} hrs",
              style: const TextStyle(color: Colors.indigoAccent, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSubstanceDisclaimerBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "STRICT DISCLAIMER: ",
                    style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: "The trade, rental, or exchange of narcotics, alcohol, tobacco, and any other illicit or prohibited substances is strictly prohibited. Engaging in such activities will lead to immediate reporting to the college administration.",
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          // Search Bar
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                key: const ValueKey('item_search_field'),
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (val) {
                  _searchQuery.value = val.toLowerCase().trim();
                },
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search items...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Filter + Sort Button
          GestureDetector(
            onTap: _openFilterSortSheet,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48,
              width: 56,
              decoration: BoxDecoration(
                color: _activeFilterCount > 0 ? Colors.indigoAccent : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _activeFilterCount > 0 ? Colors.indigoAccent : Colors.white24,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: _activeFilterCount > 0 ? Colors.white : Colors.white70,
                    size: 22,
                  ),
                  if (_activeFilterCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$_activeFilterCount',
                            style: const TextStyle(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Active filter pills
  Widget _buildActiveFilterPills() {
    if (_selectedCategories.isEmpty && _selectedLocations.isEmpty && _sortBy == 'default') {
      return const SizedBox.shrink();
    }

    final List<Widget> pills = [];

    if (_sortBy != 'default') {
      final sortLabel = {
        'price_asc': 'Price ↑',
        'price_desc': 'Price ↓',
        'newest': 'Newest',
      }[_sortBy] ?? '';
      pills.add(_filterPill(sortLabel, onRemove: () => setState(() => _sortBy = 'default'), color: Colors.purple));
    }

    for (final cat in _selectedCategories) {
      pills.add(_filterPill(cat, onRemove: () => setState(() => _selectedCategories.remove(cat))));
    }

    for (final loc in _selectedLocations) {
      pills.add(_filterPill(loc, onRemove: () => setState(() => _selectedLocations.remove(loc)), color: Colors.teal));
    }

    return Container(
      height: 36,
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: pills,
      ),
    );
  }

  Widget _filterPill(String label, {required VoidCallback onRemove, Color color = Colors.indigoAccent}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: color),
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
        child: Center(child: Icon(Icons.inventory_2, size: iconSize, color: Colors.white24)),
      );
    }
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl, width: width, height: height, fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width, height: height, color: Colors.grey[850],
          child: Center(child: Icon(Icons.inventory_2, size: iconSize, color: Colors.white24)),
        ),
      );
    }
    try {
      return Image.memory(
        base64Decode(imageUrl), width: width, height: height, fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width, height: height, color: Colors.grey[850],
          child: Center(child: Icon(Icons.broken_image, size: iconSize, color: Colors.white24)),
        ),
      );
    } catch (e) {
      return Container(
        width: width, height: height, color: Colors.grey[850],
        child: Center(child: Icon(Icons.error, size: iconSize, color: Colors.white24)),
      );
    }
  }

  Widget _buildActiveItemRentalCard(BuildContext context, DocumentSnapshot booking) {
    Map<String, dynamic> bData = (booking.data() as Map<String, dynamic>?) ?? {};
    Map<String, dynamic> data = (bData['itemData'] as Map<String, dynamic>?) ?? {};
    String status = bData['status'] ?? 'booked';
    String itemId = bData['itemId'] ?? '';

    String displayStatus = status.toUpperCase();
    Color statusColor = Colors.amber;
    String buttonText = "START SESSION";
    Color buttonColor = Colors.green;

    if (status == 'started') {
      statusColor = Colors.green;
      buttonText = "END SESSION & PAY";
      buttonColor = Colors.red;
    } else if (status == 'payment_pending') {
      statusColor = Colors.green;
      buttonText = "PAY NOW";
      buttonColor = Colors.green;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2C2C3E), Color(0xFF1E1E2E)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ACTIVE ITEM RENTAL", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                child: Text(displayStatus, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              )
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImage(data['imageUrl'] ?? (data['imageUrls'] is List && (data['imageUrls'] as List).isNotEmpty ? data['imageUrls'][0] : ''), width: 60, height: 60),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['itemName'] ?? 'Item', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("Collect: ${data['location'] ?? 'Campus'} Bhavan", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (status == 'booked') {
                  try {
                    await FirebaseFirestore.instance.collection('bookings').doc(booking.id).update({
                      'status': 'started',
                      'startTime': FieldValue.serverTimestamp(),
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Rental Session Started!"), backgroundColor: Color(0xFF18181B)),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error starting session: $e"), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(data: data, itemId: itemId)));
                }
              },
              child: Text(
                buttonText, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (status == 'booked' || status == 'started') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  foregroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _cancelItemBookingByRenter(context, booking.id, bData),
                child: const Text("CANCEL BOOKING (50% Fee)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _cancelItemBookingByRenter(BuildContext context, String bookingId, Map<String, dynamic> bData) async {
    double base = 20.0;
    if (bData['estimatedCost'] != null) {
      base = (bData['estimatedCost'] as num).toDouble();
    } else if (bData['basePrice'] != null) {
      base = (bData['basePrice'] as num).toDouble();
    } else if (bData['itemData']?['basePrice'] != null) {
      base = (bData['itemData']['basePrice'] as num).toDouble();
    }
    double cancellationFee = base * 0.5;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Cancel Item Booking?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Are you sure you want to cancel this booking?",
              style: TextStyle(color: Colors.white70),
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
            child: const Text("BACK", style: TextStyle(color: Colors.grey)),
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
      await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationFee': cancellationFee,
        'finalCost': cancellationFee,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Booking cancelled. Cancellation fee: ₹${cancellationFee.toStringAsFixed(0)}"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error cancelling booking: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildItemCard(BuildContext context, Map<String, dynamic> data, String itemId, {double? totalPrice}) {
    String itemName = data['itemName'] ?? 'Item';
    String itemType = data['itemType'] ?? 'General';
    String location = data['location'] ?? 'Campus';
    int basePrice = data['basePrice'] ?? 20;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItemDetailScreen(
            data: data,
            itemId: itemId,
            initialStartTime: _selectedStartTime,
            initialEndTime: _selectedEndTime,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        height: 240,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _buildImage(data['imageUrl']),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.95)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.indigoAccent, borderRadius: BorderRadius.circular(20)),
                child: Text(itemType, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(itemName, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.indigoAccent, size: 13),
                            const SizedBox(width: 4),
                            Text("Collect: $location Bhavan", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (totalPrice != null) ...[
                        const Text("TOTAL", style: TextStyle(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                        Text("₹${totalPrice.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ] else ...[
                        Text("₹$basePrice / 2hrs", style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LandingScreen())),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("RentX • Rent Anything", style: TextStyle(fontSize: 19, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
            Text("Campus peer-to-peer rental hub", style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.post_add, color: Colors.indigoAccent),
            tooltip: "Requests Board",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ItemRequestsScreen(initialTab: 'rent'))),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())),
              child: CircleAvatar(
                backgroundImage: NetworkImage(user?.photoURL ?? "https://via.placeholder.com/150"),
                backgroundColor: Colors.grey,
                radius: 18,
              ),
            ),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: user?.uid)
            .where('status', whereIn: ['booked', 'started', 'payment_pending'])
            .snapshots(),
        builder: (context, bookingSnapshot) {
          DocumentSnapshot? activeBooking;
          if (bookingSnapshot.hasData && bookingSnapshot.data!.docs.isNotEmpty) {
            final itemBookings = bookingSnapshot.data!.docs.where((d) {
              final map = d.data() as Map<String, dynamic>;
              return map.containsKey('itemId');
            }).toList();
            if (itemBookings.isNotEmpty) {
              activeBooking = itemBookings.first;
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('items').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Error loading items", style: TextStyle(color: Colors.white)));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));

              var allDocs = snapshot.data!.docs;

              // Filter out active item from available items
              if (activeBooking != null) {
                final abMap = activeBooking.data() as Map<String, dynamic>?;
                if (abMap != null && abMap.containsKey('itemId')) {
                  allDocs = allDocs.where((d) => d.id != abMap['itemId']).toList();
                }
              }

              // Exclude own items
              if (user != null) {
                allDocs = allDocs.where((d) {
                  var data = d.data() as Map<String, dynamic>;
                  return data['ownerId'] != user!.uid;
                }).toList();
              }

              // Exclude disabled items
              allDocs = allDocs.where((d) {
                var data = d.data() as Map<String, dynamic>;
                return data['ownerDisabled'] != true;
              }).toList();

              // Category filter
              if (_selectedCategories.isNotEmpty) {
                allDocs = allDocs.where((d) {
                  var data = d.data() as Map<String, dynamic>;
                  return _selectedCategories.contains(data['itemType']);
                }).toList();
              }

              // Location filter
              if (_selectedLocations.isNotEmpty) {
                allDocs = allDocs.where((d) {
                  var data = d.data() as Map<String, dynamic>;
                  return _selectedLocations.contains(data['location']);
                }).toList();
              }

              // Sort
              if (_sortBy == 'price_asc') {
                allDocs.sort((a, b) {
                  final ad = a.data() as Map<String, dynamic>;
                  final bd = b.data() as Map<String, dynamic>;
                  return (ad['basePrice'] ?? 0).compareTo(bd['basePrice'] ?? 0);
                });
              } else if (_sortBy == 'price_desc') {
                allDocs.sort((a, b) {
                  final ad = a.data() as Map<String, dynamic>;
                  final bd = b.data() as Map<String, dynamic>;
                  return (bd['basePrice'] ?? 0).compareTo(ad['basePrice'] ?? 0);
                });
              } else if (_sortBy == 'newest') {
                allDocs.sort((a, b) {
                  final ad = a.data() as Map<String, dynamic>;
                  final bd = b.data() as Map<String, dynamic>;
                  final at = ad['createdAt'];
                  final bt = bd['createdAt'];
                  if (at == null || bt == null) return 0;
                  return (bt as dynamic).compareTo(at as dynamic);
                });
              }

              return ValueListenableBuilder<String>(
                valueListenable: _searchQuery,
                builder: (context, searchVal, _) {
                  var docs = allDocs;
                  if (searchVal.isNotEmpty) {
                    docs = docs.where((d) {
                      var data = d.data() as Map<String, dynamic>;
                      final name = (data['itemName'] ?? '').toLowerCase();
                      final type = (data['itemType'] ?? '').toLowerCase();
                      final desc = (data['description'] ?? '').toLowerCase();
                      return name.contains(searchVal) || type.contains(searchVal) || desc.contains(searchVal);
                    }).toList();
                  }

                  return CustomScrollView(
                    slivers: [
                      // Active Item Rental Banner
                      if (activeBooking != null)
                        SliverToBoxAdapter(
                          child: _buildActiveItemRentalCard(context, activeBooking),
                        ),

                      // Time Slot Filter
                      SliverToBoxAdapter(child: _buildTimeFilter()),

                      // Illicit Substance Disclaimer Banner
                      SliverToBoxAdapter(child: _buildSubstanceDisclaimerBanner()),

                      // Search + Filter/Sort row
                      SliverToBoxAdapter(child: _buildSearchAndFilterBar()),

                      // Active filter pills
                      SliverToBoxAdapter(child: _buildActiveFilterPills()),

                      // Results count
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Text(
                            "${docs.length} item${docs.length == 1 ? '' : 's'} found",
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      ),

                      if (docs.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.search_off, size: 60, color: Colors.grey),
                                  const SizedBox(height: 12),
                                  Text(
                                    searchVal.isNotEmpty
                                        ? 'No items found for "$searchVal"'
                                        : "No items match your filters.",
                                    style: const TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_activeFilterCount > 0) ...[
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: () => setState(() {
                                        _selectedCategories.clear();
                                        _selectedLocations.clear();
                                        _sortBy = 'default';
                                      }),
                                      child: const Text("Clear Filters", style: TextStyle(color: Colors.indigoAccent)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              var data = docs[index].data() as Map<String, dynamic>;
                              String itemId = docs[index].id;

                              double? dynamicTotal;
                              if (_selectedStartTime != null && _selectedEndTime != null) {
                                double durationHrs = _selectedEndTime!.difference(_selectedStartTime!).inMinutes / 60.0;
                                if (durationHrs < 0) durationHrs = 0;
                                double base = (data['basePrice'] ?? 0).toDouble();
                                double hourly = (data['hourlyPrice'] ?? 0).toDouble();
                                dynamicTotal = durationHrs <= 2 ? base : base + ((durationHrs - 2).ceil() * hourly);
                              }

                              return _buildItemCard(context, data, itemId, totalPrice: dynamicTotal);
                            },
                            childCount: docs.length,
                          ),
                        ),

                      const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'rent_request',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemRequestScreen(requestType: 'rent'))),
            label: const Text("Request Item"),
            icon: const Icon(Icons.post_add),
            backgroundColor: const Color(0xFF1E1E1E),
            foregroundColor: Colors.indigoAccent,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'list_item_rent',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemScreen())),
            label: const Text("List an Item"),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.indigoAccent,
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
