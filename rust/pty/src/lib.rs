use core::slice;
use std::io::Read;
use std::mem::{self};
use std::os::raw::c_char;
use std::sync::{Arc, Mutex};
use std::thread::sleep;
use std::time::Duration;
use std::usize;
use std::{ffi::CStr, thread};

use allo_isolate::Isolate;
use portable_pty::{native_pty_system, Child, CommandBuilder, ExitStatus, PtyPair, PtySize};

// StudioPty stores all states that is associated with the pty.
struct StudioPty {
    pair: PtyPair,
    child: Arc<SharedChild>,
}

// SharedChild is a wrapper on Child to allow the child being accessed from
// multiple threads.
struct SharedChild {
    child: Mutex<Box<dyn Child + Send + Sync>>,
}

impl SharedChild {
    fn new(child: Box<dyn Child + Send + Sync>) -> Self {
        let child = Mutex::new(child);
        Self { child }
    }

    fn wait(&self) -> ExitStatus {
        loop {
            let status = self.child.lock().unwrap().try_wait().unwrap();
            if let Some(exitcode) = status {
                return exitcode;
            }
            sleep(Duration::from_millis(100))
        }
    }

    fn kill(&self) {
        self.child.lock().unwrap().kill().unwrap();
    }
}

#[no_mangle]
pub extern "C" fn pty_new(
    executable: *const c_char,
    argc: isize,
    argv: *const *const c_char,
    output_port: i64,
    exitcode_port: i64,
) -> usize {
    let executable = unsafe { CStr::from_ptr(executable).to_str().unwrap().to_string() };
    let arguments = save_arguments(argc, argv);
    let output_port = Isolate::new(output_port);
    let exitcode_port = Isolate::new(exitcode_port);

    let pair = new_pty();
    let mut cmd = CommandBuilder::new(executable);
    cmd.args(&arguments);

    let child = pair.slave.spawn_command(cmd).unwrap();
    let child = Arc::new(SharedChild::new(child));
    thread_wait_child_exit(Arc::clone(&child), exitcode_port);

    let reader = pair.master.try_clone_reader().unwrap();
    thread_read_output(reader, output_port);

    let pty = Box::new(StudioPty { pair, child });
    let pty_handle = Box::into_raw(pty) as usize;
    pty_handle
}

fn new_pty() -> PtyPair {
    let pty_system = native_pty_system();
    let pair = pty_system
        .openpty(PtySize {
            rows: 24,
            cols: 80,
            // Not all systems support pixel_width, pixel_height,
            // but it is good practice to set it to something
            // that matches the size of the selected font.  That
            // is more complex than can be shown here in this
            // brief example though!
            pixel_width: 0,
            pixel_height: 0,
        })
        .unwrap();
    pair
}

fn save_arguments(argc: isize, argv: *const *const c_char) -> Vec<String> {
    let mut result = vec![];

    unsafe {
        for i in 0..argc {
            let argument = CStr::from_ptr(*argv.offset(i));
            result.push(argument.to_str().unwrap().to_string());
        }
    }

    return result;
}

fn thread_wait_child_exit(child: Arc<SharedChild>, exitcode_port: Isolate) {
    thread::spawn(move || {
        let exitcode = child.wait();
        exitcode_port.post(exitcode.success());
    });
}

fn thread_read_output(mut reader: Box<dyn Read + Send>, output_port: Isolate) {
    thread::spawn(move || {
        let mut buffer = [0u8; 4096];

        loop {
            let ret = reader.read(&mut buffer);
            match ret {
                Ok(size) => {
                    if size == 0 {
                        break;
                    }
                    let data = Vec::from(&buffer[..size]);
                    output_port.post(data);
                }
                Err(error) => {
                    dbg!(error);
                    return;
                }
            }
        }
    });
}

#[no_mangle]
pub extern "C" fn pty_write(handle: *mut usize, data: *const u8, size: usize) {
    let mut pty = unsafe { Box::<StudioPty>::from_raw(handle.cast()) };
    let data = unsafe { slice::from_raw_parts(data, size) };
    pty.pair.master.write_all(data).unwrap();
    mem::forget(pty);
}

#[no_mangle]
pub extern "C" fn pty_resize(
    handle: *mut usize,
    rows: usize,
    cols: usize,
    pixel_width: usize,
    pixel_height: usize,
) -> bool {
    let pty = unsafe { Box::<StudioPty>::from_raw(handle.cast()) };
    let result = pty.pair.master.resize(PtySize {
        rows: rows as u16,
        cols: cols as u16,
        pixel_width: pixel_width as u16,
        pixel_height: pixel_height as u16,
    });

    mem::forget(pty);

    match result {
        Ok(_) => true,
        Err(_) => false,
    }
}

#[no_mangle]
pub extern "C" fn pty_kill(handle: *mut usize) {
    let pty = unsafe { Box::<StudioPty>::from_raw(handle.cast()) };
    pty.child.kill();
    mem::forget(pty);
}

#[no_mangle]
pub extern "C" fn pty_drop(handle: *mut usize) {
    let _ = unsafe { Box::<StudioPty>::from_raw(handle.cast()) };
}

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
