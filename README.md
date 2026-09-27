# 🚨 Emergence

**Emergence** is a Flutter-based real-time location-sharing application that allows users to share their current location and view the live locations of other users who have joined the application.

The project uses **Firebase Realtime Database** for synchronizing location data between users and **MapLibre** for displaying locations on an interactive map.

---

## 📱 Overview

Emergence is designed to provide a simple way for users to share and monitor locations in real time.

Users can:

* 📍 Share their current location.
* 👥 View the locations of other users who are connected through the application.
* 🗺️ View users on an interactive MapLibre map.
* 🔄 Receive real-time location updates.
* 📡 Synchronize location data using Firebase Realtime Database.
* 👤 Identify users using their unique user information.
* 📊 Track location-related information such as latitude, longitude, accuracy, bearing, and other location properties.

---

## ✨ Features

### 📍 Real-Time Location Sharing

The application obtains the user's device location and continuously updates their location information.

Example location data:

```json
{
  "user-id": {
    "accuracy": 7.27,
    "bearing": 90.00,
    "latitude": 28.6600054,
    "longitude": 77.1992709
  }
}
```

The location can include information such as:

* Latitude
* Longitude
* Accuracy
* Bearing
* Speed
* Timestamp
* Altitude
* Other location metadata

---

### 👥 View Other Users

Users who have joined the application can see other participating users on the map.

Whenever another user's location changes, the Firebase Realtime Database synchronizes the updated information and the map can update the corresponding marker.

Conceptually:

```text
User A ──────┐
             │
User B ──────┼──> Firebase Realtime Database
             │
User C ──────┘
                    │
                    ▼
              Emergence App
                    │
                    ▼
              MapLibre Map
```

---

### 🗺️ MapLibre Maps

Emergence uses **MapLibre** to render interactive maps.

MapLibre is responsible for:

* Rendering the map
* Displaying user locations
* Moving the camera
* Managing map markers/symbols
* Providing an interactive map experience

---

### 🔥 Firebase Realtime Database

**Firebase Realtime Database** is used as the real-time synchronization layer.

Location information is stored in the database and changes are propagated to connected clients.

Example structure:

```text
locations
│
├── user-id-1
│   ├── latitude
│   ├── longitude
│   ├── accuracy
│   ├── bearing
│   └── timestamp
│
├── user-id-2
│   ├── latitude
│   ├── longitude
│   ├── accuracy
│   ├── bearing
│   └── timestamp
│
└── user-id-3
    ├── latitude
    ├── longitude
    ├── accuracy
    ├── bearing
    └── timestamp
```

---

## 🏗️ Technology Stack

| Technology                     | Purpose                                |
| ------------------------------ | -------------------------------------- |
| **Flutter**                    | Cross-platform application development |
| **Dart**                       | Application programming language       |
| **Firebase Realtime Database** | Real-time location synchronization     |
| **MapLibre**                   | Map rendering and visualization        |
| **Location Services**          | Obtaining device location              |
| **Firebase**                   | Backend infrastructure                 |

---

## 🔄 How It Works

The general data flow of Emergence is:

```text
┌──────────────────┐
│   User Device    │
│                  │
│ Location Service │
└────────┬─────────┘
         │
         │ Location
         ▼
┌──────────────────────┐
│ Flutter Application  │
│      Emergence       │
└────────┬─────────────┘
         │
         │ Write location
         ▼
┌────────────────────────────┐
│ Firebase Realtime Database │
└─────────────┬──────────────┘
              │
              │ Real-time updates
              ▼
┌──────────────────────┐
│ Other Emergence Users│
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│      MapLibre        │
│                      │
│ 📍 User A             │
│ 📍 User B             │
│ 📍 User C             │
└──────────────────────┘
```

---

## 📂 Project Structure

A suggested structure for the project is:

```text
lib/
│
├── main.dart
│
├── core/
│   ├── constants/
│   ├── services/
│   └── utils/
│
├── data/
│   ├── models/
│   ├── repositories/
│   └── services/
│
├── presentation/
│   ├── screens/
│   ├── widgets/
│   └── controllers/
│
└── firebase/
    └── ...
```

The exact structure can be adjusted according to the current implementation.

---

## 🔐 Location Permissions

Because Emergence accesses device location, the application requires location permissions.

### Android

The required permissions should be configured in:

```text
android/app/src/main/AndroidManifest.xml
```

For example:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

If background location tracking is implemented, additional Android configuration may be required.

### iOS

For iOS, location usage descriptions need to be added to:

```text
ios/Runner/Info.plist
```

---

## 🔥 Firebase Configuration

Before running the project, configure Firebase for the target platform.

Typical Flutter Firebase configuration files include:

```text
android/app/google-services.json
```

and:

```text
ios/Runner/GoogleService-Info.plist
```

Make sure Firebase Realtime Database is enabled in the Firebase project.

---

## 🗺️ Map Configuration

MapLibre requires a map style/source configuration.

Depending on the selected map provider, the project may require a style URL or other map configuration.

For example:

```text
MapLibre
    │
    ├── Map Style
    ├── Map Tiles
    └── User Location Markers
```

Make sure the required map style and tile source are available before running the application.

---

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
```

### 2. Enter the Project

```bash
cd emergence
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Configure Firebase

Add the appropriate Firebase configuration for Android/iOS and configure Firebase Realtime Database.

### 5. Configure MapLibre

Configure the required MapLibre map style/tile source.

### 6. Run the Application

```bash
flutter run
```

---

## 📡 Real-Time Location Flow

When a user joins Emergence:

```text
User joins
    ↓
Location permission requested
    ↓
Location obtained
    ↓
Location data created
    ↓
Firebase Realtime Database
    ↓
Other clients receive update
    ↓
MapLibre updates the map
```

When the user's location changes:

```text
New GPS location
       ↓
Update Firebase
       ↓
Firebase broadcasts change
       ↓
Other clients receive change
       ↓
User marker moves on MapLibre
```

---

## 📊 Location Data

Emergence can maintain detailed location information instead of storing only latitude and longitude.

Example:

```json
{
  "user-id": {
    "accuracy": 7.270999908447266,
    "bearing": 90.00177001953125,
    "latitude": 28.6600054,
    "longitude": 77.1992709,
    "speed": 0.0,
    "timestamp": 1750000000000
  }
}
```

This allows the application to support features such as:

* Location accuracy visualization
* Direction/orientation
* Movement tracking
* Last-updated information
* User movement visualization

---

## 🔒 Security Considerations

Because location data is sensitive, Firebase Realtime Database rules should be configured carefully.

Do not leave the database publicly writable in a production application.

A production implementation should consider:

* Firebase Authentication
* User-specific database permissions
* Validating location updates
* Restricting unauthorized reads
* Restricting unauthorized writes
* Removing inactive users
* Protecting user identifiers

Example concept:

```text
Authenticated User
        │
        ├── Read permitted locations
        │
        └── Write only own location
```

---

## 🛠️ Future Improvements

Potential improvements for Emergence include:

* 🔐 Firebase Authentication
* 👥 Groups for location sharing
* 📍 Custom user markers
* 🚨 Emergency/SOS functionality
* 🔔 Location-based notifications
* 🧭 Direction indicators
* 📏 Distance between users
* 🗺️ Route visualization
* 🕐 Location history
* 📴 Offline location handling
* 🔒 Improved Firebase security rules
* 🔋 Battery-efficient background tracking
* 👤 User profiles and names
* 🟢 Online/offline user status

---

## 🤝 Contributing

Contributions are welcome.

1. Fork the repository.
2. Create a new branch.

```bash
git checkout -b feature/new-feature
```

3. Make your changes.
4. Commit your changes.

```bash
git commit -m "Add new feature"
```

5. Push the branch.

```bash
git push origin feature/new-feature
```

6. Create a Pull Request.

---


---

## 👨‍💻 Project

**Emergence** — Real-time location sharing built with Flutter, Firebase Realtime Database, and MapLibre.

> A real-time map-based platform for sharing and visualizing the locations of connected users.
