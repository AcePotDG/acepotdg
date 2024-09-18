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

              batch.update(userDoc.reference, {
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
      String? divisionName = division.get('name') as String?; // Adjust based on your Firestore schema
      print('--------------------');
      print(divisionName);
      print('--------------------');

      if (divisionName == null) {
        print('Division name is null for document: ${division.id}');
        continue; // Skip if the division name is null
      }

      QuerySnapshot divisionSnapshot = await _firestore
        .collection('organizations')
        .doc('houstondiscgolf')
        .collection('members')
        .where('checkedin', isEqualTo: true)
        .where('division', isEqualTo: divisionName)  // Ensure this matches the field used in your database
        .orderBy('positionNo', descending: false)
        .orderBy('startingTag', descending: false)
        .get();

      List<QueryDocumentSnapshot> players = divisionSnapshot.docs;

      // Filter out players with a tag of 0
      List<QueryDocumentSnapshot> validPlayers = players
        .where((player) {
          final data = player.data() as Map<String, dynamic>?; // Safely cast to Map
          final tag = data?['tag'];
          // Check if tag is not 0
          return int.tryParse(tag.toString()) != 0;
        })
        .toList();

      List<int> tags = validPlayers
        .map((player) {
          final data = player.data() as Map<String, dynamic>?; // Safely cast to Map
          final tag = data?['tag'];
          if (tag == null) {
            return 0; // Default to 0 if tag is null
          }
          // Convert tag to an integer
          return int.tryParse(tag.toString()) ?? 0;
        })
        .where((tag) => tag > 0) // Ensure only tags > 0 are included
        .toList();

      // Sort the tags in ascending order
      tags.sort();

      print('Number of valid players retrieved: ${validPlayers.length}');
      for (var player in validPlayers) {
        print('Player ID: ${player.id}');
      }

      print('--------------------');
      print('Pre Batch update call');
      print('--------------------');
      
      WriteBatch batch = _firestore.batch();
      for (int i = 0; i < validPlayers.length; i++) {
        DocumentReference playerRef = validPlayers[i].reference;
        int newTag = i < tags.length ? tags[i] : 0; // Handle case where tags list may be shorter
        print('Player ID: ${validPlayers[i].id} | New tag: $newTag');
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
              icon: const Icon(Icons.person),
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

    // Print division name and document ID for debugging
    print('Division Name: $divisionName, Division Doc ID: ${divisionDoc.id}');

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('organizations')
                        .doc('houstondiscgolf')
                        .collection('members')
                        .where('checkedin', isEqualTo: true)
                        .where('division', isEqualTo: divisionName)  // Use the division name for the query
                        .orderBy('positionNo', descending: false)
                        .orderBy('startingTag', descending: false)
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