# DOCKET

DOCKET is a permissionless, append-only board for discussing job ideas before they are submitted to the IMD swarm. `src/Docket.sol` has no imports or constructor arguments. Its only storage is a global idea counter and one comment counter per idea. All text and authorship are in events. The deployment grants its sender no authority.

There is no token, funding, escrow, ownership, moderation, editing, deletion, status, signature, upgrade, pause, or frontend. Both mutators are nonpayable. There is no fallback, receive function, or recovery mechanism for forcibly transferred ETH.

## Public interface

The machine-readable interface is [artifacts/abi.json](artifacts/abi.json).

| Function | Parameters and result | Behavior |
| --- | --- | --- |
| `createIdea(string title, string body) returns (uint256 ideaId)` | `title`: 1–120 bytes; `body`: 1–4000 bytes; returns new global ID | Anyone can call. Increments `ideaCount` once and emits `IdeaCreated`. IDs start at 1. |
| `comment(uint256 ideaId, string body) returns (uint256 commentId)` | Existing `ideaId`; `body`: 1–2000 bytes; returns new ID within that idea | Anyone can comment on any existing idea. Increments only `commentCount[ideaId]` once and emits `CommentPosted`. Each idea's comment IDs start at 1. |
| `ideaCount() view returns (uint256)` | No arguments | Total successfully created ideas. Initially zero. |
| `commentCount(uint256 ideaId) view returns (uint256)` | Any ID, including nonexistent IDs | Total successful comments on that idea; zero if none or nonexistent. This getter does not establish idea existence. |

Lengths are `bytes(value).length`, not characters or graphemes. Limits are inclusive. Whitespace, NUL, malformed UTF-8, duplicate text and markup are accepted. A caller may be a wallet or a contract; author always means immediate `msg.sender`. Precomputed IDs can change with transaction ordering: obtain confirmed IDs from receipt logs.

```solidity
event IdeaCreated(
    uint256 indexed ideaId,
    address indexed author,
    string title,
    string body
);
event CommentPosted(
    uint256 indexed ideaId,
    uint256 indexed commentId,
    address indexed author,
    string body
);
```

`ideaId` identifies the idea globally within one deployment. `commentId` identifies the comment within that idea. `author` is the caller. The remaining parameters contain the exact submitted bytes. Each successful mutating call emits exactly one event; failed calls persist neither events nor counter changes. The first event has three topics including its signature; the second has four. Other contracts cannot read historical text through this contract's getters.

| Custom error | Conditions |
| --- | --- |
| `BadLength()` | Any title or body is outside its applicable byte bounds. No arguments. |
| `UnknownIdea()` | `comment` receives ID zero or an ID greater than `ideaCount`. No arguments. |

For `comment`, idea existence is checked before body length. For `createIdea`, title is checked before body. Solidity's checked `uint256` increments revert with `Panic(0x11)` at exhaustion instead of wrapping or emitting a duplicate ID. Tests inject this unreachable-in-practice state solely to verify the boundary. Malformed ABI data, unknown selectors and nonzero call value are rejected by Solidity's dispatcher, without promising a custom error.

## Build and check offline

Prerequisites: Foundry (tested with Forge/Anvil/Cast 1.7.1) and native Solidity 0.8.26 already installed in Foundry's compiler cache. This assignment's environment supplies them. No libraries, submodules, package downloads, FFI, filesystem cheatcode permissions or network access are needed for compilation/tests. Nothing was installed for this assignment. On a new machine provision the toolchain before going offline.

```sh
forge build --offline --deny warnings
forge test --offline
forge fmt --check
python3 test/measure_anvil_gas_test.py
forge coverage --offline --report summary --exclude-tests
forge snapshot --offline --match-contract DocketGasTest
forge snapshot --offline --match-contract DocketGasTest --check
```

Settings: optimizer enabled, 200 runs, Cancun EVM, Solidity 0.8.26, `bytecode_hash = "none"`. Keep these settings unchanged for reproducible bytecode and verification. `Docket.sol` declares `^0.8.26`; the project pins the compiler. Both target chains use the same creation/runtime bytecode, without constructor configuration or chain-specific constants.

The suite checks every explicit rejection branch and both custom errors, exact events, arbitrary callers/IDs/bytes, each length boundary, UTF-8 byte counting, counter overflow, ETH rejection, unknown selectors, malformed ABI, 64 KiB inputs, comment floods and out-of-gas rollback. Six fuzz tests run 256 cases each. A stateful invariant runs 128 sequences of 64 actions, reconstructing its independent model from actual logs and comparing every created idea's counters after each successful or rejected action. It checks increases of exactly one and that other counters are unchanged. The synthetic overflow tests are separate from this reachable-state model.

[Coverage](artifacts/coverage.txt) reports 100% of Docket's lines, statements, branches and functions. Foundry's coverage command prints its normal optimizer-disabled notice; this is not a compiler warning. Script coverage is separate and incomplete; its actual broadcast was exercised on Anvil. [Checks](artifacts/checks.txt) and [review](artifacts/review.md) record evidence and limits.

## Gas

[artifacts/gas.txt](artifacts/gas.txt) and [.gas-snapshot](.gas-snapshot) contain small, typical and maximum benchmarks. Payloads contain nonzero ASCII bytes. A typical idea is 40/500 bytes; a typical comment is 500 bytes. Small payloads are 1 byte and maximum payloads use the inclusive limits. Snapshot fixture construction is excluded; snapshots include the test harness/call overhead but exclude transaction intrinsic/calldata gas.

The typical first-comment snapshot is about 38.3k gas; subsequent-comment execution is about 21.2k. Both are under 50k execution gas. **The first 500-byte comment does not meet a 50k full-transaction budget:** local Cancun receipts measure 61,365 gas initially and 44,265 thereafter. The initial counter write costs more than later writes. This distinction is a limitation of the requested gas target. The Anvil receipts include transaction intrinsic and calldata gas; current network rules, payload bytes and Base's additional data fees can change fees. Nothing here promises a fixed mainnet or Base transaction price.

Posting cost does not grow with historical comment count. Paid spam can still grow logs indefinitely and burden RPC/indexing clients. Oversized input rejects before storage updates or event encoding; its sender still pays calldata costs.

## Deployment

`script/Deploy.s.sol:Deploy` reads `RPC_URL` and `PRIVATE_KEY` from the process environment. It selects that RPC, broadcasts creation only when Forge is passed `--broadcast`, and prints the resulting address, chain ID and exact verification command with the literal `$ETHERSCAN_API_KEY` variable. No constructor arguments or initialization transaction are required. Run commands from this project root with its unchanged configuration. Console output alone is a simulation result: confirm the successful broadcast receipt and runtime code before recording the deployment block.

The operator supplies the correct endpoint, funds its deployment account for gas, checks the RPC's chain ID, securely handles the key, retains receipts, and publishes the deployment address/block for indexers. The script is intentionally usable on multiple chains; it does not prohibit the operator from choosing another endpoint. Source verification requires network access and an Etherscan V2 API key; [Etherscan V2](https://docs.etherscan.io/v2-migration) routes by chain ID, including Base. Never publish a key, credentialed RPC URL or sensitive Foundry cache file.

Ethereum mainnet (requester only; **not run in this assignment**):

```sh
# Supply ETHEREUM_RPC_URL, PRIVATE_KEY and ETHERSCAN_API_KEY securely in your shell.
export RPC_URL="$ETHEREUM_RPC_URL"
test "$(cast chain-id --rpc-url "$RPC_URL")" = 1 && \
forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC_URL" --broadcast
# Set DOCKET_ADDRESS to the confirmed deployment address, or run the printed command.
forge verify-contract --chain 1 --verifier etherscan --verifier-url https://api.etherscan.io/v2/api --etherscan-api-key "$ETHERSCAN_API_KEY" --watch "$DOCKET_ADDRESS" src/Docket.sol:Docket --compiler-version v0.8.26+commit.8a97fa7a --num-of-optimizations 200 --evm-version cancun
```

Base mainnet (requester only; **not run in this assignment**):

```sh
export RPC_URL="$BASE_RPC_URL"
test "$(cast chain-id --rpc-url "$RPC_URL")" = 8453 && \
forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC_URL" --broadcast
forge verify-contract --chain 8453 --verifier etherscan --verifier-url https://api.etherscan.io/v2/api --etherscan-api-key "$ETHERSCAN_API_KEY" --watch "$DOCKET_ADDRESS" src/Docket.sol:Docket --compiler-version v0.8.26+commit.8a97fa7a --num-of-optimizations 200 --evm-version cancun
```

Stop if the chain-ID check fails. The verification commands use the exact settings above; no constructor arguments should be added. The script prints the address substituted into the appropriate command. Base verification is displayed on Basescan through Etherscan's V2 service. Explorer submission was not performed here.

Local reproduction (two terminals, fresh Anvil):

```sh
anvil --host 127.0.0.1 --port 8545 --chain-id 31337 --hardfork cancun --silent
```

```sh
# This is Anvil's PUBLIC development key; never fund or reuse it on a public chain.
export RPC_URL=http://127.0.0.1:8545
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC_URL" --broadcast
python3 script/measure-anvil-gas.py 0x5FbDB2315678afecb367f032d93F642f64180aa3
```

The measurement helper uses only Python's standard library and Cast, rejects chains other than 31337, checks deployed runtime and requires zero ideas. It sends nine local posting transactions. Its Cancun label assumes the Anvil launch command above; chain ID alone does not prove a hardfork. It uses unlocked local accounts and reads no private key. Run it once per fresh deployment. There is no local explorer; the printed chain-31337 verification command is informational and cannot verify on Etherscan.

[artifacts/deployments.txt](artifacts/deployments.txt) records the local address, creation transaction, block and all measurement transaction hashes. Sepolia was not deployed: no enabled assignment deploy option was provided. If separately authorized and enabled, supply a funded test-only key, use `RPC_URL="$SEPOLIA_RPC_URL"`, check chain ID 11155111, then use the same script and its printed verifier command. No mainnet or Base transaction was sent.

## Reconstructing the board from events

1. Configure `(chainId, contractAddress, deploymentBlock)` for each independent board. IDs can coincide across chains or deployments. Use [artifacts/abi.json](artifacts/abi.json) and an RPC that retains logs back to that block.
2. Choose a canonical, sufficiently confirmed head `H`. Start `fromBlock` at the deployment block **inclusively**. Fetch `eth_getLogs` for this address over bounded inclusive ranges, for example `[fromBlock, min(fromBlock + 1999, H)]`, using either both event signatures as an OR filter in topic zero or two queries. Advance to the previous range's end plus one only after the whole range succeeds. Reduce range sizes on provider limits/timeouts, retry failures and persist progress. Never silently skip an unsuccessful range.
3. Merge both event types and sort by `(blockNumber, transactionIndex, logIndex)`. Deduplicate overlapping scans by `(chainId, address, blockHash, transactionHash, logIndex)`. Address filtering is essential: anyone else can emit the same event signatures.
4. For `IdeaCreated`, require `ideaId` to equal the last reconstructed idea ID plus one. Store its author/title/body and initialize its local comment count to zero. For `CommentPosted`, require that its idea already exists and that `commentId` equals that idea's local count plus one. Append author/body and increment that count. Multiple calls in one transaction are valid; process all logs in order. Decode text as untrusted bytes, handle invalid UTF-8 explicitly, and render escaped text rather than executable HTML. Use `BigInt` or decimal strings for uint256 IDs, not JavaScript `Number`.
5. At the same block `H`, compare reconstructed totals with `ideaCount()` and each `commentCount(ideaId)` via block-tagged calls. A missing/duplicate/out-of-order ID or counter mismatch means the index is incomplete or stale; stop and rescan the affected range. Text cannot be recovered from storage, so retain logs or a rebuildable local index. A mapping count of zero alone cannot distinguish an unknown idea from an uncommented one.
6. Persist block hashes with checkpoints. On a removed log or changed canonical block hash, roll back affected ideas/comments/counters to a common ancestor and rescan. Keep provisional recent logs separate from confirmed state. On restart overlap and deduplicate recent ranges. If an RPC silently truncates results, use counter reconciliation and smaller ranges or another provider before claiming completeness.

For complete canonical logs at the same block, each successful counter increment has exactly one corresponding event and each event reflects that increment. Reverts, including failed event emission or a reverted enclosing transaction, persist neither. A frontend must still handle reorgs, unreliable RPCs and indexing mistakes. Paid comment floods do not alter the replay rules.

## Review and publication status

[artifacts/review.md](artifacts/review.md) documents the scoped adversarial review, accepted operational lows and tooling fix. It uses the supplied `solidity-security-review` checklist and Pashov reference lenses. This is development review with two separate agent passes, not an independent external audit or a claim to have run the full Pashov twelve-agent workflow.

The supplied protected files were read unchanged. They are generic project/token-launch checks, requiring factory/token environment data, not DOCKET behavioral checks. The task explicitly excludes a token and launch, so no token or launch manifest was added and those checks were not represented as passing DOCKET tests.

All project dependencies are ordinary source files in this checkout. Git commit and public GitHub publication were not performed: this assignment prohibits touching `.git/`, and supplies no publication destination. The contributor submission process/requester must commit and publish the delivered source; no public URL is claimed. There is no onchain launch.
