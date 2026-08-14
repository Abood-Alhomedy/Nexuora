import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:lottie/lottie.dart';
import 'package:nexuora/main.dart';
import 'package:nexuora/services/live_device_service.dart';
import 'package:nexuora/utils/AppWidget.dart';
import 'package:nb_utils/nb_utils.dart';

class DeviceSelectionDialog extends StatefulWidget {
  final Function(String) onDeviceSelected;
  
  const DeviceSelectionDialog({
    Key? key, 
    required this.onDeviceSelected
  }) : super(key: key);

  @override
  _DeviceSelectionDialogState createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends State<DeviceSelectionDialog> {
  List<DeviceInfo> devices = [];
  bool isLoading = true;
  String? errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadDevices();
  }
  
  Future<void> _loadDevices() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final service = LiveDeviceService();
      final deviceList = await service.getDevices();
      
      setState(() {
        devices = deviceList;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.devices, color: appStore.isDarkMode ? Colors.white : Colors.black),
            8.width,
            Text(
              'Select Device',
              style: TextStyle(
                color: appStore.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        content: Container(
          width: 350,
          height: 350,
          child: isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset('images/loader.json', width: 60, height: 60),
                      16.height,
                      Text(
                        'Scanning for devices...',
                        style: TextStyle(
                          color: appStore.isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                )
              : errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.red,
                          ),
                          16.height,
                          Text(
                            'Error loading devices',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          8.height,
                          Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: appStore.isDarkMode ? Colors.white70 : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          16.height,
                          ElevatedButton.icon(
                            onPressed: _loadDevices,
                            icon: Icon(Icons.refresh),
                            label: Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : devices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.device_hub,
                                size: 60,
                                color: Colors.grey,
                              ),
                              16.height,
                              Text(
                                'No devices found',
                                style: TextStyle(
                                  color: appStore.isDarkMode ? Colors.white70 : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              8.height,
                              Text(
                                'Please connect a device or\nstart an emulator',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: appStore.isDarkMode ? Colors.white54 : Colors.black45,
                                  fontSize: 12,
                                ),
                              ),
                              16.height,
                              ElevatedButton.icon(
                                onPressed: _loadDevices,
                                icon: Icon(Icons.refresh),
                                label: Text('Refresh'),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                itemCount: devices.length,
                                itemBuilder: (context, index) {
                                  final device = devices[index];
                                  return _buildDeviceTile(device);
                                },
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: appStore.isDarkMode ? Colors.grey[800] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${devices.length} device(s) found',
                                    style: TextStyle(
                                      color: appStore.isDarkMode ? Colors.white70 : Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _loadDevices,
                                    icon: Icon(Icons.refresh, size: 16),
                                    label: Text('Refresh'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: appStore.isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
        backgroundColor: appStore.isDarkMode ? Colors.grey[900] : Colors.white,
      ),
    );
  }
  
  Widget _buildDeviceTile(DeviceInfo device) {
    IconData deviceIcon;
    Color iconColor;
    
    switch (device.platform.toLowerCase()) {
      case 'android':
        deviceIcon = Icons.android;
        iconColor = Colors.green;
        break;
      case 'ios':
        deviceIcon = Icons.apple;
        iconColor = Colors.grey;
        break;
      case 'web':
        deviceIcon = Icons.web;
        iconColor = Colors.blue;
        break;
      case 'windows':
        deviceIcon = Icons.window;
        iconColor = Colors.blueGrey;
        break;
      case 'macos':
        deviceIcon = Icons.computer;
        iconColor = Colors.grey;
        break;
      case 'linux':
        deviceIcon = Icons.terminal;
        iconColor = Colors.orange;
        break;
      default:
        deviceIcon = Icons.device_unknown;
        iconColor = Colors.grey;
    }
    
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      color: appStore.isDarkMode ? Colors.grey[800] : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(
            deviceIcon,
            color: iconColor,
          ),
        ),
        title: Text(
          device.name,
          style: TextStyle(
            color: appStore.isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              device.platform,
              style: TextStyle(
                color: appStore.isDarkMode ? Colors.white60 : Colors.black54,
                fontSize: 12,
              ),
            ),
            if (device.isEmulator) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Emulator',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: appStore.isDarkMode ? Colors.white54 : Colors.black54,
        ),
        onTap: () {
          widget.onDeviceSelected(device.id);
          Navigator.pop(context);
        },
      ),
    );
  }
}