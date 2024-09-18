import 'dart:convert';  // Make sure this import is present for jsonDecode
import 'package:http/http.dart' as http;

class ApiService {
  final String getScoreboardData = 'https://us-central1-acepotdg.cloudfunctions.net/getScoreboardData';
  final String getParticipantData = 'https://us-central1-acepotdg.cloudfunctions.net/getParticipantData';
  final String updateUserData = 'https://us-central1-acepotdg.cloudfunctions.net/updateUserDatabase';

  Future<void> updateUserDatabase(String eventId) async {
    try {
      final response = await http.post(
        Uri.parse(updateUserData),
        body: {
          'eventId': eventId,  // Ensure this is being passed
        },
      );

      if (response.statusCode == 200) {
        print('ApiService(updateUserDatabase) User database updated successfully.');
      } else {
        throw Exception('Failed to update user database. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('ApiService(updateUserDatabase) Error updating user database: $e');
      rethrow;
    }
  }

  Future<Map<String, List<dynamic>>> fetchEventData(String eventId) async {
    try {
      final response = await http.get(Uri.parse('$getScoreboardData?eventId=$eventId'));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print('Decoded data: $data');

        if (data is Map<String, dynamic>) {
          return data.map((key, value) {
            if (value is List<dynamic>) {
              // Ensure each item in the list is a Map
              return MapEntry(key, value.map((item) {
                if (item is Map<String, dynamic>) {
                  return item;
                } else {
                  throw Exception('Unexpected item format');
                }
              }).toList());
            } else {
              throw Exception('Unexpected value format for key: $key');
            }
          });
        } else {
          throw Exception('Root data is not a Map');
        }
      } else {
        throw Exception('Failed to load event data');
      }
    } catch (e) {
      print('Error during API call: $e');
      throw Exception('Error during API call: $e');
    }
  }
}
