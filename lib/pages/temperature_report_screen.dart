import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../services/dhis2_service.dart';
import '../utils/color_utils.dart';
import '../widgets/app_card.dart';

class TemperatureReportScreen extends StatefulWidget {
  const TemperatureReportScreen({Key? key}) : super(key: key);

  @override
  _TemperatureReportScreenState createState() =>
      _TemperatureReportScreenState();
}

class _TemperatureReportScreenState extends State<TemperatureReportScreen> {
  final _dhis2Service = DHIS2Service();
  bool _isLoading = true;
  String _errorMessage = '';

  // List of patients with temperature data
  List<Map<String, dynamic>> _patients = [];

  // Map of patient IDs to their temperature history
  Map<String, List<Map<String, dynamic>>> _temperatureData = {};

  // Currently selected patient ID
  String? _selectedPatientId;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
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

      // Fetch patients
      final patients = await _dhis2Service.getPatients(orgUnitId: orgUnitId);

      // Filter patients to only include those with temperature data
      final patientsWithTemperature =
          patients.where((patient) {
            final attributes = patient['attributes'] as Map<String, String>;
            return attributes.containsKey('temperature') &&
                attributes['temperature'] != null &&
                attributes['temperature']!.isNotEmpty;
          }).toList();

      if (patientsWithTemperature.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No patients with temperature data found.';
        });
        return;
      }

      // Create a map of patient IDs to their current temperature
      Map<String, List<Map<String, dynamic>>> temperatureData = {};

      for (var patient in patientsWithTemperature) {
        final id = patient['id'] as String;
        final attributes = patient['attributes'] as Map<String, String>;
        final tempValue = attributes['temperature']!;

        // Try to parse the temperature value
        final temperature = double.tryParse(tempValue);
        if (temperature != null) {
          // Create a single temperature reading with today's date
          temperatureData[id] = [
            {
              'date': DateTime.now().toIso8601String(),
              'temperature': temperature,
            },
          ];

          // Try to get temperature history if available
          try {
            final history = await _dhis2Service.getPatientTemperatureHistory(
              id,
            );
            if (history.isNotEmpty) {
              temperatureData[id] = history;
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error fetching temperature history for patient $id: $e');
            }
            // Keep using the current temperature if history fetch fails
          }
        }
      }

      // Filter to only include patients with valid temperature data
      final patientsWithHistory =
          patientsWithTemperature.where((p) {
            final id = p['id'] as String;
            return temperatureData.containsKey(id) &&
                temperatureData[id]!.isNotEmpty;
          }).toList();

      setState(() {
        _patients = patientsWithHistory;
        _temperatureData = temperatureData;
        _isLoading = false;

        // Select the first patient by default if available
        if (_patients.isNotEmpty) {
          _selectedPatientId = _patients.first['id'];
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load patient data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'DHIS2  Reports',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.grey[850],
        iconTheme: IconThemeData(color: Colors.grey[850]),
      ),
      body: SafeArea(
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
                        'Loading patient data...',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
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
                          onPressed: _loadPatients,
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
                          'No patients with temperature data found',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Register patients with temperature readings to see them here',
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
                : Column(
                  children: [
                    // Patient selector
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildPatientSelector(),
                    ),

                    // Temperature chart
                    Expanded(
                      child:
                          _selectedPatientId != null
                              ? _buildTemperatureChart()
                              : Center(
                                child: Text(
                                  'Select a patient to view temperature data',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildPatientSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedPatientId,
          hint: Text(
            'Select a patient',
            style: TextStyle(color: Colors.grey[600], fontSize: 15),
          ),
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: Colors.teal,
            size: 28,
          ),
          elevation: 2,
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          onChanged: (String? newValue) {
            setState(() {
              _selectedPatientId = newValue;
            });
          },
          items:
              _patients.map<DropdownMenuItem<String>>((patient) {
                final name = patient['displayName'] ?? 'Unknown';
                final attributes = patient['attributes'] as Map<String, String>;
                final temperature = attributes['temperature'] ?? '';

                return DropdownMenuItem<String>(
                  value: patient['id'],
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.teal.withAlpha(25), // 0.1 opacity
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person, color: Colors.teal, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            ),
                            if (temperature.isNotEmpty)
                              Text(
                                'Temp: $temperature°C',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildTemperatureChart() {
    if (_selectedPatientId == null ||
        !_temperatureData.containsKey(_selectedPatientId)) {
      return const Center(child: Text('No temperature data available.'));
    }

    final temperatureReadings = _temperatureData[_selectedPatientId]!;
    if (temperatureReadings.isEmpty) {
      return const Center(child: Text('No temperature data available.'));
    }

    // Sort by date (oldest first for the chart)
    temperatureReadings.sort((a, b) => a['date'].compareTo(b['date']));

    // Create spot data for the chart
    final spots = <FlSpot>[];
    final dates = <String>[];

    // If we only have one reading, create a second point to show a line
    if (temperatureReadings.length == 1) {
      final reading = temperatureReadings[0];
      final temperature = reading['temperature'] as double;
      final date = reading['date'] as String;

      // Add the actual reading
      spots.add(FlSpot(0, temperature));
      dates.add(date);

      // Add a second point with the same temperature (flat line)
      spots.add(FlSpot(1, temperature));

      // Create a date 1 day later for the second point
      final dateTime = DateTime.parse(date);
      final nextDay = dateTime.add(const Duration(days: 1));
      dates.add(nextDay.toIso8601String());
    } else {
      // Multiple readings - add them all
      for (int i = 0; i < temperatureReadings.length; i++) {
        final reading = temperatureReadings[i];
        spots.add(FlSpot(i.toDouble(), reading['temperature']));
        dates.add(reading['date']);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient info
          _buildPatientInfo(),

          const SizedBox(height: 24),

          // Chart
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 1,
                  verticalInterval: 1,
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final int index = value.toInt();
                        if (index < 0 || index >= dates.length) {
                          return const SizedBox.shrink();
                        }

                        // Format the date
                        final dateStr = dates[index];
                        final date = DateTime.parse(dateStr);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('MM/dd').format(date),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.black12),
                ),
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: 35, // Minimum temperature
                maxY: 42, // Maximum temperature
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.teal,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final temperature = spot.y;
                        return FlDotCirclePainter(
                          radius: 6,
                          color: getTemperatureColor(temperature),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.teal.withAlpha(25), // 0.1 opacity
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Legend
          const SizedBox(height: 16),
          _buildTemperatureLegend(),
        ],
      ),
    );
  }

  Widget _buildPatientInfo() {
    if (_selectedPatientId == null) return const SizedBox.shrink();

    final patient = _patients.firstWhere(
      (p) => p['id'] == _selectedPatientId,
      orElse: () => <String, dynamic>{},
    );

    if (patient.isEmpty) return const SizedBox.shrink();

    final attributes = patient['attributes'] as Map<String, String>;
    final name = patient['displayName'] ?? 'Unknown';
    final gender = attributes['gender'] ?? 'Unknown';
    final orgName = patient['orgUnitName'] ?? 'Unknown';
    final temperature = attributes['temperature'] ?? '';
    final phone = attributes['phone'] ?? '';
    final address = attributes['address'] ?? '';

    return AppCard(
      padding: AppDimensions.cardPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(25), // 0.1 opacity
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: Colors.teal, size: 24),
          ),
          const SizedBox(width: 16),
          // Patient details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Gender: $gender',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Organization: $orgName',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (temperature.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.thermostat_outlined,
                        size: 16,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Current Temp: $temperature°C',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.teal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        phone,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildLegendItem(Colors.blue.shade800, 'Hypothermia (<35.0°C)'),
        _buildLegendItem(Colors.blue.shade400, 'Below normal (35.0-36.4°C)'),
        _buildLegendItem(Colors.green, 'Normal (36.5-37.5°C)'),
        _buildLegendItem(Colors.orange.shade300, 'Slight fever (37.6-38.0°C)'),
        _buildLegendItem(Colors.orange.shade700, 'Fever (38.1-39.5°C)'),
        _buildLegendItem(Colors.red, 'High Fever (>39.5°C)'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
