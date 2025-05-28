import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/patient.dart';

const String _prefsKeyAuthToken = 'authToken';

class DHIS2Service {
  final String baseUrl = 'https://project.ccdev.org/ictprojects/api';
  String _lastErrorMessage = '';

  String get lastErrorMessage => _lastErrorMessage;

  // DHIS2 program IDs and attributes
  static const String programId = DHIS2Constants.programId;
  static const String trackedEntityTypeId = DHIS2Constants.trackedEntityTypeId;

  // Tracked Entity Attribute IDs
  static const String attrPatientId = DHIS2Constants.attrPatientId;
  static const String attrFirstName = DHIS2Constants.attrFirstName;
  static const String attrLastName = DHIS2Constants.attrLastName;
  static const String attrPhoneNumber = DHIS2Constants.attrPhoneNumber;
  static const String attrGender = DHIS2Constants.attrGender;
  static const String attrTemperaturesTEI = DHIS2Constants.attrTemperaturesTEI;
  static const String attrPhysicalAddress = DHIS2Constants.attrPhysicalAddress;

  // Program Stage and Data Element for Temperature Events
  static const String programStageIdForTemperatureEvent =
      DHIS2Constants.programStageIdForTemperatureEvent;
  static const String dataElementIdForTemperatureInEvent =
      DHIS2Constants.dataElementIdForTemperatureInEvent;

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefsKeyAuthToken);
    if (token == null || token.isEmpty) {
      _lastErrorMessage = 'Authentication token not found. Please log in.';
      return null;
    }
    return token;
  }

  Future<bool> testConnection(String username, String password) async {
    _lastErrorMessage = '';
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/me'),
            headers: {
              'Authorization':
                  'Basic ${base64Encode(utf8.encode('$username:$password'))}',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      } else {
        _lastErrorMessage =
            'Connection test failed with status ${response.statusCode}.';
        return false;
      }
    } catch (e) {
      _lastErrorMessage = 'Connection error during test: $e';
      return false;
    }
  }

  /// Get all available regions (top-level organization units)
  Future<List<Map<String, dynamic>>> getRegions() async {
    _lastErrorMessage = '';

    final String? authToken = await _getAuthToken();
    if (authToken == null) return [];

    try {
      // Get top-level organization units (regions)
      final String fields = 'id,name,level';
      final Uri requestUrl = Uri.parse(
        '$baseUrl/organisationUnits?fields=$fields&filter=level:eq:1&paging=false',
      );

      final response = await http
          .get(
            requestUrl,
            headers: {
              'Authorization': authToken,
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (kDebugMode) {
          print('Regions response: $data');
        }
        if (data['organisationUnits'] != null &&
            data['organisationUnits'] is List) {
          return List<Map<String, dynamic>>.from(
            (data['organisationUnits'] as List).map(
              (region) => {
                'id': region['id'],
                'name': region['name'],
                'level': region['level'],
                'isRegion': true,
              },
            ),
          );
        } else {
          _lastErrorMessage = 'No regions found in the response.';
          return [];
        }
      } else {
        _lastErrorMessage =
            'Failed to fetch regions: ${response.statusCode} - ${response.body}';
        return [];
      }
    } catch (e) {
      _lastErrorMessage = 'Error fetching regions: $e';
      return [];
    }
  }

  /// Get organization units, optionally filtered by region
  Future<List<Map<String, dynamic>>> getOrganizationUnits({
    String? regionId,
  }) async {
    _lastErrorMessage = '';

    final String? authToken = await _getAuthToken();
    if (authToken == null) return [];

    try {
      final String fields = 'id,name,level,parent[id,name]';
      String url =
          '$baseUrl/programs/$programId/organisationUnits?fields=$fields&paging=false';

      // If regionId is provided, filter organizations by the region
      if (regionId != null && regionId.isNotEmpty) {
        url =
            '$baseUrl/organisationUnits/$regionId/children?fields=$fields&paging=false';
      }

      final Uri requestUrl = Uri.parse(url);

      final response = await http
          .get(
            requestUrl,
            headers: {
              'Authorization': authToken,
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (kDebugMode) {
          print('==== ORGANIZATION UNITS API RESPONSE ====');
          print('URL: $url');
          print('Response status: ${response.statusCode}');
          print(
            'Organization units count: ${data['organisationUnits']?.length ?? 0}',
          );
          print('First few organizations:');
          if ((data['organisationUnits'] as List?)?.isNotEmpty ?? false) {
            for (var i = 0; i < min(5, data['organisationUnits'].length); i++) {
              print(
                '  ${i + 1}. ${data['organisationUnits'][i]['name']} (ID: ${data['organisationUnits'][i]['id']}, Level: ${data['organisationUnits'][i]['level']})',
              );
              print(
                '     Parent: ${data['organisationUnits'][i]['parent'] != null ? '${data['organisationUnits'][i]['parent']['name']} (ID: ${data['organisationUnits'][i]['parent']['id']})' : 'None'}',
              );
            }
          } else {
            print('  No organizations found in response');
          }
          print('=======================================');
        }

        // The response structure is different depending on the endpoint
        List<dynamic> orgUnits;
        if (regionId != null && regionId.isNotEmpty) {
          // When fetching children of a region
          orgUnits = data['organisationUnits'] ?? [];
        } else {
          // When fetching from program endpoint
          orgUnits = data['organisationUnits'] ?? [];
        }

        if (orgUnits.isNotEmpty) {
          return List<Map<String, dynamic>>.from(
            orgUnits.map(
              (orgUnit) => {
                'id': orgUnit['id'],
                'name': orgUnit['name'],
                'level': orgUnit['level'],
                'parent':
                    orgUnit['parent'] != null
                        ? {
                          'id': orgUnit['parent']['id'],
                          'name': orgUnit['parent']['name'],
                        }
                        : null,
              },
            ),
          );
        } else {
          _lastErrorMessage = 'No organisation units found in the response.';
          return [];
        }
      } else {
        _lastErrorMessage =
            'Failed to fetch organization units: ${response.statusCode} - ${response.body}';
        return [];
      }
    } catch (e) {
      _lastErrorMessage = 'Error fetching organization units: $e';
      return [];
    }
  }

  /// Fetches patients (tracked entity instances) from DHIS2
  /// Returns a list of patients with their attributes
  Future<List<Map<String, dynamic>>> getPatients({
    String? searchText,
    required String orgUnitId,
  }) async {
    _lastErrorMessage = '';

    final String? authToken = await _getAuthToken();
    if (authToken == null) return [];

    try {
      // Build the URL for fetching tracked entity instances
      // Include the organization unit ID that the user has selected
      String url =
          '$baseUrl/trackedEntityInstances?program=$programId&ou=$orgUnitId&ouMode=DESCENDANTS';

      // Add search parameters if provided
      if (searchText != null && searchText.isNotEmpty) {
        // Search by name (first name or last name)
        url += '&filter=$attrFirstName:like:$searchText';
      }

      // Add fields to include in the response
      url +=
          '&fields=trackedEntityInstance,orgUnit,attributes[attribute,value],enrollments[enrollment,program,orgUnit,orgUnitName,enrollmentDate,status]';

      if (kDebugMode) {
        print('Fetching patients with URL: $url');
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': authToken,
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (kDebugMode) {
          print(
            'Patient data response: ${data.toString().substring(0, min(200, data.toString().length))}...',
          );
        }

        if (data['trackedEntityInstances'] != null &&
            data['trackedEntityInstances'] is List) {
          // Transform the response into a more usable format
          return _transformPatientData(data['trackedEntityInstances'] as List);
        }

        _lastErrorMessage = 'No patients found in the response.';
        return [];
      } else {
        _lastErrorMessage =
            'Failed to fetch patients: ${response.statusCode} - ${response.body}';
        if (kDebugMode) {
          print(
            'Failed to fetch patients: ${response.statusCode} - ${response.body}',
          );
        }
        return [];
      }
    } catch (e) {
      _lastErrorMessage = 'Error fetching patients: $e';
      if (kDebugMode) {
        print('Error fetching patients: $e');
      }
      return [];
    }
  }

  /// Transforms the raw patient data from DHIS2 into a more usable format
  List<Map<String, dynamic>> _transformPatientData(List rawData) {
    final List<Map<String, dynamic>> patients = [];

    for (var tei in rawData) {
      final Map<String, dynamic> patient = {
        'id': tei['trackedEntityInstance'],
        'orgUnit': tei['orgUnit'],
        'orgUnitName': '', // Will be populated if available
        'attributes': <String, String>{},
      };

      // Extract organization name if available
      if (tei['enrollments'] != null &&
          tei['enrollments'] is List &&
          tei['enrollments'].isNotEmpty) {
        // Try to get org unit name from enrollments
        for (var enrollment in tei['enrollments']) {
          if (enrollment['orgUnitName'] != null) {
            patient['orgUnitName'] = enrollment['orgUnitName'];
            break;
          }
        }
      }

      // Extract attributes
      if (tei['attributes'] != null && tei['attributes'] is List) {
        for (var attr in tei['attributes']) {
          final String attributeId = attr['attribute'];
          final String value = attr['value'];

          // Map attribute IDs to more readable names
          if (attributeId == attrFirstName) {
            patient['attributes']['firstName'] = value;
          } else if (attributeId == attrLastName) {
            patient['attributes']['lastName'] = value;
          } else if (attributeId == attrGender) {
            patient['attributes']['gender'] = value;
          } else if (attributeId == attrPhoneNumber) {
            patient['attributes']['phone'] = value;
          } else if (attributeId == attrTemperaturesTEI) {
            patient['attributes']['temperature'] = value;
          } else if (attributeId == attrPhysicalAddress) {
            patient['attributes']['address'] = value;
          } else if (attributeId == attrPatientId) {
            patient['attributes']['patientId'] = value;
          } else {
            // Store other attributes with their IDs
            patient['attributes'][attributeId] = value;
          }
        }
      }

      // Add display name for convenience
      final String firstName = patient['attributes']['firstName'] ?? '';
      final String lastName = patient['attributes']['lastName'] ?? '';
      patient['displayName'] = '$firstName $lastName'.trim();

      patients.add(patient);
    }

    return patients;
  }

  /// Fetches temperature history for a patient
  /// Returns a list of temperature readings with dates
  Future<List<Map<String, dynamic>>> getPatientTemperatureHistory(
    String patientId,
  ) async {
    _lastErrorMessage = '';

    final String? authToken = await _getAuthToken();
    if (authToken == null) return [];

    try {
      // Build the URL for fetching events for this patient
      String url =
          '$baseUrl/events?trackedEntityInstance=$patientId&program=$programId&programStage=$programStageIdForTemperatureEvent';

      // Add fields to include in the response
      url += '&fields=eventDate,dataValues[dataElement,value]';

      if (kDebugMode) {
        print('Fetching temperature history with URL: $url');
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': authToken,
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['events'] != null && data['events'] is List) {
          List<Map<String, dynamic>> temperatureReadings = [];

          for (var event in data['events']) {
            String? eventDate = event['eventDate'];
            double? temperature;

            // Extract temperature value from data values
            if (event['dataValues'] != null && event['dataValues'] is List) {
              for (var dataValue in event['dataValues']) {
                if (dataValue['dataElement'] ==
                    dataElementIdForTemperatureInEvent) {
                  temperature = double.tryParse(dataValue['value']);
                  break;
                }
              }
            }

            if (eventDate != null && temperature != null) {
              temperatureReadings.add({
                'date': eventDate,
                'temperature': temperature,
              });
            }
          }

          // Sort by date (newest first)
          temperatureReadings.sort((a, b) => b['date'].compareTo(a['date']));

          return temperatureReadings;
        }
      } else {
        _lastErrorMessage =
            'Failed to fetch temperature history: ${response.statusCode} - ${response.body}';
        if (kDebugMode) {
          print(
            'Failed to fetch temperature history: ${response.statusCode} - ${response.body}',
          );
        }
      }
    } catch (e) {
      _lastErrorMessage = 'Error fetching temperature history: $e';
      if (kDebugMode) {
        print('Error fetching temperature history: $e');
      }
    }

    return [];
  }

  /// Fetches temperature history for multiple patients
  /// Returns a map with patient IDs as keys and temperature readings as values
  Future<Map<String, List<Map<String, dynamic>>>>
  getMultiplePatientTemperatureHistory(List<String> patientIds) async {
    Map<String, List<Map<String, dynamic>>> result = {};

    for (String patientId in patientIds) {
      result[patientId] = await getPatientTemperatureHistory(patientId);
    }

    return result;
  }

  /// Updates an existing patient in DHIS2
  /// Returns true if the update was successful
  Future<bool> updatePatient(Patient patient, String authToken) async {
    _lastErrorMessage = '';

    if (patient.trackedEntityInstanceId.isEmpty) {
      _lastErrorMessage =
          'Cannot update patient: Missing tracked entity instance ID';
      return false;
    }

    try {
      // Build attributes for update
      final attributes = _buildPatientAttributes(patient);

      // Create payload for update
      final updatePayload = {
        'trackedEntityType': trackedEntityTypeId,
        'orgUnit': patient.organizationUnit,
        'attributes': attributes,
      };

      // Send update request
      final updateUrl =
          '$baseUrl/trackedEntityInstances/${patient.trackedEntityInstanceId}';

      if (kDebugMode) {
        print('Updating patient with URL: $updateUrl');
        print('Update payload: ${json.encode(updatePayload)}');
      }

      final updateResponse = await http
          .put(
            Uri.parse(updateUrl),
            headers: {
              'Authorization': authToken,
              'Content-Type': 'application/json',
            },
            body: json.encode(updatePayload),
          )
          .timeout(const Duration(seconds: 20));

      if (updateResponse.statusCode >= 200 && updateResponse.statusCode < 300) {
        if (kDebugMode) {
          print('Patient update successful: ${updateResponse.body}');
        }

        // Create temperature event if temperature is provided
        if (patient.temperature > 0) {
          await _createTemperatureEvent(
            patient.trackedEntityInstanceId,
            patient.organizationUnit,
            patient.temperature.toString(),
            authToken,
          );
        }

        return true;
      } else {
        _lastErrorMessage =
            'Failed to update patient: ${updateResponse.statusCode} - ${updateResponse.body}';
        if (kDebugMode) {
          print(_lastErrorMessage);
        }
        return false;
      }
    } catch (e) {
      _lastErrorMessage = 'Error updating patient: $e';
      if (kDebugMode) {
        print(_lastErrorMessage);
      }
      return false;
    }
  }

  /// Builds the attributes list for patient registration or update
  List<Map<String, dynamic>> _buildPatientAttributes(Patient patient) {
    final List<Map<String, dynamic>> attributes = [
      {'attribute': attrFirstName, 'value': patient.firstName},
      {'attribute': attrLastName, 'value': patient.lastName},
      {
        'attribute': attrGender,
        'value': patient.gender,
      }, // Assumes "Male", "Female" etc. are accepted.
      // Check DHIS2 if specific codes are needed for an option set.
      {
        'attribute': attrTemperaturesTEI,
        'value': patient.temperature.toString(),
      }, // Temp on TEI
    ];

    if (patient.telephone.isNotEmpty) {
      attributes.add({
        'attribute': attrPhoneNumber,
        'value': patient.telephone,
      });
    }
    if (patient.address.isNotEmpty) {
      attributes.add({
        'attribute': attrPhysicalAddress,
        'value': patient.address,
      });
    }

    // Add patient ID if available
    if (patient.patientId.isNotEmpty) {
      attributes.add({'attribute': attrPatientId, 'value': patient.patientId});
    }

    return attributes;
  }

  Future<bool> registerPatient(Patient patient, String authToken) async {
    _lastErrorMessage = '';
    String? newTrackedEntityInstanceId;

    // --- 1. Create Tracked Entity Instance (Patient) & Enroll ---
    try {
      final attributes = _buildPatientAttributes(patient);

      final teiPayload = {
        'trackedEntityType': trackedEntityTypeId,
        'orgUnit': patient.organizationUnit,
        'attributes': attributes,
        'enrollments': [
          {
            'program': programId,
            'orgUnit': patient.organizationUnit,
            'enrollmentDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'incidentDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          },
        ],
      };

      final teiResponse = await http
          .post(
            Uri.parse(
              '$baseUrl/trackedEntityInstances?strategy=CREATE_AND_UPDATE',
            ),
            headers: {
              'Authorization': authToken,
              'Content-Type': 'application/json',
            },
            body: json.encode(teiPayload),
          )
          .timeout(const Duration(seconds: 20));

      if (teiResponse.statusCode == 200 || teiResponse.statusCode == 201) {
        final responseBody = json.decode(teiResponse.body);
        if (kDebugMode) {
          print('TEI Response body: $responseBody');
        }

        // Extract TEI ID - handle different response formats
        if (responseBody['status'] == 'SUCCESS' &&
            responseBody['response'] != null &&
            responseBody['response']['reference'] != null) {
          // Format 1: Direct reference in response
          newTrackedEntityInstanceId = responseBody['response']['reference'];
        } else if (responseBody['importSummaries'] != null &&
            (responseBody['importSummaries'] as List).isNotEmpty &&
            responseBody['importSummaries'][0]['reference'] != null) {
          // Format 2: Reference in importSummaries
          newTrackedEntityInstanceId =
              responseBody['importSummaries'][0]['reference'];
        } else if (responseBody['response'] != null &&
            responseBody['response']['importSummaries'] != null &&
            (responseBody['response']['importSummaries'] as List).isNotEmpty) {
          // Format 3: Try to extract from nested importSummaries
          final importSummaries =
              responseBody['response']['importSummaries'] as List;
          if (importSummaries.isNotEmpty &&
              importSummaries[0]['reference'] != null) {
            newTrackedEntityInstanceId = importSummaries[0]['reference'];
          } else if (importSummaries.isNotEmpty &&
              importSummaries[0]['href'] != null) {
            // Format 4: Extract ID from href URL if available
            final String href = importSummaries[0]['href'];
            final Uri hrefUri = Uri.parse(href);
            final String lastSegment = hrefUri.pathSegments.last;
            if (lastSegment.isNotEmpty) {
              newTrackedEntityInstanceId = lastSegment;
            }
          }
        }

        // If we still don't have an ID but the import was successful,
        // we'll need to query for the TEI to get its ID
        if (newTrackedEntityInstanceId == null &&
            (responseBody['status'] == 'SUCCESS' ||
                responseBody['status'] == 'OK')) {
          _lastErrorMessage =
              'Patient registered, but TEI ID not found in response. Will need to implement TEI lookup. ${teiResponse.body}';
          return false;
        } else if (newTrackedEntityInstanceId == null) {
          _lastErrorMessage =
              'Patient registered, but TEI ID not found in response. ${teiResponse.body}';
          return false;
        }
        if (kDebugMode) {
          print(
            'Patient (TEI) with enrollment created successfully. ID: $newTrackedEntityInstanceId',
          );
        }
      } else {
        _lastErrorMessage =
            'Failed to register patient (TEI): ${teiResponse.statusCode}. Body: ${teiResponse.body}';
        if (kDebugMode) {
          print(
            'TEI creation failed: ${teiResponse.statusCode} - ${teiResponse.body}',
          );
        }
        return false;
      }
    } catch (e) {
      _lastErrorMessage = 'Error registering patient (TEI): $e';
      if (kDebugMode) {
        print('TEI creation error: $e');
      }
      return false;
    }

    // At this point, newTrackedEntityInstanceId should not be null
    // The previous checks should have caught any issues

    // --- 2. Create Initial Temperature Event in Program Stage ---
    try {
      final success = await _createTemperatureEvent(
        newTrackedEntityInstanceId,
        patient.organizationUnit,
        patient.temperature.toString(),
        authToken,
      );

      if (!success) {
        _lastErrorMessage =
            'Patient registered, but there was an error creating the temperature event';
        if (kDebugMode) {
          print(_lastErrorMessage);
        }
      }

      return true; // Return true to indicate patient was registered
    } catch (e) {
      _lastErrorMessage =
          'Patient registered, but there was an error creating the temperature event: $e';
      if (kDebugMode) {
        print('Initial Event creation error: $e');
      }
      // For now, we'll consider the patient registration successful even if the event creation fails
      return true; // Return true to indicate patient was registered
    }
  }

  /// Creates a temperature event for a patient
  /// Returns true if the event was created successfully
  Future<bool> _createTemperatureEvent(
    String trackedEntityInstanceId,
    String organizationUnit,
    String temperatureValue,
    String authToken,
  ) async {
    try {
      final String eventDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Let's add more detailed debugging for the event creation
      if (kDebugMode) {
        print('Creating event for TEI: $trackedEntityInstanceId');
        print('Program ID: $programId');
        print('Program Stage ID: $programStageIdForTemperatureEvent');
        print('Organization Unit: $organizationUnit');
        print('Temperature Value: $temperatureValue');
      }

      final eventPayload = {
        'program': programId,
        'programStage': programStageIdForTemperatureEvent,
        'orgUnit': organizationUnit,
        'trackedEntityInstance': trackedEntityInstanceId,
        'eventDate': eventDate,
        'status': 'COMPLETED',
        'dataValues': [
          {
            'dataElement': dataElementIdForTemperatureInEvent,
            'value': temperatureValue,
          },
        ],
      };

      final eventResponse = await http
          .post(
            Uri.parse('$baseUrl/events'),
            headers: {
              'Authorization': authToken,
              'Content-Type': 'application/json',
            },
            body: json.encode(eventPayload),
          )
          .timeout(const Duration(seconds: 15));

      if (eventResponse.statusCode >= 200 && eventResponse.statusCode < 300) {
        final responseBody = json.decode(eventResponse.body);
        if (responseBody['status'] == 'SUCCESS' ||
            (responseBody['httpStatus'] == 'OK' ||
                responseBody['httpStatus'] == 'Created')) {
          if (kDebugMode) {
            print(
              'Temperature event created successfully for TEI ID: $trackedEntityInstanceId',
            );
          }
          return true;
        } else {
          _lastErrorMessage =
              'Temperature event creation failed. Response: ${eventResponse.body}';
          if (kDebugMode) {
            print(
              'Event creation failed (status not SUCCESS): ${eventResponse.statusCode} - ${eventResponse.body}',
            );
          }
          return false;
        }
      } else {
        _lastErrorMessage =
            'Failed to record temperature event: ${eventResponse.statusCode}. Body: ${eventResponse.body}';
        if (kDebugMode) {
          print(
            'Event creation failed: ${eventResponse.statusCode} - ${eventResponse.body}',
          );
        }
        return false;
      }
    } catch (e) {
      _lastErrorMessage = 'Error creating temperature event: $e';
      if (kDebugMode) {
        print('Event creation error: $e');
      }
      return false;
    }
  }
}
