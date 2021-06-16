import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:studio_nativeshell/pty/dylib.dart';

typedef _store_dart_post_cobject_rust = Void Function(
  Pointer<NativeFunction<Int8 Function(Int64, Pointer<Dart_CObject>)>> ptr,
);
typedef _store_dart_post_cobject_dart = void Function(
  Pointer<NativeFunction<Int8 Function(Int64, Pointer<Dart_CObject>)>> ptr,
);

class RustApi {
  static var _initialized = false;

  static void ensureInitialized() {
    if (_initialized) {
      return;
    }

    final store_dart_post_cobject = dylib.lookupFunction<
        _store_dart_post_cobject_rust,
        _store_dart_post_cobject_dart>('store_dart_post_cobject');

    store_dart_post_cobject(NativeApi.postCObject);

    _initialized = true;
  }
}

typedef pty_new_rust = IntPtr Function(
  Pointer<Utf8> executable,
  IntPtr argc,
  Pointer<Utf8> argv,
  IntPtr outputPort,
  IntPtr exitcodePort,
);

typedef pty_new_dart = int Function(
  Pointer<Utf8> executable,
  int argc,
  Pointer<Utf8> argv,
  int outputPort,
  int exitcodePort,
);

typedef pty_write_rust = IntPtr Function(
  IntPtr handle,
  Pointer<Utf8> data,
  IntPtr length,
);

typedef pty_write_dart = int Function(
  int handle,
  Pointer<Utf8> data,
  int length,
);

typedef pty_resize_rust = IntPtr Function(
  IntPtr handle,
  IntPtr rows,
  IntPtr cols,
  IntPtr pixel_width,
  IntPtr pixel_height,
);

typedef pty_resize_dart = int Function(
  int handle,
  int rows,
  int cols,
  int pixel_width,
  int pixel_height,
);

typedef pty_drop_rust = IntPtr Function(
  IntPtr handle,
);

typedef pty_drop_dart = int Function(
  int handle,
);

class PtyFFI {
  static final create = dylib.lookupFunction<pty_new_rust, pty_new_dart>(
    'pty_new',
  );

  static final write = dylib.lookupFunction<pty_write_rust, pty_write_dart>(
    'pty_write',
  );

  static final resize = dylib.lookupFunction<pty_resize_rust, pty_resize_dart>(
    'pty_resize',
  );

  static final drop = dylib.lookupFunction<pty_drop_rust, pty_drop_dart>(
    'pty_drop',
  );
}
