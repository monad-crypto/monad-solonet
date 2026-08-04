# txgen profiles

Ready-to-use txgen configuration profiles for different testing scenarios.

## Profiles

| File | TPS | Senders | Recipients | Mode | Native / ERC20 |
|---|---|---|---|---|---|
| `txgen-light.toml` | 250 | 30 | 1 | native | 100% / 0% |
| `txgen-standard.toml` | 1,000 | 120 | 1,000,000 | native | 100% / 0% |
| `txgen-max-throughput.toml` | 12,000 | 1,440 | 1 | native | 100% / 0% |
| `txgen-evm-stress.toml` | 12,000 | 1,440 | 1,000,000 | non_deterministic_storage | 0% / 100%* |
| `txgen-mempool-stress.toml` | 8,000 | 960 | 1,000,000 | many_to_many | 100% / 0%* |

\* `non_deterministic_storage` sends contract calls (not native transfers). `many_to_many` does not set `tx_type` explicitly — assumed native but verify if unsure.

### `txgen-light.toml` — 250 TPS, smoke test / dev
- `senders = 30`, `recipients = 1`, native transfers
- Low resource usage, quick startup — good for iterating on config or debugging

### `txgen-standard.toml` — 1,000 TPS, everyday testing
- `senders = 120`, `recipients = 1,000,000`, native transfers
- Realistic state distribution without hammering the node

### `txgen-max-throughput.toml` — 12,000 TPS, raw benchmark
- `senders = 1,440`, `recipients = 1`, native transfers
- Single recipient eliminates state-write overhead for a pure throughput ceiling measurement

### `txgen-evm-stress.toml` — 12,000 TPS, EVM execution stress
- `senders = 1,440`, `recipients = 1,000,000`, `non_deterministic_storage`
- Hammers EVM storage access patterns rather than transfer throughput

### `txgen-mempool-stress.toml` — 8,000 TPS, mempool pressure
- `senders = 960`, `recipients = 1,000,000`, `many_to_many`
- Large sender + recipient pools simulate realistic traffic and test mempool under high fan-out

## Usage

Select a profile via env var (defaults to `txgen-light.toml` if unset):

```bash
MONAD_TXGEN_PROFILE="txgen-standard.toml"
```

## Sizing reference

All profiles follow the same sizing rules (per-sender rate ~8–10 TPS, ~1.8 s nonce window):

| Target TPS | Senders | Groups (`senders / 10`) | txs/block (0.4 s) |
|---|---|---|---|
| 250 | 30 | 3 | ~100 |
| 1,000 | 120 | 12 | ~400 |
| 5,000 | 600 | 60 | ~2,000 |
| 8,000 | 960 | 96 | ~3,200 |
| 12,000 | 1,440 | 144 | ~4,800 |
