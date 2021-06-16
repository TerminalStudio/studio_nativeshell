use core::slice;
use std::io::Read;
use std::mem::{self};
use std::os::raw::c_char;
use std::usize;
use std::{ffi::CStr, thread};

use allo_isolate::Isolate;
use portable_pty::{native_pty_system, Child, CommandBuilder, PtyPair, PtySize};

struct StudioPty {
    pair: PtyPair,
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
    thread_wait_child_exit(child, exitcode_port);

    let reader = pair.master.try_clone_reader().unwrap();
    thread_read_output(reader, output_port);

    let pty = Box::new(StudioPty { pair });
    Box::into_raw(pty) as usize
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

fn thread_wait_child_exit(mut child: Box<dyn Child + Send + Sync>, exitcode_port: Isolate) {
    thread::spawn(move || {
        let status = child.wait();
        match status {
            Ok(exitcode) => {
                exitcode_port.post(exitcode.success());
            }
            Err(error) => {
                dbg!(error);
                return;
            }
        }
    });
}

fn thread_read_output(mut reader: Box<dyn Read + Send>, output_port: Isolate) {
    thread::spawn(move || {
        let mut buffer = [0; 4096];

        loop {
            let ret = reader.read(&mut buffer);
            match ret {
                Ok(size) => {
                    if size == 0 {
                        return;
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
