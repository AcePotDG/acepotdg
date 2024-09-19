import 'dart:async';
import 'package:acepotdg/pages/event/event_list.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:acepotdg/api_service.dart';
import 'package:acepotdg/pages/checkin/search_user.dart';

class LeaderboardPage extends StatefulWidget {
  final String eventId;
  final String organizationId;

  const LeaderboardPage({
    super.key, 
    required this.eventId,
    required this.organizationId
  });

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
    print('Organization ID: ' + widget.organizationId);
    print('Event ID: ' + widget.eventId);
    setState(() {
      _isLoading = true;
    });
    try {
      final leaderboardData = await ApiService().fetchEventData(widget.eventId);
      await _updateFirestoreWithLeaderboardData(leaderboardData);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateFirestoreWithLeaderboardData(Map<String, List<dynamic>> leaderboardData) async {
    final collectionRef = _firestore.collection('organizations')
          .doc(widget.organizationId)
          .collection('members');

    try {
      await ApiService().updateUserDatabase(widget.eventId);
    } catch (e) {
      return;
    }

    WriteBatch batch = _firestore.batch();
    bool hasUpdates = false;
    
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
              batch.update(userDoc.reference, {
                'position': playerPosition,
                'positionNo': playerPositionNo,
              });
              hasUpdates = true;
            }
          } catch (e) {
            return;
          }
        }
      }
    }

    QuerySnapshot divisionsSnapshot = await _firestore
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('divisions')
        .get();
        
    for (QueryDocumentSnapshot division in divisionsSnapshot.docs) {
      String? divisionName = division.get('name') as String?;
      QuerySnapshot divisionSnapshot = await _firestore
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('members')
        .where('checkedin', isEqualTo: true)
        .where('division', isEqualTo: divisionName)
        .orderBy('positionNo', descending: false)
        .orderBy('startingTag', descending: false)
        .get();

      List<QueryDocumentSnapshot> players = divisionSnapshot.docs;

      List<QueryDocumentSnapshot> validPlayers = players
        .where((player) {
          final data = player.data() as Map<String, dynamic>?;
          final tag = data?['tag'];
          return int.tryParse(tag.toString()) != 0;
        })
        .toList();

      List<int> tags = validPlayers
        .map((player) {
          final data = player.data() as Map<String, dynamic>?;
          final tag = data?['tag'];
          if (tag == null) {
            return 0;
          }
          return int.tryParse(tag.toString()) ?? 0;
        })
        .where((tag) => tag > 0)
        .toList();
      tags.sort();
      
      for (int i = 0; i < validPlayers.length; i++) {
        DocumentReference playerRef = validPlayers[i].reference;
        int newTag = i < tags.length ? tags[i] : 0;
        batch.update(playerRef, {'tag': newTag});
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      try {
        await batch.commit();
      } catch (e) {
        return;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _refreshLeaderboard() async {
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
                      return child;
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
                    pageBuilder: (context, animation, secondaryAnimation) => CheckinListPage(eventId: widget.eventId, organizationId: widget.organizationId),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return child;
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLeaderboard,
        child: _isLoading ? 
          const Center(
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
                                    .doc(widget.organizationId)
                                    .collection('divisions')
                                    .orderBy('rank', descending: false)
                                    .snapshots(),
          builder: (context, divisionSnapshot) {
            final divisions = divisionSnapshot.data!.docs;
            print('Org ID: ' + widget.organizationId);
            if (!divisionSnapshot.hasData || divisionSnapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No divisions found.'));
            }
            return ListView.builder(
              itemCount: divisions.length,
              itemBuilder: (context, index) {
                var divisionDoc = divisions[index];
                var divisionData = divisionDoc.data() as Map<String, dynamic>;
                final divisionName = divisionData['name'];
                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('organizations')
                      .doc(widget.organizationId)
                      .collection('members')
                      .where('checkedin', isEqualTo: true)
                      .where('division', isEqualTo: divisionName)
                      .orderBy('positionNo', descending: false)
                      .orderBy('startingTag', descending: false)
                      .snapshots(),
                  builder: (context, userSnapshot) {
                    final users = userSnapshot.data?.docs ?? [];
                    if (userSnapshot.hasError) {
                      return const Text('Error occurred');
                    }
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
                          ...users.isEmpty ? 
                          const [ListTile(title: Text('No players checked in'))]
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
                                    child: Center(
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
                                    child: Center(
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