# esavior_driver_project

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
name: esavior_project
description: "A new Flutter project."

publish_to: 'none'



version: 1.0.0+1

environment:
sdk: ">=3.5.0 <4.0.0"

dependencies:
flutter:
sdk: flutter
http: ^0.13.5
video_player: ^2.9.1
image_picker: ^0.8.4+2
google_maps_flutter: ^2.2.1
cupertino_icons: ^1.0.8
url_launcher: ^6.0.20
geocoding: ^2.0.0 # Dùng để chuyển đổi địa chỉ thành tọa độ

dev_dependencies:
flutter_test:
sdk: flutter
flutter_lints: ^4.0.0
flutter_launcher_icons: ^0.10.0
flutter_map: any
latlong2: any
flutter:
uses-material-design: true

fonts:
- family: 'Nunito'
fonts:
- asset: assets/fonts/Nunito-VariableFont_wght.ttf
assets:
- assets/images/esavior-high-resolution-logo-transparent.png