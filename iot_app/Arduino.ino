#include <Arduino.h>
#include <ESP32Servo.h>
#include "HX711.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <time.h>
#include <vector>

// ================= CONFIG =================
const char* ssid = "Joe97178";
const char* password = "JW0509SB";

const char* API_BASE_URL =
  "https://smartmed-mongo-api-1007306144996.asia-southeast1.run.app";

// ================= HARDWARE =================
Servo myServo;
HX711 scale;

const int PIN_SERVO = 47;
const int PIN_BUTTON = 4;
const int PIN_LED = 21;
const int PIN_BUZZER = 12;
const int PIN_HX711_DT = 48;
const int PIN_HX711_SCK = 38;

const float WEIGHT_THRESHOLD = 0.05;

// ================= STATE =================
String boxId = "";                 // medicineBoxId
String activeRecordId = "";        // record_ or temp_ doc ID
int activeBoxNumber = 0;

bool isBoxOpen = false;
float weightAtStart = 0.0;

// ================= DATA STRUCT =================
struct RecordInfo {
  String docId;
  String logicalKey;   // boxId + reminderId
  bool isTemp;
  bool isCompleted;
  bool isOverdue;
  int reminderHour;
  int reminderMinute;
};

// ================= UTILS =================
String extractLogicalKey(const String& docId) {
  // prefix_boxId_reminderId_timestamp
  int first = docId.indexOf('_');
  int second = docId.indexOf('_', first + 1);
  int third = docId.indexOf('_', second + 1);
  return docId.substring(first + 1, third); // boxId_reminderId
}

// ================= FIRESTORE QUERY =================
bool fetchMedicineRecords(String& response) {
  HTTPClient http;
  http.begin(String(API_BASE_URL) + "/getRecords");
  http.addHeader("Content-Type", "application/json");

  String payload =
    "{ \"deviceId\": \"" + boxId + "\" }";

  int code = http.POST(payload);
  if (code != 200) {
    Serial.println("❌ API getRecords failed");
    http.end();
    return false;
  }

  response = http.getString();
  http.end();
  return true;
}

// ================= RECORD EXTRACTION =================
void extractRecords(const String& resp, std::vector<RecordInfo>& records) {
  int pos = 0;

  while ((pos = resp.indexOf("/medicineRecords/", pos)) != -1) {
    int start = pos + 17;
    int end = resp.indexOf("\"", start);
    String docId = resp.substring(start, end);
    pos = end;

    int next = resp.indexOf("/medicineRecords/", pos);
    String doc = (next == -1) ? resp.substring(pos) : resp.substring(pos, next);

    RecordInfo r;
    r.docId = docId;
    r.logicalKey = extractLogicalKey(docId);
    r.isTemp = docId.startsWith("temp_");
    r.isCompleted = doc.indexOf("\"completed\"") != -1;
    r.isOverdue = doc.indexOf("\"overdue\"") != -1;

    // reminderHour
    int hIdx = doc.indexOf("\"reminderHour\"");
    r.reminderHour = (hIdx != -1)
      ? doc.substring(doc.indexOf(":", hIdx) + 1).toInt()
      : 0;

    // reminderMinute
    int mIdx = doc.indexOf("\"reminderMinute\"");
    r.reminderMinute = (mIdx != -1)
      ? doc.substring(doc.indexOf(":", mIdx) + 1).toInt()
      : 0;

    // boxNumber
    int boxIdx = doc.indexOf("\"boxNumber\"");
    if (boxIdx != -1) {
      activeBoxNumber = doc.substring(doc.indexOf(":", boxIdx) + 1).toInt();
    }

    records.push_back(r);
  }
}

// ================= RECORD SELECTION =================
String selectBestRecord(const std::vector<RecordInfo>& records) {
  struct tm t;
  getLocalTime(&t);
  int nowMin = t.tm_hour * 60 + t.tm_min;

  long minDiff = 999999;
  String bestUpcoming = "";

  // 1️⃣ OVERDUE temp_
  for (auto& r : records)
    if (r.isTemp && r.isOverdue && !r.isCompleted)
      return r.docId;

  // 2️⃣ OVERDUE record_
  for (auto& r : records)
    if (!r.isTemp && r.isOverdue && !r.isCompleted)
      return r.docId;

  // 3️⃣ NEAREST UPCOMING temp_
  for (auto& r : records) {
    if (r.isCompleted) continue;
    int sched = r.reminderHour * 60 + r.reminderMinute;
    int diff = sched - nowMin;
    if (diff < 0) diff += 1440;

    if (r.isTemp && diff < minDiff) {
      minDiff = diff;
      bestUpcoming = r.docId;
    }
  }

  if (bestUpcoming != "") return bestUpcoming;

  // 4️⃣ NEAREST UPCOMING record_
  for (auto& r : records) {
    if (r.isCompleted) continue;
    int sched = r.reminderHour * 60 + r.reminderMinute;
    int diff = sched - nowMin;
    if (diff < 0) diff += 1440;

    if (!r.isTemp && diff < minDiff) {
      minDiff = diff;
      bestUpcoming = r.docId;
    }
  }

  return bestUpcoming;
}

// ================= FIRESTORE UPDATE =================
void updateRecordToCompleted(const String& recordId) {
  HTTPClient http;
  http.begin(String(API_BASE_URL) + "/markCompleted");
  http.addHeader("Content-Type", "application/json");

  struct tm timeinfo;
  getLocalTime(&timeinfo);
  char timeBuf[30];
  strftime(timeBuf, sizeof(timeBuf), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);

  String payload =
    "{"
      "\"recordId\":\"" + recordId + "\","
      "\"takenTime\":\"" + String(timeBuf) + "\""
    "}";

  int code = http.POST(payload);

  if (code == 200)
    Serial.println("✅ Record marked completed");
  else
    Serial.println("❌ Update failed");

  http.end();
}

// ================= HARDWARE =================
void openBox() {
  if (isBoxOpen) return;

  Serial.println("\n🔓 BOX OPENED");

  // Open the box physically first
  myServo.write(90);
  isBoxOpen = true;
  digitalWrite(PIN_LED, HIGH);
  delay(1500);

  weightAtStart = scale.get_units(20);
  Serial.printf("⚖️ START WEIGHT: %.2fg\n", weightAtStart);

  // Then check for medicine records
  String resp;
  if (!fetchMedicineRecords(resp)) {
    Serial.println("⚠️ Box opened but couldn't fetch records");
    return;
  }

  std::vector<RecordInfo> records;
  extractRecords(resp, records);

  activeRecordId = selectBestRecord(records);

  if (activeRecordId == "") {
    Serial.println("✅ No medicine needed now (box still open)");
  } else {
    Serial.println("🎯 Selected Record: " + activeRecordId);
  }
}

void closeBox() {
  if (!isBoxOpen) return;

  Serial.println("🔒 BOX CLOSED");

  myServo.write(0);
  delay(1500);

  float endWeight = scale.get_units(20);
  float loss = weightAtStart - endWeight;

  Serial.printf("⚖️ END WEIGHT: %.2fg | LOSS: %.2fg\n", endWeight, loss);

  isBoxOpen = false;
  digitalWrite(PIN_LED, LOW);

  if (loss >= WEIGHT_THRESHOLD && activeRecordId != "") {
    Serial.println("💊 Medicine taken");
    updateRecordToCompleted(activeRecordId);
    activeRecordId = "";
  } else {
    Serial.println("⚠️ No medicine removed");
  }
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200);

  pinMode(PIN_BUTTON, INPUT_PULLUP);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);

  Serial.println("\n📡 Connecting to WiFi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\n✅ WiFi connected");
  Serial.println("🌐 IP: " + WiFi.localIP().toString());

  configTime(8 * 3600, 0, "pool.ntp.org", "time.nist.gov");

  String mac = WiFi.macAddress();
  mac.replace(":", "");
  boxId = mac.substring(6);
  Serial.println("🆔 MEDICINE BOX ID: " + boxId);

  myServo.attach(PIN_SERVO);
  myServo.write(0);

  scale.begin(PIN_HX711_DT, PIN_HX711_SCK);
  scale.set_scale(414.0);
  scale.tare();

  Serial.println("🚀 SYSTEM READY");
}

// ================= LOOP =================
void loop() {
  static bool lastBtn = HIGH;
  bool btn = digitalRead(PIN_BUTTON);

  if (btn == LOW && lastBtn == HIGH) {
    delay(50);
    if (isBoxOpen) closeBox();
    else openBox();
  }
  lastBtn = btn;
}
