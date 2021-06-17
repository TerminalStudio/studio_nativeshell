import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:nativeshell/accelerators.dart';
import 'package:nativeshell/nativeshell.dart';
import 'package:studio_nativeshell/shortcut/intents.dart';
import 'package:studio_nativeshell/utils/pty_terminal_backend.dart';
import 'package:studio_nativeshell/utils/unawaited.dart';
import 'package:tabs/tabs.dart';

import 'package:flutter/material.dart' hide Tab, TabController;
import 'package:xterm/flutter.dart';
import 'package:xterm/isolate.dart';
import 'package:xterm/theme/terminal_style.dart';
import 'package:xterm/xterm.dart';

void dispatchIntent(Intent intent) {
  final primaryContext = primaryFocus?.context;
  if (primaryContext != null) {
    final action = Actions.maybeFind<Intent>(
      primaryContext,
      intent: intent,
    );
    if (action != null && action.isEnabled(intent)) {
      Actions.of(primaryContext).invokeAction(action, intent, primaryContext);
    }
  }
}

class MainWindowState extends WindowState {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terminal Lite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }

  @override
  WindowSizingMode get windowSizingMode =>
      WindowSizingMode.atLeastIntrinsicSize;

  @override
  Future<void> initializeWindow(Size intrinsicContentSize) async {
    await setupMenu();
    await window.setTitle('Terminal Studio');
    return super.initializeWindow(Size(1280, 720));
  }

  Future<void> setupMenu() async {
    if (Platform.isMacOS) {
      await Menu(buildMenu).setAsAppMenu();
    }
  }

  List<MenuItem> buildMenu() {
    return [
      MenuItem.children(title: 'App', children: [
        MenuItem.withRole(role: MenuItemRole.hide),
        MenuItem.withRole(role: MenuItemRole.hideOtherApplications),
        MenuItem.withRole(role: MenuItemRole.showAll),
        MenuItem.separator(),
        MenuItem.withRole(role: MenuItemRole.quitApplication),
      ]),
      MenuItem.children(title: 'Window', role: MenuRole.window, children: [
        MenuItem.withRole(role: MenuItemRole.minimizeWindow),
        MenuItem.withRole(role: MenuItemRole.zoomWindow),
      ]),
      MenuItem.children(title: 'Edit', children: [
        MenuItem(
          title: 'Copy',
          action: () => dispatchIntent(TerminalCopyIntent()),
          accelerator: cmdOrCtrl + 'c',
        ),
        MenuItem(
          title: 'Paste',
          action: () => dispatchIntent(TerminalPasteIntent()),
          accelerator: cmdOrCtrl + 'v',
        ),
      ]),
      MenuItem.children(title: 'View', children: [
        MenuItem(
          title: 'Zoom In',
          action: () => dispatchIntent(TerminalZoomInIntent()),
          accelerator: cmdOrCtrl + '+',
        ),
        MenuItem(
          title: 'Zoom Out',
          action: () => dispatchIntent(TerminalZoomOutIntent()),
          accelerator: cmdOrCtrl + '-',
        ),
      ]),
    ];
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final tabs = TabsController();

  final group = TabGroupController();

  var tabCount = 0;

  @override
  void initState() {
    addTab();

    final group = TabsGroup(controller: this.group);

    tabs.replaceRoot(group);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          // color: Color(0xFF3A3D3F),
          color: Colors.transparent,
          child: TabsView(
            controller: tabs,
            actions: [
              TabsGroupAction(
                icon: CupertinoIcons.add,
                onTap: (group) async {
                  final tab = await buildTab();
                  group.addTab(tab, activate: true);
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  void addTab() async {
    group.addTab(await buildTab(), activate: true);
  }

  Future<Tab> buildTab() async {
    tabCount++;
    var tabIsClosed = false;

    final tab = TabController();

    if (!Platform.isWindows) {
      Directory.current = Platform.environment['HOME'] ?? '/';
    }

    // terminal.debug.enable();

    final shell = getShell();

    final backend = PtyTerminalBackend(
      shell,
      [],
    );

    // pty.write('cd\n');

    final terminal = TerminalIsolate(
      onTitleChange: tab.setTitle,
      backend: backend,
      platform: getPlatform(true),
      minRefreshDelay: Duration(milliseconds: 50),
      maxLines: 10000,
    );

    await terminal.start();

    final focusNode = FocusNode();

    SchedulerBinding.instance!.addPostFrameCallback((timeStamp) {
      focusNode.requestFocus();
    });

    terminal.backendExited
        .then(
          (_) => tab.requestClose(),
        )
        .unawaited;

    return Tab(
      controller: tab,
      title: 'Terminal',
      content: TerminalTab(
        terminal: terminal,
        focusNode: focusNode,
      ),
      onActivate: () {
        focusNode.requestFocus();
      },
      onDrop: () {
        SchedulerBinding.instance!.addPostFrameCallback((timeStamp) {
          focusNode.requestFocus();
        });
      },
      onClose: () {
        // this handler can be called multiple times.
        // e.g. click to close tab => handler => terminateBackend => exitedEvent => close tab
        // which leads to an inconsistent tabCount value
        if (tabIsClosed) {
          return;
        }
        tabIsClosed = true;
        terminal.terminateBackend();

        tabCount--;

        if (tabCount <= 0) {
          exit(0);
        }
      },
    );
  }

  String getShell() {
    if (Platform.isWindows) {
      // return r'C:\windows\system32\cmd.exe';
      return r'C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe';
    }

    return Platform.environment['SHELL'] ?? 'sh';
  }

  PlatformBehavior getPlatform([bool forLocalShell = false]) {
    if (Platform.isWindows) {
      return PlatformBehaviors.windows;
    }

    if (forLocalShell && Platform.isMacOS) {
      return PlatformBehaviors.mac;
    }

    return PlatformBehaviors.unix;
  }
}

class TerminalTab extends StatefulWidget {
  TerminalTab({
    required this.terminal,
    required this.focusNode,
  });

  final TerminalUiInteraction terminal;
  final FocusNode focusNode;
  final scrollController = ScrollController();

  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
  var fontSize = 14.0;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: actions,
      child: GestureDetector(
        onSecondaryTapDown: (details) async {
          await showContextMenu(details);
        },
        child: CupertinoScrollbar(
          controller: widget.scrollController,
          isAlwaysShown: true,
          child: TerminalView(
            scrollController: widget.scrollController,
            terminal: widget.terminal,
            focusNode: widget.focusNode,
            opacity: 0.85,
            style: TerminalStyle(
              fontSize: fontSize,
              fontFamily: const ['Cascadia Mono'],
            ),
          ),
        ),
      ),
    );
  }

  late final actions = <Type, Action<Intent>>{
    TerminalCopyIntent: CallbackAction(onInvoke: (_) => onCopy()),
    TerminalPasteIntent: CallbackAction(onInvoke: (_) => onPaste()),
    TerminalZoomInIntent: CallbackAction(onInvoke: (_) => onZoomIn()),
    TerminalZoomOutIntent: CallbackAction(onInvoke: (_) => onZoomOut()),
  };

  Future<void> showContextMenu(TapDownDetails e) async {
    final menu = Menu(buildContextMenu);
    await Window.of(context).showPopupMenu(menu, e.globalPosition);
  }

  List<MenuItem> buildContextMenu() {
    return [
      MenuItem(
        title: 'Zoom In',
        action: onZoomIn,
        accelerator: cmdOrCtrl + '+',
      ),
      MenuItem(
        title: 'Zoom Out',
        action: onZoomOut,
        accelerator: cmdOrCtrl + '-',
      ),
      MenuItem.separator(),
      MenuItem(
        title: 'Copy',
        action: onCopy,
        accelerator: cmdOrCtrl + 'c',
      ),
      MenuItem(
        title: 'Paste',
        action: onPaste,
        accelerator: cmdOrCtrl + 'v',
      ),
      MenuItem(
        title: 'Select all',
        action: () {},
        accelerator: cmdOrCtrl + 'a',
      ),
      MenuItem.separator(),
      MenuItem(
        title: 'Clear',
        action: () {},
        accelerator: cmdOrCtrl + 'k',
      ),
      MenuItem(
        title: 'Kill',
        action: onKill,
        accelerator: cmdOrCtrl + 'e',
      ),
    ];
  }

  void updateFontSize(int delta) {
    final minFontSize = 4;
    final maxFontSize = 40;

    final newFontSize = fontSize + delta;

    if (newFontSize < minFontSize || newFontSize > maxFontSize) {
      return;
    }

    setState(() => fontSize = newFontSize);
  }

  void onZoomIn() {
    updateFontSize(1);
  }

  void onZoomOut() {
    updateFontSize(-1);
  }

  void onCopy() {
    final text = widget.terminal.selectedText ?? '';
    Clipboard.setData(ClipboardData(text: text));
    widget.terminal.clearSelection();
    //widget.terminal.debug.onMsg('copy ┤$text├');
    widget.terminal.refresh();
  }

  void onPaste() async {
    final clipboardData = await Clipboard.getData('text/plain');

    final clipboardHasData = clipboardData?.text?.isNotEmpty == true;

    if (clipboardHasData) {
      widget.terminal.paste(clipboardData!.text!);
      //terminal.debug.onMsg('paste ┤${clipboardData.text}├');
    }
  }

  void onSelectAll() {
    print('Select All is currently not implemented.');
  }

  void onClear() {
    print('Clear is currently not implemented.');
  }

  void onKill() {
    widget.terminal.terminateBackend();
  }
}
