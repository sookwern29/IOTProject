# 💊 Smart Medicine Box

A Flutter mobile application for IoT-based smart medicine box system with MongoDB cloud connectivity and customizable reminder features.

---

## 📋 Overview

This application allows users to:

- 🔗 **Connect and manage smart medicine boxes** via Bluetooth Low Energy (BLE)
- ⏰ **Set customizable reminder times** for medication schedules
- ☁️ **Sync with IoT devices and MongoDB cloud** for real-time data
- 📊 **Track medication schedules and adherence** with visual reports
- 🔍 **Find your device** by triggering LED indicators on the medicine box

---

## ✨ Features

### 📱 Mobile App Features

- **Smart Reminders**: Customize medication schedule with flexible time slots
- **Data Dashboard**: View medication adherence reports with interactive charts
- **Find My Device**: Locate your medicine box by triggering visual/audio alerts
- **WiFi Device Scanning**: Discover and connect to nearby medicine boxes

### 🔧 IoT Device Features

- **LED Indicators**: 7 compartment-specific LEDs + 1 external status LED
- **Servo Motor**: Automated compartment lock/unlock mechanism
- **Load Cell**: Weight-based pill detection (optional feature)
- **Button Input**: Manual override and interaction
- **WiFi Connectivity**: HTTPS communication with cloud backend

---

## 🏗️ Hardware Setup & Configuration

### Required Components

- **Cytron Maker Feather AIoT S3**
- **Breadboard**
- **Onpow Button**
- **SG90 Servo Motor**
- **HX711 Load Cell Amplifier** 
- **1kg Load Cell** 
- **LED** 
- **Resistors** 

### Wiring Diagram

#### Onpow Button

```
Left Leg  → Breadboard Negative Power Rail (GND)
Right Leg → A4 Pin of the Maker Port
```

#### SG90 Servo Motor

```
Brown cable  → Breadboard Negative Power Rail (GND)
Red cable    → Breadboard Positive Power Rail (VCC)
Orange cable → GPIO 47 Pin of the Maker Port
```

#### Load Cell + HX711

```
Load Cell:
  Red cable   → E+ Pin of HX711
  Black cable → E- Pin of HX711
  Grey cable  → A- Pin of HX711
  Green cable → A+ Pin of HX711

HX711:
  GND → Breadboard Negative Power Rail
  DT  → GPIO 38 Pin of the Maker Port
  SCK → GPIO 48 Pin of the Maker Port
  VCC → 3.3V Pin of the Maker Port
```

#### LED Configuration

| Compartment      | LED Pin (via Resistor)        | Cathode |
| ---------------- | ----------------------------- | ------- |
| LED 1 (Box 1)    | GPIO 18 (A8) through Resistor | GND     |
| LED 2 (Box 2)    | GPIO 16 (A9) through Resistor | GND     |
| LED 3 (Box 3)    | GPIO 7 (A5) through Resistor  | GND     |
| LED 4 (Box 4)    | GPIO 6 (A2) through Resistor  | GND     |
| LED 5 (Box 5)    | GPIO 5 (A3) through Resistor  | GND     |
| LED 6 (Box 6)    | GPIO 17 (A6) through Resistor | GND     |
| LED 7 (Box 7)    | GPIO 14 through Resistor      | GND     |
| **External LED** | GPIO 21 through Resistor      | GND     |

---

## 🚀 Software Setup

### Prerequisites

- **Flutter SDK**: 3.8.1 or higher
- **Dart SDK**: 3.8.1 or higher
- **Android Studio** or **VS Code** with Flutter extensions
- **Android device/emulator** (API 21+) 
- **MongoDB Atlas Account** (for cloud database)
- **Google Cloud Account** (for backend deployment)

### Installation Steps

1. **Clone the repository:**

   ```bash
   git clone https://github.com/sookwern29/IOTProject.git
   cd iot_app
   ```

2. **Install dependencies:**

   ```bash
   flutter pub get
   ```

3. **Configure MongoDB Backend:**
   - Set up MongoDB Atlas cluster
   - Deploy backend to Google Cloud Run (see Backend Setup section)
   - Update `mongodb_service.dart` with your backend URL:
     ```dart
     static const String baseUrl = 'https://smartmed-mongo-api-1007306144996.asia-southeast1.run.app';
     ```

4. **Run the app:**
   ```bash
   flutter run
   ```

---

## 📦 Dependencies

### Core Dependencies

#### State Management & Architecture

- **`provider: ^6.1.2`** - State management for app-wide data flow

#### Notifications

- **`flutter_local_notifications: ^18.0.1`** - Local push notifications for medication reminders
- **`timezone: ^0.9.4`** - Timezone support for scheduled notifications

#### Permission

- **`permission_handler: ^11.3.1`** - Runtime permissions for Bluetooth, notifications, and location

#### Networking & API

- **`http: ^1.1.0`** - HTTP client for REST API communication with MongoDB backend and IoT devices

#### Data Visualization

- **`fl_chart: ^0.69.0`** - Interactive charts for medication adherence reports

#### Local Storage

- **`shared_preferences: ^2.2.2`** - Persistent key-value storage for device configuration

#### Utilities

- **`intl: ^0.19.0`** - Internationalization and date/time formatting
- **`cupertino_icons: ^1.0.8`** - iOS-style icons

### Dev Dependencies

- **`flutter_test`** - Widget and unit testing framework
- **`flutter_lints: ^5.0.0`** - Recommended linting rules

---

## 🗄️ Backend Setup (MongoDB + Google Cloud Run)

### 1. MongoDB Atlas Configuration

1. Create a MongoDB Atlas account at https://www.mongodb.com/cloud/atlas
2. Create a new cluster (Free tier M0 works fine)
3. Create a database named `smartMedicineBox` with collections:
   - `users` - User authentication
   - `medicineBoxes` - Medicine box data with reminders
   - `medicineRecords` - Medication intake records
   - `devices` - IoT device configurations

4. Get your connection string:
   ```
   mongodb+srv://<username>:<do-contact-projectowner-for-the-password>@smartmed-cluster.tgq6zpd.mongodb.net/?retryWrites=true&w=majority
   ```

### 2. Deploy Backend to Google Cloud Run

1. **Install Google Cloud CLI:**

   ```bash
   gcloud init
   ```

2. **Navigate to backend directory:**

   ```bash
   cd <backend-directory>
   ```

3. **Set environment variables:**
   Create a `.env` file:

   ```env
   MONGO_URI=mongodb+srv://<username>:<password>@cluster0.xxxxx.mongodb.net/
   MONGO_DB_NAME=smartmed
   ```

4. **Deploy:**

   ```bash
   gcloud run deploy smartmed-mongo-api --source . --region asia-southeast1
   ```

5. **Copy the deployed URL** (e.g., `https://smartmed-mongo-api-xxxxx.run.app`)

### 3. Update Flutter App Configuration

Edit `lib/services/mongodb_service.dart`:

```dart
static const String baseUrl = 'https://smartmed-mongo-api-1007306144996.asia-southeast1.run.app';
```

---

## 📱 IoT Device Setup

### WiFi Configuration

1. **Upload Arduino sketch** (`Arduino.ino`) to Cytron Maker Feather AIoT S3
2. **Configure WiFi credentials** in the sketch:

   ```cpp
   const char* ssid = "Your_WiFi_SSID";
   const char* password = "Your_WiFi_Password";
   ```

3. **Set backend URL** in Arduino code:

   ```cpp
   const char* serverUrl = "https://smartmed-mongo-api-1007306144996.asia-southeast1.run.app";
   ```

4. **Upload and monitor** via Serial Monitor to get device IP address

### Device Discovery Options

#### Option A: Manual Configuration (Recommended)

1. Open Serial Monitor to find device IP (e.g., `192.168.1.100`)
2. In app, go to **Device Setup Helper** page
3. Enter:
   - **Device ID**: MAC-based ID from Serial Monitor
   - **IP Address**: Local IP address
4. Tap **Save Configuration**

#### Option B: Network Scan

1. Go to **Device Setup Helper** page
2. Tap **Scan Network**
3. App scans `192.168.1.1-254` to find your device
4. Auto-configures when found

---

## 🎯 Usage Guide

### 1. User Registration

- Open app → **Sign Up** → Enter email, password, and full name

### 2. Add Medicine Box

- Navigate to **Medicine Boxes** page
- Tap **+ Add Box**
- Fill in:
  - Medicine name
  - Box number (1-7)
  - Medicine type (prescription/OTC)
  - Device ID

### 3. Set Reminders

- Open a medicine box
- Tap **Add Reminder**
- Configure:
  - Time (hour:minute)
  - Days of week
  - Repeat pattern

### 4. Take Medication

- View **Today's Doses** page
- Detect **Weight Changes** 
- Status updates to **Completed** in database

### 5. Find Compartment

- Tap **💡 LED icon** on any dose
- Corresponding LED on medicine box will blink for 10 seconds

### 6. View Reports

- Navigate to **Adherence Report** page
- Select date range
- View interactive charts showing:
  - Total scheduled doses
  - Completed vs missed
  - Adherence percentage

---

## 🔧 Configuration Files

### `pubspec.yaml`

Contains all Flutter dependencies and app metadata.

### `BACKEND_INDEX_UPDATED.js`

Node.js backend with MongoDB driver. Key endpoints:

- `/auth/register` - User registration
- `/auth/login` - User authentication
- `/medicineBoxes` - CRUD operations for medicine boxes
- `/updateRecord` - Update medication intake status
- `/generateRecords` - Auto-generate records for reminders
- `/doses/today` - Get today's scheduled doses

### `Arduino.ino`

ESP32-S3 firmware for IoT device with HTTPS server and GPIO control.

---

## 🔐 Permissions Required

### Android (`AndroidManifest.xml`)
- `INTERNET` - API communication
- `POST_NOTIFICATIONS` - Medication reminders
