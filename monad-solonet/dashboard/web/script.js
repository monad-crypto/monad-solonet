const RPC_URL = `${window.location.origin}/rpc/`;
let userAddress = null;

async function rpcCall(method, params = []) {
  const response = await fetch(RPC_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ jsonrpc: "2.0", method, params, id: Date.now() })
  });
  const data = await response.json();
  return data.result;
}

async function updateStats() {
  try {
    const hexHeight = await rpcCall('eth_blockNumber');
    if (hexHeight) document.getElementById('blockHeight').innerText = parseInt(hexHeight, 16).toLocaleString();
    const netId = await rpcCall('net_version');
    if (netId) document.getElementById('networkId').innerText = netId;
    if (userAddress) updateBalance();
  } catch (e) { console.error(e); }
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
      <div style="display: grid; grid-template-columns: 120px 1fr; gap: 5px; font-family: 'JetBrains Mono', monospace;">
        <span style="color:var(--monad-dim)">TX Hash:</span>
        <span style="color:#fff; word-break: break-all;">${txHash}</span>
        <span style="color:var(--monad-dim)">Status:</span>
        <span style="color:var(--monad-purple)">⏳ Sequencing...</span>
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
      <div style="display: grid; grid-template-columns: 120px 1fr; gap: 5px; font-family: 'JetBrains Mono', monospace;">
        <span style="color:var(--monad-dim)">TX Hash:</span>
        <span style="color:#fff; word-break: break-all;">${txHash}</span>
      </div>
      <div style="margin-top: 15px; padding-top: 10px; border-top: 1px dashed var(--monad-border);">
        <div style="color:var(--monad-berry); font-weight:bold; margin-bottom: 5px;">⚡ TRANSACTION FINALIZED</div>
        <div style="display: grid; grid-template-columns: 120px 1fr; gap: 5px; font-family: 'JetBrains Mono', monospace;">
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

updateStats();
setInterval(updateStats, 3000);
