import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../widgets/app_card.dart';
import 'edit_patient_screen.dart';

class PatientDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const PatientDetailsScreen({Key? key, required this.patient})
    : super(key: key);

  @override
  _PatientDetailsScreenState createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  bool _isLoading = false;
  String _errorMessage = '';
  Map<String, dynamic> _patientDetails = {};

  @override
  void initState() {
    super.initState();
    _patientDetails = widget.patient;
  }

  Future<void> _navigateToEditScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPatientScreen(patientData: _patientDetails),
      ),
    );

    // If the edit was successful, refresh the patient details
    if (result == true) {
      // Check if widget is still mounted
      if (!mounted) return;

      setState(() {
        _isLoading = true;
      });

      // Reload patient details
      // For now, we'll just go back to the patient list screen
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attributes = _patientDetails['attributes'] as Map<String, String>;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Patient Details', style: AppTextStyles.heading),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[850],
        iconTheme: IconThemeData(color: Colors.grey[850]),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.primary),
            tooltip: 'Edit Patient',
            onPressed: () => _navigateToEditScreen(),
          ),
        ],
      ),
      body:
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
                          AppColors.primary,
                        ),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading patient details...',
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
                        style: TextStyle(color: Colors.red[700], fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () {
                          // Reload patient details if needed
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.buttonBorderRadius,
                            ),
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
              : SingleChildScrollView(
                padding: AppDimensions.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient header
                    AppCard(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(25),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 30,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _patientDetails['displayName'] ??
                                          'Unknown',
                                      style: AppTextStyles.heading,
                                    ),
                                    if (attributes.containsKey('patientId'))
                                      Text(
                                        'ID: ${attributes['patientId']}',
                                        style: AppTextStyles.caption,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (attributes.containsKey('temperature')) ...[
                            const SizedBox(height: 16),
                            _buildTemperatureIndicator(
                              attributes['temperature']!,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Patient details
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 4,
                        bottom: 8,
                        top: 8,
                      ),
                      child: Text(
                        'Personal Information',
                        style: AppTextStyles.subheading,
                      ),
                    ),
                    AppCard(
                      child: Column(
                        children: [
                          _buildDetailRow(
                            'Gender',
                            attributes['gender'] ?? 'Not specified',
                            Icons.person_outline,
                          ),
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Colors.grey[200],
                          ),
                          _buildDetailRow(
                            'Phone',
                            attributes['phone'] ?? 'Not available',
                            Icons.phone_outlined,
                          ),
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Colors.grey[200],
                          ),
                          _buildDetailRow(
                            'Address',
                            attributes['address'] ?? 'Not available',
                            Icons.location_on_outlined,
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(
                        left: 4,
                        bottom: 8,
                        top: 16,
                      ),
                      child: Text(
                        'Organization Information',
                        style: AppTextStyles.subheading,
                      ),
                    ),
                    AppCard(
                      child: Column(
                        children: [
                          _buildDetailRow(
                            'Organization',
                            _patientDetails['orgUnitName']?.toString() ??
                                'Not specified',
                            Icons.business_outlined,
                          ),
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Colors.grey[200],
                          ),
                          _buildDetailRow(
                            'Organization ID',
                            _patientDetails['orgUnit']?.toString() ??
                                'Not available',
                            Icons.tag_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildTemperatureIndicator(String temperatureStr) {
    final double? temperature = double.tryParse(temperatureStr);
    final bool isHigh = temperature != null && temperature > 38.0;

    final Color bgColor =
        isHigh ? Colors.red.withAlpha(25) : AppColors.primary.withAlpha(25);
    final Color borderColor =
        isHigh ? Colors.red.withAlpha(50) : AppColors.primary.withAlpha(50);
    final Color textColor = isHigh ? Colors.red : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius / 2),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.thermostat_outlined, color: textColor, size: 20),
          const SizedBox(width: 8),
          Text(
            'Temperature: $temperatureStr °C',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: textColor,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          if (isHigh)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'HIGH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
