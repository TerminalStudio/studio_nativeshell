import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:studio_nativeshell/pty/ffi.dart';

typedef Bytes = List<int>;

Pointer<Utf8> _buildArguments(List<String> list) {
  final buffer = calloc<IntPtr>(list.length);

  for (var i = 0; i < list.length; i++) {
    buffer.elementAt(i).value = list[i].toNativeUtf8().address;
  }

  return buffer.cast();
}

class NativePty {
  NativePty(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    RustApi.ensureInitialized();

    final outputPort = ReceivePort();
    outputPort.listen(_onOutput);

    final exitcodePort = ReceivePort();
    exitcodePort.listen(_onExit);

    _handle = PtyFFI.create(
      executable.toNativeUtf8(),
      arguments.length,
      _buildArguments(arguments),
      outputPort.sendPort.nativePort,
      exitcodePort.sendPort.nativePort,
    );

    print('handle $_handle');
  }

  late final int _handle;
  var _exited = false;

  final _output = StreamController<Bytes>();
  Stream<String> get output => _output.stream.transform(utf8.decoder);

  final _exitCode = Completer<int>();
  Future<int> get exitCode => _exitCode.future;

  void _onOutput(data) {
    _output.sink.add(data);
  }

  void _onExit(data) {
    _exitCode.complete(data ? 0 : 1);
    PtyFFI.drop(_handle);
    _output.close();
    _exited = true;
  }

  void resize(
    int rows,
    int cols,
    int pixel_width,
    int pixel_height,
  ) {
    PtyFFI.resize(
      _handle,
      rows,
      cols,
      pixel_width,
      pixel_height,
    );
  }

  void write(String data) {
    if (_exited) {
      return;
    }

    final units = utf8.encode(data);
    final result = malloc<Uint8>(units.length);
    final nativeString = result.asTypedList(units.length);
    nativeString.setAll(0, units);
    PtyFFI.write(_handle, result.cast(), units.length);
    malloc.free(result);
  }
}
