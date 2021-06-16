#!/usr/bin/env dart

import 'dart:io';

/// Utility to manage git dependencies.
///
/// Usage:
///   sync_deps.dart [clone|pull|<custom action>]
///
/// Example:
///   sync_deps.dart          # initialize
///   sync_deps.dart  clone   # clone only.
///   sync_deps.dart  pull    # run git pull
///   sync_deps.dart  pub     # run certain custom action (pub get in this example).

final deps = [
  Dependency(
    path: 'deps/xterm',
    repo: 'git@github.com:TerminalStudio/xterm.dart.git',
    actions: {
      'checkout': 'git checkout master',
      'pub': 'flutter pub get',
    },
  ),
  Dependency(
    path: 'deps/tabs',
    repo: 'git@github.com:TerminalStudio/tabs.git',
    actions: {
      'checkout': 'git checkout stable',
      'pub': 'flutter pub get',
    },
  ),
];

// ---------------------------------------- //

void main(List<String> args) async {
  if (args.isEmpty) {
    return doAll();
  }

  final command = args[0];
  switch (command) {
    case 'clone':
      return clone();
    case 'pull':
      return pull();
    default:
      return customAction(command);
  }
}

class Dependency {
  Dependency({
    required this.path,
    required this.repo,
    this.actions = const {},
  });

  final String path;
  final String repo;
  final Map<String, String> actions;
}

Future<void> doAll() async {
  await clone();
  await customAction();
}

Future<void> run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  if (workingDirectory != null) {
    print('[sync_deps] cd $workingDirectory');
  }
  print('[sync_deps] $executable ${arguments.join(' ')}');

  final process = await Process.start(
    executable,
    arguments,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
    workingDirectory: workingDirectory,
  );

  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    print('$executable returned $exitCode');
    exit(exitCode);
  }
}

Future<void> clone() async {
  for (var dep in deps) {
    if (Directory(dep.path).existsSync()) {
      print('[sync_deps] ${dep.path} already exists, clone skipped.');
      continue;
    }
    await run('git', ['clone', dep.repo, dep.path]);
  }
}

Future<void> pull() async {
  for (var dep in deps) {
    await run('git', ['pull'], workingDirectory: dep.path);
  }
}

Future<void> customAction([String? name]) async {
  for (var dep in deps) {
    for (var action in dep.actions.entries) {
      if (name != null && action.key != name) {
        continue;
      }
      final parts = action.value.split(' ');
      await run(parts.first, parts.sublist(1), workingDirectory: dep.path);
    }
  }
}
