# Juicebox

Juicebox is a great way for open-source projects to raise money. As it is a smart contract running on Ethereum, it makes a natural fit for Planet to integrate it.

## Mainnet and Testnet

Juicebox has deployed both on mainnet and testnet:

- https://juicebox.money/
- https://goerli.juicebox.money/

So we can ask user to provide a mainnet project ID or a testnet project ID.

- juiceboxProjectID
- juiceboxProjectIDGoerli

That should be sufficient to get the project info from their subgraph.

https://api.thegraph.com/subgraphs/id/QmcKc84SeJy1BJVH74YGJpfnjgbZtdG6MuifH9BfSf9fKP/graphql?query=query+project%28%24id%3A+ID%21%29+%7B%0A++project%28id%3A+%24id%29+%7B%0A++++++metadataUri%0A++++++owner%0A++++++handle%0A++++++totalPaid%0A++++++totalRedeemed%0A++++++trendingPaymentsCount%0A++++++trendingVolume%0A++++++currentBalance%0A++++++createdAt%0A++%7D%0A%7D

The query:

```graphql
query project($id: ID!) {
  project(id: $id) {
      metadataUri
      owner
      handle
      totalPaid
      totalRedeemed
      trendingPaymentsCount
      trendingVolume
      currentBalance
      createdAt
  }
}
```

The variables:

```json
{"id": "2-1"}
```

The "2" is the project version. The "1" is the project ID. Project ID is only integer.

The output of the query:

```json
{
  "data": {
    "project": {
      "metadataUri": "QmQHGuXv7nDh1rxj48HnzFtwvVxwF1KU9AfB6HbfG8fmJF",
      "owner": "0xaf28bcb48c40dbc86f52d459a6562f658fc94b1e",
      "handle": "juicebox",
      "totalPaid": "43700865470365565682",
      "totalRedeemed": "0",
      "trendingPaymentsCount": 8,
      "trendingVolume": "333303193178816602",
      "currentBalance": "1214758196341795204043",
      "createdAt": 1651939234
    }
  }
}
```

## Project Metadata

The metadata is stored on IPFS. The metadata is a JSON file. The metadata contains the project name, description, logo, etc.

https://ipfs.io/ipfs/QmQHGuXv7nDh1rxj48HnzFtwvVxwF1KU9AfB6HbfG8fmJF

As an example, this is the metadata of the JuiceboxDAO project:

```json
{
  "name":"JuiceboxDAO",
  "description":"Supports projects built using the Juicebox protocol, and the development of the protocol itself. All projects withdrawing funds from their treasury pay a 2.5% membership fee and receive JBX at the current issuance rate. JBX members govern the NFT that represents ownership over this treasury.",
  "logoUri":"https://jbx.mypinata.cloud/ipfs/QmWXCt1zYAJBkNb7cLXTNRNisuWu9mRAmXTaW9CLFYkWVS",
  "infoUri":"https://snapshot.org/#/jbdao.eth",
  "twitter":"juiceboxETH",
  "discord":"https://discord.gg/W9mTVG4QhD",
  "payButton":"Add juice",
  "tokens":[],
  "version":4
}
```

## Features

Features we can build for the integration:

- [ ] Show a Juicebox button on the toolbar. Click on it will display basic project information. It can be opened with Chrome for further interaction.
- [ ] Link the Juicebox project from the site's homepage
- [ ] Utilize WalletConnect to pay the project