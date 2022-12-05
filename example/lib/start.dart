import 'dart:isolate';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_foreground_task_example/task_handler.dart';
import 'package:geolocator/geolocator.dart';

ReceivePort? _receivePort;

// The callback function should always be a top-level function.
@pragma('vm:entry-point')
void startCallback() {
  // The setTaskHandler function must be called to handle the task in the background.

  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

Future<bool> startForegroundTask(
  BuildContext context, {
  required ValueChanged<String>? onPosition,
}) async {
  // "android.permission.SYSTEM_ALERT_WINDOW" permission must be granted for
  // onNotificationPressed function to be called.
  //
  // When the notification is pressed while permission is denied,
  // the onNotificationPressed function is not called and the app opens.
  //
  // If you do not use the onNotificationPressed or launchApp function,
  // you do not need to write this code.
  if (!await FlutterForegroundTask.canDrawOverlays) {
    final isGranted =
        await FlutterForegroundTask.openSystemAlertWindowSettings();
    if (!isGranted) {
      print('SYSTEM_ALERT_WINDOW permission denied!');
      return false;
    }
  }

  // You can save data using the saveData function.
  await FlutterForegroundTask.saveData(key: 'customData', value: 'hello');

  bool reqResult;
  if (await FlutterForegroundTask.isRunningService) {
    reqResult = await FlutterForegroundTask.restartService();
  } else {
    reqResult = await FlutterForegroundTask.startService(
      notificationTitle: 'Foreground Service is running',
      notificationText: 'Tap to return to the app',
      callback: startCallback,
    );
  }

  ReceivePort? receivePort;
  if (reqResult) {
    receivePort = await FlutterForegroundTask.receivePort;
  }

  return _registerReceivePort(context, receivePort, onPosition);
}

Future<bool> stopForegroundTask() async {
  return await FlutterForegroundTask.stopService();
}

Future<bool> _registerReceivePort(
  BuildContext context,
  ReceivePort? receivePort,
  ValueChanged<String>? onPosition,
) async {
  closeReceivePort();

  if (receivePort != null) {
    _receivePort = receivePort;

    _receivePort?.listen((message) async {
      if (message is String && message == 'onNotificationPressed') {
        Navigator.of(context).pushNamed('/resume-route');
      } else if (message is DateTime) {
        print('timestamp: ${message.toString()}');
      } else {
        onPosition?.call(message);
      }
    });

    return true;
  }

  return false;
}

void closeReceivePort() {
  _receivePort?.close();
  _receivePort = null;
}
