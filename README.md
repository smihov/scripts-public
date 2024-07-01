
# WebRTC Packet Loss Test Server

## Why?

Because the entire internet kept insisting that this is not possible. Yet - here we are - quite possible.

## Overview

This script sets up a WebRTC Packet Loss Test Server using Node.js and various other dependencies. The server uses `uWebSockets.js` for WebSocket communication and `express` for serving static files. It also generates a self-signed SSL certificate for secure connections.

## Features

- **WebRTC Data Channel Test:** Tests packet loss over a WebRTC data channel.
- **HTTPS Support:** Serves the test page over HTTPS using a self-signed SSL certificate.
- **WebSocket Support:** Handles WebSocket connections for WebRTC signaling.
- **Result Storage:** Stores test results on the server and provides a link to view the results.
- **Automated Cleanup:** Periodically cleans up old result files.

## Prerequisites

- A Debian-based system (This has been tested and created on Debian 12, other OS might require some tweaks)
- `curl`
- `git`
- `python3`

## Installation

1. **Clone the Repository:**
   ```sh
   git clone <repository_url>
   cd <repository_directory>
   ```

2. **Run the Setup Script:**
   ```sh
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Access the Server:**
   Open a web browser and navigate to `https://<your_server_ip>` to start the packet loss test.

## Script Breakdown

### System Update and Dependency Installation

```sh
apt update
apt upgrade -y
apt install -y curl build-essential python3 git lsof
```

### Node.js and npm Setup

```sh
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs
npm install -g node-pre-gyp
```

### Server Directory Setup

```sh
mkdir -p /opt/webrtc_server/results
cd /opt/webrtc_server
npm init -y
npm install uNetworking/uWebSockets.js#v20.10.0 wrtc serve-static finalhandler uuid express
```

### Port Cleanup

```sh
if lsof -Pi :443 -sTCP:LISTEN -t >/dev/null ; then
    lsof -Pi :443 -sTCP:LISTEN -t | xargs kill -9
fi

if lsof -Pi :9001 -sTCP:LISTEN -t >/dev/null ; then
    lsof -Pi :9001 -sTCP:LISTEN -t | xargs kill -9
fi
```

### SSL Certificate Generation

```sh
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/webrtc-selfsigned.key -out /etc/ssl/certs/webrtc-selfsigned.crt -subj "/CN=$(curl -4 icanhazip.com)"
```

### Server Code (`server.js`)

Creates a Node.js server using `uWebSockets.js` and `express` to handle WebRTC signaling and serve static files.

### Client HTML Page (`public/index.html`)

A simple HTML page that initiates the WebRTC packet loss test and displays the result.

## Running the Server

The server is started as a background process:

```sh
node server.js &
```

To access the server, open a web browser and navigate to:

```sh
https://$(curl -4 icanhazip.com)
```

## Notes

- **Security Warning:** This setup uses a self-signed SSL certificate, which is not secure for production use. For production, use a certificate from a trusted Certificate Authority (CA).
- **Port Availability:** Ensure ports 443 and 9001 are available and not used by other services.
- **Old Result Cleanup:** The server automatically deletes result files older than 7 days.

## Contributing

Contributions are welcome. Please fork the repository and submit pull requests.

## License

This project is licensed under the MIT License.

---

This README provides a comprehensive guide to setting up and using the WebRTC Packet Loss Test Server. If you encounter any issues or have questions, please feel free to open an issue on the repository.
