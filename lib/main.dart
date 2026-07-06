import 'package:flutter/material.dart';
import 'app/app_bootstrap.dart';
import 'app/app_root.dart';

Future<void> main() async {
  await AppBootstrap.initialize();
  runApp(const HayahApp());
}
