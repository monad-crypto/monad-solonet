if [[ "${NODE_ID:-1}" != "1" ]]; then
  # "NODE_ID is not 1, skipping."
  return
fi

VERSION="$(monad-node --version 2>/dev/null | cut -d ' ' -f2 | jq -r .tag)"
NODES="$(yq -r '"  \(.node_name): \(.secp256k1.public_key)"' /shared/peers/* | sort)"

log "Initial delegation"
echo "Available Accounts"
echo "=================="
echo
echo "(0) 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (100000000000000000000.000000000000000000 MON)"
echo "(1) 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (100000000000000000000.000000000000000000 MON)"
echo "(2) 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC (100000000000000000000.000000000000000000 MON)"
echo "(3) 0x90F79bf6EB2c4f870365E785982E1f101E93b906 (100000000000000000000.000000000000000000 MON)"
echo "(4) 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65 (100000000000000000000.000000000000000000 MON)"
echo "(5) 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc (100000000000000000000.000000000000000000 MON)"
echo "(6) 0x976EA74026E726554dB657fA54763abd0C3a0aa9 (100000000000000000000.000000000000000000 MON)"
echo "(7) 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955 (100000000000000000000.000000000000000000 MON)"
echo "(8) 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f (100000000000000000000.000000000000000000 MON)"
echo "(9) 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720 (100000000000000000000.000000000000000000 MON)"
echo
echo "Private Keys"
echo "============"
echo
echo "(0) 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
echo "(1) 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
echo "(2) 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
echo "(3) 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
echo "(4) 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a"
echo "(5) 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba"
echo "(6) 0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e"
echo "(7) 0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356"
echo "(8) 0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97"
echo "(9) 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6"
echo
echo "Wallet"
echo "======"
echo "Mnemonic:          test test test test test test test test test test test junk"
echo "Derivation path:   m/44'/60'/0'/0/"
echo
echo

log "NETWORK STARTED! 🚀"
echo
printf "\033[38;2;131;110;249m ███████╗ ██████╗ ██╗      ██████╗ ███╗   ██╗███████╗████████╗\033[0m\n"
printf "\033[38;2;131;110;249m ██╔════╝██╔═══██╗██║     ██╔═══██╗████╗  ██║██╔════╝╚══██╔══╝\033[0m\n"
printf "\033[38;2;131;110;249m ███████╗██║   ██║██║     ██║   ██║██╔██╗ ██║█████╗     ██║   \033[0m\n"
printf "\033[38;2;131;110;249m ╚════██║██║   ██║██║     ██║   ██║██║╚██╗██║██╔══╝     ██║   \033[0m\n"
printf "\033[38;2;131;110;249m ███████║╚██████╔╝███████╗╚██████╔╝██║ ╚████║███████╗   ██║   \033[0m\n"
printf "\033[38;2;131;110;249m ╚══════╝ ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝   ╚═╝   %s\033[0m\n" "${SOLONET_VERSION:-dev}"
echo
echo "Network name:        solonet"
echo "Network type:        devnet"
echo "Chain ID:            20143"
echo "Monad revision:      MONAD_NEXT"
echo "Node name:           $NODE_NAME"
echo "Client version:      $VERSION"
echo "BFT Logs:            /var/log/monad-bft.log"
echo "Execution Logs:      /var/log/monad-execution.log"
echo "RPC Logs:            /var/log/monad-rpc.log"
echo "Ledger tail Logs:    /var/log/monad-ledger-tail.log"
echo "Total nodes:         $TOTAL_NODE_NUMBER"
echo "Nodes:"
echo "$NODES"
echo
echo "RPC endpoint:        http://localhost:8080"
echo "WebSocket endpoint:  ws://localhost:8081"
echo "Dashboard            http://localhost:8082"
echo "CORS RPC endpoint:   http://localhost:8082/rpc/"
echo

show_rpc_methods || true
