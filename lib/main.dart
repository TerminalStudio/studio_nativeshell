import 'package:studio_nativeshell/pty/pty.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nativeshell/nativeshell.dart';
import 'package:studio_nativeshell/main_window.dart';

void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return WindowWidget(
      onCreateState: (initData) {
        WindowState? state;
        state ??= MainWindowState();
        return state;
      },
    );
  }
}

// class MainWindowState extends WindowState {
//   final pty = NativePty('bash', []);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Column(
//         children: [
//           ElevatedButton(
//             child: Text('Click me!'),
//             onPressed: () {
//               pty.output.listen((data) {
//                 print('data >>$data<<');
//               });
//             },
//           ),
//           TextField(onSubmitted: (data) {
//             pty.write('$data\r\n');
//           }),
//         ],
//       ),
//     );
//   }
// }
