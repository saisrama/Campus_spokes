import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for future profile data fetch if needed
import 'login_screen.dart';
import 'my_listings_screen.dart';
import 'ride_history_screen.dart';
import 'payment_history_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_setup_screen.dart';
import 'received_bookings_screen.dart';

class ProfileScreen extends StatelessWidget {
  final User? user = FirebaseAuth.instance.currentUser;

  ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginScreen()), (r) => false);
            },
          )
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: 30),
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(user?.photoURL ?? "https://via.placeholder.com/150"),
            ),
          ),
          SizedBox(height: 10),
          Text(user?.displayName ?? "User", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(user?.email ?? "", style: TextStyle(color: Colors.grey)),
            ],
          ),
          
          SizedBox(height: 40),

          // Menu Items
          ListTile(
            leading: Icon(Icons.edit, color: Colors.purple),
            title: Text("Edit Profile"),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSetupScreen(isEditing: true)));
            },
          ),
          ListTile(
            leading: Icon(Icons.list_alt, color: Colors.blueAccent),
            title: Text("My Listings"),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MyListingsScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.history, color: Colors.white),
            title: Text("Your Rides"),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => RideHistoryScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.bookmark_added, color: Colors.orange),
            title: Text("Received Bookings"),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ReceivedBookingsScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.payment, color: Colors.green), // Changed icon to payment related
            title: Text("Payment History"),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentHistoryScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.support_agent, color: Colors.amber),
            title: Text("File Grievance"),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () async {
               final Uri whatsappUrl = Uri.parse("https://wa.me/917022914482");
               if (await canLaunchUrl(whatsappUrl)) {
                 await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
               } else {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not open WhatsApp")));
               }
            },
          ),
          Divider(color: Colors.grey),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text("Log Out", style: TextStyle(color: Colors.red)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginScreen()), (r) => false);
            },
          ),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text("Made with ❤️ by Sai Sreerama M", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text(
                  "Special thanks to:",
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
                Text(
                  "Athithan V, Bhanuteja Abburi, Pariksheth Malathkar, Praneel S Gandhe, Madhav Praveen, Ram K Musti, Saket M, Sameer Singh, Srijen Raja and Yash Raj",
                  style: TextStyle(color: Colors.grey, fontSize: 9),
                  textAlign: TextAlign.center,
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}