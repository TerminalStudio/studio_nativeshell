import 'package:studio_nativeshell/pty/pty.dart';
import 'package:xterm/xterm.dart';

class PtyTerminalBackend implements TerminalBackend {
  PtyTerminalBackend(
    this.executable,
    this.arguments, {
    this.workingDirectory,
    this.environment,
  });

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String>? environment;

  late final NativePty pty;

  @override
  void init() {
    pty = NativePty(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }

  @override
  Future<int> get exitCode => pty.exitCode;

  @override
  Stream<String> get out => pty.output;

  @override
  void resize(int width, int height, int pixelWidth, int pixelHeight) {
    pty.resize(height, width, pixelWidth, pixelHeight);
  }

  @override
  void write(String input) {
    pty.write(input);
  }

  @override
  void terminate() {
    // pty.kill();
  }

  @override
  void ackProcessed() {
    // pty.ackProcessed();
  }
}
