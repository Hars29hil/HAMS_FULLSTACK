# HAMS: iOS Deployment Guide

This guide covers the exact steps required to build and deploy the HAMS Flutter application to iOS devices using TestFlight or the App Store.

---

## Prerequisites
- **A macOS Computer** (MacBook, Mac Mini, Mac Studio, etc.). iOS apps can **only** be compiled using Apple's Xcode software.
- **Apple Developer Account** ($99/year). Required for distributing apps via TestFlight or the App Store.
- **Flutter & CocoaPods** installed on the Mac.

---

## Step 1: Add iOS Permissions for Bluetooth

Apple strictly requires apps to explain *why* they use Bluetooth. Without these strings, Apple will instantly reject your app.

1. Open your code and navigate to `ios/Runner/Info.plist`.
2. Scroll to the bottom and add these two keys just before the final `</dict>` tag:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to the floor device to mark attendance.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to the floor device to mark attendance.</string>
```

---

## Step 2: Set Up Firebase (For Push Notifications)

Because iOS does not use the `google-services.json` file that Android uses, you must configure Firebase specifically for iOS.

1. Go to your **Firebase Console**.
2. Click **"Add app"** and select the **iOS** icon.
3. Register your iOS Bundle ID (e.g., `com.hams.app`).
4. Download the **`GoogleService-Info.plist`** file.
5. **CRITICAL:** Do *not* just paste it into a folder using Windows Explorer or VS Code. You must open `ios/Runner.xcworkspace` in the Xcode app on your Mac, and **drag-and-drop** the `GoogleService-Info.plist` file directly into the "Runner" folder inside Xcode so that Xcode properly links it.

*(Note: To actually receive push notifications on iPhones, you will also need to generate an APNs Auth Key in your Apple Developer account and upload it to your Firebase Console).*

---

## Step 3: Install iOS Dependencies

Open your Mac's terminal, navigate to your frontend folder, and run:

```bash
flutter clean
flutter pub get
cd ios
pod install
```
*This installs all the required iOS-specific libraries (like the iOS Bluetooth and Firebase SDKs).*

---

## Step 4: Configure Signing in Xcode

1. In Xcode, click on **Runner** on the top-left sidebar.
2. Go to the **Signing & Capabilities** tab.
3. Check the box that says **"Automatically manage signing"**.
4. Log into your Apple Developer Account.
5. Click **"+ Capability"** (top left) and add **Push Notifications**.
6. Click **"+ Capability"** again and add **Background Modes**. Check the box for **"Remote notifications"**.

---

## Step 5: Build the App

In your Mac terminal, navigate back to the main frontend folder (e.g., `cd ..` so you are out of the `ios` folder) and run:

```bash
flutter build ipa
```

This process will compile the code and take a few minutes. Once it finishes, it will generate an **`.ipa`** file (the iOS equivalent of an APK) inside the `build/ios/ipa/` directory.

---

## Step 6: Upload to Apple

1. Open the **Transporter** app (you can download this for free from the Mac App Store).
2. Log in with your Apple Developer Account.
3. Drag and drop your `.ipa` file into Transporter and click **Deliver**.
4. Wait 10-15 minutes, and the app will finish processing. It will then appear in your **App Store Connect** dashboard.
5. From App Store Connect, you can release it to your students via **TestFlight** or submit it for review to be published on the **App Store**.
