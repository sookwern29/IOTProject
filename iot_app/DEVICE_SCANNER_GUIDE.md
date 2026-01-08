# Device Scanner Guide

## Overview
The Device Scanner page now supports both **WiFi/IP scanning** and **Bluetooth scanning** to connect your ESP32 medicine box.

## Accessing the Device Scanner
1. Open the app
2. Tap the **"Devices"** tab in the bottom navigation (3rd icon)
3. Choose between **WiFi/IP** or **Bluetooth** tabs

---

## WiFi/IP Scanner (Recommended for ESP32)

### Auto-Discover Devices
1. Make sure your ESP32 is:
   - Powered on
   - Connected to the same WiFi network as your phone
   - Running the Arduino code with `/discover` endpoint

2. Tap **"Start Network Scan"**
   - Scans IP range: 192.168.1.1 - 192.168.1.254
   - Takes 30-60 seconds
   - Shows progress indicator

3. **Discovered Devices** will appear with:
   - Device name: "Smart Medicine Box"
   - IP address (e.g., 192.168.1.100)
   - Green checkmark icon

4. Actions for discovered devices:
   - **Link to Box**: Connect device to a specific medicine box (Box 1-7)
   - **Save**: Save device configuration for manual use

### Manual Configuration
If auto-discovery fails:

1. **Find ESP32 IP Address**:
   - Check your router's connected devices
   - Use Arduino Serial Monitor
   - Use network scanner app

2. **Enter Device IP**:
   - Example: `192.168.1.100`

3. **Enter Device ID** (optional):
   - Leave blank for auto-generated ID
   - Or use custom ID like `box1_device`

4. **Test Connection**:
   - Tap **"Test Connection"**
   - Shows success dialog with device info
   - Shows error if device unreachable

5. **Save Device**:
   - Tap **"Save Device"**
   - Device configuration stored locally
   - Can be linked to medicine boxes

---

## Bluetooth Scanner

### Scanning for Bluetooth Devices
1. Switch to **Bluetooth** tab
2. Grant Bluetooth permissions if prompted
3. Tap **"Scan for Devices"**
4. Available devices will appear in list

### Connecting to Bluetooth Device
1. Tap **"Connect"** on desired device
2. Connection status shown at top
3. Tap **X** to disconnect

**Note**: ESP32 in this project uses WiFi/HTTP, not Bluetooth. Use WiFi/IP tab for medicine box connection.

---

## Linking Devices to Medicine Boxes

### Why Link Devices?
Linking a discovered ESP32 device to a medicine box enables:
- Automatic LED control from "Today's Doses" page
- Lightbulb icon triggers corresponding LED
- Box 1 → LED on GPIO 18
- Box 2 → LED on GPIO 16
- Box 3-7 → Corresponding GPIO pins

### How to Link
1. Discover or manually configure ESP32 device
2. Tap **"Link to Box"**
3. Select medicine box from list (Box 1-7)
4. Device IP saved with box ID
5. Now lightbulb icons on doses page will work!

---

## Troubleshooting

### "No ESP32 devices found on network"
- ✅ Verify ESP32 is powered on
- ✅ Check ESP32 is connected to WiFi (check Serial Monitor)
- ✅ Ensure phone on same WiFi network
- ✅ Try manual IP entry
- ✅ Check router firewall settings

### "Connection Failed"
- ✅ Ping the IP address from another device
- ✅ Check ESP32 Serial Monitor for errors
- ✅ Verify `/discover` and `/status` endpoints work
- ✅ Restart ESP32 and try again

### Scan Takes Too Long
- Network scan checks 254 IPs (can take 30-60 seconds)
- Use manual IP entry for faster setup
- Check only essential network range

### Device Found But Won't Link
- ✅ Ensure medicine boxes created in app
- ✅ Check box numbers configured (1-7)
- ✅ Verify Firestore connection
- ✅ Try saving device manually first

---

## Testing the Integration

### After Linking Device
1. Go to **"Today" tab**
2. Find a medicine dose with lightbulb icon
3. Tap the lightbulb icon
4. ESP32 LED should blink 3 times
5. Success message appears

### Verification Checklist
- [ ] ESP32 powers on and connects to WiFi
- [ ] Device scanner finds ESP32 IP
- [ ] Test connection shows success
- [ ] Device linked to correct medicine box
- [ ] Lightbulb tap triggers LED blink
- [ ] Correct LED lights up (Box 1 = LED 1, etc.)

---

## Network Configuration Tips

### Static IP (Recommended)
Configure ESP32 with static IP for reliable connection:

```cpp
IPAddress local_IP(192, 168, 1, 100);
IPAddress gateway(192, 168, 1, 1);
IPAddress subnet(255, 255, 255, 0);

WiFi.config(local_IP, gateway, subnet);
```

### Router Settings
- Reserve IP in DHCP settings for ESP32 MAC address
- Disable AP isolation
- Allow local network communication

### Subnet Variations
If your network uses different subnet:
- Common: 192.168.0.x → Modify scanner code
- Custom: 10.0.0.x → Update `_scanNetwork()` method
- Edit subnet prefix in scanning function

---

## Advanced Usage

### Multiple ESP32 Devices
- Each medicine box can have its own ESP32
- Link different IPs to different boxes
- Box 1 → ESP32 at 192.168.1.100
- Box 2 → ESP32 at 192.168.1.101
- etc.

### Remote Access (Future Enhancement)
Currently supports **local network only**. For remote access:
- Use port forwarding
- Set up VPN
- Use cloud relay service
- Implement MQTT for IoT communication

---

## Support

### Check Logs
- Arduino Serial Monitor (ESP32)
- Flutter console (app logs)
- Device scanner status messages

### Common Issues
| Issue | Solution |
|-------|----------|
| No devices found | Check WiFi connection |
| Connection timeout | Verify ESP32 IP address |
| LED won't blink | Check GPIO pin mapping |
| Wrong LED lights up | Verify box number mapping |
| App crashes | Check Flutter console for errors |

---

## Quick Reference

### Box to LED Mapping
| Box | GPIO Pin | LED Number |
|-----|----------|------------|
| 1   | 18       | LED 1      |
| 2   | 16       | LED 2      |
| 3   | 7        | LED 3      |
| 4   | 6        | LED 4      |
| 5   | 5        | LED 5      |
| 6   | 17       | LED 6      |
| 7   | 14       | LED 7      |

### HTTP Endpoints
- `GET /discover` - Device identification
- `GET /status` - Device status info
- `GET /blink?box=1&times=3` - Blink LED
- `GET /led?box=1&state=on` - Set LED state

### Default Settings
- Scan range: 192.168.1.1-254
- Connection timeout: 3 seconds
- Blink times: 3 (configurable)
- LED state: off (after blink)
