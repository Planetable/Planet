# Build with Xcode 15

If you encounter the following issue while building with Xcode 15, as depicted in the screenshot below:

![](images/xcode15_build_issue.png)

```
Call can throw, but it is not marked with 'try' and the error is not handled
```

You might face this issue, or similar ones, mainly with `GeneratedAssetSymbols.swift`. To mitigate the problem, add the three lines of config below to your `local.xcconfig` file:

```
ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = NO;
ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_FRAMEWORKS = "";
ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = NO;
```