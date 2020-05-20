//! A very basic webserver that handles the Postmark webhook.
//!
//! This server simply stores and provides the last `POST` body received.
//!
//! Assumes a buffering front proxy, and no pipelining. (Like Nginx with defaults.)

#![deny(warnings)]

use httparse::{Request, Status, EMPTY_HEADER};
use std::env;
use std::io::{Read, Write};
use std::net::{SocketAddr, TcpListener};

pub fn main() {
    let listen_addr = env::var("LISTEN_ADDR").expect("LISTEN_ADDR is required");
    let secret_file = env::var("SECRET_FILE").expect("SECRET_FILE is required");

    let secret = std::fs::read(secret_file).expect("Could not read SECRET_FILE");
    let secret = String::from_utf8(secret).expect("SECRET_FILE is not UTF-8");
    let secret = secret.trim();

    const BUF_LEN: usize = 65536;
    let mut last_post = Vec::with_capacity(BUF_LEN);

    let listen_addr: SocketAddr = listen_addr.parse().expect("Invalid LISTEN_ADDR");
    let listener = TcpListener::bind(listen_addr).expect("Could not bind socket");
    'accept: loop {
        let (mut stream, _) = listener.accept().expect("Could not accept connection");

        // We can't accept while in this read/write loop, but assume our front proxy is buffering
        // so both reading and writing are immediately available.
        enum Action {
            None,
            RecvBody { body_start: usize, body_len: usize },
            SendBody,
        }
        let mut buf = [0; BUF_LEN];
        let mut pos = 0;
        let mut action = Action::None;
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
            let body_start = match req.parse(&buf[..pos]) {
                Err(_) => continue 'accept,
                Ok(Status::Partial) => continue 'read,
                Ok(Status::Complete(bytes)) => bytes,
            };

            let in_secret = req
                .path
                .filter(|path| path.starts_with("/autotest/"))
                .map(|path| &path[10..]);
            let status_line = if in_secret != Some(secret) {
                "400 Bad Request"
            } else if req.method == Some("POST") {
                match req
                    .headers
                    .iter()
                    .find(|header| header.name.eq_ignore_ascii_case("Content-Length"))
                    .and_then(|header| std::str::from_utf8(header.value).ok())
                    .and_then(|value| value.parse().ok())
                {
                    Some(body_len) if body_len <= BUF_LEN - body_start => {
                        action = Action::RecvBody {
                            body_start,
                            body_len,
                        };
                        "200 OK"
                    }
                    Some(_) => "413 Payload Too Large",
                    None => "400 Bad Request",
                }
            } else if req.method == Some("GET") {
                action = Action::SendBody;
                "200 OK"
            } else {
                "405 Method Not Allowed"
            };

            let res = format!("HTTP/1.1 {}\r\nConnection: close\r\n\r\n", status_line);
            if let Err(_) = stream.write_all(res.as_bytes()) {
                continue 'accept;
            }

            break 'read;
        }

        match action {
            Action::None => {}
            Action::RecvBody {
                body_start,
                body_len,
            } => {
                let body_end = body_start + body_len;
                if let Err(_) = stream.read_exact(&mut buf[pos..body_end]) {
                    continue 'accept;
                }
                last_post.clear();
                last_post.extend_from_slice(&buf[body_start..body_end]);
            }
            Action::SendBody => {
                if let Err(_) = stream.write_all(&last_post) {
                    continue 'accept;
                }
                last_post.clear();
            }
        }
    }
}
