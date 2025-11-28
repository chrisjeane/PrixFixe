# SimpleServer Example

A basic SMTP server that accepts connections and logs received messages to the console.

## Features

- Listens on port 2525 (non-privileged port)
- Accepts up to 10 concurrent connections
- Handles messages up to 10 MB
- Logs all received messages to stdout
- Works on macOS and Linux

## Building

```bash
cd Examples/SimpleServer
swift build
```

## Running

```bash
swift run
```

Or after building:

```bash
.build/debug/SimpleServer
```

## Testing

You can test the server using telnet or any SMTP client:

### Using telnet:

```bash
telnet localhost 2525
```

Then type:

```
EHLO test.example.com
MAIL FROM:<sender@example.com>
RCPT TO:<recipient@example.com>
DATA
Subject: Test Message

This is a test message body.
.
QUIT
```

### Using swaks (Swiss Army Knife SMTP):

```bash
# Install swaks first (macOS: brew install swaks, Ubuntu: apt install swaks)
swaks --to recipient@example.com --from sender@example.com --server localhost:2525 --body "Test message"
```

### Using Python:

```python
import smtplib
from email.message import EmailMessage

msg = EmailMessage()
msg.set_content("This is a test message")
msg['Subject'] = 'Test from Python'
msg['From'] = 'sender@example.com'
msg['To'] = 'recipient@example.com'

with smtplib.SMTP('localhost', 2525) as server:
    server.send_message(msg)
    print("Message sent!")
```

## Platform Notes

### macOS
- You may be prompted to allow network access
- Uses Network.framework by default (or Foundation sockets as fallback)

### Linux
- Uses Foundation sockets (BSD/POSIX)
- Requires Swift 6.0+ installed
- No special permissions needed for port 2525

## Stopping

Press Ctrl+C to stop the server gracefully.
