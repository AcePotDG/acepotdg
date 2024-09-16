import 'package:acepotdg/api_service.dart';
import 'package:acepotdg/pages/checkin/user_checkin.dart';
import 'package:acepotdg/pages/event/leaderboard.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckinListPage extends StatefulWidget {
  final String eventId; // Add this line to accept event ID

  const CheckinListPage({super.key, required this.eventId}); // Constructor to accept event ID
  
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
        centerTitle: true, // Center the title automatically
        automaticallyImplyLeading: false, // Hide the default back button
        title: const Text(
          "Checkin Player",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => LeaderboardPage(eventId: widget.eventId,),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return child; // No animation
                },
              ),
            );
          },
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
                  .where("checkedin", isEqualTo: false) // Ensure this matches the index field
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
            )
          ),
        ],
      ),
    );
  }

  void _checkUserOnLeaderboard(QueryDocumentSnapshot user) async {
    // This function is not used, you can either remove it or integrate it where needed
    String userName = user["name"];
    final leaderboardData = await ApiService().fetchEventData(widget.eventId); // Fetch leaderboard

    bool found = false;
    leaderboardData.forEach((division, results) {
      for (var result in results) {
        if (result['name'] == userName) {
          found = true;
          // Add position and division to Firestore
          FirebaseFirestore.instance
              .collection("organizations")
              .doc("houstondiscgolf")
              .collection("members")
              .doc(user.id) // Use userId
              .update({
            "division": division,
            "position": result['position'],
          });
        }
      }
    });

    if (found) {
      print("$userName checked in and found on leaderboard.");
    } else {
      print("$userName not found on leaderboard.");
    }
  }
}
