import 'dart:io';
import 'package:flutter/foundation.dart';

Future<void> testPublicStorageAccess() async {
  // Get the most restrictive public/shared directory
  final downloadsDir = '/storage/emulated/0/Download';
  final testDir = Directory('$downloadsDir/Curio_Test_Dir');

  print('Testing access to public Download path: ${testDir.path}');

  try {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }

    if (!await testDir.exists()) {
      await testDir.create(recursive: true);
      print('SUCCESS: Created test directory at ${testDir.path}');

      // Attempt a file write
      final testFile = File('${testDir.path}/test.txt');
      await testFile.writeAsString('Storage access confirmed.');
      print('SUCCESS: Wrote test file.');
      await testDir.delete(recursive: true); // Clean up
      print('Storage access is TRUE; you are using the correct Media/SAF API.');
      return;
    }
  } catch (e) {
    print('FAILURE: Caught a permission denial.');
    print('Error: $e');
    print(
      'Diagnosis: This is expected on Android 11+ (API 30+). You CANNOT use dart:io to write to public storage sections.',
    );
    print(
      'Action: Use a package that implements the Media Store API (or write your own Kotlin/Java code to get a URI/File Descriptor).',
    );
  }
}
