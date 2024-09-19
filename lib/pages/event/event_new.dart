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
  String? _selectedOrganization;
  final List<String> _Organizations= [];

  @override
  void initState() {
    super.initState();
    _fetchOrganizations();
  }

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

  // Fetch divisions from Firestore
  void _fetchOrganizations() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('organizations')
        .get();

    List<String> OrganizationList = snapshot.docs
        .map((doc) => doc['name'] as String) // Assuming each document has a 'name' field
        .toList();

    setState(() {
      _Organizations.addAll(OrganizationList);
    });
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedOrganization,
                      items: _Organizations.map((String Organization) {
                        return DropdownMenuItem<String>(
                          value: Organization,
                          child: Text(Organization),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedOrganization = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select an Organization.';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.lightBlue.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'Select Organization',
                        fillColor: Colors.grey[200],
                        filled: true,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: TextFormField(
                      controller: _eventName,
                      validator: (text) {
                        if (text == null || text.isEmpty) {
                          return 'Please enter the event name.';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.lightBlue.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'Event Name',
                        fillColor: Colors.grey[200],
                        filled: true,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: TextFormField(
                      controller: _eventLocation,
                      validator: (text) {
                        if (text == null || text.isEmpty) {
                          return 'Please enter the event location.';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.lightBlue.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'Event Location',
                        fillColor: Colors.grey[200],
                        filled: true,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: TextFormField(
                      controller: _eventDate,
                      validator: (text) {
                        if (text == null || text.isEmpty) {
                          return 'Please enter the event date.';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.lightBlue.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'Event Date',
                        fillColor: Colors.grey[200],
                        filled: true,
                      ),
                      onTap: () => _selectDate(context),
                      readOnly: true,
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: TextFormField(
                      controller: _eventLink,
                      validator: (text) {
                        if (text == null || text.isEmpty) {
                          return 'Please enter the event link.';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.lightBlue.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'Event Link',
                        fillColor: Colors.grey[200],
                        filled: true,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _submitForm();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue.shade400,
                        padding: EdgeInsets.all(20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Create Event',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}