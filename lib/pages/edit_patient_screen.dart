import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/patient.dart';
import '../providers/auth_provider.dart';
import '../providers/bluetooth_provider.dart';
import '../services/dhis2_service.dart';

class EditPatientScreen extends StatefulWidget {
  final Map<String, dynamic> patientData;

  const EditPatientScreen({Key? key, required this.patientData}) : super(key: key);

  @override
  _EditPatientScreenState createState() => _EditPatientScreenState();
}

class _EditPatientScreenState extends State<EditPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _dhis2Service = DHIS2Service();
  
  String _selectedGender = 'Male';
  bool _isUpdating = false;
  String _errorMessage = '';
  double _temperature = 0.0;
  late Patient _patient;

  @override
  void initState() {
    super.initState();
    _initializePatientData();
  }

  void _initializePatientData() {
    final attributes = widget.patientData['attributes'] as Map<String, String>;
    
    _firstNameController.text = attributes['firstName'] ?? '';
    _lastNameController.text = attributes['lastName'] ?? '';
    _telephoneController.text = attributes['phone'] ?? '';
    _addressController.text = attributes['address'] ?? '';
    _selectedGender = attributes['gender'] ?? 'Male';
    
    if (attributes['temperature'] != null && attributes['temperature']!.isNotEmpty) {
      _temperature = double.tryParse(attributes['temperature']!) ?? 0.0;
    }
    
    // Create patient object for later use
    _patient = Patient.fromDhis2(widget.patientData);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _telephoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _updatePatient() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isUpdating = true;
      _errorMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final bluetoothProvider = Provider.of<BluetoothProvider>(context, listen: false);
      
      // Use current temperature if connected to device
      double temperature = _temperature;
      if (bluetoothProvider.isConnected && bluetoothProvider.temperatureValue.isNotEmpty) {
        final currentTemp = double.tryParse(bluetoothProvider.temperatureValue);
        if (currentTemp != null) {
          temperature = currentTemp;
        }
      }

      // Create updated patient object
      final updatedPatient = Patient(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        gender: _selectedGender,
        temperature: temperature,
        telephone: _telephoneController.text,
        address: _addressController.text,
        organizationUnit: _patient.organizationUnit,
        patientId: _patient.patientId,
        trackedEntityInstanceId: _patient.trackedEntityInstanceId,
      );

      // Update patient in DHIS2
      final success = await _dhis2Service.updatePatient(
        updatedPatient,
        authProvider.authToken,
      );

      // Check if widget is still mounted
      if (!mounted) return;

      setState(() {
        _isUpdating = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate update was successful
      } else {
        setState(() {
          _errorMessage = _dhis2Service.lastErrorMessage;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating patient: $e');
      }
      
      if (!mounted) return;
      
      setState(() {
        _isUpdating = false;
        _errorMessage = 'Error updating patient: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Edit Patient',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.grey[850],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isUpdating
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Updating patient...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    
                    // Form fields
                    _buildFormSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Update button
                    ElevatedButton(
                      onPressed: _updatePatient,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Update Patient',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First Name
        TextFormField(
          controller: _firstNameController,
          decoration: _inputDecoration('First Name'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter first name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Last Name
        TextFormField(
          controller: _lastNameController,
          decoration: _inputDecoration('Last Name'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter last name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Gender
        DropdownButtonFormField<String>(
          value: _selectedGender,
          decoration: _inputDecoration('Gender'),
          items: ['Male', 'Female', 'Other'].map((gender) {
            return DropdownMenuItem(
              value: gender,
              child: Text(gender),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedGender = value;
              });
            }
          },
        ),
        const SizedBox(height: 16),

        // Telephone
        TextFormField(
          controller: _telephoneController,
          decoration: _inputDecoration('Telephone (Optional)'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),

        // Address
        TextFormField(
          controller: _addressController,
          decoration: _inputDecoration('Address (Optional)'),
          maxLines: 2,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
