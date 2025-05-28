// lib/utils/color_utils.dart
import 'package:flutter/material.dart';

// Returns a color based on temperature value
Color getTemperatureColor(double? temperature) {
  if (temperature == null) return Colors.grey;

  if (temperature < 35.0) return Colors.blue.shade800; // Hypothermia
  if (temperature < 36.5) return Colors.blue.shade400; // Below normal
  if (temperature <= 37.5) return Colors.green; // Normal
  if (temperature <= 38.0) return Colors.orange.shade300; // Slight fever
  if (temperature <= 39.5) return Colors.orange.shade700; // Fever
  return Colors.red; // High fever
}
