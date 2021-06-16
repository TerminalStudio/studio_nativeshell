# NativeShell Application Template

This is a template for minimal NativeShell application.

## Prerequisites

1. [Install Rust](https://www.rust-lang.org/tools/install)
2. [Install Flutter](https://flutter.dev/docs/get-started/install)
3. [Enable Flutter desktop support](https://flutter.dev/desktop#set-up)
4. Switch to Fluttter Master (`flutter channel master; flutter upgrade`)

## Getting Started

TL;DR
```
dart sync_deps.dart clone
dart sync_deps.dart checkout
dart sync_deps.dart pub
cargo run
```

Get git dependencies with `dart sync_deps.dart clone`;

Launch it with `cargo run`.

To debug or hot reload dart code, start the `Flutter: Attach to Process` configuration once the application runs.

For more information go to [nativeshell.dev](https://nativeshell.dev).

