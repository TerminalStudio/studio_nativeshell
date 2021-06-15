import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nativeshell/nativeshell.dart';

void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTextStyle(
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        child: Container(
          color: Colors.black,
          child: WindowWidget(
            onCreateState: (initData) {
              WindowState? state;
              state ??= MainWindowState();
              return state;
            },
          ),
        ),
      ),
    );
  }
}

class MainWindowState extends WindowState {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ElevatedButton(
        child: Text('Click me!'),
        onPressed: () {
          final dylib = DynamicLibrary.executable();
          final fn = dylib.lookupFunction<Void Function(), void Function()>('pty_new');
          fn();
          print('hello');
        },
      ),
    );
  }
}
