// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'package:acepotdg/pages/event/event_list.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:acepotdg/api_service.dart';
import 'package:acepotdg/pages/checkin/search_user.dart'; // Import the CheckinPage

class LeaderboardPage extends StatefulWidget {
  final String eventId; // Add this line to accept event ID

  const LeaderboardPage({super.key, required this.eventId}); // Constructor to accept event ID

  @override
  _LeaderboardPageState createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _cacheTimer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboardData();
    //_startCacheTimer();
  }

  void _startCacheTimer() {
    _cacheTimer = Timer.periodic(const Duration(minutes: 5), (Timer timer) {
      _fetchLeaderboardData();
    });
  }

  @override
  void dispose() {
    _cacheTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLeaderboardData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final leaderboardData = await ApiService().fetchEventData(widget.eventId);
      setState(() {
        _isLoading = false;
      });

      await _updateFirestoreWithLeaderboardData(leaderboardData);

      print('Leaderboard data fetched and Firestore updated');
    } catch (e) {
      print('Error fetching leaderboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateFirestoreWithLeaderboardData(Map<String, List<dynamic>> leaderboardData) async {
    final collectionRef = _firestore.collection('organizations')
                                    .doc('houstondiscgolf')
                                    .collection('members');

    try {
      await ApiService().updateUserDatabase(widget.eventId);
    } catch (e) {
      print('Leaderboard(_updateFirestoreWithLeaderboardData) Error updating user database: $e');
      return;
    }

    // Create a Firestore batch for bulk updating
    WriteBatch batch = _firestore.batch();
    bool hasUpdates = false; // Track if there are updates to commit

    // Proceed with updating the leaderboard data
    for (var divisionName in leaderboardData.keys) {
      final results = leaderboardData[divisionName];

      if (results != null) {
        for (var playerData in results) {
          final playerName = playerData['name'];
          final playerNameLowercase = playerData['nameLowercase'];
          final playerPosition = playerData['position'];
          final playerPositionNo = playerData['positionNo'];

          try {
            var userQuerySnapshot = await collectionRef
                .where('name', isEqualTo: playerName)
                .limit(1)
                .get();

            if (userQuerySnapshot.docs.isNotEmpty) {
              final userDoc = userQuerySnapshot.docs[0];
              final userId = userDoc.id;

              // TODO: Check if nameLowercase is empty
              batch.update(userDoc.reference, {
                'nameLowercase': playerNameLowercase,
                'position': playerPosition,
                'positionNo': playerPositionNo,
              });
              hasUpdates = true;

              print('Queued update for userId $userId with position $playerPosition');
            } else {
              print('No matching user found in Firestore for player name: $playerName');
            }
          } catch (e) {
            print('Error querying Firestore for player name $playerName: $e');
          }
        }
      } else {
        print('No results for division: $divisionName');
      }
    }

    QuerySnapshot divisionsSnapshot = await _firestore
        .collection('organizations')
        .doc('houstondiscgolf')
        .collection('divisions')
        .get();
        
    for (QueryDocumentSnapshot division in divisionsSnapshot.docs) {
      // Extract division name or value
      String? divisionName = division.get('name') as String?; // Adjust based on your Firestore schema
      print(divisionName);

      if (divisionName == null) {
        print('Division name is null for document: ${division.id}');
        continue; // Skip if the division name is null
      }

      print('--------------------');
      QuerySnapshot divisionSnapshot = await _firestore
        .collection('organizations')
        .doc('houstondiscgolf')
        .collection('members')
        .where('division', isEqualTo: division.id)
        .where('checkedin', isEqualTo: true)
        .orderBy('positionNo', descending: false)
        .get();

      print('Query snapshot size: ${divisionSnapshot.size}');

      List<QueryDocumentSnapshot> players = divisionSnapshot.docs;

      print('Number of players retrieved: ${players.length}');
      for (var player in players) {
        print('Player ID: ${player.id}');
        print('Player Data: ${player.data()}');
      }

      List<int> tags = players
        .map((player) {
          final data = player.data() as Map<String, dynamic>?; // Safely cast to Map
          final tag = data?['tag'];
          print('Raw Tag Data: $tag');
          if (tag == null) {
            print('Tag is null for player ${player.id}');
            return 0; // Default to 0 if tag is null
          }
          // Attempt to convert tag to an integer
          return int.tryParse(tag.toString()) ?? 0;
        })
        .toList();

      print('Tags:');
      for (int tag in tags) {
        print(tag);
      }

      print('--------------------');
      print('Pre Batch update call');
      print('--------------------');
      
      WriteBatch batch = _firestore.batch();
      for (int i = 0; i < players.length; i++) {
        DocumentReference playerRef = players[i].reference;
        int newTag = i < tags.length ? tags[i] : 0; // Handle case where tags list may be shorter
        print('Batch update for tag: $newTag completed successfully.');
        batch.update(playerRef, {'tag': newTag});
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      try {
        await batch.commit();
        print('Batch update completed successfully.');
      } catch (e) {
        print('Error committing batch update: $e');
      }
    } else {
      print('No updates to commit.');
    }
  }

  Future<void> _refreshLeaderboard() async {
    print('Refreshing leaderboard...');
    await _fetchLeaderboardData();
  }

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
                    pageBuilder: (context, animation, secondaryAnimation) => HomePage(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return child; // No animation
                    },
                  ),
                );
              },
            ),
            const Text(
              "Leaderboard",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            IconButton(
              icon: const Icon(Icons.add),
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
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLeaderboard, // Use _refreshLeaderboard to refresh data
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Loading scoreboard data..."),
                  ],
                ),
              )
            : StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('organizations')
                                  .doc('houstondiscgolf')
                                  .collection('divisions')
                                  .orderBy('rank', descending: false)
                                  .snapshots(),
                builder: (context, divisionSnapshot) {
                  if (divisionSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!divisionSnapshot.hasData || divisionSnapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No divisions found.'));
                  }

                  final divisions = divisionSnapshot.data!.docs;

                  return ListView.builder(
                    itemCount: divisions.length,
                    itemBuilder: (context, index) {
                      var divisionDoc = divisions[index];
                      var divisionData = divisionDoc.data() as Map<String, dynamic>;
                      final divisionName = divisionData['name'];

                      return StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collection('organizations')
                                          .doc('houstondiscgolf')
                                          .collection('members')
                                          .where('checkedin', isEqualTo: true)
                                          .where('division', isEqualTo: divisionDoc.id)
                                          .orderBy('positionNo', descending: false)
                                          .snapshots(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.hasError) {
                            print("Error: ${userSnapshot.error}");
                            return const Text('Error occurred');
                          }

                          final documents = userSnapshot.data?.docs;
                          // Print documents for debugging
                          documents?.forEach((doc) {
                            print(doc.data()); // Log each document
                          });

                          final users = userSnapshot.data?.docs ?? [];
                          return Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: Text(divisionName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              initiallyExpanded: true,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        flex: 15,
                                        child: Text(
                                          'POS',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 70,
                                        child: Text(
                                          'NAME',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 15,
                                        child: Text(
                                          'TAG',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...users.isEmpty
                                    ? const [ListTile(title: Text('No players checked in'))]
                                    : users.map((userDoc) {
                                        var userData = userDoc.data() as Map<String, dynamic>;
                                        final name = userData['name'] ?? 'Unknown';
                                        final tag = userData['tag'] ?? 0; // Retrieve the tag
                                        final position = userData['position'] ?? 'N/A';

                                        return ListTile(
                                          title: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                flex: 15,
                                                child: Center(  // Center the position text
                                                  child: Text(
                                                    '$position', 
                                                    style: const TextStyle(fontSize: 16),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 70,
                                                child: Text(name, style: const TextStyle(fontSize: 16)),
                                              ),
                                              Expanded(
                                                flex: 15,
                                                child: Center(  // Center the tag text
                                                  child: Text(
                                                    tag != 0 ? '$tag' : 'X',
                                                    style: const TextStyle(fontSize: 16),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}