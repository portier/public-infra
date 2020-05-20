//! A very basic webserver that receives a webhook and runs a command.
//!
//! Ensures the command runs only once simultaneously, queuing a rerun if new requests arrive in
//! the mean time. Command output is simply forwarded to our own output.
//!
//! Assumes a buffering front proxy, and no pipelining. (Like Nginx with defaults.)
//!
//! This tool is deliberately kept as simple as possible, because it runs as root.

#![deny(warnings)]

use httparse::{Request, Status, EMPTY_HEADER};
use std::env;
use std::io::{Read, Write};
use std::net::{SocketAddr, TcpListener};
use std::process::{Command, Stdio};
use std::sync::mpsc::{sync_channel, TrySendError};

pub fn main() {
    let listen_addr = env::var("LISTEN_ADDR").expect("LISTEN_ADDR is required");
    let secret_file = env::var("SECRET_FILE").expect("SECRET_FILE is required");
    let command = env::var_os("COMMAND").expect("COMMAND is required");

    let secret = std::fs::read(secret_file).expect("Could not read SECRET_FILE");
    let secret = String::from_utf8(secret).expect("SECRET_FILE is not UTF-8");
    let secret = secret.trim();

    // Use a channel with queue size 1 to achieve the debounce behavior we want.
    let (worker_sender, worker_receiver) = sync_channel(1);
    let worker_thread = std::thread::spawn(move || {
        for _ in worker_receiver {
            match Command::new(&command).stdin(Stdio::null()).status() {
                Ok(status) => {
                    if !status.success() {
                        eprintln!("Command failed: {}", status);
                    }
                }
                Err(err) => {
                    eprintln!("Could not run command: {}", err);
                }
            }
        }
    });

    let listen_addr: SocketAddr = listen_addr.parse().expect("Invalid LISTEN_ADDR");
    let listener = TcpListener::bind(listen_addr).expect("Could not bind socket");
    'accept: loop {
        let (mut stream, _) = listener.accept().expect("Could not accept connection");

        // We can't accept while in this read/write loop, but assume our front proxy is buffering
        // so both reading and writing are immediately available.
        const BUF_LEN: usize = 4096;
        let mut buf = [0; BUF_LEN];
        let mut pos = 0;
        'read: loop {
            if pos == BUF_LEN {
                continue 'accept;
            }
            match stream.read(&mut buf[pos..]) {
                Err(_) => continue 'accept,
                Ok(0) => continue 'accept,
                Ok(n) => pos += n,
            }

            let mut headers = [EMPTY_HEADER; 16];
            let mut req = Request::new(&mut headers);
            match req.parse(&buf[..pos]) {
                Err(_) => continue 'accept,
                Ok(Status::Partial) => continue 'read,
                Ok(Status::Complete(_)) => {}
            }

            let auth_header = req
                .headers
                .iter()
                .find(|header| header.name.eq_ignore_ascii_case("Authorization"))
                .filter(|header| header.value.starts_with(b"Bearer "))
                .map(|header| &header.value[7..]);
            let status_line = if req.path != Some("/webhook") {
                "400 Bad Request"
            } else if req.method != Some("POST") {
                "405 Method Not Allowed"
            } else if auth_header != Some(secret.as_bytes()) {
                "401 Unauthorized"
            } else {
                match worker_sender.try_send(()) {
                    Ok(_) | Err(TrySendError::Full(_)) => "202 Accepted",
                    Err(TrySendError::Disconnected(_)) => {
                        worker_thread.join().expect("Worker thread panicked");
                        panic!("Worker thread unexpectedly exited");
                    }
                }
            };

            let res = format!("HTTP/1.1 {}\r\nConnection: close\r\n\r\n", status_line);
            if let Err(_) = stream.write_all(res.as_bytes()) {
                continue 'accept;
            }

            break 'read;
        }
    }
}
