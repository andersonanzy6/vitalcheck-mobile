# VitalCheck Mobile

Flutter patient and doctor app for VitalCheck. The UI follows the web patient/doctor flows and shared booking and chat patterns.

## Run

`flutter pub get`
`flutter run --dart-define=API_BASE_URL=https://vitalcheck-56uj.onrender.com/api`

Default API base is `https://vitalcheck-56uj.onrender.com/api`. API requests use the `{ success, data }` envelope. Access and refresh tokens are stored with flutter_secure_storage.

## Release APK

`flutter build apk --release --dart-define=API_BASE_URL=https://vitalcheck-56uj.onrender.com/api`

Features include role-based patient and doctor navigation, authentication, appointment booking and management, provider discovery, profile/medical records/payments, notifications, Socket.IO messaging and WebRTC calls using backend ICE server configuration.
