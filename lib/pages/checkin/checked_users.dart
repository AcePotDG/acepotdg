import 'package:acepotdg/pages/checkin/search_user.dart';
import 'package:acepotdg/pages/checkin/user_checkin.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckedUsersPage extends StatefulWidget {
  final String eventId;

  const CheckedUsersPage({super.key, required this.eventId});
  
  @override
  _CheckedUsersPageState createState() => _CheckedUsersPageState();
}

class _CheckedUsersPageState extends State<CheckedUsersPage> {
  String _searchText = "";
  String organizationId = '';

  void _fetchOrganizationId(String eventId) async {
    try {
      DocumentSnapshot eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();

      if (eventDoc.exists) {
        var eventData = eventDoc.data() as Map<String, dynamic>;
        String orgId = eventData['organization'] ?? '';

        setState(() {
          organizationId = orgId;
        });
      }
    } catch (e) {
      print('Error fetching organizationId: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchOrganizationId(widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue.shade400,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "Checked-in Players",
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
                pageBuilder: (context, animation, secondaryAnimation) => CheckinListPage(eventId: widget.eventId),
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
                  .doc(organizationId)
                  .collection("members")
                  .where("checkedin", isEqualTo: true) // Show only checked-in players
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
                  return const Center(child: Text('No checked-in users found.'));
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
    );
  }
}
