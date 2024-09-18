import 'package:acepotdg/pages/checkin/checked_users.dart';
import 'package:acepotdg/pages/checkin/new_user.dart';
import 'package:acepotdg/pages/checkin/user_checkin.dart';
import 'package:acepotdg/pages/event/event_list.dart';
import 'package:acepotdg/pages/event/leaderboard.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckinListPage extends StatefulWidget {
  final String eventId;

  const CheckinListPage({super.key, required this.eventId});
  
  @override
  _CheckinListPageState createState() => _CheckinListPageState();
}

class _CheckinListPageState extends State<CheckinListPage> {
  String _searchText = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue.shade400,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              color: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => LeaderboardPage(eventId: widget.eventId),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return child; // No animation
                    },
                  ),
                );
              },
            ),
            const Text(
              "Check-in Players",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            IconButton(
              icon: const Icon(Icons.list),
              color: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => CheckedUsersPage(eventId: widget.eventId),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return child; // No animation
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Search by Name",
              ),
              onChanged: (text) {
                setState(() {
                  _searchText = text.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("organizations")
                  .doc("houstondiscgolf")
                  .collection("members")
                  .where("checkedin", isEqualTo: false)
                  .where("nameLowercase", isGreaterThanOrEqualTo: _searchText)
                  .where("nameLowercase", isLessThanOrEqualTo: '$_searchText\uf8ff')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print('Error fetching data: ${snapshot.error}');
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No users found.'));
                }

                var users = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var user = users[index];
                    return ListTile(
                      title: Text(user["name"]),
                      onTap: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => CheckinUserPage(
                              userId: user.id,
                              eventId: widget.eventId,
                            ),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return child; // No animation
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to the new user creation page
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NewUserPage(eventId: widget.eventId), // Adjust with your page
            ),
          );
        },
        backgroundColor: Colors.lightBlue.shade400,
        icon: const Icon(Icons.add, color: Colors.white), // Plus sign
        label: const Text(
          'New',
          style: TextStyle(color: Colors.white), // Text "New"
        ),
      ),
    );
  }
}
