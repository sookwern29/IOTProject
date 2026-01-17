# 🔐 Fix Registration Error - Quick Setup

## Problem
Your app is trying to register users, but your MongoDB backend doesn't have authentication endpoints yet.

## Solution - Add Auth Endpoints to Your Backend

### Step 1: Install bcrypt in your Cloud Run project

```bash
# In your backend project directory
npm install bcryptjs
```

### Step 2: Update your `index.js`

Replace your current `index.js` with the complete code from `backend_auth_endpoints.js` OR add these two routes to your existing switch statement:

```javascript
case "/auth/register": {
  const { email, password, fullName } = req.body;
  
  if (!email || !password || !fullName) {
    return res.status(400).json({ 
      message: 'Email, password, and full name are required' 
    });
  }

  const usersCol = db.collection('users');
  
  const existingUser = await usersCol.findOne({ email: email.toLowerCase() });
  if (existingUser) {
    return res.status(400).json({ 
      message: 'User with this email already exists' 
    });
  }

  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash(password, salt);

  const newUser = {
    email: email.toLowerCase(),
    password: hashedPassword,
    fullName: fullName,
    createdAt: new Date(),
    lastLogin: new Date()
  };

  const result = await usersCol.insertOne(newUser);
  const token = Buffer.from(`${result.insertedId}:${Date.now()}`).toString('base64');

  return res.status(201).json({
    message: 'User registered successfully',
    userId: result.insertedId.toString(),
    email: email.toLowerCase(),
    fullName: fullName,
    token: token
  });
}

case "/auth/login": {
  const { email, password } = req.body;
  
  if (!email || !password) {
    return res.status(400).json({ 
      message: 'Email and password are required' 
    });
  }

  const usersCol = db.collection('users');
  
  const user = await usersCol.findOne({ email: email.toLowerCase() });
  if (!user) {
    return res.status(401).json({ 
      message: 'Invalid email or password' 
    });
  }

  const isMatch = await bcrypt.compare(password, user.password);
  if (!isMatch) {
    return res.status(401).json({ 
      message: 'Invalid email or password' 
    });
  }

  await usersCol.updateOne(
    { _id: user._id },
    { $set: { lastLogin: new Date() } }
  );

  const token = Buffer.from(`${user._id}:${Date.now()}`).toString('base64');

  return res.status(200).json({
    message: 'Login successful',
    userId: user._id.toString(),
    email: user.email,
    fullName: user.fullName,
    token: token
  });
}
```

### Step 3: Add bcrypt import at the top of index.js

```javascript
const { MongoClient } = require("mongodb");
const bcrypt = require('bcryptjs');  // ADD THIS LINE
```

### Step 4: Deploy to Cloud Run

```bash
# In your backend project directory
gcloud run deploy smartmed-mongo-api --source .
```

### Step 5: Test Registration

1. Restart your Flutter app
2. Try registering a new account
3. Should work now! ✅

---

## Alternative: Quick Test Without Backend Changes

If you want to test the app without implementing auth, you can temporarily bypass authentication:

**In `lib/main.dart`**, change:

```dart
home: _isLoading
    ? Scaffold(body: Center(child: CircularProgressIndicator()))
    : _isAuthenticated
        ? HomePage()
        : AuthPage(onAuthSuccess: _onAuthChanged),
```

To:

```dart
home: _isLoading
    ? Scaffold(body: Center(child: CircularProgressIndicator()))
    : HomePage(),  // Skip auth temporarily
```

⚠️ **This is only for testing! Add proper auth for production.**

---

## MongoDB Collections Needed

Your MongoDB database should have:
- ✅ `medicineRecords` - Already created
- ✅ `medicineBoxes` - For medicine box data
- ✅ `devices` - For IoT device info
- 🆕 `users` - For user authentication (will be created automatically)

The `users` collection will be created automatically when the first user registers.

---

## Testing the Endpoints

You can test with curl:

```bash
# Test registration
curl -X POST https://smartmed-mongo-api-1007306144996.asia-southeast1.run.app/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "fullName": "Test User"
  }'

# Test login
curl -X POST https://smartmed-mongo-api-1007306144996.asia-southeast1.run.app/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

Expected response:
```json
{
  "message": "User registered successfully",
  "userId": "507f1f77bcf86cd799439011",
  "email": "test@example.com",
  "fullName": "Test User",
  "token": "NTA3ZjFmNzdiY2Y4NmNkNzk5NDM5MDExOjE3MDU0ODc2MjAwMDA="
}
```
