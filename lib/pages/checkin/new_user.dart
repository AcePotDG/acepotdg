import 'package:acepotdg/pages/checkin/search_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NewUserPage extends StatefulWidget {
  final String eventId; // Add this line to accept event ID
  final String organizationId;

  const NewUserPage({
    super.key,
    required this.eventId,
    required this.organizationId
  });

  @override
  _NewUserPageState createState() => _NewUserPageState();
}

class _NewUserPageState extends State<NewUserPage> {
  String? selectedDivision; // For storing selected division
  int tag = 0; // For the tag text box
  bool isLoading = true; // For loading user data
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _udiscid = TextEditingController();
  final TextEditingController _tag = TextEditingController();
  String? _selectedDivision;
  final List<String> _divisions = [];
  
  @override
  void initState() {
    super.initState();
    _fetchDivisions();
  }

  addNewUserToOrg() async {
    try {
      // Create a new entry in the Firestore "users" collection
      await FirebaseFirestore.instance.collection('users').doc(_udiscid.text).set({
        'division': _selectedDivision, // Save the email to the Firestore database
        'tag': _tag,
        //'udiscname': _udiscname.text, // Ensure you use .text to get the value from the controller
        // Add any additional fields you want here, e.g., name, role, etc.
      });

      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              CheckinListPage(eventId: widget.eventId,organizationId: widget.organizationId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return child; // No animation
          },
        ),
      );
      
      print("User registered and added to Firestore successfully.");
      // Optionally navigate to another page or show a success message
    } catch (e) {
      print("Error registering user: $e");
      // Optionally show an error message
    }
  }

  // Fetch divisions from Firestore
  void _fetchDivisions() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('divisions')
        .get();

    List<String> divisionsList = snapshot.docs
        .map((doc) => doc['name'] as String) // Assuming each document has a 'name' field
        .toList();

    setState(() {
      _divisions.addAll(divisionsList);
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
          "Create New Player",
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
                pageBuilder: (context, animation, secondaryAnimation) => CheckinListPage(eventId: widget.eventId,organizationId: widget.organizationId),
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
                  SizedBox(height: 20), // Add spacing below the logo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: TextFormField(
                      controller: _udiscid,
                      validator: (text) {
                        if (text == null || text.isEmpty) {
                          return 'Please enter a valid UDisc ID.';
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
                        hintText: 'UDisc ID',
                        fillColor: Colors.grey[200],
                        filled: true,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedDivision,
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
                      validator: (text) {
                        if (text == null || text.isEmpty) {
                          return 'Please enter the players tag.';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly, // Allow only digits
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
                          addNewUserToOrg();
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
