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
  String _searchQuery = '';

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
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
                controller: _searchController,
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
        stream: FirebaseFirestore.instance.collection('items').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error loading items", style: TextStyle(color: Colors.white)));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));

          var docs = snapshot.data!.docs;

          // Exclude own items
          if (user != null) {
            docs = docs.where((d) {
              var data = d.data() as Map<String, dynamic>;
              return data['ownerId'] != user!.uid;
            }).toList();
          }

          // Exclude disabled items
          docs = docs.where((d) {
            var data = d.data() as Map<String, dynamic>;
            return data['ownerDisabled'] != true;
          }).toList();

          // Category filter
          if (_selectedCategories.isNotEmpty) {
            docs = docs.where((d) {
              var data = d.data() as Map<String, dynamic>;
              return _selectedCategories.contains(data['itemType']);
            }).toList();
          }

          // Location filter
          if (_selectedLocations.isNotEmpty) {
            docs = docs.where((d) {
              var data = d.data() as Map<String, dynamic>;
              return _selectedLocations.contains(data['location']);
            }).toList();
          }

          // Search filter
          if (_searchQuery.isNotEmpty) {
            docs = docs.where((d) {
              var data = d.data() as Map<String, dynamic>;
              final name = (data['itemName'] ?? '').toLowerCase();
              final type = (data['itemType'] ?? '').toLowerCase();
              final desc = (data['description'] ?? '').toLowerCase();
              return name.contains(_searchQuery) || type.contains(_searchQuery) || desc.contains(_searchQuery);
            }).toList();
          }

          // Sort
          if (_sortBy == 'price_asc') {
            docs.sort((a, b) {
              final ad = a.data() as Map<String, dynamic>;
              final bd = b.data() as Map<String, dynamic>;
              return (ad['basePrice'] ?? 0).compareTo(bd['basePrice'] ?? 0);
            });
          } else if (_sortBy == 'price_desc') {
            docs.sort((a, b) {
              final ad = a.data() as Map<String, dynamic>;
              final bd = b.data() as Map<String, dynamic>;
              return (bd['basePrice'] ?? 0).compareTo(ad['basePrice'] ?? 0);
            });
          } else if (_sortBy == 'newest') {
            docs.sort((a, b) {
              final ad = a.data() as Map<String, dynamic>;
              final bd = b.data() as Map<String, dynamic>;
              final at = ad['createdAt'];
              final bt = bd['createdAt'];
              if (at == null || bt == null) return 0;
              return (bt as dynamic).compareTo(at as dynamic);
            });
          }

          return CustomScrollView(
            slivers: [
              // Time Slot Filter
              SliverToBoxAdapter(child: _buildTimeFilter()),

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
                            _searchQuery.isNotEmpty
                                ? 'No items found for "$_searchQuery"'
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
