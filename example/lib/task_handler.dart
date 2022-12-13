import 'dart:async';
import 'dart:isolate';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rxdart/rxdart.dart';

class MyTaskHandler extends TaskHandler {
  SendPort? _sendPort;
  StreamSubscription? sub;
  Position? lastPosition;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;

    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    sub = Geolocator.getPositionStream(
        locationSettings: AppleSettings(
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
    )).debounceTime(const Duration(seconds: 2)).listen((pos) {
      lastPosition = pos;
    })
      ..onError((e) {
        print(e);
      });
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    FlutterForegroundTask.updateService(
      notificationTitle: 'MyTaskHandler',
      notificationText: '$timestamp - $lastPosition',
    );

    scheduleMicrotask(() async {
      final coll =
          FirebaseFirestore.instance.collection('locations').doc('123');
      final map = await coll.get();

      coll.set(<String, dynamic>{
        ...map.data() ?? {},
        timestamp.toString(): lastPosition?.toString(),
      });
    });

    sendPort?.send('$timestamp - $lastPosition');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    await FlutterForegroundTask.clearAllData();
  }

  @override
  void onButtonPressed(String id) {
    print('onButtonPressed >> $id');
  }

  @override
  void onNotificationPressed() {
    // Called when the notification itself on the Android platform is pressed.
    //
    // "android.permission.SYSTEM_ALERT_WINDOW" permission must be granted for
    // this function to be called.

    // Note that the app will only route to "/resume-route" when it is exited so
    // it will usually be necessary to send a message through the send port to
    // signal it to restore state when the app is already started.
    FlutterForegroundTask.launchApp("/resume-route");
    _sendPort?.send('onNotificationPressed');
  }
}
