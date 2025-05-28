import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/bluetooth_provider.dart';
import 'bluetooth_device_selection_screen.dart';
import 'patient_list_screen.dart';
import 'register_patient_screen.dart';
import 'login_screen.dart';
import 'temperature_report_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bluetoothProvider = Provider.of<BluetoothProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: const Text(
          'DHIS2 Smart App',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              if (bluetoothProvider.isConnected) {
                await bluetoothProvider.disconnect();
              }
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                );
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                context,
                child: UserOrganizationCard(
                  username: authProvider.username,
                  organizationName: authProvider.organizationName,
                ),
              ),
              _buildSection(
                context,
                child: DeviceStatusCard(
                  bluetoothProvider: bluetoothProvider,
                  onConnectPressed: () {
                    // Navigate to the connection screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (context) => const BluetoothDeviceSelectionScreen(),
                      ),
                    );
                  },
                  onDisconnectPressed: () {
                    bluetoothProvider.disconnect();
                  },
                ),
              ),
              if (bluetoothProvider.isConnected)
                _buildSection(
                  context,
                  child: TemperatureCard(bluetoothProvider: bluetoothProvider),
                ),
              _buildSection(
                context,
                child: PatientManagementSection(
                  isConnected: bluetoothProvider.isConnected,
                  onRegisterPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => const RegisterPatientScreen(),
                      ),
                    );
                  },
                  onPatientListPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => const PatientListScreen(),
                      ),
                    );
                  },
                  onTemperatureReportPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => const TemperatureReportScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: child,
    );
  }
}

class UserOrganizationCard extends StatelessWidget {
  final String username;
  final String organizationName;

  const UserOrganizationCard({
    Key? key,
    required this.username,
    required this.organizationName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business_outlined,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Organization',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        organizationName.isNotEmpty
                            ? organizationName
                            : "None selected",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceStatusCard extends StatelessWidget {
  final BluetoothProvider bluetoothProvider;
  final VoidCallback onConnectPressed;
  final VoidCallback onDisconnectPressed;

  const DeviceStatusCard({
    Key? key,
    required this.bluetoothProvider,
    required this.onConnectPressed,
    required this.onDisconnectPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isConnected = bluetoothProvider.isConnected;
    final bool isProcessing = bluetoothProvider.isProcessingBluetoothAction;
    final bool isActuallyConnecting = bluetoothProvider.isConnecting;
    final String currentActionStatus = bluetoothProvider.bluetoothActionStatus;

    String displayedDeviceNameOrStatus;
    Color statusColor;
    IconData statusIconData;
    Color iconBackgroundColor;
    Widget buttonWidget;

    if (isProcessing) {
      displayedDeviceNameOrStatus =
          currentActionStatus.isNotEmpty
              ? currentActionStatus
              : "Processing...";
      statusColor = Colors.orange;
      statusIconData = Icons.bluetooth_searching;
      iconBackgroundColor = Colors.orange.withOpacity(0.1);
      buttonWidget = SizedBox(
        width: 90,
        height: 44,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
        ),
      );
    } else if (isConnected && bluetoothProvider.selectedDevice != null) {
      displayedDeviceNameOrStatus = bluetoothProvider.selectedDevice!.name;
      statusColor = Colors.blue;
      statusIconData = Icons.bluetooth_connected;
      iconBackgroundColor = Colors.blue.withOpacity(0.1);
      buttonWidget = TextButton(
        onPressed: onDisconnectPressed,
        style: TextButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(90, 44),
        ),
        child: const Text(
          'Disconnect',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      );
    } else {
      displayedDeviceNameOrStatus =
          currentActionStatus.isNotEmpty
              ? currentActionStatus
              : 'ESP32-Thermo not connected';
      statusColor = Colors.red;
      statusIconData = Icons.bluetooth_disabled;
      iconBackgroundColor = Colors.blue.withOpacity(0.1);
      buttonWidget = TextButton(
        onPressed: onConnectPressed,
        style: TextButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(90, 44),
        ),
        child: const Text(
          'Connect',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIconData, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Bluetooth Device Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[850],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isProcessing && !isConnected)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                statusColor,
                              ),
                            ),
                          )
                        else
                          Icon(
                            isConnected
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                            color: isConnected ? Colors.blue : statusColor,
                            size: 18,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            displayedDeviceNameOrStatus,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                buttonWidget,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Temperature display and reading card
class TemperatureCard extends StatelessWidget {
  final BluetoothProvider bluetoothProvider;

  const TemperatureCard({Key? key, required this.bluetoothProvider})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool hasValidReading =
        bluetoothProvider.getTemperatureAsDouble() != null;
    final bool isReadingInProgress = bluetoothProvider.isReading;

    Color temperatureColor;
    String displayedTemperatureText = bluetoothProvider.temperatureValue;

    if (isReadingInProgress) {
      temperatureColor = Colors.orange;
    } else if (hasValidReading) {
      temperatureColor = Colors.teal;
      displayedTemperatureText = '${bluetoothProvider.temperatureValue} °C';
    } else {
      temperatureColor = Colors.grey[600]!;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.thermostat_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Temperature',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[850],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  color: temperatureColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      displayedTemperatureText,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w500,
                        color: temperatureColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isReadingInProgress)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Please wait...', // Simpler message
                          style: TextStyle(
                            color: Colors.orange,
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              icon:
                  isReadingInProgress
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Icon(Icons.thermostat),
              label: Text(
                isReadingInProgress ? 'Reading...' : 'Take Reading',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                disabledBackgroundColor: Colors.blue.withOpacity(0.5),
                disabledForegroundColor: Colors.white.withOpacity(0.7),
              ),
              onPressed:
                  isReadingInProgress || !bluetoothProvider.isConnected
                      ? null // Button is disabled
                      : () => bluetoothProvider.startTemperatureReading(),
            ),
          ],
        ),
      ),
    );
  }
}

// Patient management options
class PatientManagementSection extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onRegisterPressed;
  final VoidCallback onPatientListPressed;
  final VoidCallback? onTemperatureReportPressed;

  const PatientManagementSection({
    Key? key,
    required this.isConnected,
    required this.onRegisterPressed,
    required this.onPatientListPressed,
    this.onTemperatureReportPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Patient Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
              letterSpacing: 0.2,
            ),
          ),
        ),
        // Register patient card
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border:
                isConnected
                    ? Border.all(color: Colors.blue.withOpacity(0.3), width: 1)
                    : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: isConnected ? onRegisterPressed : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color:
                            isConnected
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person_add_outlined,
                        color: isConnected ? Colors.blue : Colors.grey,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Register New Patient',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color:
                                  isConnected ? Colors.grey[850] : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isConnected
                                ? 'Add patient with temperature data'
                                : 'Connect device to register patients',
                            style: TextStyle(
                              color:
                                  isConnected ? Colors.grey[600] : Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          if (isConnected)
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Device Connected',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            isConnected
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color:
                            isConnected
                                ? Colors.blue
                                : Colors.grey.withOpacity(0.5),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Patient list card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onPatientListPressed,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.people_alt_outlined,
                        color: Colors.blue,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'View Patient Records',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Search and manage all patient records',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.blue,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Temperature report card (only show if callback is provided)
        if (onTemperatureReportPressed != null) ...[
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onTemperatureReportPressed,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.show_chart,
                          color: Colors.blue,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DHIS2 Reports',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'View temperature graphs for patients',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.blue,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
