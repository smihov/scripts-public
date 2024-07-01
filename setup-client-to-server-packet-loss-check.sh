#!/bin/bash

# Exit on any error
set -e

# Update system and install dependencies
apt update
apt upgrade -y
apt install -y curl build-essential python3 git lsof

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Install node-pre-gyp globally
npm install -g node-pre-gyp

# Create server directory
mkdir -p /opt/webrtc_server/results
cd /opt/webrtc_server

# Initialize a new Node.js project
npm init -y

# Install dependencies
npm install uNetworking/uWebSockets.js#v20.10.0 wrtc serve-static finalhandler uuid express

# Kill any processes using ports 443 and 9001
if lsof -Pi :443 -sTCP:LISTEN -t >/dev/null ; then
    lsof -Pi :443 -sTCP:LISTEN -t | xargs kill -9
fi

if lsof -Pi :9001 -sTCP:LISTEN -t >/dev/null ; then
    lsof -Pi :9001 -sTCP:LISTEN -t | xargs kill -9
fi

# Generate self-signed SSL certificate
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/webrtc-selfsigned.key -out /etc/ssl/certs/webrtc-selfsigned.crt -subj "/CN=$(curl -4 icanhazip.com)"

# Create server code
cat <<'EOF' > server.js
const uWS = require('uWebSockets.js');
const wrtc = require('wrtc');
const express = require('express');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const https = require('https');

const app = express();
const resultsDir = path.join(__dirname, 'results');

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Serve result files
app.get('/results/:id', (req, res) => {
  const filePath = path.join(resultsDir, `${req.params.id}.json`);
  if (fs.existsSync(filePath)) {
    fs.readFile(filePath, 'utf8', (err, data) => {
      if (err) {
        res.status(500).send('Failed to read result file');
        return;
      }
      const resultData = JSON.parse(data);
      res.send(`
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <title>Packet Loss Test Results</title>
          <style>
            body {
              font-family: Arial, sans-serif;
              text-align: center;
              background: #f0f0f0;
              margin: 0;
              padding: 0;
            }
            .container {
              max-width: 600px;
              margin: 100px auto;
              padding: 20px;
              background: white;
              border-radius: 10px;
              box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
            }
            h1 {
              color: #333;
            }
            .result {
              margin: 20px 0;
              padding: 10px;
              background: #e9e9e9;
              border-radius: 5px;
            }
            button {
              background: #4caf50;
              color: white;
              border: none;
              padding: 10px 20px;
              font-size: 16px;
              border-radius: 5px;
              cursor: pointer;
            }
            button:hover {
              background: #45a049;
            }
            .logo {
              width: 100%;
              max-width: 200px;
              margin: 20px auto;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <img src="/411logo.png" alt="411Logo" class="logo">
            <h1>Packet Loss Test Results</h1>
            <div class="result">
              <p>Total Packets: ${resultData.totalPackets}</p>
              <p>Received Packets: ${resultData.receivedPackets}</p>
              <p>Packet Loss: ${resultData.packetLoss.toFixed(2)}%</p>
            </div>
            <button onclick="copyLink()">Copy Link</button>
          </div>
          <script>
            function copyLink() {
              const testLink = window.location.href;
              navigator.clipboard.writeText(testLink).then(() => {
                alert('Copied link to clipboard: ' + testLink);
              }).catch(err => {
                console.error('Failed to copy link:', err);
                alert('Failed to copy link. Please manually copy the link: ' + testLink);
              });
            }
          </script>
        </body>
        </html>
      `);
    });
  } else {
    res.status(404).send('Result not found');
  }
});

// Create HTTPS server for Express and uWebSockets.js
const httpsOptions = {
  key: fs.readFileSync('/etc/ssl/private/webrtc-selfsigned.key'),
  cert: fs.readFileSync('/etc/ssl/certs/webrtc-selfsigned.crt')
};

const httpsServer = https.createServer(httpsOptions, app);

httpsServer.listen(443, () => {
  console.log('HTTPS server listening on port 443');
});

const uwsApp = uWS.SSLApp({
  key_file_name: '/etc/ssl/private/webrtc-selfsigned.key',
  cert_file_name: '/etc/ssl/certs/webrtc-selfsigned.crt'
}).ws('/*', {
  open: (ws) => {
    console.log('WebSocket connection opened');
  },
  message: (ws, message, isBinary) => {
    const strMessage = Buffer.from(message).toString();
    console.log('Received WebSocket message:', strMessage);
    try {
      const { type, offer, testId } = JSON.parse(strMessage);
      if (type === 'offer') {
        const peerConnection = new wrtc.RTCPeerConnection({
          iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
        });

        peerConnection.onicecandidate = (event) => {
          if (event.candidate) {
            console.log('New ICE candidate:', event.candidate);
          }
        };

        peerConnection.ondatachannel = (event) => {
          const receiveChannel = event.channel;
          const receivedPackets = [];
          receiveChannel.onmessage = (event) => {
            console.log('Received message:', event.data);
            receivedPackets.push(event.data);
            receiveChannel.send(event.data); // Echo the message back

            // When all packets are received, store the result and send the link
            if (receivedPackets.length === 200) {
              const resultsFilePath = path.join(resultsDir, `${testId}.json`);
              const resultData = {
                totalPackets: 200,
                receivedPackets: receivedPackets.length,
                packetLoss: ((200 - receivedPackets.length) / 20) * 100
              };
              fs.writeFile(resultsFilePath, JSON.stringify(resultData), (err) => {
                if (err) {
                  console.error('Failed to write results file:', err);
                } else {
                  console.log('Results written to file:', resultsFilePath);
                  ws.send(JSON.stringify({ type: 'result', url: `/results/${testId}` }));
                }
              });
            }
          };
        };

        peerConnection.setRemoteDescription(new wrtc.RTCSessionDescription(offer)).then(() => {
          return peerConnection.createAnswer();
        }).then((answer) => {
          return peerConnection.setLocalDescription(answer);
        }).then(() => {
          ws.send(JSON.stringify({ type: 'answer', answer: peerConnection.localDescription }));
        });
      }
    } catch (e) {
      console.error('Failed to parse message:', e);
    }
  },
  close: (ws, code, message) => {
    console.log('WebSocket connection closed');
  }
}).listen(9001, (token) => {
  if (token) {
    console.log('Secure WebSocket server listening on port 9001');
  } else {
    console.log('Secure WebSocket server failed to start');
  }
});

// Clean up old result files older than 7 days
const cleanupOldFiles = () => {
  const now = Date.now();
  const expirationTime = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds

  fs.readdir(resultsDir, (err, files) => {
    if (err) {
      console.error('Failed to read results directory:', err);
      return;
    }
    files.forEach(file => {
      const filePath = path.join(resultsDir, file);
      fs.stat(filePath, (err, stats) => {
        if (err) {
          console.error('Failed to stat file:', err);
          return;
        }
        if (now - stats.mtimeMs > expirationTime) {
          fs.unlink(filePath, err => {
            if (err) {
              console.error('Failed to delete old file:', err);
            } else {
              console.log('Deleted old file:', filePath);
            }
          });
        }
      });
    });
  });
};

// Schedule cleanup every 24 hours
setInterval(cleanupOldFiles, 24 * 60 * 60 * 1000);
EOF

# Create client HTML page
mkdir -p public
cat <<'EOF' > public/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Packet Loss Test</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      text-align: center;
      background: #f0f0f0;
      margin: 0;
      padding: 0;
    }
    .container {
      max-width: 600px;
      margin: 100px auto;
      padding: 20px;
      background: white;
      border-radius: 10px;
      box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
    }
    h1 {
      color: #333;
    }
    button {
      background: #4caf50;
      color: white;
      border: none;
      padding: 10px 20px;
      font-size: 16px;
      border-radius: 5px;
      cursor: pointer;
    }
    button:hover {
      background: #45a049;
    }
    #loading-bar {
      width: 100%;
      background-color: #f3f3f3;
      border: 1px solid #ddd;
      margin-top: 20px;
      padding: 5px;
    }
    #loading-bar div {
      height: 20px;
      width: 0;
      background-color: #4caf50;
    }
    #result {
      margin-top: 20px;
    }
    .logo {
      width: 100%;
      max-width: 200px;
      margin: 20px auto;
    }
  </style>
</head>
<body>
  <div class="container">
    <img src="/411logo.png" alt="411Logo" class="logo">
    <h1>Packet Loss Test</h1>
    <button id="startTest">TEST</button>
    <div id="loading-bar" style="display: none;">
      <div></div>
    </div>
    <div id="result"></div>
  </div>
  <script>
    const startButton = document.getElementById('startTest');
    const loadingBar = document.getElementById('loading-bar').firstElementChild;
    const resultDiv = document.getElementById('result');
    const testId = Date.now() + '-' + Math.random().toString(36).substr(2, 9);

    startButton.addEventListener('click', () => {
      startButton.style.display = 'none';
      document.getElementById('loading-bar').style.display = 'block';

      const socket = new WebSocket('wss://' + location.hostname + ':9001');

      socket.onopen = () => {
        console.log('WebSocket connection opened');
        const peerConnection = new RTCPeerConnection({ iceServers: [{ urls: 'stun:stun.l.google.com:19302' }] });

        peerConnection.onicecandidate = (event) => {
          if (event.candidate) {
            console.log('New ICE candidate:', event.candidate);
          }
        };

        const dataChannel = peerConnection.createDataChannel('ping-pong');
        let receivedPackets = 0;
        const totalPackets = 200;

        dataChannel.onopen = () => {
          console.log('Data channel is open');
          for (let i = 1; i <= totalPackets; i++) {
            setTimeout(() => {
              const pingMessage = 'ping ' + i;
              dataChannel.send(pingMessage);
              loadingBar.style.width = ((i / totalPackets) * 100) + '%';
            }, i * 100);
          }
        };

        dataChannel.onmessage = (event) => {
          const packetNumber = event.data.split(' ')[1];
          console.log(`Packet ${packetNumber} received`);
          receivedPackets++;
          if (receivedPackets === totalPackets) {
            loadingBar.style.width = '100%';
            const packetLoss = ((totalPackets - receivedPackets) / totalPackets) * 100;
            socket.send(JSON.stringify({ type: 'result', testId: testId, totalPackets: totalPackets, receivedPackets: receivedPackets, packetLoss: packetLoss.toFixed(2) }));
          }
        };

        peerConnection.createOffer().then((offer) => {
          return peerConnection.setLocalDescription(offer);
        }).then(() => {
          console.log('Offer created and set as local description:', peerConnection.localDescription.sdp);
          socket.send(JSON.stringify({ type: 'offer', offer: peerConnection.localDescription, testId: testId }));
        });

        socket.onmessage = async (event) => {
          const message = JSON.parse(event.data);
          if (message.type === 'answer') {
            await peerConnection.setRemoteDescription(new RTCSessionDescription(message.answer));
          }
          if (message.type === 'result' && message.url) {
            window.location.href = message.url;
          }
        };
      };
    });
  </script>
</body>
</html>
EOF

# Start the server
node server.js &

echo "Server setup complete. Open a web browser and navigate to https://$(curl -4 icanhazip.com) to test the packet loss functionality."

