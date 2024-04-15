# Kubo

## 20240415

go-ipfs, also known as [Kubo](https://github.com/ipfs/kubo), is a core component of Planet. We should always ship the latest version of Kubo with Planet.

There was an issue with IPNS starting from Kubo version 0.16, so we stayed at version 0.15.

https://discuss.ipfs.tech/t/ipfs-name-resolve-does-not-always-return-the-freshest-cid-for-ipns-on-kubo-0-20-0/16624

Now that Kubo has reached version 0.28, I think we should give this version another try.