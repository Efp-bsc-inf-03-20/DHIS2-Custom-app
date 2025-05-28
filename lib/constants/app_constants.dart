import 'package:flutter/material.dart';

// App theme colors
class AppColors {
  static const Color primary = Colors.teal;
  static const Color secondary = Color(0xFF757575);
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;
  static const Color error = Colors.red;
  static const Color success = Colors.green;
  static const Color warning = Colors.orange;

  // Temperature colors
  static Color hypothermia = Colors.blue.shade800;
  static Color belowNormal = Colors.blue.shade400;
  static Color normal = Colors.green;
  static Color slightFever = Colors.orange.shade300;
  static Color fever = Colors.orange.shade700;
  static Color highFever = Colors.red;
}

// App text styles
class AppTextStyles {
  static const TextStyle heading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFF212121),
  );

  static const TextStyle subheading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Color(0xFF424242),
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: Color(0xFF616161),
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: Color(0xFF757575),
  );
}

// App dimensions
class AppDimensions {
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 12.0;
  static const double inputBorderRadius = 12.0;
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets screenPadding = EdgeInsets.all(16.0);
  static const double cardElevation = 0.0;
}

// DHIS2 constants
class DHIS2Constants {
  static const String programId = "lrwV4BsFO3h";
  static const String trackedEntityTypeId = "EMdK2EGQS6x";

  // Tracked Entity Attribute IDs
  static const String attrPatientId = "YHeCuwvFYb6";
  static const String attrFirstName = "MABBsj6O2Un";
  static const String attrLastName = "MVgw7bPZc0Z";
  static const String attrPhoneNumber = "mJLeZibUwXp";
  static const String attrGender = "EDjTF6dn75s";
  static const String attrTemperaturesTEI = "IG9jXam9m3u";
  static const String attrPhysicalAddress = "p79QNVjFu45";

  // Program Stage and Data Element for Temperature Events
  static const String programStageIdForTemperatureEvent = "v3OvZ8tuyTS";
  static const String dataElementIdForTemperatureInEvent = "lQGZ3B8N5zO";
}

// Bluetooth constants
class BluetoothConstants {
  static const String deviceName = "ESP32-Thermo";
  static const String serviceUuid = "12345678-1234-1234-1234-1234567890ab";
  static const String characteristicUuid =
      "abcd1234-ab12-cd34-ef56-abcdef123456";
}
