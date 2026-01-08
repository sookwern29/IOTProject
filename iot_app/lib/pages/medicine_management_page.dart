import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicine_box.dart';
import '../services/firestore_service.dart';
import '../services/device_service.dart';
import 'device_scanner_page.dart';

class MedicineManagementPage extends StatefulWidget {
  @override
  _MedicineManagementPageState createState() => _MedicineManagementPageState();
}

class _MedicineManagementPageState extends State<MedicineManagementPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final DeviceService _deviceService = DeviceService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Medicine Management'),
      ),
      body: StreamBuilder<List<MedicineBox>>(
        stream: _firestoreService.getMedicineBoxes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services_outlined, size: 100, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'No medicine boxes added yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Tap + to add a new medicine box',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final boxes = snapshot.data!;
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: boxes.length,
            itemBuilder: (context, index) {
              return _buildMedicineBoxCard(boxes[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMedicineBoxDialog(context),
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildMedicineBoxCard(MedicineBox box) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: box.isConnected ? Colors.green : Colors.grey,
          child: Text(
            box.boxNumber.toString(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          box.name,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device: ${box.deviceId}'),
            Text('Type: ${box.medicineType}'),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminders',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 12),
                if (box.reminders.isEmpty)
                  Text('No reminders set', style: TextStyle(color: Colors.grey))
                else
                  ...box.reminders.map((reminder) => _buildReminderItem(reminder, box)),
                SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: Icon(Icons.add, size: 18),
                      label: Text('Reminder'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () => _showAddReminderDialog(context, box),
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.edit, size: 18),
                      label: Text('Edit'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () => _showEditBoxDialog(context, box),
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.delete, size: 18, color: Theme.of(context).colorScheme.error),
                      label: Text('Delete'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () => _confirmDelete(box),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderItem(ReminderTime reminder, MedicineBox box) {
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final activeDays = reminder.daysOfWeek.map((d) => days[d]).join(', ');
    
    return Card(
      color: reminder.isEnabled ? Colors.blue[50] : Colors.grey[200],
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.alarm,
          color: reminder.isEnabled ? Theme.of(context).colorScheme.primary : Colors.grey,
        ),
        title: Text(
          reminder.getTimeString(),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Days: $activeDays'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, size: 20),
              onPressed: () => _showEditReminderDialog(context, box, reminder),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete, size: 20, color: Theme.of(context).colorScheme.error),
              onPressed: () => _deleteReminder(box, reminder),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMedicineBoxDialog(BuildContext context) {
    _showMedicineBoxDialog(context, null);
  }

  void _showEditBoxDialog(BuildContext context, MedicineBox box) {
    _showMedicineBoxDialog(context, box);
  }

  void _showMedicineBoxDialog(BuildContext context, MedicineBox? box) async {
    // Get the latest device from Firestore devices collection
    String autoDeviceId = '';
    if (box == null) {
      try {
        final devicesSnapshot = await FirebaseFirestore.instance
            .collection('devices')
            .orderBy('connectedAt', descending: true)
            .limit(1)
            .get();
        
        if (devicesSnapshot.docs.isNotEmpty) {
          autoDeviceId = devicesSnapshot.docs.first.id;
          print('📦 Auto-detected device: $autoDeviceId');
        } else {
          print('⚠️ No devices found in Firestore');
        }
      } catch (e) {
        print('Error fetching device: $e');
      }
    }
    
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController(text: box?.name ?? '');
    int _selectedBoxNumber = box?.boxNumber ?? 1;
    final _deviceIdController = TextEditingController(text: box?.deviceId ?? autoDeviceId);
    String _medicineType = box?.medicineType ?? 'prescription';
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(box == null ? 'Add Medicine Box' : 'Edit Medicine Box'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Box Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.edit),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter box name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Box Number',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: List.generate(7, (index) {
                              final boxNum = index + 1;
                              final isSelected = _selectedBoxNumber == boxNum;
                              
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedBoxNumber = boxNum;
                                  });
                                },
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.white,
                                    border: Border.all(
                                      color: isSelected 
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.grey[400]!,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: isSelected ? [
                                      BoxShadow(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      )
                                    ] : [],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.medical_services,
                                        color: isSelected ? Colors.white : Colors.grey[600],
                                        size: 28,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        '$boxNum',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isSelected ? Colors.white : Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _deviceIdController,
                              decoration: InputDecoration(
                                labelText: box == null ? 'Device ID (Auto-detected)' : 'Device ID',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.router),
                                helperText: box == null && autoDeviceId.isNotEmpty 
                                    ? 'Linked to: $autoDeviceId' 
                                    : null,
                                helperStyle: TextStyle(color: Colors.green),
                              ),
                              readOnly: box == null && autoDeviceId.isNotEmpty,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'No device found. Please scan for devices first.';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DeviceScannerPage(),
                                ),
                              );
                              // Re-open dialog after returning from scanner
                              if (mounted) {
                                _showMedicineBoxDialog(context, box);
                              }
                            },
                            icon: Icon(Icons.wifi_find),
                            tooltip: 'Scan for Devices',
                            style: IconButton.styleFrom(
                              backgroundColor: Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _medicineType,
                        decoration: InputDecoration(
                          labelText: 'Medicine Type',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'prescription',
                            child: Row(
                              children: [
                                Icon(Icons.local_hospital, size: 20, color: Color(0xFFE53935)),
                                SizedBox(width: 8),
                                Text('Prescription'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'over-the-counter',
                            child: Row(
                              children: [
                                Icon(Icons.shopping_bag, size: 20, color: Color(0xFF1976D2)),
                                SizedBox(width: 8),
                                Text('Over the Counter'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'supplement',
                            child: Row(
                              children: [
                                Icon(Icons.eco, size: 20, color: Color(0xFF66BB6A)),
                                SizedBox(width: 8),
                                Text('Supplement'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _medicineType = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final boxId = box?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
                      
                      final newBox = MedicineBox(
                        id: boxId,
                        name: _nameController.text,
                        boxNumber: _selectedBoxNumber,
                        deviceId: _deviceIdController.text,
                        medicineType: _medicineType,
                        isConnected: _deviceIdController.text.isNotEmpty,
                        lastUpdated: DateTime.now(),
                        reminders: box?.reminders ?? [],
                      );

                      try {
                        // Save device IP mapping
                        _deviceService.setDeviceIp(boxId, _deviceIdController.text);
                        
                        if (box == null) {
                          await _firestoreService.addMedicineBox(newBox);
                          // Generate records for all reminders if box has any
                          if (newBox.reminders.isNotEmpty) {
                            await _firestoreService.generateRecordsForBox(newBox);
                          }
                        } else {
                          await _firestoreService.updateMedicineBox(newBox);
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(box == null 
                                ? 'Medicine box added successfully!' 
                                : 'Medicine box updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: Text(box == null ? 'Add' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddReminderDialog(BuildContext context, MedicineBox box) async {
    final _formKey = GlobalKey<FormState>();
    int selectedHour = DateTime.now().hour;
    int selectedMinute = DateTime.now().minute;
    List<bool> selectedDays = List.filled(7, false);
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Reminder'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                itemExtent: 40,
                                perspective: 0.005,
                                diameterRatio: 1.2,
                                physics: FixedExtentScrollPhysics(),
                                controller: FixedExtentScrollController(
                                  initialItem: selectedHour,
                                ),
                                onSelectedItemChanged: (index) {
                                  setState(() {
                                    selectedHour = index;
                                  });
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  builder: (context, index) {
                                    if (index < 0 || index > 23) return null;
                                    return Center(
                                      child: Text(
                                        index.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: index == selectedHour 
                                              ? Theme.of(context).colorScheme.primary
                                              : Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                  childCount: 24,
                                ),
                              ),
                            ),
                            Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                itemExtent: 40,
                                perspective: 0.005,
                                diameterRatio: 1.2,
                                physics: FixedExtentScrollPhysics(),
                                controller: FixedExtentScrollController(
                                  initialItem: selectedMinute,
                                ),
                                onSelectedItemChanged: (index) {
                                  setState(() {
                                    selectedMinute = index;
                                  });
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  builder: (context, index) {
                                    if (index < 0 || index > 59) return null;
                                    return Center(
                                      child: Text(
                                        index.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: index == selectedMinute 
                                              ? Theme.of(context).colorScheme.primary
                                              : Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                  childCount: 60,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Select Days:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      ...['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].asMap().entries.map((entry) {
                        return CheckboxListTile(
                          title: Text(entry.value),
                          value: selectedDays[entry.key],
                          onChanged: (value) {
                            setState(() {
                              selectedDays[entry.key] = value ?? false;
                            });
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedDays.any((day) => day)) {
                      final reminderId = DateTime.now().millisecondsSinceEpoch.toString();
                      final enabledDays = selectedDays.asMap()
                          .entries
                          .where((entry) => entry.value)
                          .map((entry) => entry.key)
                          .toList();
                      
                      final newReminder = ReminderTime(
                        id: reminderId,
                        hour: selectedHour,
                        minute: selectedMinute,
                        isEnabled: true,
                        daysOfWeek: enabledDays,
                        status: 'upcoming',
                      );
                      
                      final updatedBox = MedicineBox(
                        id: box.id,
                        name: box.name,
                        boxNumber: box.boxNumber,
                        deviceId: box.deviceId,
                        medicineType: box.medicineType,
                        isConnected: box.isConnected,
                        lastUpdated: DateTime.now(),
                        reminders: [...box.reminders, newReminder],
                      );
                      
                      try {
                        await _firestoreService.updateMedicineBox(updatedBox);
                        // Generate records for this reminder
                        await _firestoreService.generateRecordsForReminder(updatedBox, newReminder);
                        
                        Navigator.pop(context);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('Reminder added successfully!'),
                            backgroundColor: Color(0xFF66BB6A),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Color(0xFFE53935)),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('Please select at least one day'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditReminderDialog(BuildContext context, MedicineBox box, ReminderTime reminder) async {
    final _formKey = GlobalKey<FormState>();
    int selectedHour = reminder.hour;
    int selectedMinute = reminder.minute;
    List<bool> selectedDays = List.generate(7, (index) => reminder.daysOfWeek.contains(index));
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit Reminder'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                itemExtent: 40,
                                perspective: 0.005,
                                diameterRatio: 1.2,
                                physics: FixedExtentScrollPhysics(),
                                controller: FixedExtentScrollController(
                                  initialItem: selectedHour,
                                ),
                                onSelectedItemChanged: (index) {
                                  setState(() {
                                    selectedHour = index;
                                  });
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  builder: (context, index) {
                                    if (index < 0 || index > 23) return null;
                                    return Center(
                                      child: Text(
                                        index.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: index == selectedHour 
                                              ? Theme.of(context).colorScheme.primary
                                              : Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                  childCount: 24,
                                ),
                              ),
                            ),
                            Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                itemExtent: 40,
                                perspective: 0.005,
                                diameterRatio: 1.2,
                                physics: FixedExtentScrollPhysics(),
                                controller: FixedExtentScrollController(
                                  initialItem: selectedMinute,
                                ),
                                onSelectedItemChanged: (index) {
                                  setState(() {
                                    selectedMinute = index;
                                  });
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  builder: (context, index) {
                                    if (index < 0 || index > 59) return null;
                                    return Center(
                                      child: Text(
                                        index.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: index == selectedMinute 
                                              ? Theme.of(context).colorScheme.primary
                                              : Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                  childCount: 60,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Select Days:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      ...['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].asMap().entries.map((entry) {
                        return CheckboxListTile(
                          title: Text(entry.value),
                          value: selectedDays[entry.key],
                          onChanged: (value) {
                            setState(() {
                              selectedDays[entry.key] = value ?? false;
                            });
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedDays.any((day) => day)) {
                      final enabledDays = selectedDays.asMap()
                          .entries
                          .where((entry) => entry.value)
                          .map((entry) => entry.key)
                          .toList();
                      
                      final updatedReminder = ReminderTime(
                        id: reminder.id,
                        hour: selectedHour,
                        minute: selectedMinute,
                        isEnabled: reminder.isEnabled,
                        daysOfWeek: enabledDays,
                        status: reminder.status,
                      );
                      
                      final updatedReminders = box.reminders.map((r) {
                        return r.id == reminder.id ? updatedReminder : r;
                      }).toList();
                      
                      final updatedBox = MedicineBox(
                        id: box.id,
                        name: box.name,
                        boxNumber: box.boxNumber,
                        deviceId: box.deviceId,
                        medicineType: box.medicineType,
                        isConnected: box.isConnected,
                        lastUpdated: DateTime.now(),
                        reminders: updatedReminders,
                      );
                      
                      try {
                        // Delete old future records for this reminder
                        await _firestoreService.deleteFutureRecordsForReminder(box.id, reminder.id);
                        
                        // Update the box with new reminder
                        await _firestoreService.updateMedicineBox(updatedBox);
                        
                        // Generate new records for updated reminder
                        await _firestoreService.generateRecordsForReminder(updatedBox, updatedReminder);
                        
                        Navigator.pop(context);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('Reminder updated successfully!'),
                            backgroundColor: Color(0xFF66BB6A),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Color(0xFFE53935)),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('Please select at least one day'),
                          backgroundColor: Color(0xFFFF9800),
                        ),
                      );
                    }
                  },
                  child: Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteReminder(MedicineBox box, ReminderTime reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Reminder'),
        content: Text('Are you sure you want to delete this reminder (${reminder.getTimeString()})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFE53935)),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete future records for this reminder (keeps historical data)
        await _firestoreService.deleteFutureRecordsForReminder(box.id, reminder.id);
        
        final updatedReminders = box.reminders.where((r) => r.id != reminder.id).toList();
        
        final updatedBox = MedicineBox(
          id: box.id,
          name: box.name,
          boxNumber: box.boxNumber,
          deviceId: box.deviceId,
          medicineType: box.medicineType,
          isConnected: box.isConnected,
          lastUpdated: DateTime.now(),
          reminders: updatedReminders,
        );
        
        await _firestoreService.updateMedicineBox(updatedBox);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder deleted'), backgroundColor: Color(0xFFFF9800)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Color(0xFFE53935)),
        );
      }
    }
  }

  Future<void> _confirmDelete(MedicineBox box) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Medicine Box'),
        content: Text('Are you sure you want to delete ${box.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFE53935)),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteMedicineBox(box.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Medicine box deleted'), backgroundColor: Color(0xFFFF9800)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Color(0xFFE53935)),
        );
      }
    }
  }
}
