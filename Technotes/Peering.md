# Peering

Planet sets no `Peering.Peers` since 2026-11-03. On each start, `setupIPFS` in
`Planet/IPFS/IPFSDaemon.swift` writes an empty list. Builds from 2022-06 to
2025-10 wrote a list of four peers into the Kubo repo. Without the empty write,
Kubo would keep dialing those addresses on every launch.

## Why it is off

The old list named four nodes. On 2026-11-03, two of them no longer answered, one
refused peer dials, and one answers but Pinnable no longer uses it:

| Peer | Address | State on 2026-11-03 |
| --- | --- | --- |
| Pinnable `12D3KooWBJY6ZVV8Tk8UDDFMEqWoxn89Xc8wnpm8uBFSR3ijDkui` | `/ip4/167.71.172.216/tcp/4001` and its IPv6 and QUIC forms | The server is retired. Port 4001 does not answer. |
| bit.site `12D3KooWJ6MTkNM8Bu8DzNiRm1GY3Wqh8U8Pp1zRWap6xY3MvsNw` | `/dnsaddr/node-1.ipfs.bit.site` | The name has no DNS record. |
| Filebase `12D3KooWGtYkBAaqJMJEmywMxaCiNP7LCEFUAFiLEBASe232c2VH` | `/dns4/bitswap.filebase.io/tcp/443/wss` | Answers. The name is a CNAME to an S3 endpoint now. Pinnable stopped using Filebase on 2026-11-03. |
| 4everland `12D3KooWQ85aSCFwFkByr5e3pUCQeuheVhobVxGSSs1DrRQHGv1t` | `/dnsaddr/node-1.ipfs.4everland.net` | Port 4001 answers a TCP probe, but peer dials from two nodes failed. |

One live peer that Pinnable no longer uses is not worth a config write on every
launch. So the list stays empty until Pinnable has a node with a public address
again. Pinnable's current
node has only relay addresses, so it cannot be a peer yet.

## History

- 2022-06-01, `6edf06a0`: peering added, with the Pinnable node.
- 2023-10-19, `ac16b3ea`: eth.limo nodes added.
- 2024-07-09, `bbd1c1c8`: eth.limo and Cloudflare removed, UDP addresses added.
- 2026-04-10, `28df4c11`: the eth.sucks node removed.
- 2026-11-03: all peers removed. The old entries are in this file's history.

## To bring it back

1. Make sure that the node answers on its swarm port from outside: `nc -z <ip> 4001`.
2. Get its ID and addresses from `ipfs id` on that node.
3. Add a `static let peers = JSON([...])` list of `{"ID": …, "Addrs": […]}` to
   `IPFSDaemon.swift`, and pass its JSON to `IPFSCommand.setPeers` in `setupIPFS`
   in place of `"[]"`.

`tools/monitor-ipfs-peers/peers.txt` still lists the 2023 peers. It is a
monitor script's input, not app configuration.
