# IoT Medicine Box Setup Guide

## LED Light-Up Feature

When you tap the lightbulb icon on a missed dose in the Today's Doses page, it will make the corresponding LED on your medicine box blink for 10 seconds to help you locate which compartment has the missed medicine.

### Box Number to LED Mapping:
- **Box 1** → LED on GPIO 18 (PIN_BOX1_LED)
- **Box 2** → LED on GPIO 16 (PIN_BOX2_LED)
- **Box 3** → LED on GPIO 7  (PIN_BOX3_LED)
- **Box 4** → LED on GPIO 6  (PIN_BOX4_LED)
- **Box 5** → LED on GPIO 5  (PIN_BOX5_LED)
- **Box 6** → LED on GPIO 17 (PIN_BOX6_LED)
- **Box 7** → LED on GPIO 14 (PIN_BOX7_LED)

## Setup Steps

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Configure Device IP Address

You have 3 options:

#### Option A: Manual Configuration (Recommended for first setup)
1. Power on your medicine box
2. Check the Serial Monitor or your router to find the IP address (e.g., 192.168.1.100)
3. In your app, navigate to Device Setup Helper page
4. Enter:
   - **Device ID**: The MAC-based ID shown in Serial Monitor (e.g., "A1B2C3D4E5F6")
   - **IP Address**: The local IP (e.g., "192.168.1.100")
5. Tap "Save Configuration"

#### Option B: Auto Discovery (Network Scan)
1. Navigate to Device Setup Helper page
2. Tap "Scan Network"
3. The app will scan your network (192.168.1.1-254) to find your medicine box
4. Device will be automatically configured if found

#### Option C: Store IP in Firestore (Persistent)
Add an `ipAddress` field to your MedicineBox documents in Firestore:
```dart
// In medicine_box.dart model, add:
final String? ipAddress;

// Update DeviceService to read from Firestore instead of cache
```

### 3. Test the LED Control

1. Create a medicine box with box number 1-7
2. Add a reminder
3. Mark it as "Missed"
4. Tap the 💡 lightbulb icon
5. The corresponding LED on your physical box should blink 10 times (10 seconds)

### 4. Troubleshooting

#### "Device IP not found"
- Make sure you configured the device IP using one of the methods above
- Check that the deviceId in Firestore matches the actual device

#### "Device not responding"
- Verify the medicine box is powered on
- Check WiFi connection (box and phone should be on same network)
- Verify IP address is correct (check router or Serial Monitor)
- Try pinging the device: `http://<ip-address>/status`

#### "TimeoutException"
- Device might be offline or on a different network
- Check firewall settings
- Ensure ESP32 web server is running (check Serial Monitor for "HTTP Web Server Started!")

### 5. Arduino Endpoints Used

The app communicates with these endpoints on your ESP32:

- `GET /blink?box=<1-7>&times=<10>` - Blink specific LED
- `GET /led?box=<1-7>&state=<on/off>` - Turn LED on/off
- `GET /status` - Get device status
- `GET /discover` - For auto-discovery

### 6. Advanced: Store IP in Firestore

For production use, consider storing the IP address in Firestore so it persists across app restarts:

1. Add `ipAddress` field to MedicineBox model
2. Update `DeviceService.getDeviceIp()` to query Firestore
3. Store IP when device is first discovered

Example:
```dart
// In medicine_management_page.dart, after connecting device:
await _firestoreService.updateMedicineBox(
  box.copyWith(ipAddress: discoveredIp),
);
```

## Testing Checklist

- [ ] Device powers on and connects to WiFi
- [ ] Serial Monitor shows IP address
- [ ] Can access `http://<ip>/status` in browser
- [ ] Device setup in app (manual or auto)
- [ ] Lightbulb icon appears for missed doses
- [ ] Tapping lightbulb makes correct LED blink
- [ ] Multiple boxes work independently
- [ ] Works across app restarts (if using Firestore IP storage)
