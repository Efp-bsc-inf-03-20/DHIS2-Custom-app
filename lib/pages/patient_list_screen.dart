import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/dhis2_service.dart';
import 'patient_details_screen.dart';
import 'temperature_report_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({Key? key}) : super(key: key);

  @override
  _PatientListScreenState createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _dhis2Service = DHIS2Service();
  final _searchController = TextEditingController();
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _patients = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients({String? searchText}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get the organization unit ID from the auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final orgUnitId = authProvider.organizationUnit;

      if (orgUnitId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'No organization unit selected. Please select an organization unit first.';
        });
        return;
      }

      final patients = await _dhis2Service.getPatients(
        searchText: searchText,
        orgUnitId: orgUnitId,
      );

      setState(() {
        _patients = patients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load patients: $e';
      });
    }
  }

  void _performSearch() {
    final searchText = _searchController.text.trim();
    if (searchText.isNotEmpty) {
      _loadPatients(searchText: searchText);
    } else {
      _loadPatients();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Patient List',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.grey[850],
        iconTheme: IconThemeData(color: Colors.grey[850]),
        actions: [
          // Temperature report button
          IconButton(
            icon: const Icon(Icons.show_chart, color: Colors.teal),
            tooltip: 'DHIS2 Reports',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const TemperatureReportScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13), // 0.05 opacity
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                  decoration: InputDecoration(
                    hintText: 'Search patients by name',
                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Colors.grey[500],
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _loadPatients();
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.teal, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
              ),
            ),

            // Patient list or loading indicator
            Expanded(
              child:
                  _isLoading
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.teal,
                                ),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading patients...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      )
                      : _errorMessage.isNotEmpty
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red[400],
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextButton(
                                onPressed: () => _loadPatients(),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      : _patients.isEmpty
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search,
                                color: Colors.grey[400],
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No patients found',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try a different search or register new patients',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      : RefreshIndicator(
                        color: Colors.teal,
                        onRefresh:
                            () => _loadPatients(
                              searchText:
                                  _searchController.text.isEmpty
                                      ? null
                                      : _searchController.text,
                            ),
                        child: ListView.builder(
                          itemCount: _patients.length,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 80),
                          itemBuilder: (context, index) {
                            final patient = _patients[index];
                            final attributes =
                                patient['attributes'] as Map<String, String>;
                            final temperature = attributes['temperature'] ?? '';
                            final hasHighTemp =
                                temperature.isNotEmpty &&
                                double.tryParse(temperature) != null &&
                                double.parse(temperature) > 38.0;

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(
                                      13,
                                    ), // 0.05 opacity
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                border:
                                    hasHighTemp
                                        ? Border.all(
                                          color: Colors.red.withAlpha(50),
                                          width: 1.5,
                                        )
                                        : null,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () {
                                    // Navigate to patient details screen
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (ctx) => PatientDetailsScreen(
                                              patient: patient,
                                            ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Patient avatar
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color:
                                                hasHighTemp
                                                    ? Colors.red.withAlpha(25)
                                                    : Colors.teal.withAlpha(25),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            color:
                                                hasHighTemp
                                                    ? Colors.red
                                                    : Colors.teal,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Patient details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                patient['displayName'] ??
                                                    'Unknown',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[800],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              if (attributes.containsKey(
                                                'patientId',
                                              ))
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.badge_outlined,
                                                      size: 16,
                                                      color: Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'ID: ${attributes['patientId']}',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              if (attributes.containsKey(
                                                'gender',
                                              ))
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.person_outline,
                                                        size: 16,
                                                        color: Colors.grey[600],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Gender: ${attributes['gender']}',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color:
                                                              Colors.grey[700],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.business_outlined,
                                                      size: 16,
                                                      color: Colors.orange,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        patient['orgUnitName'] !=
                                                                    null &&
                                                                patient['orgUnitName']
                                                                    .toString()
                                                                    .isNotEmpty
                                                            ? patient['orgUnitName']
                                                            : "None selected",
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              Colors.grey[700],
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (temperature.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .thermostat_outlined,
                                                        size: 16,
                                                        color:
                                                            hasHighTemp
                                                                ? Colors.red
                                                                : Colors.teal,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Temperature: $temperature°C',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color:
                                                              hasHighTemp
                                                                  ? Colors.red
                                                                  : Colors.teal,
                                                          fontWeight:
                                                              hasHighTemp
                                                                  ? FontWeight
                                                                      .bold
                                                                  : FontWeight
                                                                      .w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // Chevron
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey[400],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
