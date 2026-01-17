# MongoDB Backend API Endpoints Required

This document lists all the backend endpoints needed for the IoT Medicine Box app to work with MongoDB Atlas.

## Base URL
```
https://smartmed-mongo-api-1007306144996.asia-southeast1.run.app
```

---

## 📦 Medicine Box Endpoints

### 1. Get All Medicine Boxes
**Endpoint:** `GET /medicineBoxes`  
**Description:** Retrieve all medicine boxes for the current user  
**Response:**
```json
[
  {
    "_id": "box123",
    "boxNumber": 1,
    "name": "Aspirin",
    "medicineType": "prescription",
    "deviceId": "device001",
    "reminders": [
      {
        "id": "reminder1",
        "hour": 8,
        "minute": 0,
        "daysOfWeek": [1, 2, 3, 4, 5],
        "isEnabled": true,
        "status": "pending"
      }
    ],
    "userId": "user123"
  }
]
```

### 2. Get Single Medicine Box
**Endpoint:** `GET /medicineBoxes/:id`  
**Description:** Get a specific medicine box by ID  
**Response:** Single medicine box object

### 3. Create Medicine Box
**Endpoint:** `POST /medicineBoxes`  
**Body:**
```json
{
  "id": "box123",
  "boxNumber": 1,
  "name": "Aspirin",
  "medicineType": "prescription",
  "deviceId": "device001",
  "reminders": [],
  "userId": "user123"
}
```

### 4. Update Medicine Box
**Endpoint:** `PUT /medicineBoxes/:id`  
**Body:** Complete medicine box object with updates

### 5. Delete Medicine Box
**Endpoint:** `DELETE /medicineBoxes/:id`  
**Description:** Delete a medicine box

---

## 💊 Medicine Records Endpoints

### 6. Create Record ✅ (Already implemented)
**Endpoint:** `POST /createRecord`  
**Body:**
```json
{
  "recordId": "rec123",
  "deviceId": "device001",
  "boxNumber": 1,
  "medicineName": "Aspirin",
  "medicineType": "prescription",
  "medicineBoxId": "box123",
  "scheduledTime": "2026-01-17T08:00:00.000Z",
  "status": "pending",
  "userId": "user123"
}
```

### 7. Get Records ✅ (Already implemented)
**Endpoint:** `POST /getRecords`  
**Body:**
```json
{
  "deviceId": "device001"
}
```

### 8. Update Record ✅ (Already implemented)
**Endpoint:** `POST /updateRecord`  
**Body:**
```json
{
  "recordId": "rec123",
  "status": "completed",
  "takenTime": "2026-01-17T08:05:00.000Z"
}
```

### 9. Delete Record ✅ (Already implemented)
**Endpoint:** `POST /deleteRecord`  
**Body:**
```json
{
  "recordId": "rec123"
}
```

### 10. Get Today's Doses
**Endpoint:** `GET /doses/today`  
**Description:** Get all medicine doses scheduled for today  
**Response:** Array of medicine records for today

### 11. Get Records in Date Range
**Endpoint:** `POST /getRecordsInRange`  
**Body:**
```json
{
  "startDate": "2026-01-01T00:00:00.000Z",
  "endDate": "2026-01-31T23:59:59.000Z",
  "userId": "user123"
}
```
**Response:** Array of medicine records within the date range

### 12. Auto-Complete Record from Device
**Endpoint:** `POST /autoCompleteRecord`  
**Description:** Automatically mark a record as completed when device detects medicine taken  
**Body:**
```json
{
  "deviceId": "device001",
  "boxNumber": 1
}
```

---

## 🗑️ Bulk Operations

### 13. Delete Future Records for Reminder
**Endpoint:** `POST /deleteFutureRecords`  
**Description:** Delete all future scheduled records for a specific reminder (used when reminder is deleted/disabled)  
**Body:**
```json
{
  "medicineBoxId": "box123",
  "reminderId": "reminder1"
}
```

### 14. Generate Records for Reminder
**Endpoint:** `POST /generateRecords`  
**Description:** Generate scheduled medicine records for the next 30 days based on reminder schedule  
**Body:**
```json
{
  "medicineBoxId": "box123",
  "boxNumber": 1,
  "medicineName": "Aspirin",
  "medicineType": "prescription",
  "deviceId": "device001",
  "reminder": {
    "id": "reminder1",
    "hour": 8,
    "minute": 0,
    "daysOfWeek": [1, 2, 3, 4, 5],
    "isEnabled": true
  },
  "userId": "user123"
}
```

### 15. Update All Reminder Statuses
**Endpoint:** `POST /updateReminderStatuses`  
**Description:** Update status of all reminders (completed/pending) based on current time  
**Body:** Empty or userId

---

## 🔌 Device Management Endpoints

### 16. Save Device
**Endpoint:** `POST /saveDevice`  
**Body:**
```json
{
  "deviceId": "device001",
  "ip": "192.168.1.100",
  "name": "Smart Medicine Box #1",
  "lastSeen": "2026-01-17T10:00:00.000Z"
}
```

### 17. Get Device
**Endpoint:** `POST /getDevice`  
**Body:**
```json
{
  "deviceId": "device001"
}
```
**Response:**
```json
{
  "deviceId": "device001",
  "ip": "192.168.1.100",
  "name": "Smart Medicine Box #1",
  "lastSeen": "2026-01-17T10:00:00.000Z"
}
```

---

## 🔄 Implementation Priority

### High Priority (App won't work without these):
1. ✅ POST /createRecord
2. ✅ POST /getRecords  
3. ✅ POST /updateRecord
4. ✅ POST /deleteRecord
5. ❌ GET /medicineBoxes
6. ❌ GET /medicineBoxes/:id
7. ❌ POST /medicineBoxes
8. ❌ PUT /medicineBoxes/:id
9. ❌ DELETE /medicineBoxes/:id
10. ❌ GET /doses/today

### Medium Priority (Important features):
11. ❌ POST /getRecordsInRange (for adherence reports)
12. ❌ POST /autoCompleteRecord (for MQTT auto-completion)
13. ❌ POST /saveDevice
14. ❌ POST /getDevice

### Low Priority (Nice to have):
15. ❌ POST /generateRecords
16. ❌ POST /deleteFutureRecords
17. ❌ POST /updateReminderStatuses

---

## 💡 Backend Implementation Tips

1. **Collections Needed:**
   - `medicineBoxes` - Store medicine box configurations
   - `medicineRecords` - Store dose records
   - `devices` - Store device information

2. **Add these routes to your Cloud Run function:**
```javascript
switch (req.path) {
  case "/createRecord": { /* existing */ }
  case "/getRecords": { /* existing */ }
  case "/updateRecord": { /* existing */ }
  case "/deleteRecord": { /* existing */ }
  
  // Add these:
  case "/medicineBoxes": {
    if (req.method === 'GET') { /* get all */ }
    if (req.method === 'POST') { /* create */ }
  }
  case "/medicineBoxes/:id": {
    if (req.method === 'GET') { /* get one */ }
    if (req.method === 'PUT') { /* update */ }
    if (req.method === 'DELETE') { /* delete */ }
  }
  case "/doses/today": { /* get today's doses */ }
  case "/getRecordsInRange": { /* date range query */ }
  case "/saveDevice": { /* save device */ }
  case "/getDevice": { /* get device */ }
  case "/autoCompleteRecord": { /* auto complete */ }
  // ... etc
}
```

3. **Query Examples:**
```javascript
// Get today's doses
const today = new Date();
today.setHours(0, 0, 0, 0);
const tomorrow = new Date(today);
tomorrow.setDate(tomorrow.getDate() + 1);

const todayDoses = await db.collection('medicineRecords')
  .find({
    scheduledTime: {
      $gte: today,
      $lt: tomorrow
    }
  })
  .toArray();
```

---

## 📝 Notes

- All endpoints should accept and return JSON
- Add proper error handling and validation
- Consider adding authentication tokens to headers
- Use MongoDB indexes on frequently queried fields (deviceId, scheduledTime, userId)
