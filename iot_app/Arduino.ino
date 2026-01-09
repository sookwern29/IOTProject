#include <Arduino.h>
#include <ESP32Servo.h>
#include "HX711.h"
#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <PubSubClient.h>
#include <Preferences.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>

// ================= CONFIGURATION =================
const char* ssid = "Uhuk";
const char* password = "kam1234@";
const char* mqtt_server = "34.19.178.165"; 
const int mqtt_port = 1883;
const char* FIREBASE_PROJECT_ID = "smart-medicine-box-482122";
const char* FIRESTORE_HOST = "https://firestore.googleapis.com";

// ================= GLOBALS =================
Preferences preferences;
String boxId = "";           
String medicineBoxId = "";   

// Reminder Details (To preserve UI data structure)
String currentReminderId = "";
int currentReminderH = 0;
int currentReminderM = 0;
bool currentReminderEnabled = true;

WiFiClient espClient;
PubSubClient mqtt(espClient);
WebServer server(80);
Servo myServo;
HX711 scale;

// Pins
const int PIN_SERVO = 47, PIN_BUTTON = 4, PIN_BUZZER = 12, PIN_LED = 21;
const int PIN_HX711_DT = 48, PIN_HX711_SCK = 38;
const int BOX_LEDS[] = {0, 18, 16, 7, 6, 5, 17, 14};

// Settings
const float WEIGHT_THRESHOLD = 0.05; 

// State Variables
bool isBoxOpen = false, reminderActive = false;
float weightAtStart = 0.0;
int activeBoxNumber = 0; 
unsigned long lastFirestoreCheck = 0, lastReminderBuzz = 0, lastTakenTime = 0; 

const unsigned long POLL_INTERVAL = 30000; 
const unsigned long SYNC_COOLDOWN = 15000; 

// ================= FIRESTORE DISCOVERY & UPDATES =================

bool discoverMedicineBoxId() {
  Serial.println("\n--- 🧠 SCANNING FIRESTORE FOR ACTIVE RECORD ---");
  HTTPClient http;
  http.begin(String(FIRESTORE_HOST) + "/v1/projects/" + FIREBASE_PROJECT_ID + "/databases/(default)/documents:runQuery");
  http.addHeader("Content-Type", "application/json");
  
  String query = "{\"structuredQuery\":{\"from\":[{\"collectionId\":\"medicineBox\"}],\"where\":{\"fieldFilter\":{\"field\":{\"fieldPath\":\"deviceId\"},\"op\":\"EQUAL\",\"value\":{\"stringValue\":\"" + boxId + "\"}}}}}";
  
  int code = http.POST(query);
  if (code != 200) { http.end(); return false; }
  String resp = http.getString();
  http.end();

  String fallbackId = "";
  int searchPos = 0;
  while ((searchPos = resp.indexOf("/medicineBox/", searchPos)) != -1) {
    int start = searchPos + 13;
    int end = resp.indexOf("\"", start);
    String currentDocId = resp.substring(start, end);
    searchPos = end; 

    int nextDoc = resp.indexOf("/medicineBox/", searchPos);
    String docContent = (nextDoc == -1) ? resp.substring(searchPos) : resp.substring(searchPos, nextDoc);

    if (docContent.indexOf("\"overdue\"") != -1) {
      Serial.println("⭐ FOUND ACTIVE OVERDUE RECORD: " + currentDocId);
      medicineBoxId = currentDocId;
      return true; 
    }
    if (fallbackId == "") fallbackId = currentDocId;
  }

  if (fallbackId != "") { medicineBoxId = fallbackId; return true; }
  return false;
}

void updateFirestoreToTaken() {
  if (medicineBoxId == "") return;
  Serial.println("📝 SYNC: Updating full reminder structure to Cloud...");
  
  HTTPClient http;
  String url = String(FIRESTORE_HOST) + "/v1/projects/" + FIREBASE_PROJECT_ID + "/databases/(default)/documents/medicineBox/" + medicineBoxId + "?updateMask.fieldPaths=reminders";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  // Reconstruct the FULL structure so it stays in the "Completed" category in UI
  String payload = "{\"fields\":{\"reminders\":{\"arrayValue\":{\"values\":[{\"mapValue\":{\"fields\":{";
  payload += "\"status\":{\"stringValue\":\"completed\"},";
  payload += "\"id\":{\"stringValue\":\"" + currentReminderId + "\"},";
  payload += "\"hour\":{\"integerValue\":\"" + String(currentReminderH) + "\"},";
  payload += "\"minute\":{\"integerValue\":\"" + String(currentReminderM) + "\"},";
  payload += "\"isEnabled\":{\"booleanValue\":" + String(currentReminderEnabled ? "true" : "false") + "},";
  payload += "\"boxNumber\":{\"integerValue\":\"" + String(activeBoxNumber) + "\"}";
  payload += "}}}]}}}}";
  
  int code = http.PATCH(payload);
  if (code == 200) Serial.println("✅ Full Sync Successful. UI should now show 'Completed'.");
  else Serial.println("❌ Sync Error: " + String(code));
  http.end();
}

void analyzeReminders() {
  if (millis() - lastTakenTime < SYNC_COOLDOWN) return;
  if (medicineBoxId == "" && !discoverMedicineBoxId()) return;

  HTTPClient http;
  http.begin(String(FIRESTORE_HOST) + "/v1/projects/" + FIREBASE_PROJECT_ID + "/databases/(default)/documents/medicineBox/" + medicineBoxId);
  
  if (http.GET() == 200) {
    String resp = http.getString();
    if (resp.indexOf("\"overdue\"") != -1) {
      
      // --- CAPTURE DETAILS TO PRESERVE THEM LATER ---
      int idIdx = resp.indexOf("\"id\"");
      if (idIdx != -1) {
          int s = resp.indexOf("\"", resp.indexOf("\"stringValue\"", idIdx) + 14) + 1;
          int e = resp.indexOf("\"", s);
          currentReminderId = resp.substring(s, e);
      }
      int hIdx = resp.indexOf("\"hour\"");
      if (hIdx != -1) {
          int s = resp.indexOf("\"", resp.indexOf("\"integerValue\"", hIdx) + 15) + 1;
          int e = resp.indexOf("\"", s);
          currentReminderH = resp.substring(s, e).toInt();
      }
      int mIdx = resp.indexOf("\"minute\"");
      if (mIdx != -1) {
          int s = resp.indexOf("\"", resp.indexOf("\"integerValue\"", mIdx) + 15) + 1;
          int e = resp.indexOf("\"", s);
          currentReminderM = resp.substring(s, e).toInt();
      }
      int boxIdx = resp.indexOf("\"boxNumber\"");
      if (boxIdx != -1) {
        int s = resp.indexOf("\"", resp.indexOf("\"integerValue\"", boxIdx) + 15) + 1;
        int e = resp.indexOf("\"", s);
        activeBoxNumber = resp.substring(s, e).toInt();
        
        if (!reminderActive && !isBoxOpen) {
           Serial.println("🚨 ALERT: Medicine " + currentReminderId + " is OVERDUE!");
           reminderActive = true;
           digitalWrite(BOX_LEDS[activeBoxNumber], HIGH);
        }
      }
    } else if (reminderActive) {
      reminderActive = false;
      noTone(PIN_BUZZER);
      for(int i=1; i<=7; i++) digitalWrite(BOX_LEDS[i], LOW);
    }
  }
  http.end();
}

// ================= HARDWARE ACTIONS =================

void openBox() {
  if (isBoxOpen) return;
  discoverMedicineBoxId(); // Sync before opening
  Serial.println("\n🔓 Opening Box. Capturing weight...");
  myServo.write(90);
  isBoxOpen = true;
  digitalWrite(PIN_LED, HIGH);
  delay(1500); 
  weightAtStart = scale.get_units(20); 
  Serial.printf("⚖️ START WEIGHT: %.2fg\n", weightAtStart);
}

void closeBox() {
  if (!isBoxOpen) return;
  Serial.println("🔒 Closing Box. Finalizing results...");
  myServo.write(0);
  delay(1500); 
  
  float weightAtEnd = scale.get_units(20);
  float weightLoss = weightAtStart - weightAtEnd;
  
  Serial.printf("⚖️ END WEIGHT: %.2fg | LOSS: %.2fg\n", weightAtEnd, weightLoss);

  isBoxOpen = false;
  digitalWrite(PIN_LED, LOW);
  
  if (weightLoss >= WEIGHT_THRESHOLD) {
    Serial.println("💊 SUCCESS: Medicine taken. Updating Cloud...");
    reminderActive = false;
    noTone(PIN_BUZZER);
    for(int i=1; i<=7; i++) digitalWrite(BOX_LEDS[i], LOW);
    
    lastTakenTime = millis(); 
    updateFirestoreToTaken();
    medicineBoxId = ""; // Clear for next scan
  } else {
    Serial.println("⚠️ WARNING: No medicine removed. Alarm will resume.");
  }
}

// ================= CORE =================

void setup() {
  Serial.begin(115200);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_LED, OUTPUT);
  for(int i=1; i<=7; i++) pinMode(BOX_LEDS[i], OUTPUT);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.println(" Connected!");

  configTime(8 * 3600, 0, "pool.ntp.org", "time.nist.gov"); // UTC+8

  String mac = WiFi.macAddress(); mac.replace(":", "");
  boxId = mac.substring(6); 
  Serial.println("🆔 DEVICE ID: " + boxId);

  myServo.attach(PIN_SERVO);
  myServo.write(0);
  scale.begin(PIN_HX711_DT, PIN_HX711_SCK);
  scale.set_scale(414.0);
  scale.tare();

  server.begin();
  Serial.println("🚀 SYSTEM ONLINE.");
}

void loop() {
  server.handleClient();
  if (!mqtt.connected()) mqtt.connect(boxId.c_str());
  mqtt.loop();

  analyzeReminders();

  if (reminderActive && !isBoxOpen) {
    if (millis() - lastReminderBuzz > 4000) {
      lastReminderBuzz = millis();
      tone(PIN_BUZZER, 1000, 500);
    }
  } else {
    noTone(PIN_BUZZER); 
  }

  static bool lastBtn = HIGH;
  bool btn = digitalRead(PIN_BUTTON);
  if (btn == LOW && lastBtn == HIGH) { 
    delay(50);
    if (isBoxOpen) closeBox(); else openBox();
  }
  lastBtn = btn;
}