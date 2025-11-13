# Borrowing Function Flow - Mobile App Implementation

This document describes how the borrowing functionality works in the Flutter mobile app, for integration with the web admin side.

## 📋 Table of Contents
1. [Database Structure](#database-structure)
2. [Request Creation Flow](#request-creation-flow)
3. [Request Status Flow](#request-status-flow)
4. [Data Fields](#data-fields)
5. [Notifications](#notifications)
6. [Key Operations](#key-operations)

---

## 🗄️ Database Structure

### Firebase Realtime Database Paths

#### 1. Borrow Requests
**Path:** `/borrow_requests/{requestId}`

Each borrow request is stored with the following structure:
```json
{
  "requestId": "auto-generated-uuid",
  "userId": "student-user-id",
  "userEmail": "student@email.com",
  "itemId": "equipment-item-id",
  "categoryId": "category-id",
  "itemName": "Equipment Name",
  "categoryName": "Category Name",
  "itemNo": "LAB-XXXXX",
  "laboratory": "Laboratory 1",
  "quantity": 1,
  "dateToBeUsed": "2024-01-15T00:00:00.000Z",
  "dateToReturn": "2024-01-20T00:00:00.000Z",
  "adviserName": "Teacher Name",
  "adviserId": "teacher-user-id",
  "status": "pending",
  "requestedAt": "2024-01-10T10:30:00.000Z",
  "signature": "optional-base64-json-signature",
  "batchId": "optional-batch-id-for-batch-requests",
  "processedAt": "optional-iso-date",
  "processedBy": "optional-processor-user-id",
  "returnedAt": "optional-iso-date"
}
```

#### 2. Batch Requests (Optional)
**Path:** `/batch_requests/{batchId}`

Batch requests are used when students borrow multiple items at once. Each item in the batch creates a separate entry in `borrow_requests` but shares the same `batchId`.

#### 3. Equipment Items
**Path:** `/equipment_categories/{categoryId}/equipments/{itemId}`

When a request is created, the app updates:
- `quantity_borrowed`: Incremented by the requested quantity

#### 4. Notifications
**Path:** `/notifications/{userId}/{notificationId}`

Notifications are stored per user with the following structure:
```json
{
  "title": "Notification Title",
  "message": "Notification Message",
  "type": "info|success|error|warning",
  "timestamp": "2024-01-10T10:30:00.000Z",
  "isRead": false,
  "createdAt": "2024-01-10T10:30:00.000Z",
  "requestId": "optional",
  "itemName": "optional",
  "status": "optional"
}
```

---

## 🔄 Request Creation Flow

### Single Item Request

1. **User selects equipment** from the equipment page
2. **Form is filled** with:
   - Laboratory (dropdown: Laboratory 1-5)
   - Quantity (number input)
   - Item Number (auto-generated or manual)
   - Date to be Used (date picker)
   - Date to Return (date picker)
   - Adviser Name (dropdown from teachers)
   - Signature (optional e-signature)

3. **On submission** (`FormService.submitBorrowRequest`):
   - Creates entry in `/borrow_requests/{requestId}`
   - Updates `quantity_borrowed` on equipment item
   - Sends notification to adviser
   - Sends confirmation notification to student
   - Sets status to `"pending"`

### Batch Request (Multiple Items)

1. **User adds items to cart** (CartService)
2. **User navigates to batch form** with all cart items
3. **Form is filled** with:
   - Laboratory (dropdown: Laboratory 1-3) ⚠️ Note: Different from single request
   - Date to be Used (same for all items)
   - Date to Return (same for all items)
   - Adviser Name (same for all items)

4. **On submission** (`BatchBorrowFormPage._submitBatchRequest`):
   - Creates a `batchId`
   - For each cart item:
     - Creates separate entry in `/borrow_requests/{requestId}`
     - Sets `batchId` field on each request
     - Updates `quantity_borrowed` on equipment item
   - Sends notification to adviser about batch
   - Sends confirmation to student
   - Clears cart
   - All requests start with status `"pending"`

---

## 📊 Request Status Flow

### Status Values
- `"pending"` - Initial status when request is created
- `"approved"` - Adviser/Admin approved the request
- `"rejected"` - Adviser/Admin rejected the request
- `"released"` - Item has been released for pickup (optional)
- `"returned"` - Item has been returned

### Status Updates

#### Approval/Rejection (Adviser Side)
**Location:** `RequestPage._updateRequestStatus`

**Process:**
1. Updates `/borrow_requests/{requestId}` with:
   - `status`: "approved" or "rejected"
   - `processedAt`: Current timestamp
   - `processedBy`: User ID of approver/rejector

2. Updates student's request copy (if stored separately):
   - Path: `/users/{userId}/borrow_requests/{requestId}`
   - Updates same fields

3. Sends notification to student via `NotificationService.notifyRequestStatusChange`

#### Return (Student Side)
**Location:** `BorrowingHistoryPage._markAsReturned`

**Process:**
1. Updates `/borrow_requests/{requestId}` with:
   - `status`: "returned"
   - `returnedAt`: Current timestamp

**Note:** The app does NOT update equipment `quantity_borrowed` on return. This should be handled by the web admin or a backend function.

---

## 📝 Data Fields

### Required Fields
- `userId` - Student's user ID
- `userEmail` - Student's email
- `itemId` - Equipment item ID
- `categoryId` - Category ID
- `itemName` - Equipment name
- `categoryName` - Category name
- `quantity` - Requested quantity (integer)
- `dateToBeUsed` - ISO 8601 date string
- `dateToReturn` - ISO 8601 date string
- `adviserName` - Adviser's name (string)
- `adviserId` - Adviser's user ID
- `status` - Request status
- `requestedAt` - ISO 8601 timestamp

### Optional Fields
- `itemNo` - Item number (auto-generated: "LAB-{itemId.substring(0,5).toUpperCase()}")
- `laboratory` - Laboratory name (default: "Laboratory 1")
- `signature` - Base64 JSON encoded signature data
- `batchId` - Batch ID for batch requests
- `processedAt` - ISO 8601 timestamp
- `processedBy` - User ID of processor
- `returnedAt` - ISO 8601 timestamp

### Laboratory Options
- **Single Request Form:** Laboratory 1, Laboratory 2, Laboratory 3, Laboratory 4, Laboratory 5
- **Batch Request Form:** Laboratory 1, Laboratory 2, Laboratory 3

⚠️ **Note:** Laboratories are hardcoded in the app. Consider creating a `laboratories` collection in Firebase for dynamic management.

---

## 🔔 Notifications

### Notification Types
- `"info"` - General information
- `"success"` - Success message
- `"error"` - Error message
- `"warning"` - Warning message

### Notification Flow

#### On Request Creation
1. **To Adviser:**
   - Title: "New Borrow Request"
   - Message: "{studentEmail} has requested to borrow {itemName}"
   - Type: "info"
   - Additional Data: `requestId`, `itemName`, `studentEmail`, `requestedAt`

2. **To Student:**
   - Title: "Request Submitted"
   - Message: "Your request for {itemName} has been submitted and is pending approval."
   - Type: "success"
   - Additional Data: `requestId`, `itemName`, `adviserName`

#### On Status Change
**To Student:**
- **Approved:**
  - Title: "Request Approved"
  - Message: "Your request for {itemName} has been approved."
  - Type: "success"

- **Rejected:**
  - Title: "Request Rejected"
  - Message: "Your request for {itemName} was rejected. Reason: {reason}"
  - Type: "error"

- **Released:**
  - Title: "Item Released"
  - Message: "Your request for {itemName} has been released and is ready for pickup."
  - Type: "success"

- **Returned:**
  - Title: "Item Returned"
  - Message: "You have successfully returned {itemName}."
  - Type: "success"

---

## 🔧 Key Operations

### Querying Requests

#### Get All Requests for an Adviser
```javascript
// Firebase Realtime Database
ref('borrow_requests')
  .orderByChild('adviserId')
  .equalTo(adviserUserId)
  .once('value')
```

#### Get All Requests for a Student
```javascript
ref('borrow_requests')
  .orderByChild('userId')
  .equalTo(studentUserId)
  .once('value')
```

#### Get Requests by Status
```javascript
ref('borrow_requests')
  .orderByChild('status')
  .equalTo('pending')
  .once('value')
```

#### Get Requests by Batch
```javascript
ref('borrow_requests')
  .orderByChild('batchId')
  .equalTo(batchId)
  .once('value')
```

### Updating Request Status

#### Approve Request
```javascript
ref('borrow_requests').child(requestId).update({
  status: 'approved',
  processedAt: new Date().toISOString(),
  processedBy: adminUserId
});
```

#### Reject Request
```javascript
ref('borrow_requests').child(requestId).update({
  status: 'rejected',
  processedAt: new Date().toISOString(),
  processedBy: adminUserId
});
```

#### Release Item
```javascript
ref('borrow_requests').child(requestId).update({
  status: 'released',
  releasedAt: new Date().toISOString(),
  releasedBy: adminUserId
});
```

#### Mark as Returned
```javascript
ref('borrow_requests').child(requestId).update({
  status: 'returned',
  returnedAt: new Date().toISOString()
});

// Also update equipment quantity_borrowed (decrement)
ref('equipment_categories')
  .child(categoryId)
  .child('equipments')
  .child(itemId)
  .child('quantity_borrowed')
  .transaction((current) => (current || 0) - quantity);
```

### Equipment Quantity Management

#### On Request Creation
```javascript
// Increment quantity_borrowed
ref('equipment_categories')
  .child(categoryId)
  .child('equipments')
  .child(itemId)
  .child('quantity_borrowed')
  .transaction((current) => (current || 0) + quantity);
```

#### On Return
```javascript
// Decrement quantity_borrowed
ref('equipment_categories')
  .child(categoryId)
  .child('equipments')
  .child(itemId)
  .child('quantity_borrowed')
  .transaction((current) => Math.max(0, (current || 0) - quantity));
```

---

## 🚨 Important Notes for Web Admin

### 1. Database Indexes
Ensure these indexes exist in Firebase:
- `borrow_requests`: `adviserId`, `userId`, `status`, `requestedAt`, `batchId`
- `equipment_categories`: `title`
- `users`: `email`, `role`

### 2. Status Workflow
The mobile app expects this workflow:
1. **pending** → (admin action) → **approved** or **rejected**
2. **approved** → (optional) → **released**
3. **approved/released** → (student/admin action) → **returned**

### 3. Quantity Management
- The app increments `quantity_borrowed` on request creation
- The app does NOT decrement `quantity_borrowed` on return
- **Web admin should handle quantity updates on return**

### 4. Batch Requests
- Batch requests share the same `batchId`
- Each item in a batch is a separate request in `borrow_requests`
- Consider showing batch requests grouped in the web admin

### 5. Signature Field
- Signature is stored as base64 JSON string
- Format: `{"points": [{"x": number, "y": number, "isNewStroke": boolean}], "strokeWidth": number}`
- Can be used for signature verification/display on web

### 6. Laboratory Field
- Currently hardcoded in the app
- Consider creating a `laboratories` collection for dynamic management
- Single form uses 5 labs, batch form uses 3 labs (inconsistency to fix)

### 7. Notifications
- Notifications are stored in `/notifications/{userId}`
- Mark as read by setting `isRead: true`
- Consider implementing notification aggregation in web admin

### 8. Date Format
- All dates are stored as ISO 8601 strings
- Example: `"2024-01-15T00:00:00.000Z"`
- Parse using `new Date(dateString)` in JavaScript

---

## 📱 Mobile App Files Reference

### Request Creation
- `lib/home/form_page.dart` - Single item request form
- `lib/home/batch_borrow_form_page.dart` - Batch request form
- `lib/home/service/form_service.dart` - Request submission service

### Request Management
- `lib/home/request_page.dart` - Adviser request management (approve/reject)
- `lib/home/borrowing_history_page.dart` - Student borrowing history

### Services
- `lib/home/service/cart_service.dart` - Cart management for batch requests
- `lib/home/service/notification_service.dart` - Notification management
- `lib/home/service/teacher_service.dart` - Teacher/adviser loading

### Widgets
- `lib/home/widgets/form_sections.dart` - Form sections (includes laboratory field)
- `lib/home/widgets/signature_pad.dart` - E-signature widget

---

## 🔗 Integration Points

### For Web Admin to Implement

1. **Request Management Dashboard**
   - Display all requests with filtering by status, adviser, student
   - Group batch requests by `batchId`
   - Show request details including signature

2. **Status Management**
   - Approve/Reject requests
   - Release items (set status to "released")
   - Mark items as returned
   - Update `quantity_borrowed` on return

3. **Equipment Management**
   - Track available quantity: `quantity - quantity_borrowed`
   - Prevent over-borrowing
   - Update quantities on approval/rejection/return

4. **Notifications**
   - Send notifications to students on status changes
   - Send notifications to advisers on new requests
   - Mark notifications as read

5. **Laboratory Management**
   - Create/update/delete laboratories
   - Sync with mobile app (consider API or Firebase collection)

6. **Reporting**
   - Request statistics
   - Equipment usage analytics
   - Student borrowing history
   - Adviser approval statistics

---

## 📞 Support

For questions or issues, refer to:
- Database structure: `README.md`
- Security rules: `database.rules.json`
- Mobile app code: `lib/home/` directory

