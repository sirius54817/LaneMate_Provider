# LaneMate Provider

LaneMate Provider is a cross-platform Flutter application designed for providers in the LaneMate ecosystem. It supports Android, iOS, Linux, macOS, Windows, and Web platforms.

## Features
- User authentication (Firebase Auth)
- Order management
- Google Maps integration
- Image picker and file uploads
- Geolocation services
- Payment integration (Razorpay)
- Push notifications
- Custom widgets and UI components

## Project Structure
```
lib/
  firebase_options.dart
  main.dart
  klu_page/
  pages/
  services/
  utils/
  widgets/
assets/
  images/
  ...
android/, ios/, linux/, macos/, windows/, web/  # Platform-specific code
```

## Getting Started
1. **Clone the repository:**
   ```sh
   git clone <repo-url>
   cd LaneMate_Provider
   ```
2. **Install dependencies:**
   ```sh
   flutter pub get
   ```
3. **Configure Firebase:**
   - Update `lib/firebase_options.dart` with your Firebase project settings.
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) if needed.
4. **Run the app:**
   ```sh
   flutter run
   ```
   - For web: `flutter run -d chrome`
   - For desktop: `flutter run -d linux` (or `windows`, `macos`)

## Build
- Android: `flutter build apk`
- iOS: `flutter build ios`
- Web: `flutter build web`
- Desktop: `flutter build linux` / `windows` / `macos`

## Dependencies
- [firebase_core](https://pub.dev/packages/firebase_core)
- [firebase_auth](https://pub.dev/packages/firebase_auth)
- [cloud_firestore](https://pub.dev/packages/cloud_firestore)
- [firebase_storage](https://pub.dev/packages/firebase_storage)
- [google_maps_flutter](https://pub.dev/packages/google_maps_flutter)
- [geolocator](https://pub.dev/packages/geolocator)
- [razorpay_flutter](https://pub.dev/packages/razorpay_flutter)
- [image_picker](https://pub.dev/packages/image_picker)
- [fluttertoast](https://pub.dev/packages/fluttertoast)
- [shared_preferences](https://pub.dev/packages/shared_preferences)
- [url_launcher](https://pub.dev/packages/url_launcher)
- [webview_flutter](https://pub.dev/packages/webview_flutter)

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[MIT](LICENSE)
