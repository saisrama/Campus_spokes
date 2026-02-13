import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class CycleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String cycleId;
  final DateTime? initialStartTime;
  final DateTime? initialEndTime;

  CycleDetailScreen({
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
  DateTime _endTime = DateTime.now().add(Duration(hours: 2));
  double _totalCost = 0;
  double _durationInHours = 2.0;

  User? currentUser = FirebaseAuth.instance.currentUser;
  String? _bookingId;
  String? _bookingStatus = 'none'; // none, booked, started, end_requested, payment_pending, completed
  DateTime? _rideStartTime;
  DateTime? _scheduledStartTime;
  DateTime? _scheduledEndTime;
  bool _isNoShow = false;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    // Default start to next quarter hour or just now
    _startTime = now;
    
    if (widget.initialStartTime != null) {
       _startTime = widget.initialStartTime!;
    }
    
    if (widget.initialEndTime != null) {
       _endTime = widget.initialEndTime!;
       // Validation check: ensure end is after start
       if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(Duration(hours: 2));
       }
    } else {
       // Default 2 hours from start
       _endTime = _startTime.add(Duration(hours: 2));
    }

    _calculateCost();
    _checkActiveBooking();
  }

  Future<void> _checkActiveBooking() async {
    if (currentUser == null) return;
    
    // Check if THIS cycle is already booked by THIS user and not completed
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

      // 3. NO-SHOW CHECK
      // If status is 'booked' (not started) AND Time > Scheduled End Time
      if (status == 'booked' && scheduledEndX != null && DateTime.now().isAfter(scheduledEndX)) {
          // Perform async update outside setState
          
          // 1. Update Booking
          await doc.reference.update({
             'status': 'payment_pending',
             'isNoShow': true,
             'endTime': scheduledEndX,
          });
          
          // 2. Release Cycle — clear nextAvailableTime hint
          await FirebaseFirestore.instance.collection('cycles').doc(widget.cycleId).update({
             'nextAvailableTime': FieldValue.serverTimestamp(), 
          });
          
          status = 'payment_pending';
          isNoShowDoc = true;
          
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("Booking Expired (No Show). Please pay for the reserved slot."),
                backgroundColor: Colors.orangeAccent,
                duration: Duration(seconds: 5),
              ));
          }
      }

      if (!mounted) return;

      setState(() {
        _bookingId = doc.id;
        _bookingStatus = status;
        _isNoShow = isNoShowDoc;
        
        if (startTimeStamp != null) _rideStartTime = startTimeStamp;
        
        _scheduledStartTime = scheduledStartX;
        _scheduledEndTime = scheduledEndX;
        
        if (_scheduledStartTime != null) _startTime = _scheduledStartTime!;
        if (_scheduledEndTime != null) _endTime = _scheduledEndTime!;
        
        // Ensure _rideStartTime is set for payment if missing (No Show case)
        if (status == 'payment_pending') {
           if (_rideStartTime == null && _scheduledStartTime != null) _rideStartTime = _scheduledStartTime;
        }
      });
      
      // ALWAYS recalculate cost after updating times from Firestore
      _calculateCost();
      
      // For payment_pending, also show the payment dialog
      if (status == 'payment_pending') {
          _calculateFinalCostAndShowPayment();
      }
    }

    /* 
    4. NO-SHOW CHECK (Client Side Polling? Or simple check on load)
    We handled it above for the Active User.
    What if the user opens the app 5 hours later? The above check runs on init.
    */
  }

  // ... (existing methods) ...

  void _calculateFinalCostAndShowPayment() {
    // If _rideStartTime is null (e.g. app restart), fetch it or handle error. 
    // User requested "Reserved Time Start" -> Prioritize _scheduledStartTime
    DateTime startTime = _scheduledStartTime ?? _rideStartTime ?? DateTime.now(); 
    DateTime actualEndTime = DateTime.now();

    // 1. Calculate Base Duration (Scheduled)
    
    DateTime scheduledEnd = _scheduledEndTime ?? actualEndTime;
    
    // Duration actually used
    final duration = actualEndTime.difference(startTime);
    final double durationInHours = duration.inMinutes / 60.0;
    
    int basePrice = widget.data['basePrice'] ?? 20;
    int hourlyPrice = widget.data['hourlyPrice'] ?? 10;
    
    double finalCost = 0;
    bool isLate = false;
    double lateFee = 0;

    // 2. Base Cost Calculation
    
    // Calculate Scheduled Cost
    double scheduledDurationHrs = 2.0;
    if (_scheduledStartTime != null && _scheduledEndTime != null) {
       scheduledDurationHrs = _scheduledEndTime!.difference(_scheduledStartTime!).inMinutes / 60.0;
    }
    
    double scheduledCost = basePrice.toDouble();
    if (scheduledDurationHrs > 2) {
       scheduledCost += ((scheduledDurationHrs - 2).ceil() * hourlyPrice);
    }
    
    // NO-SHOW LOGIC: If No Show, Pay Scheduled Cost ONLY. No Late Fees.
    if (_isNoShow) {
        finalCost = scheduledCost;
        // Proceed to show dialog
        _showEndRideDialog(finalCost, scheduledDurationHrs, false, 0);
        return;
    }

    // 3. Strict Late Fee Logic (Only if NOT a No-Show)
    if (actualEndTime.isAfter(scheduledEnd)) {
      isLate = true;
      
      // Calculate Late Duration
      Duration lateDuration = actualEndTime.difference(scheduledEnd);
      double lateHours = lateDuration.inMinutes / 60.0;
      
      // Charge for every started hour late
      double lateHoursCeil = lateHours.ceilToDouble();
      if (lateHoursCeil < 1) lateHoursCeil = 1; 
      
      // Rate: 2x Hourly Price
      lateFee = lateHoursCeil * (hourlyPrice * 2);
    }
    
    finalCost = scheduledCost + lateFee;

    _showEndRideDialog(finalCost, durationInHours, isLate, lateFee);
  }

  void _showEndRideDialog(double cost, double durationHrs, bool isLate, double lateFee) {
    DateTime startTime = _rideStartTime ?? DateTime.now().subtract(Duration(minutes: (durationHrs * 60).round()));
    DateTime endTime = DateTime.now();
    
    // For No-Show, show specific details
    String title = "End Ride & Pay";
    if (_isNoShow) {
        title = "No Show - Pay Reserved Slot";
        endTime = _scheduledEndTime ?? endTime; // Show scheduled end time
    }

    double baseCost = cost - lateFee;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(title, style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Breakdown
            _buildDialogRow("Start Time", DateFormat('hh:mm a').format(startTime)),
            _buildDialogRow("End Time", DateFormat('hh:mm a').format(endTime)),
            _buildDialogRow("Total Duration", "${durationHrs.toStringAsFixed(1)} hrs"),
            Divider(color: Colors.white24),
            
            if (_isNoShow) ...[
                 Text("You did not start the ride on time.", style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                 Text("Please pay for the reserved slot.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                 SizedBox(height: 10),
            ] else ...[
                // Cost Breakdown
                _buildDialogRow("Base Cost", "₹${baseCost.toStringAsFixed(0)}"),
                if (isLate) ...[
                   _buildDialogRow("Late Fee (2x)", "+₹${lateFee.toStringAsFixed(0)}", valueColor: Colors.redAccent),
                   SizedBox(height: 5),
                   Text(
                     "Late Return Detected! You exceeded the scheduled time.", 
                     style: TextStyle(color: Colors.redAccent, fontSize: 10)
                   ),
                ],
            ],
            Divider(color: Colors.white24),
            
            // Total
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Total To Pay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text("₹${cost.toStringAsFixed(0)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            )
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _launchUPI(cost, onSuccess: () => _showRatingDialog(cost));
            },
            child: Text("PAY NOW", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<bool> _validateBookingSlot({required DateTime start, required DateTime end}) async {
    DateTime now = DateTime.now();
    
    // Strict check: Start Time < Now - 1 minute (grace)
    if (start.isBefore(now.subtract(Duration(minutes: 1)))) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
         content: Text("Start time cannot be in the past!"),
         backgroundColor: Colors.redAccent,
       ));
       return false;
    }

    // PROPOSED SLOT BUFFER LOGIC:
    // User wants slot [S, E]
    // Effectively occupies [S, E + 30m]
    // Condition to be valid: NO overlap with any existing [BookedS, BookedE + 30m]
    
    DateTime myEffectiveStart = start;
    DateTime myEffectiveEnd = end.add(Duration(minutes: 30));

    try {
      var query = await FirebaseFirestore.instance
          .collection('bookings')
          .where('cycleId', isEqualTo: widget.cycleId)
          .where('status', whereIn: ['booked', 'started']) // Active bookings
          .get();

      for (var doc in query.docs) {
         var data = doc.data();
         DateTime? bookedStart;
         DateTime? bookedEnd;
         
         if (data['scheduledStartTime'] != null) bookedStart = (data['scheduledStartTime'] as Timestamp).toDate();
         else if (data['startTime'] != null) bookedStart = (data['startTime'] as Timestamp).toDate(); 
         
         if (data['scheduledEndTime'] != null) bookedEnd = (data['scheduledEndTime'] as Timestamp).toDate();
         
         if (bookedStart == null) continue;
         if (bookedEnd == null) bookedEnd = bookedStart.add(Duration(hours: 2)); 
         

         // EXISITNG SLOT BUFFER LOGIC:
         // Occupies [BookedS, BookedE + 30m]
         DateTime theirEffectiveStart = bookedStart;
         DateTime theirEffectiveEnd = bookedEnd.add(Duration(minutes: 30));
         
         // OVERLAP CHECK:
         if (myEffectiveStart.isBefore(theirEffectiveEnd) && myEffectiveEnd.isAfter(theirEffectiveStart)) {
            DateTime displayBookedEndWithBuffer = bookedEnd.add(Duration(minutes: 30));
            String conflictMsg = "Gap conflict! Cycles need 30m buffer. Intersection with booking ${DateFormat('HH:mm').format(bookedStart)} - ${DateFormat('HH:mm').format(displayBookedEndWithBuffer)}";

            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(conflictMsg),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 4),
            ));
            return false;
         }
      }
    } catch (e) {
      print("Error validating slot: $e");
      return false; // Fail safe?
    }
    
    return true;
  }

  Future<void> _selectTime(bool isStart) async {
    DateTime initialDate = isStart ? _startTime : _endTime;
    TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDate);

    // 1. Pick Date
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(Duration(days: 1)), // Allow slightly past for testing/edge cases? Better strict.
      lastDate: DateTime.now().add(Duration(days: 7)), // 1 Week advance booking
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: Colors.white, onSurface: Colors.white),
        ),
        child: child!,
      ),
    );

    if (pickedDate == null) return;

    // 2. Pick Time
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

    // 3. Combine
    DateTime pickedDateTime = DateTime(
      pickedDate.year, 
      pickedDate.month, 
      pickedDate.day, 
      pickedTime.hour, 
      pickedTime.minute
    );

    DateTime tempStart = isStart ? pickedDateTime : _startTime;
    DateTime tempEnd = isStart ? _endTime : pickedDateTime;

    // Auto-adjust end if it becomes before start
    if (isStart && tempEnd.isBefore(tempStart)) {
       tempEnd = tempStart.add(Duration(hours: 2));
    }

    bool isValid = await _validateBookingSlot(start: tempStart, end: tempEnd);
    
    if (isValid) {
      setState(() {
        if (isStart) _startTime = tempStart;
        else _endTime = tempEnd;
        
        // If we just changed start, ensure end is at least start
        if (isStart && _endTime.isBefore(_startTime)) {
            _endTime = _startTime.add(Duration(hours: 2));
        }
        
        _calculateCost();
      });
    }
  }

  void _calculateCost() {
    Duration duration = _endTime.difference(_startTime);
    double hours = duration.inMinutes / 60.0;

    _durationInHours = hours;
    if (_durationInHours < 0) _durationInHours = 0;

    int basePrice = (widget.data['basePrice'] ?? 20).toInt();
    int hourlyPrice = (widget.data['hourlyPrice'] ?? 10).toInt();

    if (_durationInHours <= 2) {
      _totalCost = basePrice.toDouble();
    } else {
      double extraHours = _durationInHours - 2;
      _totalCost = basePrice + (extraHours.ceil() * hourlyPrice).toDouble();
    }
  }

  // LATE FEE CALCULATION
  double _calculateLateFee(double durationInHours) {
    // If user booked for X hours but returned after X+Y hours
    // This requires us to know the EXPECTED end time. 
    // In the current simple flow, we don't store "Expected Duration" strongly in the booking document active state 
    // (except initially).
    // However, for the purpose of this feature request "Late Fee 2x", let's assume:
    // Any time beyond the initial 2 hours base slot (or chosen slot) is charged 2x? 
    // OR: If they exceed the time they selected in the TimePicker initially.
    
    // Simplification for MVP: The standard cost logic already charges for extra hours. 
    // The requirement says "Late Return Fee is usually 2x to 4x".
    // So if they booked for 2 hours but used 3, the 3rd hour is late? 
    // Or if they booked for 4 hours and used 5?
    
    // Implementation: We will use the selected _endTime from the UI as the "Expected Return Time".
    // If the current time (now) > _rideStartTime + (expected duration), then it's late.
    
    // But _calculateFinalCostAndShowPayment calculates based on ACTUAL duration.
    // So we need to modify the cost formula there.
    return 0.0;
  }

  // BOOKING LOGIC
  Future<void> _handleBookingAction() async {
    if (_bookingStatus == 'none') {
      // BOOK RIDE 
      
      // 1. Check if user already has ANY active booking
      var activeBookingQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: currentUser!.uid)
          .where('status', whereIn: ['booked', 'started', 'payment_pending'])
          .limit(1)
          .get();

      if (activeBookingQuery.docs.isNotEmpty) {
        // User has an active booking
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("You already have an active ride. Please complete it first."),
          backgroundColor: Colors.redAccent,
        ));
        return;
      }
      
      // 2. Validate Time Slot (Check Overlaps) - Loophole Fix
      // Even if user didn't change time (default), we must check availability
      bool isValid = await _validateBookingSlot(start: _startTime, end: _endTime);
      if (!isValid) return; // Stop booking if invalid

      // Show Start/End Time Confirmation
      _showActionConfirmationDialog(
        action: "Book Ride",
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Confirm your booking details:", style: TextStyle(color: Colors.white70)),
            SizedBox(height: 10),
            Text("Start Time: ${DateFormat('MMM d, h:mm a').format(_startTime)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text("End Time: ${DateFormat('MMM d, h:mm a').format(_endTime)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("Est. Cost: ₹${_totalCost.toStringAsFixed(0)}", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        onConfirm: _createBooking
      );

    } else if (_bookingStatus == 'booked') {
      // START RIDE
      
      // Enforce Start Time
      if (_scheduledStartTime != null) {
        if (DateTime.now().isBefore(_scheduledStartTime!)) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text("You cannot start the ride before ${DateFormat('h:mm a').format(_startTime)}"),
             backgroundColor: Colors.redAccent,
           ));
           return;
        }
      }
      
      // Enforce Expiry (Cannot start after Scheduled End)
      if (_scheduledEndTime != null) {
        if (DateTime.now().isAfter(_scheduledEndTime!)) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text("Booking Expired! You cannot start the ride after your scheduled end time (${DateFormat('h:mm a').format(_endTime)})."),
             backgroundColor: Colors.redAccent,
             duration: Duration(seconds: 4),
           ));
           return;
        }
      }
      
       _showTermsAndConditionsDialog();

    } else if (_bookingStatus == 'started') {
      // END RIDE - Simple Confirmation
      _showActionConfirmationDialog(
        action: "End Ride",
        content: Text("Are you sure you want to end your ride?", style: TextStyle(color: Colors.white70)),
        onConfirm: () async {
           await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
            'status': 'payment_pending',
            'endTime': FieldValue.serverTimestamp(),
          });
          setState(() {
            _bookingStatus = 'payment_pending';
            // We need to fetch endTime from server ideally, but for now we proceed
          });
           _calculateFinalCostAndShowPayment();
        }
      );

    } else if (_bookingStatus == 'payment_pending') {
       _calculateFinalCostAndShowPayment();
    }
  }

  // CANCEL RIDE LOGIC
  Future<void> _handleCancellation() async {
    // 1. Show Warning Dialog
    double estimatedCost = _totalCost;
    double cancellationFee = estimatedCost * 0.5;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text("Cancel Ride?", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Cancellation Policy:", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            Text("You will be charged 50% of the estimated cost.", style: TextStyle(color: Colors.grey)),
            SizedBox(height: 10),
            Text("Fee: ₹${cancellationFee.toStringAsFixed(0)}", style: TextStyle(fontSize: 20, color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            child: Text("BACK", style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              _processCancellationPayment(cancellationFee);
            },
            child: Text("ACCEPT & CANCEL", style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  void _processCancellationPayment(double fee) {
     showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text("Pay Cancellation Fee"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Cancellation Fee: ₹${fee.toStringAsFixed(0)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context); // Close Payment Dialog
              _launchUPI(fee, onSuccess: () => _finalizeCancellation(fee));
            },
            child: Text("PAY NOW", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _finalizeCancellation(double fee) async {
      try {
        // Snapshot user details for history reliability
        String renterName = "User";
        String renterPhone = "";
        try {
           DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.data['userId']).get();
           if (userDoc.exists) {
             var uData = userDoc.data() as Map<String, dynamic>;
             renterName = uData['displayName'] ?? "User";
             renterPhone = uData['phoneNumber'] ?? "";
           }
        } catch (e) {
           print("Error fetching user for snapshot: $e");
        }

        await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancellationFee': fee,
          'finalCost': fee, // Record as final cost for history
          'renterName': renterName, // Snapshot for history
          'renterPhone': renterPhone,
        });

        // Booking cancelled — _validateBookingSlot will allow new bookings
        // No need to update cycle document

        setState(() {
          _bookingStatus = 'cancelled';
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ride Cancelled.")));
        // Navigate back or refresh state? For now, stay on screen but status is 'cancelled' (which might show simplified view or exit)
        // User probably expects to leave or see cancelled state.
        
        // Let's pop back to Home or show a "Cancelled" view. 
        // Showing "Cancelled" view for now by letting build() handle it (we might need to add 'cancelled' to button logic if we persist).
        // Actually, let's just pop.
        Navigator.pop(context); 

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error cancelling: $e")));
      }
  }

  void _showActionConfirmationDialog({required String action, required Widget content, required VoidCallback onConfirm}) {
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         backgroundColor: Color(0xFF1E1E1E),
         title: Text(action, style: TextStyle(color: Colors.white)),
         content: content,
         actions: [
           TextButton(
             child: Text("CANCEL", style: TextStyle(color: Colors.grey)),
             onPressed: () => Navigator.pop(context),
           ),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
             child: Text("CONFIRM", style: TextStyle(color: Colors.black)),
             onPressed: () {
               Navigator.pop(context); // Close dialog
               onConfirm(); // Execute action
             },
           )
         ],
       )
     );
  }



  Widget _buildDialogRow(String label, String value, {Color valueColor = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // TERMS AND CONDITIONS DIALOG
  void _showTermsAndConditionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text("Terms & Conditions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Please read and accept the following terms to start your ride:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                 SizedBox(height: 15),
                 _buildTermItem("1. Facilitator Role", "Campus Spokes is strictly a platform to connect Cycle Owners with Renters. We do not own the cycles and are not a party to the rental agreement."),
                 _buildTermItem("2. No Liability", "Campus Spokes is NOT responsible for any accidents, injuries, or damages caused to the rider, third parties, or property during the ride."),
                 _buildTermItem("3. Prohibited Use", "Using the cycle/app for illegal, illicit, or unauthorized purposes is strictly prohibited. Users found misusing the platform will be banned."),
                 _buildTermItem("4. Dispute Resolution", "Any disputes regarding cycle condition, payments, or damages must be resolved directly between the Owner and the Renter. Campus Spokes will not mediate financial or physical disputes."),
                 _buildTermItem("5. STRICT No-Show Policy", "If you fail to start the ride by the scheduled end time, your booking will expire. You will be charged the FULL reserved amount (no late fees). The cycle will be immediately released for other users."),
                 _buildTermItem("6. Safety", "Riders are advised to follow traffic rules and ride responsibly. Currently, we do not provide insurance cover."),
                 SizedBox(height: 10),
                 Text("By clicking 'Accept & Start', you acknowledge that you have read and agreed to these terms.", style: TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Decline", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
               Navigator.pop(context); // Close T&C
               _startRide(); // Proceed to Start Logic
            },
            child: Text("Accept & Start", style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  Widget _buildTermItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          SizedBox(height: 4),
          Text(content, style: TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _startRide() async {
      // Proceed to Start Ride
       _showActionConfirmationDialog(
        action: "Start Ride",
        content: Text("Are you near the cycle and ready to start?", style: TextStyle(color: Colors.white70)),
        onConfirm: () async {
            await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
              'status': 'started',
              'startTime': FieldValue.serverTimestamp(),
            });
            // Ride started — _validateBookingSlot prevents overlapping bookings
            // No need to delist cycle
            setState(() {
              _bookingStatus = 'started';
              _rideStartTime = DateTime.now();
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ride Started! Have fun!")));
        }
      );
  }



  Future<void> _createBooking() async {
    try {
      // Create Booking
      var ref = await FirebaseFirestore.instance.collection('bookings').add({
        'userId': currentUser!.uid,
        'ownerId': widget.data['ownerId'],
        'cycleId': widget.cycleId,
        'status': 'booked',
        'createdAt': FieldValue.serverTimestamp(),
        'basePrice': widget.data['basePrice'], 
        'hourlyPrice': widget.data['hourlyPrice'],
        'cycleData': widget.data, 
        
        // Snapshot Owner Details for History
        'ownerName': widget.data['ownerName'] ?? 'Student',
        'ownerPhone': widget.data['ownerPhone'] ?? 'N/A',

        // Save Scheduled Times
        // Fix for Overnight: DateTimes are now fully qualified from DatePicker
        'scheduledStartTime': _startTime,
        'scheduledEndTime': _endTime,
      });

      // Update local state with scheduled times immediately
      _scheduledStartTime = _startTime;
      _scheduledEndTime = _endTime;

      // Don't fully delist — keep cycle visible for non-overlapping time slots.
      // _validateBookingSlot handles conflict prevention.
      // Only store nextAvailableTime as a hint for HomeScreen filtering.
      DateTime nextAvailable = _scheduledEndTime!.add(Duration(minutes: 30));
      
      await FirebaseFirestore.instance.collection('cycles').doc(widget.cycleId).update({
        'nextAvailableTime': nextAvailable,
      });

      setState(() {
        _bookingId = ref.id;
        _bookingStatus = 'booked';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cycle Booked! It is now reserved for you.")));
      
      // WhatsApp Redirect
      String? ownerPhone = widget.data['ownerPhone'];
      if (ownerPhone != null && ownerPhone.isNotEmpty && ownerPhone != "N/A") {
          try {
            // Strip non-digits
            String cleanPhone = ownerPhone.replaceAll(RegExp(r'\D'), '');
            // Add country code if missing (Assuming India +91 for this context)
            if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
              cleanPhone = '91$cleanPhone';
            }
            
            String startTimeStr = DateFormat('MMM d, h:mm a').format(_startTime);
            String endTimeStr = DateFormat('MMM d, h:mm a').format(_endTime);
            String message = "Hi, I just reserved your cycle (${widget.data['modelName']}) on *Campus Spokes*.\n\n"
                             "*Time:* $startTimeStr to $endTimeStr\n"
                             "*Estimated Cost:* ₹${_totalCost.toStringAsFixed(0)}\n\n"
                             "Please confirm availability.";
            
            final Uri waUrl = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
            await launchUrl(waUrl, mode: LaunchMode.externalApplication);
          } catch (e) {
             print("Could not launch WhatsApp: $e");
          }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Booking failed: $e")));
    }
  }

  void _showConfirmationAndPay() {
      // Logic moved to End Ride. 
      // Rent Now just creates the booking.
      _createBooking();
  }

  void _launchUPI(double amount, {required VoidCallback onSuccess}) async {
    String upiId = widget.data['ownerUpiId'] ?? '';
    final Uri upiUrl = Uri.parse('upi://pay?pa=$upiId&pn=CycleOwner&am=$amount&cu=INR&tn=CycleRent');
    
    try {
      await launchUrl(upiUrl, mode: LaunchMode.externalApplication);
      // Assuming payment success for demo
      onSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not launch UPI app.")));
      onSuccess(); // Proceed for demo
    }
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .where('cycleId', isEqualTo: widget.cycleId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text("Error loading reviews", style: TextStyle(color: Colors.red));
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
            
            // Filter queries client side to avoid index issues with multiple fields
            var docs = snapshot.data!.docs.where((d) {
              var data = d.data() as Map<String, dynamic>;
              // Check if rating exists and is > 0
              return data.containsKey('rating') && data['rating'] != null && (data['rating'] as num) > 0;
            }).toList();

            if (docs.isEmpty) {
              return Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(color: Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text("No reviews yet.", style: TextStyle(color: Colors.grey))),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                var data = docs[index].data() as Map<String, dynamic>;
                double rating = (data['rating'] ?? 0.0).toDouble();
                String text = data['reviewText'] ?? "";
                
                return Container(
                  margin: EdgeInsets.only(bottom: 10),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, size: 16, color: Colors.white),
                          ),
                          SizedBox(width: 8),
                          Text("Anonymous User", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          Spacer(),
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          Text(" ${rating.toStringAsFixed(1)}", style: TextStyle(color: Colors.amber)),
                        ],
                      ),
                      if (text.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(text, style: TextStyle(color: Colors.white70)),
                      ]
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }






  void _showRatingDialog(double finalCost) {
    double rating = 5.0;
    TextEditingController _reviewController = TextEditingController();
    
    // Capture the context of the Screen (CycleDetailScreen)
    final BuildContext screenContext = context;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Color(0xFF1E1E1E),
            title: Text("Rate Your Ride"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("How was your experience?", style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 30,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            rating = index + 1.0;
                          });
                        },
                      );
                    }),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _reviewController,
                    maxLines: 3,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Write a review (optional)...",
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text("NOT NOW", style: TextStyle(color: Colors.grey)),
                onPressed: () async {
                   // Mark as completed without rating update
                   await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
                    'status': 'completed',
                    'endTime': FieldValue.serverTimestamp(),
                    'finalCost': finalCost,
                   });
                   
                   // Ride completed — no need to update cycle availability

                   setState(() { _bookingStatus = 'completed'; });
                   Navigator.pop(context); // Close Dialog
                   if (screenContext.mounted) Navigator.pop(screenContext); // Close Screen
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                child: Text("SUBMIT", style: TextStyle(color: Colors.black)),
                onPressed: () async {
                  // 1. Update Booking
                  await FirebaseFirestore.instance.collection('bookings').doc(_bookingId).update({
                    'status': 'completed',
                    'endTime': FieldValue.serverTimestamp(),
                    'finalCost': finalCost,
                    'rating': rating,
                    'reviewText': _reviewController.text.trim(),
                  });

                  // 2. Update Cycle Stats (Avg Rating & Count)
                  DocumentReference cycleRef = FirebaseFirestore.instance.collection('cycles').doc(widget.cycleId);
                  
                  FirebaseFirestore.instance.runTransaction((transaction) async {
                    DocumentSnapshot snapshot = await transaction.get(cycleRef);
                    if (!snapshot.exists) return;

                    var data = snapshot.data() as Map<String, dynamic>;
                    double currentAvg = (data['averageRating'] ?? 0.0).toDouble();
                    int currentCount = (data['reviewCount'] ?? 0).toInt();

                    double newAvg = ((currentAvg * currentCount) + rating) / (currentCount + 1);
                    
                    transaction.update(cycleRef, {
                      'averageRating': newAvg,
                      'reviewCount': currentCount + 1,
                      // Rating saved — no need to update isAvailable
                    });
                  });
                  
                  setState(() {
                    _bookingStatus = 'completed';
                  });
                  
                  Navigator.pop(context); 
                  if (screenContext.mounted) {
                    Navigator.pop(screenContext); 
                  }
                },
              )
            ],
          );
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildImage(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.data['modelName'], style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                        Text(widget.data['description'] ?? "No description provided.", style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 20),
                        
                        // OWNER INFO
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10)
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.grey[800],
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              SizedBox(width: 15),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Owner: ${widget.data['ownerName'] ?? 'Student'}", style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text("Phone: ${widget.data['ownerPhone'] ?? 'N/A'}", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  Text("Room: ${widget.data['roomNumber'] ?? 'N/A'}", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              )
                            ],
                          ),
                        ),
                        SizedBox(height: 30),
      
                        // TIME PICKER ROW (Only if NOT booked/started/payment_pending)
                        if (_bookingStatus == 'none') ...[
                           Text("Select Time Slot:", style: TextStyle(fontWeight: FontWeight.bold)),
                           SizedBox(height: 10),
                           Row(
                             children: [
                               Expanded(child: _buildTimeBox("Start", _startTime, () => _selectTime(true))),
                               SizedBox(width: 10),
                               Icon(Icons.arrow_forward, color: Colors.grey),
                               SizedBox(width: 10),
                               Expanded(child: _buildTimeBox("End", _endTime, () => _selectTime(false))),
                             ],
                           ),
                           SizedBox(height: 30),
                        ] else ...[
                           // STATIC BOOKING INFO FOR ACTIVE RIDES
                           Container(
                             padding: EdgeInsets.all(16),
                             decoration: BoxDecoration(
                               color: Color(0xFF1E1E1E), // Slightly distinct background
                               borderRadius: BorderRadius.circular(12),
                               border: Border.all(color: Colors.blueAccent.withOpacity(0.3))
                             ),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(_bookingStatus == 'started' ? "Ride In Progress" : "Booking Details", 
                                     style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                 SizedBox(height: 10),
                                 Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Start Time", style: TextStyle(color: Colors.grey, fontSize: 10)),
                                          Text(DateFormat('MMM d, h:mm a').format(_startTime), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        ],
                                      ),
                                      Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text("Booked Until", style: TextStyle(color: Colors.grey, fontSize: 10)),
                                          Text(DateFormat('MMM d, h:mm a').format(_endTime), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        ],
                                      ),
                                   ],
                                 ),
                                 if (_bookingStatus == 'started' && _rideStartTime != null) ...[
                                    SizedBox(height: 10),
                                    Divider(color: Colors.white12),
                                    SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(Icons.timer, size: 14, color: Colors.green),
                                        SizedBox(width: 5),
                                        Text("Started at: ${DateFormat('hh:mm a').format(_rideStartTime!)}", style: TextStyle(color: Colors.green, fontSize: 12)),
                                      ],
                                    )
                                 ]
                               ],
                             ),
                           ),
                           SizedBox(height: 30),
                        ],
                        
                        // COST DISPLAY
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10)
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Total Estimated Cost", style: TextStyle(color: Colors.grey)),
                              Text("₹${_totalCost.toStringAsFixed(0)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ),
      
                        SizedBox(height: 30),
                        
                        // REVIEWS SECTION
                        _buildReviewsSection(),
      
                        SizedBox(height: 80), // Extra space at bottom for scrolling past button area
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
          
          // FIXED BOTTOM BUTTON CONTAINER
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getButtonColor(),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: _bookingStatus == 'cancelled' ? null : _handleBookingAction,
                    child: Text(
                      _bookingStatus == 'none' ? "BOOK RIDE" :
                      (_bookingStatus == 'booked' ? "START RIDE" : 
                      (_bookingStatus == 'started' ? "END RIDE" : 
                      (_bookingStatus == 'payment_pending' ? "PAY NOW" : 
                      (_bookingStatus == 'cancelled' ? "CANCELLED" : "COMPLETED")))),
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                  ),
                ),
                
                // CANCEL BUTTON (Only if status is 'booked')
                if (_bookingStatus == 'booked') ...[
                  SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: TextButton(
                      onPressed: _handleCancellation,
                      child: Text("Cancel Ride", style: TextStyle(color: Colors.redAccent)),
                    ),
                  ),
                ]
              ],
            ),
          ),
          
          // DISCLAIMER SECTION
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Color(0xFF121212),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Disclaimer & Policy", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                 SizedBox(height: 4),
                 Text("• No-Show: Failure to start ride by end time results in full charge of reserved slot.", style: TextStyle(color: Colors.white38, fontSize: 9)),
                 Text("• Late Returns: Charged at 2x the hourly rate for delays beyond the booked slot.", style: TextStyle(color: Colors.white38, fontSize: 9)),
                 Text("• Liability: Campus Spokes facilitates connections only. We are not responsible for accidents, damages, or disputes.", style: TextStyle(color: Colors.white38, fontSize: 9)),
                 Text("• Disputes: All financial or physical disputes must be resolved directly between Owner and Renter.", style: TextStyle(color: Colors.white38, fontSize: 9)),
                 SizedBox(height: 10), // Buffer for Android Nav Bar
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTimeBox(String label, DateTime time, VoidCallback onTap) {
    // Determine if this time represents "Tomorrow" relative to _startTime
    bool isNextDay = false;
    if (label == "End") {
       if (time.day != _startTime.day || time.month != _startTime.month || time.year != _startTime.year) {
         isNextDay = true;
       }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24)
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
            SizedBox(height: 5),
            Text(DateFormat('h:mm a').format(time), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                DateFormat('MMM d').format(time), 
                style: TextStyle(color: isNextDay ? Colors.redAccent : Colors.grey, fontSize: 10, fontWeight: isNextDay ? FontWeight.bold : FontWeight.normal)
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getButtonColor() {
     if (_bookingStatus == 'none') return Colors.white;
     if (_bookingStatus == 'booked') return Colors.greenAccent;
     if (_bookingStatus == 'started') return Colors.redAccent;
     if (_bookingStatus == 'payment_pending') return Colors.greenAccent;
     return Colors.grey;
  }

  Widget _buildImage() {
     String? imageUrl = widget.data['imageUrl'];
     if (imageUrl == null || imageUrl.isEmpty) {
        return Container(color: Colors.grey[850], child: Icon(Icons.directions_bike, size: 80, color: Colors.white24));
     }

     if (imageUrl.startsWith('http')) {
        return Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[850], child: Icon(Icons.directions_bike, size: 80, color: Colors.white24)));
     }
     
     try {
       return Image.memory(base64Decode(imageUrl), fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[850], child: Icon(Icons.broken_image, size: 80, color: Colors.white24)));
     } catch (e) {
       return Container(color: Colors.grey[850], child: Icon(Icons.error, size: 80, color: Colors.white24));
     }
  }
}