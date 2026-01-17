#include <Arduino.h>
#include <ESP32Servo.h>
#include "HX711.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <WebServer.h>
#include <time.h>
#include <vector>
#include <ArduinoJson.h>

// ================= CONFIG =================
const char* ssid = "Joe97178";
const char* password = "JW0509SB";
const char* API_BASE_URL = "https://smartmed-mongo-api-3qu7lwzn2q-as.a.run.app";

// ================= HARDWARE =================
Servo myServo;
HX711 scale;
WebServer server(80);

const int PIN_SERVO = 47;
const int PIN_BUTTON = 4;
const int PIN_LED = 21;
const int PIN_BUZZER = 12;
const int PIN_HX711_DT = 48;
const int PIN_HX711_SCK = 38;
const float WEIGHT_THRESHOLD = 0.50; // Adjusted to 0.5g for better stability

// ================= STATE =================
String boxId = "";
String activeRecordId = "";
bool isBoxOpen = false;
float weightAtStart = 0.0;

// ================= DATA STRUCT =================
struct RecordInfo {
  String recordId;
  String status;    // Store raw status: "upcoming", "overdue", "completed"
  int reminderHour;
  int reminderMinute;
};

// ================= API CALLS =================
bool fetchMedicineRecords(String& response) {
  HTTPClient http;
  http.begin(String(API_BASE_URL) + "/getRecords");
  http.addHeader("Content-Type", "application/json");

  // IMPORTANT: Ensure your MongoDB uses this specific boxId format
  String payload = "{\"deviceId\": \"" + boxId + "\"}";

  int code = http.POST(payload);
  if (code != 200) {
    Serial.printf("❌ API getRecords failed (Code: %d)\n", code);
    http.end();
    return false;
  }

  response = http.getString();
  http.end();
  return true;
}

void extractRecords(const String& resp, std::vector<RecordInfo>& records) {
  DynamicJsonDocument doc(8192);
  DeserializationError error = deserializeJson(doc, resp);
  if (error) {
    Serial.println("❌ JSON parse failed");
    return;
  }

  JsonArray arr = doc.as<JsonArray>();
  for (JsonObject obj : arr) {
    RecordInfo r;
    r.recordId = obj["recordId"].as<String>();
    r.status = obj["status"] | "upcoming";

    const char* timeStr = obj["scheduledTime"]; // Expected: "2023-10-25T14:30:00"
    if (timeStr) {
      struct tm tm_struct;
      // Using simple parsing if strptime is finicky
      sscanf(timeStr, "%*d-%*d-%*dT%d:%d", &r.reminderHour, &r.reminderMinute);
    }
    records.push_back(r);
  }
  Serial.printf("📦 Fetched %d records from backend\n", records.size());
}

// ================= IMPROVED SELECTION LOGIC =================
String selectBestRecord(const std::vector<RecordInfo>& records) {
  struct tm now;
  if (!getLocalTime(&now)) {
    Serial.println("❌ Time not synced yet!");
    return "";
  }

  int nowMin = now.tm_hour * 60 + now.tm_min;
  String overdueId = "";
  String upcomingId = "";
  int bestUpcomingDiff = 1440;

  for (auto& r : records) {
    if (r.status == "completed") continue;

    // 1. Priority: If it's already marked "overdue" by the backend, take it
    if (r.status == "overdue") {
      overdueId = r.recordId; 
      break; 
    }

    // 2. Secondary: Find the upcoming record closest to now
    int sched = r.reminderHour * 60 + r.reminderMinute;
    int diff = sched - nowMin;

    // Look for records within a 2-hour window (either 1 hour late or 1 hour early)
    if (abs(diff) < 60) {
        upcomingId = r.recordId;
    }
  }

  if (overdueId != "") return overdueId;
  return upcomingId; 
}

void updateRecordToCompleted(const String& recordId) {
  HTTPClient http;
  http.begin(String(API_BASE_URL) + "/updateRecord");
  http.addHeader("Content-Type", "application/json");

  String payload = "{\"recordId\":\"" + recordId + "\",\"status\":\"completed\"}";
  int code = http.POST(payload);
  
  if (code == 200) Serial.println("✅ Backend Updated: COMPLETED");
  else Serial.printf("❌ Backend Update Failed: %d\n", code);
  
  http.end();
}

// ================= HANDLERS =================
void handleDiscover() {
  String json = "{\"boxId\":\"" + boxId + "\",\"ip\":\"" + WiFi.localIP().toString() + "\"}";
  server.send(200, "application/json", json);
}

void openBox() {
  if (isBoxOpen) return;
  Serial.println("\n🔓 OPENING BOX...");

  // 1. Physical Action
  myServo.write(90);
  digitalWrite(PIN_LED, HIGH);
  isBoxOpen = true;
  delay(1000); 

  // 2. Weighing
  weightAtStart = scale.get_units(20);
  Serial.printf("⚖️ START WEIGHT: %.2fg\n", weightAtStart);

  // 3. Identification
  String resp;
  if (fetchMedicineRecords(resp)) {
    std::vector<RecordInfo> records;
    extractRecords(resp, records);
    activeRecordId = selectBestRecord(records);

    if (activeRecordId != "") {
      Serial.println("🎯 TARGET RECORD: " + activeRecordId);
    } else {
      Serial.println("⚠️ No pending/overdue records found for this time.");
    }
  }
}

void closeBox() {
  if (!isBoxOpen) return;
  Serial.println("🔒 CLOSING BOX...");

  myServo.write(0);
  digitalWrite(PIN_LED, LOW);
  delay(1000);

  float endWeight = scale.get_units(20);
  float loss = weightAtStart - endWeight;
  isBoxOpen = false;

  Serial.printf("⚖️ END WEIGHT: %.2fg | LOSS: %.2fg\n", endWeight, loss);

  if (loss >= WEIGHT_THRESHOLD && activeRecordId != "") {
    Serial.println("💊 Medicine detected as TAKEN.");
    updateRecordToCompleted(activeRecordId);
  } else {
    Serial.println("ℹ️ No weight change or no record selected.");
  }
  activeRecordId = "";
}

// ================= SETUP/LOOP =================
void setup() {
  Serial.begin(115200);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.println("\n✅ WiFi Connected");

  // Sync Time
  configTime(8 * 3600, 0, "pool.ntp.org"); 

  // ID Generation (Make sure this matches your DB exactly)
  String mac = WiFi.macAddress();
  mac.replace(":", "");
  boxId = mac.substring(6); 
  Serial.println("🆔 BOX ID: " + boxId);

  myServo.attach(PIN_SERVO);
  myServo.write(0);
  scale.begin(PIN_HX711_DT, PIN_HX711_SCK);
  scale.set_scale(414.0);
  scale.tare();

  server.on("/discover", handleDiscover);
  server.begin();
  Serial.println("🚀 SYSTEM READY");
}

void loop() {
  server.handleClient();
  
  static bool lastBtn = HIGH;
  bool btn = digitalRead(PIN_BUTTON);
  if (btn == LOW && lastBtn == HIGH) {
    delay(50);
    if (isBoxOpen) closeBox();
    else openBox();
  }
  lastBtn = btn;
}