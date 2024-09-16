import 'package:acepotdg/pages/event/event_list.dart';
import 'package:acepotdg/pages/event/leaderboard.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NewEventPage extends StatefulWidget {
  const NewEventPage({super.key});

  @override
  State<NewEventPage> createState() => _NewEventPageState();
}

class _NewEventPageState extends State<NewEventPage> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  final TextEditingController _eventName = TextEditingController();
  final TextEditingController _eventLocation = TextEditingController();
  final TextEditingController _eventDate = TextEditingController();
  final TextEditingController _eventLink = TextEditingController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _eventName.dispose();
    _eventLocation.dispose();
    _eventDate.dispose();
    _eventLink.dispose();
    super.dispose();
  }

  // Calculate the start and end of the current week
  DateTime _getStartOfWeek(DateTime date) {
    final dayOfWeek = date.weekday;
    return date.subtract(Duration(days: dayOfWeek - 1));
  }

  DateTime _getEndOfWeek(DateTime date) {
    final dayOfWeek = date.weekday;
    return date.add(Duration(days: 7 - dayOfWeek));
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime now = DateTime.now();
    DateTime startOfWeek = _getStartOfWeek(now);
    DateTime endOfWeek = _getEndOfWeek(now);

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: startOfWeek,
      lastDate: endOfWeek,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue,
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null && selectedDate != _selectedDate) {
      setState(() {
        _selectedDate = selectedDate;
        _eventDate.text = '${_selectedDate!.toLocal()}'.split(' ')[0]; // Update text field
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      final eventLink = _eventLink.text.trim();

      try {
        // Check if an event with the same link already exists
        final querySnapshot = await FirebaseFirestore.instance
            .collection('events')
            .where('link', isEqualTo: eventLink)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // Event with the same link already exists
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event with this link already exists.')),
          );
        } else {
          // Add new event
          await FirebaseFirestore.instance.collection('events').add({
            'name': _eventName.text.trim(),
            'location': _eventLocation.text.trim(),
            'date': _selectedDate?.toIso8601String() ?? '',
            'link': eventLink,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event added successfully!')),
          );

          // Clear the form
          _eventName.clear();
          _eventLocation.clear();
          _eventDate.clear();
          _eventLink.clear();
          setState(() {
            _selectedDate = null;
          });

          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => LeaderboardPage(eventId: eventLink,), // Pass the event ID
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return child; // No animation
              },
            ),
          );
        }
      } catch (e) {
        print('Error adding event: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add event.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue.shade400,
        centerTitle: true, // Center the title automatically
        automaticallyImplyLeading: false, // Hide the default back button
        title: const Text(
          "New Event",
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
                pageBuilder: (context, animation, secondaryAnimation) => HomePage(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return child; // No animation
                },
              ),
            );
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: OverflowBar(
              overflowSpacing: 20,
              children: [
                TextFormField(
                  controller: _eventName,
                  validator: (text) {
                    if (text == null || text.isEmpty) {
                      return 'Please enter the event name.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: "Event Name",
                  ),
                ),
                TextFormField(
                  controller: _eventLocation,
                  validator: (text) {
                    if (text == null || text.isEmpty) {
                      return 'Please enter the event location.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: "Event Location",
                  ),
                ),
                TextFormField(
                  controller: _eventDate,
                  decoration: InputDecoration(
                    labelText: 'Event Date',
                    hintText: _selectedDate != null
                        ? '${_selectedDate!.toLocal()}'.split(' ')[0]
                        : 'Select a date',
                  ),
                  validator: (value) {
                    if (_selectedDate == null) {
                      return 'Please select a date';
                    }
                    return null;
                  },
                  onTap: () => _selectDate(context),
                  readOnly: true, // Prevent user from typing manually
                ),
                TextFormField(
                  controller: _eventLink,
                  validator: (text) {
                    if (text == null || text.isEmpty) {
                      return 'Please enter the event link.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: "Event Link",
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _submitForm();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: Colors.lightBlue.shade400, // Button text color
                    ),
                    child: isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                    : const Text("Create Event"),
                  ),
                ),
              ],
            ),
          )
        )
      ),
    );
  }
}