class Patient {
  String firstName;
  String lastName;
  String gender;
  double temperature;
  String telephone;
  String address;
  String organizationUnit;
  String patientId; // DHIS2 tracked entity instance ID
  String trackedEntityInstanceId; // For updates
  DateTime enrollmentDate = DateTime.now();
  DateTime incidentDate = DateTime.now();

  Patient({
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.temperature,
    required this.telephone,
    required this.address,
    required this.organizationUnit,
    this.patientId = '',
    this.trackedEntityInstanceId = '',
    DateTime? enrollmentDate,
    DateTime? incidentDate,
  }) {
    this.enrollmentDate = enrollmentDate ?? DateTime.now();
    this.incidentDate = incidentDate ?? DateTime.now();
  }

  /// Create a Patient object from a DHIS2 patient data map
  factory Patient.fromDhis2(Map<String, dynamic> data) {
    final attributes = data['attributes'] as Map<String, String>;

    return Patient(
      firstName: attributes['firstName'] ?? '',
      lastName: attributes['lastName'] ?? '',
      gender: attributes['gender'] ?? '',
      temperature: double.tryParse(attributes['temperature'] ?? '0') ?? 0,
      telephone: attributes['phone'] ?? '',
      address: attributes['address'] ?? '',
      organizationUnit: data['orgUnit'] ?? '',
      patientId: attributes['patientId'] ?? '',
      trackedEntityInstanceId: data['id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'temperature': temperature,
      'telephone': telephone,
      'address': address,
      'organizationUnit': organizationUnit,
      'patientId': patientId,
      'trackedEntityInstanceId': trackedEntityInstanceId,
      'enrollmentDate': enrollmentDate.toIso8601String(),
      'incidentDate': incidentDate.toIso8601String(),
    };
  }
}
