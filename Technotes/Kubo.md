# Kubo

## 20240415

go-ipfs, also known as [Kubo](https://github.com/ipfs/kubo), is a core component of Planet. We should always ship the latest version of Kubo with Planet.

There was an issue with IPNS starting from Kubo version 0.16, so we stayed at version 0.15.

https://discuss.ipfs.tech/t/ipfs-name-resolve-does-not-always-return-the-freshest-cid-for-ipns-on-kubo-0-20-0/16624

Now that Kubo has reached version 0.28, I think we should give this version another try.

## General Risks When Upgrading Kubo

There is a repository migration step involved when upgrading Kubo. To test the upgrade, perform it in a development environment with disposable data, or ensure the data is fully backed up before testing.

## How to Back Up IPFS Data in Planet

IPFS repo location:

```
~/Library/Containers/xyz.planetable.Planet/Data/Library/Application Support/ipfs
```

## git-lfs

The two binaries of Kubo are tracked with [git-lfs](https://git-lfs.com/). Ensure they are added with git-lfs before pushing a commit.