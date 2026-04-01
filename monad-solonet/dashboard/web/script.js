const RPC_URL = `${window.location.origin}/rpc/`;
const WS_URL = `ws://${window.location.hostname}:8081`;
let userAddress = null;
let ws = null;
const wsPending = {};
let wsIdCounter = 100;

const ACCOUNTS = [
  { address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", key: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" },
  { address: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8", key: "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" },
  { address: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC", key: "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" },
  { address: "0x90F79bf6EB2c4f870365E785982E1f101E93b906", key: "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6" },
  { address: "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65", key: "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a" },
  { address: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc", key: "0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba" },
  { address: "0x976EA74026E726554dB657fA54763abd0C3a0aa9", key: "0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e" },
  { address: "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955", key: "0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356" },
  { address: "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f", key: "0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97" },
  { address: "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720", key: "0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6" },
];

function setStatus(id, online) {
  const dot = document.getElementById(id);
  dot.classList.toggle('online', online);
  dot.classList.toggle('offline', !online);
}

async function rpcCall(method, params = []) {
  const response = await fetch(RPC_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ jsonrpc: "2.0", method, params, id: Date.now() })
  });
  const data = await response.json();
  return data.result;
}


function wsCall(method, params = []) {
  return new Promise((resolve, reject) => {
    const id = ++wsIdCounter;
    wsPending[id] = { resolve, reject };
    ws.send(JSON.stringify({ jsonrpc: "2.0", id, method, params }));
  });
}

async function updateEpoch() {
  try {
    const result = await wsCall('eth_call', [
      { to: '0x0000000000000000000000000000000000001000', data: '0x757991a8' },
      'latest'
    ]);
    if (!result) return;
    const hex = result.slice(2);
    const epoch = BigInt('0x' + hex.slice(0, 64));
    const inDelay = hex.slice(126, 128) === '01';
    document.getElementById('epoch').innerText =
      epoch.toLocaleString() + (inDelay ? ' (delay)' : '');
  } catch (e) { console.error('epoch fetch failed', e); }
}

function connectBlockHeightWS() {
  ws = new WebSocket(WS_URL);

  ws.onopen = () => {
    setStatus('wsStatus', true);
    ws.send(JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_subscribe", params: ["newHeads"] }));
  };

  ws.onmessage = (event) => {
    const msg = JSON.parse(event.data);

    if (msg.id && wsPending[msg.id]) {
      wsPending[msg.id].resolve(msg.result);
      delete wsPending[msg.id];
      return;
    }

    const block = msg?.params?.result;
    if (block?.number) {
      document.getElementById('blockHeight').innerText = parseInt(block.number, 16).toLocaleString();
      updateEpoch();
      if (userAddress) updateBalance();
    }
  };

  ws.onclose = () => { setStatus('wsStatus', false); setTimeout(connectBlockHeightWS, 2000); };
  ws.onerror = (e) => { setStatus('wsStatus', false); console.error("WS error", e); };
}

function switchTab(name, btn) {
  document.querySelectorAll('.tab-panel').forEach(p => p.style.display = 'none');
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.getElementById('tab-' + name).style.display = '';
  btn.classList.add('active');
}

function renderAccounts() {
  const list = document.getElementById('accountsList');
  list.innerHTML = ACCOUNTS.map((a, i) => `
    <div class="account-row">
      <span class="account-index">${i}</span>
      <div class="account-cell">
        <span title="${a.address}">${a.address.slice(0, 10)}…${a.address.slice(-8)}</span>
        <button class="copy-btn" onclick="copyText('${a.address}', this)">copy</button>
      </div>
      <div class="account-cell key">
        <span title="${a.key}">${a.key.slice(0, 10)}…${a.key.slice(-8)}</span>
        <button class="copy-btn" onclick="copyText('${a.key}', this)">copy</button>
      </div>
    </div>
  `).join('');
}

async function copyText(text, btn) {
  await navigator.clipboard.writeText(text);
  const orig = btn.innerText;
  btn.innerText = '✓';
  setTimeout(() => btn.innerText = orig, 1200);
}

async function updateStats() {
  try {
    const clientVer = await rpcCall('web3_clientVersion');
    if (clientVer) document.getElementById('clientVersion').innerText = clientVer;
    if (userAddress) updateBalance();
    setStatus('rpcStatus', true);
  } catch (e) {
    setStatus('rpcStatus', false);
    console.error(e);
  }
}

async function connectWallet() {
  if (!window.ethereum) return alert("Please install MetaMask!");
  try {
    const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
    userAddress = accounts[0];
    document.getElementById('walletContent').style.display = 'none';
    document.getElementById('accountInfo').style.display = 'block';
    document.getElementById('myAddress').innerText = userAddress.substring(0, 6) + "..." + userAddress.substring(38);
    document.getElementById('transferTo').value = userAddress;
    updateBalance();
  } catch (err) { console.error(err); }
}

function disconnectWallet() {
  userAddress = null;
  document.getElementById('walletContent').style.display = 'block';
  document.getElementById('accountInfo').style.display = 'none';
  document.getElementById('transferTo').value = "";
}

async function copyAddress() {
  await navigator.clipboard.writeText(userAddress);
  const fb = document.getElementById('copyFeedback');
  fb.style.display = 'inline';
  setTimeout(() => fb.style.display = 'none', 1500);
}

async function updateBalance() {
  try {
    const hexBalance = await rpcCall('eth_getBalance', [userAddress, 'latest']);
    if (!hexBalance) return;
    const weiString = BigInt(hexBalance).toString();
    let mon;
    if (weiString.length <= 18) {
      mon = "0." + weiString.padStart(18, '0');
    } else {
      const splitIndex = weiString.length - 18;
      mon = weiString.slice(0, splitIndex) + "." + weiString.slice(splitIndex, splitIndex + 4);
    }
    const parts = mon.split(".");
    const wholeNumber = BigInt(parts[0]).toLocaleString();
    document.getElementById('myBalance').innerText = wholeNumber + " MON";
    document.getElementById('myBalance').title = mon + " MON (Raw)";
  } catch (e) { console.error("Balance fetch failed", e); }
}

async function sendTransaction() {
  if (!userAddress) return alert("Connect wallet first!");

  const to = document.getElementById('transferTo').value.trim();
  const amount = document.getElementById('transferAmount').value;
  const res = document.getElementById('transferResult');
  document.getElementById('transferStatus').style.display = 'block';

  const MONAD_CHAIN_ID = '0x4eaf'; // 20143 in Hex

  try {
    // --- 1. NETWORK ENFORCEMENT ---
    const currentChainId = await window.ethereum.request({ method: 'eth_chainId' });

    if (currentChainId !== MONAD_CHAIN_ID) {
      res.innerHTML = "// ⚠️ Wrong Network. Requesting switch...";
      try {
        await window.ethereum.request({
          method: 'wallet_switchEthereumChain',
          params: [{ chainId: MONAD_CHAIN_ID }],
        });
      } catch (switchError) {
        // This error code indicates that the chain has not been added to MetaMask.
        if (switchError.code === 4902) {
          await registerToMetaMask();
        } else {
          throw new Error("Switch to Monad Solonet (Chain 20143) to continue.");
        }
      }
      return; // Stop execution so user can click send again once switched
    }

    res.innerHTML = "✍️ Awaiting MetaMask Signature...";
    res.style.color = "var(--monad-text)";

    const hexValue = "0x" + BigInt(Math.floor(parseFloat(amount || 0) * 1e18)).toString(16);

    // --- 2. SEND TRANSACTION ---
    const txHash = await window.ethereum.request({
      method: 'eth_sendTransaction',
      params: [{
        from: userAddress,
        to: to,
        value: hexValue,
        chainId: MONAD_CHAIN_ID // Explicitly bind to Monad 20143
      }]
    });

    const startTime = Date.now();

    // Broadcast Info
    res.innerHTML = `
      <div style="display: grid; grid-template-columns: 120px 1fr; gap: 5px; font-family: 'Roboto Mono', monospace;">
        <span style="color:var(--monad-dim)">TX Hash:</span>
        <span style="color:#fff; word-break: break-all;">${txHash}</span>
        <span style="color:var(--monad-dim)">Status:</span>
        <span style="color:var(--monad-cyan)">⏳ Sequencing...</span>
      </div>
    `;

    // --- 3. POLLING ---
    let receipt = null;
    while (!receipt) {
      await new Promise(r => setTimeout(r, 100));
      receipt = await rpcCall('eth_getTransactionReceipt', [txHash]);
    }

    const duration = Date.now() - startTime;

    // --- 4. FINALIZED UI ---
    res.innerHTML = `
      <div style="display: grid; grid-template-columns: 120px 1fr; gap: 5px; font-family: 'Roboto Mono', monospace;">
        <span style="color:var(--monad-dim)">TX Hash:</span>
        <span style="color:#fff; word-break: break-all;">${txHash}</span>
      </div>
      <div style="margin-top: 15px; padding-top: 10px; border-top: 1px dashed var(--monad-border);">
        <div style="color:var(--monad-cyan); font-weight:bold; margin-bottom: 5px; font-family:'Roboto Mono',monospace; font-size:0.75rem; letter-spacing:0.08em;">⚡ TRANSACTION FINALIZED</div>
        <div style="display: grid; grid-template-columns: 120px 1fr; gap: 5px; font-family: 'Roboto Mono', monospace;">
            <span style="color:var(--monad-dim)">Receipt Hash:</span>
            <span style="color:#fff; word-break: break-all;">${receipt.transactionHash}</span>
            <span style="color:var(--monad-dim)">Inclusion Time:</span>
            <span style="color:#fff"><strong>${duration}ms</strong></span>
            <span style="color:var(--monad-dim)">Block:</span>
            <span style="color:#fff">#${parseInt(receipt.blockNumber, 16)}</span>
            <span style="color:var(--monad-dim)">Status:</span>
            <span>${parseInt(receipt.status, 16) === 1 ? "✅ Success" : "❌ Reverted"}</span>
            <span style="color:var(--monad-dim)">Gas Used:</span>
            <span style="color:#fff">${parseInt(receipt.gasUsed, 16).toLocaleString()}</span>
        </div>
      </div>`;

    updateBalance();
  } catch (err) {
    res.innerHTML = `<div style="color:var(--monad-berry); margin-top:10px;">// Error: ${err.message || "User rejected"}</div>`;
  }
}

async function lookupBlock() {
  const input = document.getElementById('blockInput').value.trim();
  const display = document.getElementById('blockContent');
  if (!input) return;
  document.getElementById('blockResult').style.display = 'block';
  try {
    let res = input.startsWith('0x') ? await rpcCall('eth_getBlockByHash', [input, false]) : await rpcCall('eth_getBlockByNumber', ["0x" + parseInt(input).toString(16), false]);
    display.innerText = res ? JSON.stringify(res, null, 2) : "// Not found";
  } catch (e) { display.innerText = "// Error: " + e.message; }
}

async function lookupTransaction() {
  const hash = document.getElementById('txHashInput').value.trim();
  const display = document.getElementById('txContent');
  if (!hash) return;
  document.getElementById('txResult').style.display = 'block';
  try {
    const tx = await rpcCall('eth_getTransactionByHash', [hash]);
    display.innerText = tx ? JSON.stringify(tx, null, 2) : "// Not found";
  } catch (e) { display.innerText = "// Error: " + e.message; }
}

async function registerToMetaMask() {
  const chainIdHex = await rpcCall('eth_chainId');
  window.ethereum.request({
    method: 'wallet_addEthereumChain',
    params: [{ chainId: chainIdHex, chainName: "Monad Solonet", nativeCurrency: { name: 'Monad', symbol: 'MON', decimals: 18 }, rpcUrls: [RPC_URL] }]
  }).catch(e => alert(e.message));
}

document.getElementById('solonetVersion').innerText = window.SOLONET_VERSION ?? '—';
renderAccounts();
connectBlockHeightWS();
updateStats();
setInterval(updateStats, 10000);
