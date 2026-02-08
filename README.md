# Campus Spokes

**Campus Spokes** is a peer-to-peer bicycle sharing application designed specifically for campus communities. It facilitates easy renting and lending of bicycles among students, providing a sustainable and convenient mode of transport.

## 🚀 Features

*   **Rent & Lend Cycles**: seamlessly list your bicycle for others to rent, or find a ride when you need one.
*   **Smart Scheduling**: 
    *   Advanced conflict detection for bookings.
    *   Automatic 30-minute buffer periods between rides.
    *   Sticky time and location filters for easy searching.
*   **Secure & Transparent**:
    *   **Mandatory Profile Setup**: Verifies Student ID and phone number (10-digit validation) before use.
    *   **History**: Track all your rides and received bookings.
*   **Payments & Cancellations**:
    *   Integrated UPI payment flow.
    *   Robust cancellation system with automated fee calculation.
    *   Instant notifications for owners when a booking is cancelled.
*   **Reviews**: Owners can view ratings and reviews for their listed cycles.

## 🛠️ Tech Stack

*   **Framework**: [Flutter](https://flutter.dev/) (Dart)
*   **Backend**: Firebase (Core, Auth, Firestore, Storage)
*   **Authentication**: Google Sign-In
*   **State Management**: `provider` (implied or standard state) components.
*   **Other Key Packages**: 
    *   `url_launcher` (for calls/payments)
    *   `flutter_local_notifications` (for alerts)
    *   `intl` (for date formatting)

## 🏁 Getting Started

### Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
*   Android Studio / VS Code configured.
*   Java JDK 17 (recommended).

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/saisrama/Campus_spokes.git
    cd Campus_spokes
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Run the app**:
    ```bash
    flutter run
    ```

## 📦 Building for Release (Android)

> **⚠️ IMPORTANT SECURITY NOTE**: 
> This project uses a securely managed signing configuration. The **Keystore** (`upload-keystore.jks`) and **Properties** (`key.properties`) files are **NOT** included in this repository for security reasons.

To build a release version, you must:
1.  Obtain the `upload-keystore.jks` and place it in `android/app/`.
2.  Obtain the `key.properties` file and place it in `android/`.
3.  Run the build command:
    ```bash
    flutter build appbundle --release
    ```

## 🤝 Contributing

Contributions are welcome! Please fork the repository and submit a pull request for any enhancements.

---
*Built with ❤️ for the Campus Community.*
