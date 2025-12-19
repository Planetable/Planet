# How to Build

After you clone the project, create a `local.xcconfig` file inside the Planet subdirectory, not at the root of the project.

```
cd Planet
code local.xcconfig
```

The `local.xcconfig` file should be in the same directory as `Planet.xcconfig`, not at the root level of the project.

Fill it with the following, and replace `DEVELOPMENT_TEAM` with your own team ID.

```
CODE_SIGN_STYLE = Automatic
DEVELOPMENT_TEAM = 66KP7KX9MX
PLANET_APP_ICON_NAME = AppIcon-Debug

WALLETCONNECTV2_PROJECT_ID = ""
ETHERSCAN_API_TOKEN = ""

ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = NO
ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_FRAMEWORKS = ""
ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = NO
```

If you want to touch the Wallet-related parts, please supply your own WalletConnect project ID and Etherscan API token.