# Contributing

## Requirements

- Android Studio (prerequisite for Flutter)
- Flutter SDK (version 3.0.0 or newer)
- Dart SDK
- macOS and Xcode (if you want to run on iOS)

## Getting Started

1. Clone this repository
2. Install dependencies:

    ```bash
    flutter pub get
    ```

3. Install npm development tools, e.g. `markdownlint-cli`

    ```bash
    npm install
    ```

## Running the App

### Running and Choosing the Target Device

Run on an emulator or physical device:

```bash
flutter run
```

On Linux it is recommended to run in Chrome - this gives the fastest result.

### Explicitly Running on iPhone

To run on your iPhone (requires a free Apple Developer account):

1. **Open in Xcode**:
    - Open the `ios` folder
    - Double-click `Runner.xcworkspace`

2. **Set up signing**:
    - In the left sidebar, select **Runner** (blue icon)
    - Select the **Runner** target in the main view
    - Go to the **Signing & Capabilities** tab
    - Under **Team**, click **Add an Account...** and sign in with your Apple ID
    - Select your **Personal Team** from the dropdown
    - Change the **Bundle Identifier** to something unique (e.g., `com.yourname.multitimer`)

3. **Run the app**:
    - Connect your iPhone with a USB cable
    - Select your device at the top
    - Click the **Play** button (or press `Cmd + R`)

4. **Trust the developer**:
    - If the app doesn't start, open **Settings** on your iPhone
    - Go to **General > VPN & Device Management** (or Profiles)
    - Tap your Apple ID and select **Trust**

### Explicitly Running on Android

To run on an Android emulator:

1. **Open in Android Studio**:
    - Launch Android Studio
    - Select **File > Open**
    - Choose the project folder

2. **Set up Flutter**:
    - Go to **Settings** (or **Preferences** on Mac)
    - Go to **Languages & Frameworks > Flutter**
    - Enter your Flutter SDK path (like `/Users/username/flutter`)
    - Click **Apply** and **OK**

3. **Create and start an emulator**:
    - Go to **Tools > Device Manager**
    - If you don't have an emulator, click **Create Device** and follow the wizard
    - Click the **Play** button next to your emulator to start it

4. **Run the app**:
    - Wait for the emulator to fully boot
    - Select your emulator from the device dropdown in the toolbar
    - Click the **Run** button (or press **Shift + F10**)

## Running the Tests

```shell
flutter test
```
