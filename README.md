
# WebRTC Packet Loss Test Server

## Why?

Because the entire internet kept insisting that this is not possible. Yet - here we are - quite possible.

## Overview

This script sets up a WebRTC Packet Loss Test Server using Node.js and various other dependencies. The server uses `uWebSockets.js` for WebSocket communication and `express` for serving static files. It uses a Let's Encrypt SSL certificate for secure connections.

## Features

- **WebRTC Data Channel Test:** Tests packet loss over a WebRTC data channel.
- **HTTPS Support:** Serves the test page over HTTPS using a Let's Encrypt SSL certificate.
- **WebSocket Support:** Handles WebSocket connections for WebRTC signaling.
- **Result Storage:** Stores test results on the server and provides a link to view the results.
- **Automated Cleanup:** Periodically cleans up old result files.

## Prerequisites

- A Debian-based system (Ubuntu recommended)
- A registered domain name pointing to your server
- `curl`
- `git`
- `python3`

## Installation

1. **Clone the Repository:**
   ```sh
   git clone <repository_url>
   cd <repository_directory>
   ```

2. **Set Your Domain Name:**
   Open the script and set your domain name at the beginning of the script:
   ```sh
   DOMAIN_NAME="your_domain"
   ```

3. **Run the Setup Script:**
   ```sh
   chmod +x setup.sh
   ./setup.sh
   ```

4. **Access the Server:**
   Open a web browser and navigate to `https://your_domain` to start the packet loss test.

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

### Certbot Installation and SSL Certificate Generation

```sh
apt install -y certbot python3-certbot-nginx
certbot certonly --standalone -d $DOMAIN_NAME --email your_email --agree-tos --non-interactive
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
https://$DOMAIN_NAME
```

## Notes

- **Domain Configuration:** Ensure your domain's DNS is properly configured and points to the server where this script is run.
- **Firewall Settings:** Ensure that ports 80, 443, and 9001 are open on your firewall.
- **Renewal:** Let's Encrypt certificates are valid for 90 days. Set up a cron job to renew the certificates automatically. For example:
  ```sh
  0 0,12 * * * certbot renew --quiet
  ```

## Contributing

Contributions are welcome. Please fork the repository and submit pull requests.

## License

This project is licensed under the MIT License.

---

This README provides a comprehensive guide to setting up and using the WebRTC Packet Loss Test Server. If you encounter any issues or have questions, please feel free to open an issue on the repository.
