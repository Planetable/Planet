According to this repo:

https://github.com/ipfs/fs-repo-migrations

| ipfs repo version | Kubo versions    |
| ----------------: | :--------------- |
|                 1 | 0.0.0 - 0.2.3.   |
|                 2 | 0.3.0 - 0.3.11   |
|                 3 | 0.4.0 - 0.4.2    |
|                 4 | 0.4.3 - 0.4.5    |
|                 5 | 0.4.6 - 0.4.10   |
|                 6 | 0.4.11 - 0.4.15  |
|                 7 | 0.4.16 - 0.4.23  |
|                 8 | 0.5.0 - 0.6.0    |
|                 9 | 0.5.0 - 0.6.0    |
|                10 | 0.6.0 - 0.7.0    |
|                11 | 0.8.0 - 0.11.0   |
|                12 | 0.12.0 - 0.17.0  |
|                13 | 0.18.0 - 0.20.0  |
|                14 | 0.21.0 - 0.22.0  |
|                15 | 0.23.0 - current |

If we are going to upgrade from 0.15 to [0.28](https://github.com/ipfs/kubo/blob/master/docs/changelogs/v0.28.md), three migrations will be needed:

- 12-to-13
- 13-to-14
- 14-to-15