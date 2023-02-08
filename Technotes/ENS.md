# ENS

## Get all domains

Here is a minimal query to get all domains owned by a specific address.

```graphql
query getNamesFromSubgraph($address: String) {
  domains(first: 1000, where: {owner: $address}) {
    name
  }
}
```

With variables:

```
{
    "address": "0x18deee9699526f8c8a87004b2e4e55029fb26b9a"
}
```

The ENS GraphQL endpoint:

https://api.thegraph.com/subgraphs/name/ensdomains/ens

The complete request can be further manipulated in RapidAPI.

https://paw.pt/hBlKIeX6

## ENS GraphQL Playground

To explore all the data that can be queried:

https://api.thegraph.com/subgraphs/name/ensdomains/ens/graphql