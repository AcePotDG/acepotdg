import 'package:acepotdg/pages/checkin/search_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CheckinUserPage extends StatefulWidget {
  final String userId; // Add this line to accept user ID
  final String eventId; // Add this line to accept event ID
  final String organizationId;

  const CheckinUserPage({
    super.key,
    required this.userId,
    required this.eventId,
    required this.organizationId
  });

  @override
  _CheckinUserPageState createState() => _CheckinUserPageState();
}

class _CheckinUserPageState extends State<CheckinUserPage> {
  bool isLoading = true; // For loading user data
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tag = TextEditingController();
  String? _selectedDivision;
  final List<String> _divisions = [];

  @override
  void initState() {
    super.initState();
    _fetchDivisions();
    _loadUserData();
  }

  void _fetchDivisions() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('divisions')
        .get();

    // Modify based on the field you want to fetch (e.g., 'divisionId')
    List<String> divisionsList = snapshot.docs
        .map((doc) => doc['name'] as String)  // Change 'divisionId' to your actual field
        .toList();

    setState(() {
      _divisions.addAll(divisionsList);  // Store fetched divisions (ID or name)
    });

    // Ensure that the division is only set after the divisions have been loaded
    _loadUserData();  // Load user data after fetching divisions
  }

  // Load user data from Firestore
  Future<void> _loadUserData() async {
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('members')
        .doc(widget.userId)
        .get();

    if (userSnapshot.exists) {
      setState(() {
        // Ensure that the selected division matches one of the available divisions
        if (_divisions.contains(userSnapshot['division'])) {
          _selectedDivision = userSnapshot['division'];
        }
        _tag.text = (userSnapshot['tag'] == 0) ? '' : userSnapshot['tag'].toString(); // Handle tag field
        isLoading = false;
      });
    }
  }

  Future<void> _checkinUser() async {
    if (_formKey.currentState?.validate() ?? false) {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('members')
          .doc(widget.userId)
          .update({
        'division': _selectedDivision,
        'tag': _tag.text.isEmpty ? 0 : int.parse(_tag.text), // Convert text to int, default to 0 if empty
        'startingTag': _tag.text.isEmpty ? 0 : int.parse(_tag.text),
        'checkedin': true,
      });

      // Navigate back to the check-in list page after updating
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => CheckinListPage(eventId: widget.eventId, organizationId: widget.organizationId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue.shade400,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          widget.userId,
          style: const TextStyle(
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
                pageBuilder: (context, animation, secondaryAnimation) =>
                    CheckinListPage(eventId: widget.eventId, organizationId: widget.organizationId),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
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
                      value: _selectedDivision, // This value should be among the fetched divisions
                      items: _divisions.map((String division) {
                        return DropdownMenuItem<String>(
                          value: division,
                          child: Text(division),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedDivision = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a division.';
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
                        hintText: 'Select Division',
                        fillColor: Colors.grey[200],
                        filled: true,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: TextFormField(
                      controller: _tag,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.lightBlue.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'Tag',
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
                          _checkinUser();
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
                          'Submit',
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
