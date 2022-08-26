# Planet

Planet is a free and open-source software for publishing and following web content, and it does not require a centralized server or service. It uses IPFS to achieve peer-to-peer content distribution. Furthermore, you can link your content to an Ethereum Name (.eth) so that others can follow you via Planet by the .eth name. Since both IPFS and ENS are decentralized, you can build your websites or follow others, all in a decentralized manner.

<img width="1371" src="Screenshots/planetable.eth.png" alt="planetable.eth">

## Features

- Build a blog and publish it to IPFS
- Built-in local IPFS node
- Generate an IPNS that is ready to be set as [EIP-1577](https://eips.ethereum.org/EIPS/eip-1577) ENS contenthash
- Pinning content when following, make content usable offline
- Follow the updates of websites running on ENS, NFT avatar as site icon is supported
- Markdown editor with live preview
- Attach video, audio, or any format of files
- Star or share posts
- Global audio player
- Template browser for managing and building templates
- Integration with [WorldWideWeb](https://apps.apple.com/us/app/worldwideweb-desktop/id1621370168?mt=12) for previewing sites built with Planet
- Integration with Plausible.io for traffic analytics, example: [plausible.io/planetable.eth.limo](https://plausible.io/planetable.eth.limo)
- RSS reader, all three formats, RSS, Atom, and JSON Feed, are supported

## Sites Using Planet

If you would like to add your site to this list, please share it in a [discussion](https://github.com/Planetable/Planet/discussions). We can't wait to see your creations!

- [planetable.eth](https://planetable.eth.limo)
- [olivida.eth](https://olivida.eth.limo)
- [yihanphotos.eth](https://yihanphotos.eth.limo)
- [gamedb.eth](https://gamedb.eth.limo)
- [zh.gamedb.eth](https://zh.gamedb.eth.limo)

Planet can follow any ENS with a [EIP-1577](https://eips.ethereum.org/EIPS/eip-1577) contenthash. If your site has RSS, Planet can read it too. For example, vitalik.eth:

<img width="1528" src="Screenshots/vitalik.eth.png" alt="vitalik.eth">

## Backup

Before you try this app out, please be advised that it is still at an early stage, and many changes happen. So we recommend you backup your data, especially your IPNS key, from time to time. When you use `Export Planet`, it will include your IPNS key.

## Build the macOS App

To use your own build config for setting `DEVELOPMENT_TEAM`, please create a `local.xcconfig` file alongside the `Planet.xcconfig` file.

The following configuration variables can be overridden:

- DEVELOPMENT_TEAM
- CODE_SIGN_STYLE
- ORGANIZATION_IDENTIFIER_PREFIX

## License

Licensed under the [MIT license](https://github.com/Planetable/Planet/blob/main/LICENSE).