import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'landing_screen.dart'; // Added import
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'add_cycle_screen.dart';
import '../services/notification_service.dart';
import 'cycle_detail_screen.dart';
import 'profile_screen.dart';
import 'profile_setup_screen.dart'; // Added import

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  String _selectedLocation = "All";
  final List<String> _locations = ["All", "VK Back Gate", "Mess 2", "VM Cycle Parking", "Mess 1", "Ganga/Meera Parking"];
  
  // Time Slot Selection
  DateTime? _selectedStartTime;
  DateTime? _selectedEndTime;
  
  // Notification Streams
  StreamSubscription? _ownerNotificationStream;
  StreamSubscription? _renterNotificationStream;

  @override
  void initState() {
    super.initState();
    // Default Time Slot
    DateTime now = DateTime.now();
    // Round to next 15 mins? Or just keep null to let user pick?
    // User wants control. Let's start with NULL or Default? 
    // Code had: _selectedStartTime = TimeOfDay.now();
    // Let's keep it initialized for better UX
    _selectedStartTime = now;
    _selectedEndTime = now.add(Duration(hours: 2));

    NotificationService.initialize();
    _setupNotifications();
    
    // Force Profile Check & Update Check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileCompletion();
      _checkForUpdate();
    });
  }

  Future<void> _checkProfileCompletion() async {
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (!doc.exists || !(doc.data() as Map<String, dynamic>).containsKey('studentId')) {
         // Profile Incomplete -> Redirect to Setup
         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProfileSetupScreen()));
      }
    }
  }

  Future<void> _checkForUpdate() async {
    // Skip on web — Play Store updates don't apply
    if (kIsWeb) return;

    try {
      // 1. Get current app version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version; // e.g. "1.0.1"

      // 2. Get minimum required version from Firestore
      var configDoc = await FirebaseFirestore.instance.collection('config').doc('app').get();
      if (!configDoc.exists) return;

      String? minVersion = configDoc.data()?['minVersion'];
      if (minVersion == null) return;

      // 3. Compare versions
      if (_isVersionLower(currentVersion, minVersion)) {
        if (!mounted) return;
        // 4. Show force-update dialog (non-dismissible)
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: AlertDialog(
              backgroundColor: Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.system_update, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text("Update Required", style: TextStyle(color: Colors.white)),
                ],
              ),
              content: Text(
                "A new version of Campus Spokes is available. Please update to continue using the app.",
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final Uri url = Uri.parse('https://play.google.com/store/apps/details?id=com.sreerama.campuspks');
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    },
                    child: Text("Update Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      print("Update check failed: $e");
    }
  }

  /// Returns true if [current] is lower than [minimum] (semantic versioning)
  bool _isVersionLower(String current, String minimum) {
    List<int> curr = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> min = minimum.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    // Pad to 3 segments
    while (curr.length < 3) curr.add(0);
    while (min.length < 3) min.add(0);

    for (int i = 0; i < 3; i++) {
      if (curr[i] < min[i]) return true;
      if (curr[i] > min[i]) return false;
    }
    return false; // equal = not lower
  }

  void _setupNotifications() {
    if (user == null) return;

    // 1. Notify Me (Owner) when someone books my cycle
    _ownerNotificationStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('ownerId', isEqualTo: user!.uid)
        .where('status', isEqualTo: 'booked')
        .snapshots()
        .listen((snapshot) {
           for (var change in snapshot.docChanges) {
             if (change.type == DocumentChangeType.added) {
               // Check if this booking is VERY recent (within last 10 seconds)
               // Otherwise it triggers on app load for all old bookings
               var data = change.doc.data() as Map<String, dynamic>;
               Timestamp? createdAt = data['createdAt'];
               if (createdAt != null) {
                 DateTime created = createdAt.toDate();
                 if (DateTime.now().difference(created).inSeconds < 30) {
                    _showNotification("New Booking!", "Someone just booked your cycle!");
                 }
               }
             }
           }
        });

    // 2. Notify Me (Renter) on Ride Status Changes
    _renterNotificationStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user!.uid)
        .snapshots()
        .listen((snapshot) {
           for (var change in snapshot.docChanges) {
             if (change.type == DocumentChangeType.modified) {
                var data = change.doc.data() as Map<String, dynamic>;
                String status = data['status'];
                // Check timestamp of update if possible, but status change is usually enough for active session
                if (status == 'started') {
                  _showNotification("Ride Started", "Your ride has officially started. Safe riding!");
                } else if (status == 'payment_pending') {
                  _showNotification("Ride Ended", "Ride completed. Please ensure payment is made.");
                } else if (status == 'cancelled') {
                  _showNotification("Ride Cancelled", "Your booking has been cancelled.");
                }
             }
           }
        });

    // 3. Notify Owner on Cancellation
    FirebaseFirestore.instance
        .collection('bookings')
        .where('ownerId', isEqualTo: user!.uid)
        .where('status', isEqualTo: 'cancelled')
        .snapshots()
        .listen((snapshot) {
           for (var change in snapshot.docChanges) {
             if (change.type == DocumentChangeType.modified || change.type == DocumentChangeType.added) {
               var data = change.doc.data() as Map<String, dynamic>;
               Timestamp? cancelledAt = data['cancelledAt'];
               if (cancelledAt != null) {
                 DateTime cancelled = cancelledAt.toDate();
                 // Only notify if cancelled within last 30 seconds
                 if (DateTime.now().difference(cancelled).inSeconds < 30) {
                    _showNotification("Booking Cancelled", "A booking for your cycle was cancelled.");
                 }
               }
             }
           }
        });
  }

  void _showNotification(String title, String message) {
    NotificationService.showNotification(title, message);
  }

  @override
  void dispose() {
    _ownerNotificationStream?.cancel();
    _renterNotificationStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // APP BAR
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LandingScreen())),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hey, ${user?.displayName?.split(' ')[0] ?? 'Student'}!", style: TextStyle(fontSize: 24)),
            Text("Find your ride", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())),
              child: CircleAvatar(
                backgroundImage: NetworkImage(user?.photoURL ?? "https://via.placeholder.com/150"),
                backgroundColor: Colors.grey,
              ),
            ),
          )
        ],
      ),

      // BODY
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: user?.uid)
            .where('status', whereIn: ['booked', 'started', 'payment_pending'])
            .snapshots(),
        builder: (context, bookingSnapshot) {
          DocumentSnapshot? activeBooking;
          if (bookingSnapshot.hasData && bookingSnapshot.data!.docs.isNotEmpty) {
            activeBooking = bookingSnapshot.data!.docs.first;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('cycles')
                .snapshots(),
            builder: (context, cycleSnapshot) {
              if (cycleSnapshot.hasError) return Center(child: Text("Something went wrong"));
              if (cycleSnapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
              
              var docs = cycleSnapshot.data!.docs;
              
              // FILTERING LOGIC
              // 1. Location
              if (_selectedLocation != "All") {
                docs = docs.where((d) => d['location'] == _selectedLocation).toList();
              }

              // 2. Active Ride Excl
              if (activeBooking != null) {
                 docs = docs.where((d) => d.id != activeBooking!['cycleId']).toList();
              }

              // 3. Own Cycles Excl
              if (user != null) {
                 docs = docs.where((d) {
                    var data = d.data() as Map<String, dynamic>;
                    return data['ownerId'] != user!.uid;
                 }).toList();
              }

              // 4. Owner Availability Filter
              // isAvailable is ONLY controlled by the owner's manual toggle in My Listings.
              // System never changes this field. _validateBookingSlot handles booking conflicts.
              docs = docs.where((d) {
                 var data = d.data() as Map<String, dynamic>;
                 // Hide only if owner manually delisted
                 if (data['isAvailable'] == false) return false;
                 return true;
              }).toList();

              return CustomScrollView(
                slivers: [
                  // 1. Active Ride Card
                  if (activeBooking != null) 
                    SliverToBoxAdapter(child: _buildActiveRideCard(context, activeBooking)),

                  // 2. Time Filter
                  SliverToBoxAdapter(child: _buildTimeFilter()),

                  // 3. Location Chips (Sticky)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyHeaderDelegate(
                      child: Container(
                        height: 60,
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _locations.length,
                          itemBuilder: (context, index) {
                            String loc = _locations[index];
                            bool isSelected = _selectedLocation == loc;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedLocation = loc),
                              child: Container(
                                margin: EdgeInsets.only(right: 10),
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : Color(0xFF2C2C2C),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(loc, style: TextStyle(
                                    color: isSelected ? Colors.black : Colors.white, 
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                                  )),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // 4. Cycle List
                  if (docs.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.directions_bike, size: 50, color: Colors.grey),
                              SizedBox(height: 10),
                              Text("No cycles available here.", style: TextStyle(color: Colors.grey)),
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
                          String cycleId = docs[index].id;
                          
                          // Dynamic Price Calc
                          double? dynamicTotal;
                          if (_selectedStartTime != null && _selectedEndTime != null) {
                             double durationHrs = _selectedEndTime!.difference(_selectedStartTime!).inMinutes / 60.0;
                             if (durationHrs < 0) durationHrs = 0;
                             
                             double base = (data['basePrice'] ?? 0).toDouble();
                             double hourly = (data['hourlyPrice'] ?? 0).toDouble();
                             
                             if (durationHrs <= 2) {
                               dynamicTotal = base;
                             } else {
                               dynamicTotal = base + ((durationHrs - 2).ceil() * hourly);
                             }
                          }

                          return _buildCycleCard(context, data, cycleId, totalPrice: dynamicTotal);
                        },
                        childCount: docs.length,
                      ),
                    ),
                    
                   // Bottom Padding
                   SliverPadding(padding: EdgeInsets.only(bottom: 100))
                ],
              );
            }
          );
        }
      ),
      
      // ADD LISTING BUTTON
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddCycleScreen())),
        label: Text("List My Cycle"),
        icon: Icon(Icons.add),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildImage(String? imageUrl, {double? width, double? height, double iconSize = 50}) {
     if (imageUrl == null || imageUrl.isEmpty) {
        return Container(
          width: width, height: height,
          color: Colors.grey[850],
          child: Center(child: Icon(Icons.directions_bike, size: iconSize, color: Colors.white24)),
        );
     }

     if (imageUrl.startsWith('http')) {
        return Image.network(
          imageUrl,
          width: width, height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
             width: width, height: height,
             color: Colors.grey[850],
             child: Center(child: Icon(Icons.directions_bike, size: iconSize, color: Colors.white24)),
          ),
        );
     }

     try {
       // Base64
       return Image.memory(
         base64Decode(imageUrl),
         width: width, height: height,
         fit: BoxFit.cover,
         errorBuilder: (context, error, stackTrace) => Container(
             width: width, height: height,
             color: Colors.grey[850],
             child: Center(child: Icon(Icons.broken_image, size: iconSize, color: Colors.white24)),
          ),
       );
     } catch (e) {
        return Container(
          width: width, height: height,
          color: Colors.grey[850],
          child: Center(child: Icon(Icons.error, size: iconSize, color: Colors.white24)),
        );
     }
  }

  Widget _buildCycleCard(BuildContext context, Map<String, dynamic> data, String cycleId, {double? totalPrice}) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CycleDetailScreen(
        data: data, 
        cycleId: cycleId,
        initialStartTime: _selectedStartTime,
        initialEndTime: _selectedEndTime,
      ))),
      child: Container(
        margin: EdgeInsets.only(bottom: 20),
        height: 250,
        decoration: BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Stack(
          children: [
            // Image
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _buildImage(data['imageUrl']),
              ),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                  ),
                ),
              ),
            ),
            
            // RATING BADGE (Top Right)
            Positioned(
              top: 16, right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.5))
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    SizedBox(width: 4),
                    Text(
                      (data['averageRating'] != null && data['averageRating'] > 0) 
                          ? (data['averageRating'] as num).toStringAsFixed(1) 
                          : "New",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
                    ),
                  ],
                ),
              ),
            ),

            // Text Content
            Positioned(
              bottom: 16, left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${data['modelName']} - ${data['gearType'] ?? 'Single Geared'}", 
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 4, bottom: 4),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Text("Hosted by ${data['ownerName']?.split(' ')[0] ?? 'Student'}", style: TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey),
                      Text(" ${data['location']}", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            // Price Tag
            Positioned(
              bottom: 16, right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white30)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (totalPrice != null) ...[
                       Text("Total", style: TextStyle(color: Colors.grey, fontSize: 10)),
                       Text("₹${totalPrice.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.greenAccent)),
                    ] else ...[
                       Text("₹${data['basePrice']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                       Text("2 hrs", style: TextStyle(fontSize: 10, color: Colors.white70)),
                       SizedBox(height: 2),
                       Text("+ ₹${data['hourlyPrice']}/hr", style: TextStyle(fontSize: 9, color: Colors.greenAccent)),
                    ]
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRideCard(BuildContext context, DocumentSnapshot booking) {
    Map<String, dynamic> data = booking['cycleData'];
    String status = booking['status'];
    String cycleId = booking['cycleId'];
    bool isNoShow = booking.data().toString().contains('isNoShow') ? (booking['isNoShow'] ?? false) : false;

    // Determine Display Status and Color
    String displayStatus = status.toUpperCase();
    Color statusColor = Colors.amber;
    String buttonText = "START RIDE";
    Color buttonColor = Colors.green;
    
    if (status == 'started') {
      statusColor = Colors.green;
      buttonText = "END RIDE";
      buttonColor = Colors.red;
    } else if (status == 'payment_pending') {
      statusColor = Colors.green;
      buttonText = "PAY NOW";
      buttonColor = Colors.green;
      
      if (isNoShow) {
        displayStatus = "NO SHOW - PAY NOW";
        statusColor = Colors.redAccent;
        buttonText = "PAY RESERVED SLOT";
        buttonColor = Colors.redAccent;
      }
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF2C2C2C), Color(0xFF1E1E1E)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor, width: 2)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ACTIVE RIDE", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                child: Text(displayStatus, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImage(data['imageUrl'], width: 60, height: 60),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['modelName'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(data['location'], style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              )
            ],
          ),
          SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => CycleDetailScreen(data: data, cycleId: cycleId)));
              },
              child: Text(
                buttonText, 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
            ),
          )
        ],
      ),
    );
    }

  Widget _buildTimeFilter() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2C2C2C), Color(0xFF1E1E1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text("Select Time Slot", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              if (_selectedStartTime != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedStartTime = null; 
                    _selectedEndTime = null;
                  }),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3))
                    ),
                    child: Text("Clear", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          ),
          SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildTimePill(
                  "Start", 
                  _selectedStartTime, 
                  () => _pickDateTime(true)
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
              ),
              Expanded(
                child: _buildTimePill(
                  "End", 
                  _selectedEndTime, 
                  () => _pickDateTime(false)
                ),
              ),
            ],
          ),
          if (_selectedStartTime != null && _selectedEndTime == null)
             Padding(
               padding: const EdgeInsets.only(top: 8.0),
               child: Row(
                 children: [
                   Icon(Icons.info_outline, size: 12, color: Colors.orange),
                   SizedBox(width: 4),
                   Text("Select End Time to see prices", style: TextStyle(color: Colors.orange, fontSize: 10)),
                 ],
               ),
             )
        ],
      ),
    );
  }

  Future<void> _pickDateTime(bool isStart) async {
      DateTime initialDate = isStart ? (_selectedStartTime ?? DateTime.now()) : (_selectedEndTime ?? DateTime.now());
      TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDate);

      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime.now().subtract(Duration(days: 1)),
        lastDate: DateTime.now().add(Duration(days: 7)),
        builder: (context, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(primary: Colors.white, onSurface: Colors.white),
          ),
          child: child!,
        ),
      );

      if (pickedDate == null) return;

      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: (context, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(primary: Colors.white, onSurface: Colors.white),
          ),
          child: child!,
        ),
      );

      if (pickedTime == null) return;

      DateTime pickedDateTime = DateTime(
        pickedDate.year, 
        pickedDate.month, 
        pickedDate.day, 
        pickedTime.hour, 
        pickedTime.minute
      );

      setState(() {
         if (isStart) {
            _selectedStartTime = pickedDateTime;
            if (_selectedEndTime != null && _selectedEndTime!.isBefore(_selectedStartTime!)) {
                _selectedEndTime = _selectedStartTime!.add(Duration(hours: 2));
            }
         } else {
            _selectedEndTime = pickedDateTime;
         }
      });
  }

  Widget _buildTimePill(String label, DateTime? time, VoidCallback onTap) {
    bool isSelected = time != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.black26, 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white10)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey, fontSize: 10)),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: isSelected ? Colors.blueAccent : Colors.white70),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    time != null ? DateFormat('MMM d, h:mm a').format(time) : "-- : --", 
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60, 
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyHeaderDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor, // Ensure background is opaque
      child: child,
    );
  }

  @override
  double get maxExtent => 60.0; // Height of the location bar

  @override
  double get minExtent => 60.0;

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}