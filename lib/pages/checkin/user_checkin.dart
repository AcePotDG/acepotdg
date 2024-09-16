import 'package:acepotdg/pages/checkin/search_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CheckinUserPage extends StatefulWidget {
  final String userId; // Add this line to accept user ID
  final String eventId; // Add this line to accept event ID

  const CheckinUserPage({
    super.key,
    required this.userId,
    required this.eventId,
  });

  @override
  _CheckinUserPageState createState() => _CheckinUserPageState();
}

class _CheckinUserPageState extends State<CheckinUserPage> {
  String? selectedDivision; // For storing selected division
  int tag = 0; // For the tag text box
  bool isLoading = true; // For loading user data
  final _formKey = GlobalKey<FormState>();
  
  @override
  void initState() {
    super.initState();
    // Fetch initial user data here
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('organizations')
        .doc('houstondiscgolf')
        .collection('members')
        .doc(widget.userId)
        .get();

    if (userSnapshot.exists) {
      setState(() {
        selectedDivision = userSnapshot['division']; // Load division
        tag = userSnapshot['tag']; // Load tag
        isLoading = false;
      });
    }
    print(isLoading);
  }

  Future<void> _checkinUser() async {
    if (_formKey.currentState?.validate() ?? false) {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc('houstondiscgolf')
          .collection('members')
          .doc(widget.userId)
          .update({
        'division': selectedDivision,
        'tag': tag,
        'startingTag': tag,
        'checkedin': true,
      });

      // Navigate back to the check-in list page after updating
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => CheckinListPage(eventId: widget.eventId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue.shade400,
        centerTitle: true, // Center the title automatically
        automaticallyImplyLeading: false, // Hide the default back button
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
                pageBuilder: (context, animation, secondaryAnimation) => CheckinListPage(eventId: widget.eventId,),
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
            child: Column(
              children: [
                // Division Dropdown with Validation
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('organizations')
                      .doc('houstondiscgolf')
                      .collection('divisions')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    var divisions = snapshot.data!.docs;

                    // Ensure the selected division exists in the fetched divisions
                    if (selectedDivision != null &&
                        !divisions.any((division) => division.id == selectedDivision)) {
                      selectedDivision = null; // Reset if the current selection is invalid
                    }

                    return DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedDivision,
                      hint: const Text('Select Division'),
                      decoration: const InputDecoration(
                        errorText: null, // Add an error text if validation fails
                      ),
                      items: divisions.map((division) {
                        return DropdownMenuItem<String>(
                          value: division.id,
                          child: Text(division['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedDivision = value!;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a division'; // Validation error message
                        }
                        return null;
                      },
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(labelText: "Tag"),
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  onChanged: (value) {
                    setState(() {
                      tag = int.tryParse(value) ?? 0;
                    });
                  },
                ),
                
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _checkinUser();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.lightBlue.shade400, // Button text color
                    ),
                    child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                      : const Text("Check In Player"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
