import 'package:acepotdg/pages/auth/auth.dart';
import 'package:acepotdg/pages/event/leaderboard.dart';
import 'package:acepotdg/pages/event/event_new.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  Future<void> _deleteEvent(BuildContext context, String eventId, String eventName) async {
    try {
      DocumentSnapshot eventDoc = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .get();

      var eventData = eventDoc.data() as Map<String, dynamic>;
      String organizationId = eventData['organization'] ?? '';

      // Query users with `checkedin: true` for this organization
      var usersSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationId) // Use organizationId here
          .collection('members')
          .where('checkedin', isEqualTo: true)
          .get();

      // Update each checked-in user, setting `checkedin` to `false`
      for (var userDoc in usersSnapshot.docs) {
        await userDoc.reference.update({
          'checkedin': false,
          'position': "",
          'positionNo': 0,
          'tag': 0
        });
      }

      // Now, delete the event
      await FirebaseFirestore.instance.collection('events').doc(eventId).delete();

      // Show a confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$eventName deleted')),
      );
    } catch (e) {
      // Handle any errors that might occur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete $eventName: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue.shade400,
        centerTitle: true,
        automaticallyImplyLeading: false, // Hide the back button
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left button
            IconButton(
              icon: const Icon(Icons.add), // Your desired icon
              color: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const NewEventPage(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return child; // No animation
                    },
                  ),
                );
              },
            ),
            // Center title
            const Text(
              "Events",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
            // Right button
            IconButton(
              icon: const Icon(Icons.logout),
              color: Colors.white,
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const AuthPage(),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('events')
          .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No events found.'));
          }

          final events = snapshot.data!.docs;

          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final eventId = event.id; // Get event document ID for deletion
              final organizationId = event['organization'] ?? 'No Organization';
              final eventName = event['name'] ?? 'No name';
              final eventLocation = event['location'] ?? 'No location';
              final eventDate = event['date'] != null
                  ? DateTime.parse(event['date']).toLocal()
                  : null;
              final eventLink = event['link'] ?? 'No link';

              return Dismissible(
                key: Key(eventId),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  // Show confirmation dialog before deletion
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Delete $eventName?'),
                        content: const Text('Are you sure you want to delete this event and reset all checked-in users?'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) async {
                  // Call the delete event function after confirmation
                  await _deleteEvent(context, eventId, eventName);
                },
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LeaderboardPage(eventId: eventId, organizationId: organizationId),
                      ),
                    );
                  },
                  child: ListTile(
                    title: Text(eventName),
                    subtitle: Text(
                      'Location: $eventLocation\n'
                      'Date: ${eventDate != null ? '${eventDate.toLocal()}'.split(' ')[0] : 'No date'}\n'
                      'Link: $eventLink',
                    ),
                    isThreeLine: true,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
