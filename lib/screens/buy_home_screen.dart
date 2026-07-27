import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_sale_item_screen.dart';
import 'buy_item_detail_screen.dart';
import 'landing_screen.dart';
import 'profile_screen.dart';
import 'item_requests_screen.dart';
import 'add_item_request_screen.dart';

class BuyHomeScreen extends StatefulWidget {
  const BuyHomeScreen({super.key});

  @override
  State<BuyHomeScreen> createState() => _BuyHomeScreenState();
}

class _BuyHomeScreenState extends State<BuyHomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<String> _searchQuery = ValueNotifier('');

  List<String> _selectedCategories = [];
  List<String> _selectedLocations = [];
  String _sortBy = 'default';
  bool _showSoldItems = false;

  final List<String> _categories = [
    "Electronics", "Sports Goods", "Books & Study Material",
    "Lab & Tech Tools", "Hostel & Appliances", "Clothing & Accessories", "Others"
  ];

  final List<String> _locations = [
    "Buddh", "Vishwakarma", "Valmiki", "Vyas", "Shankar",
    "Ram", "Krishna", "Gandhi", "Gautam", "Malviya", "Meera", "Ganga"
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  int get _activeFilterCount =>
      _selectedCategories.length + _selectedLocations.length + (_sortBy != 'default' ? 1 : 0) + (_showSoldItems ? 1 : 0);

  void _openFilterSortSheet() {
    List<String> tempCategories = List.from(_selectedCategories);
    List<String> tempLocations = List.from(_selectedLocations);
    String tempSort = _sortBy;
    bool tempShowSold = _showSoldItems;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              expand: false, initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.5,
              builder: (context, scrollController) {
                return Column(children: [
                  Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text("Filter & Sort", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => setSheetState(() { tempCategories.clear(); tempLocations.clear(); tempSort = 'default'; tempShowSold = false; }),
                        child: const Text("Clear All", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ),
                  const Divider(color: Colors.white12),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      children: [
                        const Text("SORT BY", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        Wrap(spacing: 10, runSpacing: 8, children: [
                          _sortChip('Default', 'default', tempSort, (v) => setSheetState(() => tempSort = v)),
                          _sortChip('Price ↑', 'price_asc', tempSort, (v) => setSheetState(() => tempSort = v)),
                          _sortChip('Price ↓', 'price_desc', tempSort, (v) => setSheetState(() => tempSort = v)),
                          _sortChip('Newest', 'newest', tempSort, (v) => setSheetState(() => tempSort = v)),
                        ]),
                        const SizedBox(height: 20),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text("SHOW", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Checkbox(
                            value: tempShowSold, activeColor: Colors.orangeAccent,
                            onChanged: (val) => setSheetState(() => tempShowSold = val ?? false),
                          ),
                          const Text("Include Sold Items", style: TextStyle(color: Colors.white70)),
                        ]),
                        const SizedBox(height: 20),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text("CATEGORY", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          if (tempCategories.isNotEmpty) GestureDetector(onTap: () => setSheetState(() => tempCategories.clear()), child: const Text("Clear", style: TextStyle(color: Colors.grey, fontSize: 12))),
                        ]),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10, runSpacing: 8,
                          children: _categories.map((cat) {
                            final sel = tempCategories.contains(cat);
                            return FilterChip(
                              label: Text(cat), selected: sel,
                              onSelected: (val) => setSheetState(() { if (val) tempCategories.add(cat); else tempCategories.remove(cat); }),
                              selectedColor: Colors.orangeAccent, backgroundColor: const Color(0xFF2C2C2C),
                              labelStyle: TextStyle(color: sel ? Colors.white : Colors.white70, fontSize: 13),
                              checkmarkColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              side: BorderSide(color: sel ? Colors.orangeAccent : Colors.white24),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text("LOCATION (BHAVAN)", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          if (tempLocations.isNotEmpty) GestureDetector(onTap: () => setSheetState(() => tempLocations.clear()), child: const Text("Clear", style: TextStyle(color: Colors.grey, fontSize: 12))),
                        ]),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10, runSpacing: 8,
                          children: _locations.map((loc) {
                            final sel = tempLocations.contains(loc);
                            return FilterChip(
                              label: Text(loc), selected: sel,
                              onSelected: (val) => setSheetState(() { if (val) tempLocations.add(loc); else tempLocations.remove(loc); }),
                              selectedColor: Colors.white, backgroundColor: const Color(0xFF2C2C2C),
                              labelStyle: TextStyle(color: sel ? Colors.black : Colors.white70, fontSize: 13),
                              checkmarkColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              side: BorderSide(color: sel ? Colors.white : Colors.white24),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
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
                            _showSoldItems = tempShowSold;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: const Text("Apply Filters", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ]);
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.orangeAccent : const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.orangeAccent : Colors.white24),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
            child: TextField(
              key: const ValueKey('buy_search_field'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (val) {
                _searchQuery.value = val.toLowerCase().trim();
              },
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search items for sale...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _openFilterSortSheet,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48, width: 56,
            decoration: BoxDecoration(
              color: _activeFilterCount > 0 ? Colors.orangeAccent : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _activeFilterCount > 0 ? Colors.orangeAccent : Colors.white24),
            ),
            child: Stack(alignment: Alignment.center, children: [
              Icon(Icons.tune_rounded, color: _activeFilterCount > 0 ? Colors.white : Colors.white70, size: 22),
              if (_activeFilterCount > 0)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Center(child: Text('$_activeFilterCount', style: const TextStyle(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.bold))),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildActiveFilterPills() {
    if (_selectedCategories.isEmpty && _selectedLocations.isEmpty && _sortBy == 'default' && !_showSoldItems) return const SizedBox.shrink();

    final List<Widget> pills = [];
    if (_sortBy != 'default') pills.add(_filterPill({'price_asc': 'Price ↑', 'price_desc': 'Price ↓', 'newest': 'Newest'}[_sortBy] ?? '', onRemove: () => setState(() => _sortBy = 'default'), color: Colors.purple));
    if (_showSoldItems) pills.add(_filterPill("Incl. Sold", onRemove: () => setState(() => _showSoldItems = false), color: Colors.grey));
    for (final cat in _selectedCategories) pills.add(_filterPill(cat, onRemove: () => setState(() => _selectedCategories.remove(cat)), color: Colors.orangeAccent));
    for (final loc in _selectedLocations) pills.add(_filterPill(loc, onRemove: () => setState(() => _selectedLocations.remove(loc)), color: Colors.teal));

    return Container(
      height: 36, margin: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
      child: ListView(scrollDirection: Axis.horizontal, children: pills),
    );
  }

  Widget _filterPill(String label, {required VoidCallback onRemove, Color color = Colors.orangeAccent}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        GestureDetector(onTap: onRemove, child: Icon(Icons.close, size: 14, color: color)),
      ]),
    );
  }

  Widget _buildImage(String? imageUrl, {double? width, double? height}) {
    if (imageUrl == null || imageUrl.isEmpty) return Container(width: width, height: height, color: Colors.grey[850], child: const Center(child: Icon(Icons.shopping_bag_outlined, size: 50, color: Colors.white24)));
    if (imageUrl.startsWith('http')) return Image.network(imageUrl, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: width, height: height, color: Colors.grey[850]));
    try { return Image.memory(base64Decode(imageUrl), width: width, height: height, fit: BoxFit.cover); } catch (_) { return Container(width: width, height: height, color: Colors.grey[850]); }
  }

  Widget _buildItemCard(Map<String, dynamic> data, String itemId) {
    final isSold = data['isSold'] == true;
    final price = data['price'] ?? 0;
    final itemType = data['itemType'] ?? 'General';
    final condition = data['condition'] ?? 'Good';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BuyItemDetailScreen(data: data, itemId: itemId))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        height: 240,
        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))]),
        child: Stack(children: [
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(24), child: ColorFiltered(
            colorFilter: isSold ? const ColorFilter.matrix([0.2, 0.2, 0.2, 0, 0, 0.2, 0.2, 0.2, 0, 0, 0.2, 0.2, 0.2, 0, 0, 0, 0, 0, 1, 0]) : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
            child: _buildImage(data['imageUrl']),
          ))),
          Positioned.fill(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.95)])))),
          if (isSold)
            Positioned(top: 14, left: 14, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)), child: const Text("SOLD", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
          Positioned(top: 14, right: 14, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(16)), child: Text(itemType, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)))),
          Positioned(
            bottom: 14, left: 14, right: 14,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['itemName'] ?? 'Item', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text("Condition: $condition", style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on, color: Colors.orangeAccent, size: 12),
                  const SizedBox(width: 4),
                  Text("Collect: ${data['location'] ?? ''} Bhavan", style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ]),
              ])),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("₹$price", style: const TextStyle(color: Colors.orangeAccent, fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text("FOR SALE", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ]),
          ),
        ]),
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
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LandingScreen()))),
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("RentX • Buy Anything", style: TextStyle(fontSize: 19, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
          Text("Campus buy & sell marketplace", style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA))),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.post_add, color: Colors.orangeAccent),
            tooltip: "Requests Board",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ItemRequestsScreen(initialTab: 'buy'))),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())),
              child: CircleAvatar(backgroundImage: NetworkImage(user?.photoURL ?? "https://via.placeholder.com/150"), backgroundColor: Colors.grey, radius: 18),
            ),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sale_items').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error", style: TextStyle(color: Colors.white)));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));

          var allDocs = snapshot.data!.docs;

          // Exclude own items
          if (user != null) allDocs = allDocs.where((d) { final dd = d.data() as Map<String, dynamic>; return dd['ownerId'] != user!.uid; }).toList();

          // Filter sold
          if (!_showSoldItems) allDocs = allDocs.where((d) { final dd = d.data() as Map<String, dynamic>; return dd['isSold'] != true; }).toList();

          // Owner disabled
          allDocs = allDocs.where((d) { final dd = d.data() as Map<String, dynamic>; return dd['ownerDisabled'] != true; }).toList();

          // Category filter
          if (_selectedCategories.isNotEmpty) allDocs = allDocs.where((d) { final dd = d.data() as Map<String, dynamic>; return _selectedCategories.contains(dd['itemType']); }).toList();

          // Location filter
          if (_selectedLocations.isNotEmpty) allDocs = allDocs.where((d) { final dd = d.data() as Map<String, dynamic>; return _selectedLocations.contains(dd['location']); }).toList();

          // Sort
          if (_sortBy == 'price_asc') allDocs.sort((a, b) { final ad = a.data() as Map<String, dynamic>; final bd = b.data() as Map<String, dynamic>; return (ad['price'] ?? 0).compareTo(bd['price'] ?? 0); });
          else if (_sortBy == 'price_desc') allDocs.sort((a, b) { final ad = a.data() as Map<String, dynamic>; final bd = b.data() as Map<String, dynamic>; return (bd['price'] ?? 0).compareTo(ad['price'] ?? 0); });
          else if (_sortBy == 'newest') allDocs.sort((a, b) { final ad = a.data() as Map<String, dynamic>; final bd = b.data() as Map<String, dynamic>; final at = ad['createdAt']; final bt = bd['createdAt']; if (at == null || bt == null) return 0; return (bt as dynamic).compareTo(at as dynamic); });

          return ValueListenableBuilder<String>(
            valueListenable: _searchQuery,
            builder: (context, searchVal, _) {
              var docs = allDocs;
              if (searchVal.isNotEmpty) {
                docs = docs.where((d) {
                  final dd = d.data() as Map<String, dynamic>;
                  return (dd['itemName'] ?? '').toLowerCase().contains(searchVal) ||
                      (dd['itemType'] ?? '').toLowerCase().contains(searchVal) ||
                      (dd['description'] ?? '').toLowerCase().contains(searchVal);
                }).toList();
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildSearchAndFilterBar()),
                  SliverToBoxAdapter(child: _buildActiveFilterPills()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text("${docs.length} listing${docs.length == 1 ? '' : 's'}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  ),
                  if (docs.isEmpty)
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(child: Column(children: [
                        const Icon(Icons.search_off, size: 60, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(searchVal.isNotEmpty ? 'Nothing found for "$searchVal"' : "No items match your filters.", style: const TextStyle(color: Colors.grey)),
                        if (_activeFilterCount > 0) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => setState(() { _selectedCategories.clear(); _selectedLocations.clear(); _sortBy = 'default'; _showSoldItems = false; }),
                            child: const Text("Clear Filters", style: TextStyle(color: Colors.orangeAccent)),
                          ),
                        ],
                      ])),
                    ))
                  else
                    SliverList(delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return _buildItemCard(data, docs[index].id);
                      },
                      childCount: docs.length,
                    )),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.extended(
          heroTag: 'request_buy',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemRequestScreen(requestType: 'buy'))),
          label: const Text("Request Item"),
          icon: const Icon(Icons.post_add),
          backgroundColor: const Color(0xFF1E1E1E),
          foregroundColor: Colors.orangeAccent,
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
          heroTag: 'sell_item',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSaleItemScreen())),
          label: const Text("Sell an Item"),
          icon: const Icon(Icons.sell_outlined),
          backgroundColor: Colors.orangeAccent,
          foregroundColor: Colors.white,
        ),
      ]),
    );
  }
}
