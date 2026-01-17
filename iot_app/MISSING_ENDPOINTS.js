// ================= ADD THESE TO YOUR index.js =================

// ================= GET TODAY'S DOSES =================
// ** CRITICAL - This is why reminders don't show in UI! **
if (path === "/doses/today" && method === "GET") {
  const recordsCol = database.collection("medicineRecords");
  
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);
  
  const endOfDay = new Date();
  endOfDay.setHours(23, 59, 59, 999);
  
  const todayRecords = await recordsCol
    .find({
      scheduledTime: {
        $gte: startOfDay,
        $lte: endOfDay
      }
    })
    .sort({ scheduledTime: 1 })
    .toArray();
  
  return res.json(todayRecords);
}

// ================= GET RECORDS IN DATE RANGE =================
if (path === "/getRecordsInRange" && method === "POST") {
  const { startDate, endDate, userId } = body;
  
  if (!startDate || !endDate) {
    return res.status(400).json({
      message: "startDate and endDate are required"
    });
  }
  
  const recordsCol = database.collection("medicineRecords");
  
  const records = await recordsCol
    .find({
      scheduledTime: {
        $gte: new Date(startDate),
        $lte: new Date(endDate)
      },
      ...(userId && { userId })
    })
    .sort({ scheduledTime: 1 })
    .toArray();
  
  return res.json(records);
}

// ================= DELETE FUTURE RECORDS FOR REMINDER =================
// ** IMPORTANT - Needed when editing/deleting reminders **
if (path === "/deleteFutureRecords" && method === "POST") {
  const { medicineBoxId, reminderId } = body;
  
  if (!medicineBoxId || !reminderId) {
    return res.status(400).json({
      message: "medicineBoxId and reminderId are required"
    });
  }
  
  const recordsCol = database.collection("medicineRecords");
  
  const now = new Date();
  
  const result = await recordsCol.deleteMany({
    medicineBoxId,
    reminderId,
    scheduledTime: { $gt: now },
    status: "upcoming"
  });
  
  return res.json({
    message: "Future records deleted",
    deletedCount: result.deletedCount
  });
}

// ================= AUTO COMPLETE RECORD FROM DEVICE =================
if (path === "/autoCompleteRecord" && method === "POST") {
  const { deviceId, boxNumber } = body;
  
  if (!deviceId || !boxNumber) {
    return res.status(400).json({
      message: "deviceId and boxNumber are required"
    });
  }
  
  const recordsCol = database.collection("medicineRecords");
  
  const now = new Date();
  const startOfDay = new Date(now);
  startOfDay.setHours(0, 0, 0, 0);
  
  // Find today's upcoming record for this box
  const record = await recordsCol.findOne({
    deviceId,
    boxNumber,
    scheduledTime: { $gte: startOfDay, $lte: now },
    status: "upcoming"
  });
  
  if (record) {
    await recordsCol.updateOne(
      { recordId: record.recordId },
      {
        $set: {
          status: "completed",
          takenTime: now
        }
      }
    );
    
    return res.json({
      message: "Record auto-completed",
      recordId: record.recordId
    });
  }
  
  return res.json({
    message: "No pending record found"
  });
}

// ================= UPDATE REMINDER STATUSES =================
// ** Optional - Updates past reminders to "missed" **
if (path === "/updateReminderStatuses" && method === "POST") {
  const recordsCol = database.collection("medicineRecords");
  
  const now = new Date();
  
  const result = await recordsCol.updateMany(
    {
      scheduledTime: { $lt: now },
      status: "upcoming"
    },
    {
      $set: { status: "missed" }
    }
  );
  
  return res.json({
    message: "Reminder statuses updated",
    updatedCount: result.modifiedCount
  });
}

// ================= PLACE THESE BEFORE THE "UNKNOWN ENDPOINT" HANDLER =================
