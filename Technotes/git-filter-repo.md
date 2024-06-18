# Use git-filter-repo to strip large binaries

Result of `git filter-repo --analyze` from 73a7e66acd0b7912ba8ff8317926107aaef1705f:

```
=== All paths by reverse accumulated size ===
Format: unpacked size, packed size, date deleted, path name
   239504981  108685405 2022-10-11 Planet/IPFS/go-ipfs-executables/ipfs-amd64
   238619056  104103282 2022-10-11 Planet/IPFS/go-ipfs-executables/ipfs-arm64
   110305152   39602143 2022-10-11 Planet/Assets.xcassets/IPFS-GO.dataset/ipfs
   110437216   38533437 2022-10-11 Planet/Assets.xcassets/IPFS-GO-ARM.dataset/ipfs
    67460213   33836608 <present>  Planet/IPFS/ipfs-executables/ipfs-amd64-0.28.bin
    67460213   33836608 <present>  Planet/IPFS/go-ipfs-executables/ipfs-amd64-0.28.bin
    65355701   31854693 <present>  Planet/IPFS/ipfs-executables/ipfs-arm64-0.28.bin
    65355701   31854693 <present>  Planet/IPFS/go-ipfs-executables/ipfs-arm64-0.28.bin
    62964533   28783701 2022-10-11 Planet/IPFS/go-ipfs-executables/ipfs-amd64.bin
    62437893   27342472 2022-10-11 Planet/IPFS/go-ipfs-executables/ipfs-arm64.bin
    11005024   11003931 <present>  Planet/Labs/Icon Gallery/Icons/tier2.zip
     9225100    9225233 <present>  Planet/Labs/Icon Gallery/Icons/tier3.zip
    11586800    6243872 2022-07-20 Planet/IPFS/go-ipfs-executables/fs-repo-migrations-amd64
    11190496    5992917 2022-07-20 Planet/IPFS/go-ipfs-executables/fs-repo-migrations-arm64
     3648387    3599562 <present>  Screenshots/planetable.eth.png
     3028464    1863744 <present>  Planet/IPFS/fs-repo-migrations/fs-repo-14-to-15_amd64
     3000352    1765206 <present>  Planet/IPFS/fs-repo-migrations/fs-repo-14-to-15_arm64
     2720336    1666619 <present>  Planet/IPFS/fs-repo-migrations/fs-repo-12-to-13_amd64
     2698528    1653893 <present>  Planet/IPFS/fs-repo-migrations/fs-repo-13-to-14_amd64
     2670480    1563164 <present>  Planet/IPFS/fs-repo-migrations/fs-repo-12-to-13_arm64
     2652384    1552732 <present>  Planet/IPFS/fs-repo-migrations/fs-repo-13-to-14_arm64
     1438642    1352107 <present>  Screenshots/vitalik.eth.png
     1208368    1163191 <present>  Technotes/Images/xcode15_build_issue.png
    31522127    1135696 <present>  Planet.xcodeproj/project.pbxproj
     2012535     853282 2022-02-26 Planet.xcodeproj/project.xcworkspace/xcuserdata/kai.xcuserdatad/UserInterfaceState.xcuserstate
      774329     770987 2022-05-02 Planet/Assets.xcassets/AppIcon.appiconset/108_xxxlarge-1024.png
      688318     674919 <present>  Planet/Assets.xcassets/AppDataIcon-Image.iconset/icon_512x512@2x.png
      626000     625920 <present>  Planet/Labs/Icon Gallery/Icons/vol1-5.zip
      567822     567801 <present>  Planet/Labs/Icon Gallery/Icons/vol1-4.zip
      564151     564139 <present>  Planet/Labs/Icon Gallery/Icons/vol1-8.zip
      562709     562704 <present>  Planet/Labs/Icon Gallery/Icons/vol1-2.zip
      547571     547547 <present>  Planet/Labs/Icon Gallery/Icons/vol1-1.zip
      545350     545338 <present>  Planet/Labs/Icon Gallery/Icons/vol1-6.zip
      539853     539847 <present>  Planet/Labs/Icon Gallery/Icons/vol1-7.zip
      532012     531991 <present>  Planet/Labs/Icon Gallery/Icons/vol1-3.zip
      478368     477427 <present>  Planet/Labs/Icon Gallery/Icons/tier3.png
    11270923     434497 <present>  Planet/Entities/MyPlanetModel.swift
      436496     429897 <present>  Planet/Assets.xcassets/AppIcon.appiconset/Planetable Lite 1024.png
      403456     396975 <present>  Planet/Assets.xcassets/AppIcon-Insider.appiconset/1024.png
      404852     394993 <present>  Planet/SharedAssets.xcassets/base-logo.imageset/base-logo.png
      363891     363834 <present>  Planet/Labs/Icon Gallery/Icons/tier1.zip
      301612     300767 2022-05-02 Planet/Assets.xcassets/AppIcon.appiconset/108_xxxlarge-512.png
      299639     298237 <present>  Planet/Labs/Icon Gallery/Icons/tier2.png
      311715     291668 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Image.iconset/icon_512x512@2x.png
      251725     241206 <present>  Planet/Assets.xcassets/AppIcon-Debug.appiconset/Planet Debug-1024.png
      234969     230791 <present>  Planet/Assets.xcassets/AppDataIcon-Image.iconset/icon_512x512.png
      234969     230791 <present>  Planet/Assets.xcassets/AppDataIcon-Image.iconset/icon_256x256@2x.png
      148580     147310 <present>  Planet/Assets.xcassets/AppIcon.appiconset/Planetable Lite 512.png
      148580     147310 2023-01-13 Planet/Assets.xcassets/AppIcon.appiconset/Planetable Lite 512-1.png
      142006     140602 <present>  Planet/Assets.xcassets/AppIcon-Insider.appiconset/512.png
      142006     140602 2023-01-13 Planet/Assets.xcassets/AppIcon-Insider.appiconset/512 1.png
      138871     134102 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Image.iconset/icon_512x512.png
      138871     134102 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Image.iconset/icon_256x256@2x.png
      129702     107498 <present>  Planet/SharedAssets.xcassets/arb-logo.imageset/arbitrum-logo.png
      160579     104191 <present>  Planet/SharedAssets.xcassets/eth-logo.imageset/ethereum-logo.png
      102155      99523 <present>  Planet/Assets.xcassets/AppIcon-Debug.appiconset/Planet Debug-512.png
     3818354      96741 <present>  Planet/Entities/FollowingPlanetModel.swift
       97499      96000 <present>  Planet/Labs/Icon Gallery/Icons/tier1.png
     1493843      93332 <present>  Planet/Entities/PlanetStore.swift
     1382796      90508 <present>  Planet/IPFS/IPFSDaemon.swift
      699832      81812 <present>  Planet/Entities/MyArticleModel+Save.swift
       81283      80152 <present>  Planet/Labs/Icon Gallery/Icons/vol1-2.png
       80075      79927 2022-05-02 Planet/Assets.xcassets/AppIcon.appiconset/108_xxxlarge-256.png
       79725      79465 <present>  Planet/Assets.xcassets/WalletAppIconRainbow.imageset/rainbow384.png
       80332      79200 <present>  Planet/Labs/Icon Gallery/Icons/vol1-8.png
       80285      79001 <present>  Planet/Assets.xcassets/AppDataIcon-Image.iconset/icon_256x256.png
       80285      79001 <present>  Planet/Assets.xcassets/AppDataIcon-Image.iconset/icon_128x128@2x.png
       79039      77991 <present>  Planet/Labs/Icon Gallery/Icons/vol1-1.png
       79035      77779 <present>  Planet/Labs/Icon Gallery/Icons/vol1-4.png
       78407      77306 <present>  Planet/Labs/Icon Gallery/Icons/vol1-7.png
       77728      76626 <present>  Planet/Labs/Icon Gallery/Icons/vol1-5.png
     1681327      75380 <present>  Planet/Entities/MyArticleModel.swift
       76040      74945 <present>  Planet/Labs/Icon Gallery/Icons/vol1-3.png
       75744      74636 <present>  Planet/Labs/Icon Gallery/Icons/vol1-6.png
     1144618      71141 <present>  Planet/Labs/Published Folders/PlanetPublishedServiceStore.swift
       70188      69122 <present>  Planet/Avatars.xcassets/NSTG-0018.imageset/NSTG-0018.png
       69081      68206 <present>  Planet/Avatars.xcassets/NSTG-0017.imageset/NSTG-0017.png
       68074      66943 <present>  Planet/Avatars.xcassets/NSTG-0016.imageset/NSTG-0016.png
       73391      64461 <present>  Planet/SharedAssets.xcassets/op-logo.imageset/optimism-logo.png
       62526      62252 <present>  Planet/Assets.xcassets/WalletAppIconMetaMask.imageset/metamask384.png
     1075336      61405 <present>  Planet/Entities/DraftModel.swift
       61405      60417 <present>  Planet/Avatars.xcassets/NSTG-0051.imageset/NSTG-0051.png
     1008015      59876 <present>  Planet/Views/My/MyPlanetEditView.swift
       59562      58591 <present>  Planet/Avatars.xcassets/NSTG-0050.imageset/NSTG-0050.png
       58888      57920 <present>  Planet/Avatars.xcassets/NSTG-0049.imageset/NSTG-0049.png
     1194023      56733 <present>  Planet.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
       69105      56659 <present>  PlanetLite/Assets.xcassets/AppIcon-Croptop.appiconset/Croptop-1024.png
       57263      55959 <present>  Planet/Avatars.xcassets/NSTG-0061.imageset/NSTG-0061.png
       56792      55817 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Image.iconset/icon_256x256.png
       56792      55817 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Image.iconset/icon_128x128@2x.png
       56282      54748 <present>  Planet/Avatars.xcassets/NSTG-0062.imageset/NSTG-0062.png
       56017      54738 <present>  Planet/Avatars.xcassets/NSTG-0046.imageset/NSTG-0046.png
       55900      54623 <present>  Planet/Avatars.xcassets/NSTG-0047.imageset/NSTG-0047.png
       55945      54468 <present>  Planet/Avatars.xcassets/NSTG-0048.imageset/NSTG-0048.png
     4220002      53050 2022-06-26 Planet/PlanetManager.swift
       54372      52815 <present>  Planet/Avatars.xcassets/NSTG-0063.imageset/NSTG-0063.png
       50938      50663 <present>  Planet/Assets.xcassets/AppIcon.appiconset/Planetable Lite 256.png
       50938      50663 2023-01-13 Planet/Assets.xcassets/AppIcon.appiconset/Planetable Lite 256-1.png
       50822      50336 <present>  Planet/Avatars.xcassets/NSTG-0073.imageset/NSTG-0073.png
       50048      49589 <present>  Planet/Avatars.xcassets/NSTG-0074.imageset/NSTG-0074.png
       48920      48589 <present>  Planet/Assets.xcassets/AppIcon-Insider.appiconset/256.png
       48920      48589 2023-01-13 Planet/Assets.xcassets/AppIcon-Insider.appiconset/256 1.png
       48801      48344 <present>  Planet/Avatars.xcassets/NSTG-0075.imageset/NSTG-0075.png
     2339092      45528 <present>  Planet/PlanetDataController.swift
     1139140      43501 <present>  Planet/PlanetAPI.swift
     1392519      43403 <present>  Planet/PlanetApp.swift
       43559      43214 <present>  Planet/Avatars.xcassets/NSTG-0014.imageset/NSTG-0014.png
       42967      42608 <present>  Planet/Avatars.xcassets/NSTG-0013.imageset/NSTG-0013.png
       42861      42527 <present>  Planet/Avatars.xcassets/NSTG-0015.imageset/NSTG-0015.png
      826199      39791 <present>  Planet/TemplateBrowser/Template.swift
       40741      39261 <present>  Planet/Avatars.xcassets/NSTG-0002.imageset/NSTG-0002.png
       40605      39201 <present>  Planet/Avatars.xcassets/NSTG-0001.imageset/NSTG-0001.png
       39972      38764 <present>  Planet/Avatars.xcassets/NSTG-0072.imageset/NSTG-0072.png
      460340      38650 <present>  Planet/Views/Sidebar/MyPlanetSidebarItem.swift
       39653      38253 <present>  Planet/Avatars.xcassets/NSTG-0003.imageset/NSTG-0003.png
       38580      37443 <present>  Planet/Avatars.xcassets/NSTG-0070.imageset/NSTG-0070.png
       37701      37442 <present>  Planet/Assets.xcassets/AppIcon-Debug.appiconset/Planet Debug-256.png
       38151      37002 <present>  Planet/Avatars.xcassets/NSTG-0071.imageset/NSTG-0071.png
       27554      36804 <present>  Planet/versioning.xcconfig
       38504      36658 <present>  Planet/Avatars.xcassets/NSTG-0009.imageset/NSTG-0009.png
       38659      36615 <present>  Planet/Avatars.xcassets/NSTG-0007.imageset/NSTG-0007.png
       37944      36584 <present>  Planet/Avatars.xcassets/NSTG-0085.imageset/NSTG-0085.png
       37428      35729 <present>  Planet/Avatars.xcassets/NSTG-0008.imageset/NSTG-0008.png
       36785      35429 <present>  Planet/Avatars.xcassets/NSTG-0087.imageset/NSTG-0087.png
       35571      35287 <present>  Planet/Assets.xcassets/WalletAppIconRainbow.imageset/rainbow256.png
       36212      34958 <present>  Planet/Avatars.xcassets/NSTG-0086.imageset/NSTG-0086.png
       35680      34384 <present>  Planet/Avatars.xcassets/NSTG-0077.imageset/NSTG-0077.png
      530570      33570 <present>  Planet/Views/Articles/ArticleView.swift
       34835      33552 <present>  Planet/Avatars.xcassets/NSTG-0076.imageset/NSTG-0076.png
       34208      33021 <present>  Planet/Avatars.xcassets/NSTG-0078.imageset/NSTG-0078.png
      447589      32590 <present>  Planet/Helper/KeyboardShortcutHelper.swift
      419954      32138 <present>  Planet/Views/My/MyArticleItemView.swift
       32045      30529 <present>  Planet/Avatars.xcassets/NSTG-0081.imageset/NSTG-0081.png
       31390      29995 <present>  Planet/Avatars.xcassets/NSTG-0032.imageset/NSTG-0032.png
       30260      29970 <present>  Planet/Assets.xcassets/WalletAppIconMetaMask.imageset/metamask256.png
      501647      29967 <present>  Planet/Views/Sidebar/PlanetSidebarView.swift
       31117      29857 <present>  Planet/Avatars.xcassets/NSTG-0033.imageset/NSTG-0033.png
       30815      29707 <present>  Planet/Avatars.xcassets/NSTG-0031.imageset/NSTG-0031.png
       29464      29223 <present>  Planet/Avatars.xcassets/NSTG-0084.imageset/NSTG-0084.png
       29214      28946 <present>  Planet/Avatars.xcassets/NSTG-0082.imageset/NSTG-0082.png
      193145      28922 <present>  PlanetLite/AppContentView.swift
       30102      28590 <present>  Planet/Avatars.xcassets/NSTG-0080.imageset/NSTG-0080.png
       30107      28478 <present>  Planet/Avatars.xcassets/NSTG-0079.imageset/NSTG-0079.png
       28883      28399 <present>  Planet/Assets.xcassets/AppDataIcon-Image.iconset/icon_128x128.png
      296366      28344 <present>  Planet/Entities/MyPlanetModel+Aggregate.swift
       29309      28094 <present>  Planet/Avatars.xcassets/NSTG-0099.imageset/NSTG-0099.png
       29050      27847 <present>  Planet/Avatars.xcassets/NSTG-0097.imageset/NSTG-0097.png
       28445      27779 <present>  Planet/Avatars.xcassets/NSTG-0096.imageset/NSTG-0096.png
       28022      27738 <present>  Planet/Avatars.xcassets/NSTG-0083.imageset/NSTG-0083.png
       28720      27667 <present>  Planet/Avatars.xcassets/NSTG-0098.imageset/NSTG-0098.png
       34687      27582 <present>  Planet/Avatars.xcassets/NSTG-0004.imageset/NSTG-0004.png
       33794      27507 <present>  Planet/Avatars.xcassets/NSTG-0006.imageset/NSTG-0006.png
       28156      27445 <present>  Planet/Avatars.xcassets/NSTG-0094.imageset/NSTG-0094.png
      411211      27365 <present>  Planet/Helper/Extensions.swift
       32531      27307 <present>  Planet/Avatars.xcassets/NSTG-0005.imageset/NSTG-0005.png
       27390      27294 <present>  Planet/Avatars.xcassets/NSTG-0012.imageset/NSTG-0012.png
       28126      27085 <present>  Planet/Avatars.xcassets/NSTG-0089.imageset/NSTG-0089.png
       27705      26981 <present>  Planet/Avatars.xcassets/NSTG-0095.imageset/NSTG-0095.png
       26979      26886 <present>  Planet/Avatars.xcassets/NSTG-0011.imageset/NSTG-0011.png
       26954      26834 <present>  Planet/Avatars.xcassets/NSTG-0010.imageset/NSTG-0010.png
       55056      26379 <present>  Planet/Fonts/CapsulesOTF/Capsules-700.otf
       26559      25457 <present>  Planet/Avatars.xcassets/NSTG-0090.imageset/NSTG-0090.png
       26544      25209 <present>  Planet/Avatars.xcassets/NSTG-0088.imageset/NSTG-0088.png
       25782      24708 <present>  Planet/Avatars.xcassets/NSTG-0037.imageset/NSTG-0037.png
       27180      24675 <present>  PlanetLite/Assets.xcassets/AppIcon-Croptop.appiconset/Croptop-512.png
      269168      24661 <present>  Planet/Quick Share/PlanetQuickShareView.swift
       25506      24565 <present>  Planet/Avatars.xcassets/NSTG-0064.imageset/NSTG-0064.png
       25339      24542 <present>  Planet/Avatars.xcassets/NSTG-0065.imageset/NSTG-0065.png
       25217      24367 <present>  Planet/Avatars.xcassets/NSTG-0066.imageset/NSTG-0066.png
       25084      24136 <present>  Planet/Avatars.xcassets/NSTG-0039.imageset/NSTG-0039.png
       23922      23936 2022-05-02 Planet/Assets.xcassets/AppIcon.appiconset/108_xxxlarge-128.png
       24069      23688 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Image.iconset/icon_128x128.png
       23374      22927 <present>  Planet/Avatars.xcassets/NSTG-0034.imageset/NSTG-0034.png
      108624      22853 <present>  Planet/zh-Hans.lproj/Localizable.strings
       24053      22728 <present>  Planet/Avatars.xcassets/NSTG-0038.imageset/NSTG-0038.png
       23797      22688 <present>  Planet/Avatars.xcassets/NSTG-0091.imageset/NSTG-0091.png
       23775      22621 <present>  Planet/Avatars.xcassets/NSTG-0093.imageset/NSTG-0093.png
       23670      22527 <present>  Planet/Avatars.xcassets/NSTG-0024.imageset/NSTG-0024.png
       22993      22499 <present>  Planet/Avatars.xcassets/NSTG-0035.imageset/NSTG-0035.png
       48704      22375 <present>  Planet/Fonts/CapsulesOTF/Capsules-600.otf
       23341      22282 <present>  Planet/Avatars.xcassets/NSTG-0092.imageset/NSTG-0092.png
       22587      22066 <present>  Planet/Avatars.xcassets/NSTG-0036.imageset/NSTG-0036.png
       23271      21873 <present>  Planet/Avatars.xcassets/NSTG-0023.imageset/NSTG-0023.png
       22932      21639 <present>  Planet/Avatars.xcassets/NSTG-0022.imageset/NSTG-0022.png
      228027      20806 <present>  Planet/Views/PlanetMainView.swift
      449063      20730 <present>  Planet/Entities/FollowingArticleModel.swift
       45032      20175 <present>  Planet/Fonts/CapsulesOTF/Capsules-500.otf
      127587      20110 <present>  Planet/Entities/MyArticleModel+ImportExport.swift
       20953      19689 <present>  Planet/Avatars.xcassets/NSTG-0055.imageset/NSTG-0055.png
       20962      19588 <present>  Planet/Avatars.xcassets/NSTG-0056.imageset/NSTG-0056.png
       20303      19103 <present>  Planet/Avatars.xcassets/NSTG-0057.imageset/NSTG-0057.png
       20652      19100 <present>  Planet/Avatars.xcassets/NSTG-0053.imageset/NSTG-0053.png
       20312      19070 <present>  Planet/Avatars.xcassets/NSTG-0052.imageset/NSTG-0052.png
       20174      18996 <present>  Planet/Avatars.xcassets/NSTG-0054.imageset/NSTG-0054.png
       49700      18869 <present>  Planet/Fonts/CapsulesOTF/Capsules-300.otf
       52128      18815 <present>  Planet/Fonts/CapsulesOTF/Capsules-400.otf
      242969      18235 <present>  Planet/Writer/WriterView.swift
       20827      18180 <present>  Planet/Avatars.xcassets/NSTG-0020.imageset/NSTG-0020.png
       18522      18145 <present>  Planet/Avatars.xcassets/NSTG-0045.imageset/NSTG-0045.png
       18112      17743 <present>  Planet/Avatars.xcassets/NSTG-0044.imageset/NSTG-0044.png
       18042      17669 <present>  Planet/Avatars.xcassets/NSTG-0043.imageset/NSTG-0043.png
       20203      17593 <present>  Planet/Avatars.xcassets/NSTG-0019.imageset/NSTG-0019.png
       17537      17543 <present>  Planet/Assets.xcassets/AppIcon.appiconset/Planetable Lite 128.png
      271724      17406 <present>  PlanetLite/AppContentItemView.swift
      116354      17376 <present>  Planet/IPFS/IPFSState.swift
       49209      17170 2023-03-06 Planet/Assets.xcassets/custom.github.symbolset/github.fill.svg
      502014      17022 2022-06-26 Planet/Writer/PlanetWriterView.swift
       17820      16869 <present>  Planet/Avatars.xcassets/NSTG-0058.imageset/NSTG-0058.png
       17784      16700 <present>  Planet/Avatars.xcassets/NSTG-0060.imageset/NSTG-0060.png
       16512      16479 <present>  Planet/Assets.xcassets/AppIcon-Insider.appiconset/128.png
       18855      15998 <present>  Planet/Avatars.xcassets/NSTG-0027.imageset/NSTG-0027.png
       18716      15921 <present>  Planet/Avatars.xcassets/NSTG-0021.imageset/NSTG-0021.png
       18048      15522 <present>  Planet/Avatars.xcassets/NSTG-0025.imageset/NSTG-0025.png
       18044      15497 <present>  Planet/Avatars.xcassets/NSTG-0026.imageset/NSTG-0026.png
       16594      15460 <present>  Planet/Avatars.xcassets/NSTG-0059.imageset/NSTG-0059.png
      208889      14993 2024-01-12 PlanetLite/AppMenu.swift
       40093      14659 2023-03-06 Planet/Assets.xcassets/custom.twitter.symbolset/twitter.svg
       14662      14612 <present>  Planet/Assets.xcassets/AppIcon-Debug.appiconset/Planet Debug-128.png
       16997      14387 <present>  Planet/Avatars.xcassets/NSTG-0069.imageset/NSTG-0069.png
       16777      14293 <present>  Planet/Avatars.xcassets/NSTG-0067.imageset/NSTG-0067.png
      239442      14275 <present>  Planet/Writer/WriterTextView.swift
      175561      14270 <present>  Planet/Views/My/MyArticleSettingsView.swift
      153868      14133 2024-01-12 PlanetLite/AppWindowController.swift
      170312      13831 <present>  PlanetLite/AppSidebarItemView.swift
      281856      13729 <present>  Planet/Helper/FeedUtils.swift
       31916      13711 <present>  Planet/Fonts/CapsulesOTF/Capsules-200.otf
       31988      13706 <present>  Planet/Fonts/CapsulesOTF/Capsules-100.otf
       16104      13652 <present>  Planet/Avatars.xcassets/NSTG-0068.imageset/NSTG-0068.png
      117118      13084 <present>  Planet/Views/Articles/ArticleListView.swift
      126965      13076 <present>  Planet/Views/Sidebar/AccountBadgeView.swift
      372021      12925 <present>  Planet/Labs/Published Folders/Dashboard/PFDashboardWindowController.swift
       82933      12789 <present>  Planet/Views/My/MyArticleGridView.swift
       15053      12698 <present>  Planet/Avatars.xcassets/NSTG-0030.imageset/NSTG-0030.png
      224793      12563 <present>  Planet/Views/Articles/ArticleWebView.swift
       14897      12542 <present>  Planet/Avatars.xcassets/NSTG-0029.imageset/NSTG-0029.png
       14846      12494 <present>  Planet/Avatars.xcassets/NSTG-0028.imageset/NSTG-0028.png
       28625      12355 <present>  Planet/SharedAssets.xcassets/multi.imageset/multi.png
       12585      12291 <present>  Planet/Assets.xcassets/WalletAppIconMetaMask.imageset/metamask128.png
       48749      12278 <present>  Planet/Assets.xcassets/custom.juicebox.symbolset/custom.juicebox.svg
       84439      12241 <present>  Planet/Entities/MyArticleModel+SavePublic.swift
      123591      12172 <present>  Planet/Settings/PlanetSettingsGeneralView.swift
       90320      11873 <present>  Planet/Views/Create & Follow Planet/CreatePlanetView.swift
       94310      11817 <present>  Planet/Labs/Wallet/WalletAccountView.swift
       64841      11779 <present>  PlanetLite/AppSidebarView.swift
      226827      11565 <present>  Planet/IPFS/IPFSCommand.swift
       50170      11319 <present>  Planet/Helper/ViewUtils.swift
       11350      11038 <present>  PlanetLite/Assets.xcassets/AppIcon-Croptop.appiconset/Croptop-256.png
       67787      10997 <present>  Planet/Writer/AttachmentThumbnailView.swift
       11254      10960 <present>  Planet/Assets.xcassets/WalletAppIconRainbow.imageset/rainbow128.png
       11196      10957 <present>  Planet/Assets.xcassets/AppDataIcon-Image.iconset/icon_32x32@2x.png
       10600      10374 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Image.iconset/icon_32x32@2x.png
       11723      10273 <present>  Planet/Avatars.xcassets/NSTG-0040.imageset/NSTG-0040.png
       11773      10201 <present>  Planet/Avatars.xcassets/NSTG-0041.imageset/NSTG-0041.png
       11649       9836 <present>  Planet/Avatars.xcassets/NSTG-0042.imageset/NSTG-0042.png
      109052       9525 <present>  Planet/TemplateBrowser/Window Controller/TBWindowController.swift
       25374       9468 <present>  Planet/Assets.xcassets/custom.telegram.symbolset/telegram-circle-fill.svg
       54494       9420 <present>  PlanetLite/AppDelegate.swift
      289319       9337 <present>  Planet/Views/ArticleWebView.swift
       86776       8893 <present>  Planet/Search/SearchView.swift
      184283       8663 <present>  Planet/Writer/WriterWindow.swift
      140858       8566 <present>  Planet/Assets.xcassets/custom.mastodon.fill.symbolset/mastodon.fill.svg
       54908       8046 <present>  Planet/en.lproj/Localizable.strings
        8003       8017 2022-05-02 Planet/Assets.xcassets/AppIcon.appiconset/108_xxxlarge-64.png
      390789       8003 2022-07-06 Planet/Writer/PlanetWriterManager.swift
       57170       7895 <present>  PlanetLite/Croptop/AggregationSettings.swift
      186111       7877 <present>  Planet/Views/Create & Follow Planet/EditMyPlanetView.swift
       86108       7529 <present>  Planet/Views/Create & Follow Planet/FollowPlanetView.swift
       43549       7477 <present>  Planet/Assets.xcassets/AppDataIcon-Fill.iconset/icon_512x512@2x.png
       37722       7430 <present>  Planet/Templates/WriterBasic.html
      107182       7362 <present>  Planet/Credits.html
       49559       7265 <present>  Planet/Views/Sidebar/FollowingPlanetSidebarItem.swift
       43524       7197 <present>  Planet/Assets.xcassets/custom.ens.symbolset/custom.ens.svg
       55851       6857 <present>  Planet/Quick Share/PlanetQuickShareViewModel.swift
       82783       6846 2022-06-26 Planet/Views/PlanetWriterView.swift
       82652       6815 <present>  Planet/Views/ArticleView.swift
      132961       6788 <present>  Planet/Entities/ArticleModel.swift
       40883       6709 <present>  README.md
       75722       6340 <present>  Planet/PlanetError.swift
       45026       6340 <present>  Planet/Labs/Published Folders/Dashboard/PFDashboardView.swift
       70926       6118 2024-01-12 PlanetLite/AppContentGridView.swift
      115349       6080 <present>  Planet/Views/Articles/ArticleWebViewModel.swift
       73146       6037 <present>  Planet/Helper/MarkdownUtils.swift
       71573       6035 <present>  Planet/PlanetAppDelegate.swift
       48445       5969 <present>  Planet/Labs/Published Folders/Dashboard/PFDashboardContentView.swift
        5813       5827 <present>  Planet/Assets.xcassets/AppIcon-Debug.appiconset/Planet Debug-64.png
       70664       5754 <present>  Planet/Info.plist
       60788       5729 <present>  Planet/Views/Articles/MyArticleItemView.swift
        5703       5633 <present>  PlanetLite/Assets.xcassets/AppIcon-Croptop.appiconset/Croptop-128.png
        5559       5573 <present>  Planet/Assets.xcassets/AppIcon.appiconset/Planetable Lite 64.png
       34217       5512 <present>  PlanetLite/AppContentDropDelegate.swift
       18623       5462 <present>  PlanetLite/CroptopApp.swift
        5408       5422 <present>  Planet/Assets.xcassets/AppIcon-Insider.appiconset/64.png
       35224       5418 <present>  PlanetLite/Info.plist
       72066       5412 <present>  Planet/Views/My/MyPlanetPodcastSettingsView.swift
       81778       5412 2022-06-26 Planet/Views/List/PlanetArticleListView.swift
       51733       5400 <present>  Planet/TemplateBrowser/TemplateBrowserSidebar.swift
      135313       5299 <present>  Planet/Key Manager/PlanetKeyManagerWindowController.swift
       69501       5271 <present>  Planet/Helper/Saver.swift
       49001       5256 <present>  Planet/Entities/AttachmentModel.swift
       46724       5246 <present>  Planet/Labs/IPFS Status/IPFSTrafficChartView.swift
       27385       5229 <present>  Planet/Writer/WriterTitleView.swift
       48909       5197 <present>  Planet/Views/PlanetArticleView.swift
       29130       5147 <present>  Planet/Views/My/MyPlanetInfoView.swift
      288488       5134 2022-06-26 Planet/Planet.swift
        5362       5115 <present>  Planet/Assets.xcassets/AppDataIcon-Image.iconset/icon_32x32.png
        5362       5115 <present>  Planet/Assets.xcassets/AppDataIcon-Image.iconset/icon_16x16@2x.png
       79408       5067 2022-06-26 Planet/Writer/PlanetWriterUploadImageThumbnailView.swift
       92793       5060 <present>  Planet/Downloads/PlanetDownloadsWebView.swift
       37894       4943 <present>  Planet/TemplateBrowser/TemplateBrowserPreviewWebView.swift
       32820       4915 <present>  Planet/Labs/Wallet/TipSelectView.swift
       40434       4781 <present>  Planet/Labs/IPFS Status/IPFSStatusView.swift
      111776       4678 <present>  Planet/Labs/Icon Gallery/IconManager.swift
        4853       4604 <present>  Planet/Assets.xcassets/ENS.imageset/ens@3x.png
       13158       4528 <present>  Planet/Assets.xcassets/AppDataIcon-Fill.iconset/icon_512x512.png
       13158       4528 <present>  Planet/Assets.xcassets/AppDataIcon-Fill.iconset/icon_256x256@2x.png
      148683       4410 2022-06-26 Planet/Views/PlanetAboutView.swift
       29896       4392 <present>  Planet/TemplateBrowser/TemplatePreviewView.swift
       43932       4379 <present>  Planet/Settings/PlanetSettingsAPIView.swift
       64578       4373 <present>  Planet/Labs/Wallet/WalletManager.swift
       47496       4354 <present>  Planet/TemplateBrowser/TemplateStore.swift
       61961       4256 2022-06-26 Planet/Entities/Planet.swift
       44611       4237 <present>  Planet/Helper/URLUtils.swift
        5509       4195 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Image.iconset/icon_32x32.png
        5509       4195 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Image.iconset/icon_16x16@2x.png
      113729       4073 <present>  .github/workflows/release.yml
       38135       4044 <present>  Planet/Views/My/AvatarPickerView.swift
      140990       3928 2022-06-26 Planet/Views/PlanetArticleListView.swift
       24586       3799 <present>  Planet/Search/PlanetStore+Search.swift
       45682       3776 <present>  Planet/Labs/Icon Gallery/IconGalleryView.swift
       48116       3592 <present>  Planet/Views/PlanetArticleWebView.swift
       47855       3539 <present>  Planet/Helper/KeychainHelper.swift
       50097       3474 <present>  Planet/Views/My/MyPlanetCustomCodeView.swift
       18316       3449 <present>  Planet/Helper/ENSUtils.swift
       67589       3309 <present>  Planet/Labs/Wallet/WalletConnectV1.swift
        3244       3258 2022-05-02 Planet/Assets.xcassets/AppIcon.appiconset/108_xxxlarge-32.png
        3510       3248 <present>  Planet/Assets.xcassets/ENS.imageset/ens@2x.png
      363241       3211 <present>  Planet/Views/PlanetSidebarView.swift
       24493       3204 <present>  Planet/Views/Create & Follow Planet/EditPlanetView.swift
       62184       3204 2022-06-26 Planet/PlanetStore.swift
       14733       3166 <present>  Planet/IPFS/Status Views/IPFSStatusView.swift
        3044       3058 <present>  PlanetLite/Assets.xcassets/AppIcon-Croptop.appiconset/Croptop-64.png
       36495       2980 2022-06-26 Planet/Writer/PlanetWriterWebView.swift
        4937       2961 <present>  Planet/Assets.xcassets/AppDataIcon-Fill.iconset/icon_256x256.png
        4937       2961 <present>  Planet/Assets.xcassets/AppDataIcon-Fill.iconset/icon_128x128@2x.png
        8945       2952 <present>  Technotes/Juicebox.md
       13472       2907 <present>  Planet/Entities/BackupMyPlanetModel.swift
       22263       2896 2024-01-12 PlanetLite/AppContentItemMenuView.swift
       30124       2803 <present>  Planet/Views/My/MyPlanetTemplateSettingsView.swift
       41148       2779 <present>  Planet/Labs/Published Folders/Dashboard/PFDashboardInspectorView.swift
       56271       2758 <present>  Planet/Views/Following/FollowingArticleItemView.swift
       17530       2750 <present>  Planet/Writer/WriterStore.swift
        2727       2741 <present>  Planet/Assets.xcassets/AppIcon-Debug.appiconset/Planet Debug-32.png
       15950       2709 2024-01-12 PlanetLite/AppTitlebarView.swift
       53664       2620 2022-05-08 Planet/PlanetCommand.swift
       16019       2602 <present>  Planet/Entities/PlanetStore+Timer.swift
       17858       2580 <present>  Planet/Writer/WriterWebView.swift
       11522       2560 <present>  Planet/Quick Share/PlanetQuickShareDropDelegate.swift
       24438       2520 <present>  Planet/Labs/Published Folders/Dashboard/PFDashboardSidebarItemView.swift
       94284       2514 <present>  .github/workflows/insider.yml
       24087       2466 <present>  Planet/Views/AboutFollowingPlanetView.swift
       28388       2457 <present>  Planet/LegacyCoreData/PlanetArticle.swift
       18372       2441 <present>  Planet/TemplateBrowser/TemplateBrowserView.swift
       35218       2430 <present>  Planet/Labs/Quick Post/QuickPostView.swift
       11502       2408 <present>  Planet/Release.xcconfig
       18759       2319 <present>  PlanetLite/Croptop/MintSettings.swift
       14376       2312 <present>  Planet/Labs/IPFS Status/IPFSTrafficView.swift
       21729       2258 <present>  Planet/Downloads/PlanetDownloadModel.swift
        9269       2223 <present>  Planet/IPFS/Status Views/IPFSTrafficChartView.swift
       17600       2209 <present>  Planet/Integrations/Filebase.swift
        7144       2166 <present>  Planet/IPFS/IPFSMigrationCommand.swift
       32109       2163 <present>  Planet/Views/Components/ArtworkView.swift
       10625       2140 <present>  Planet/Writer/WriterViewModel.swift
        3472       2122 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Image.iconset/icon_16x16.png
       20014       2106 2022-06-26 Planet/Writer/PlanetWriterWindow.swift
       23291       2026 <present>  Planet/Downloads/PlanetDownloadsItemView.swift
       18133       2025 <present>  Planet/TemplateBrowser/TemplateBrowserStore.swift
       11485       2022 <present>  Planet/Writer/WriterDragAndDrop.swift
        1983       1996 <present>  Planet/Assets.xcassets/AppIcon.appiconset/Planetable Lite 32.png
        1983       1996 2023-01-13 Planet/Assets.xcassets/AppIcon.appiconset/Planetable Lite 32-1.png
        1963       1976 <present>  Planet/Assets.xcassets/AppIcon-Insider.appiconset/32.png
        1963       1976 2023-01-13 Planet/Assets.xcassets/AppIcon-Insider.appiconset/32 1.png
       10279       1926 <present>  Planet/Labs/Status Manager/PlanetStatusManager.swift
        2133       1873 <present>  Planet/Assets.xcassets/ENS.imageset/ens.png
        3231       1872 <present>  Planet/Assets.xcassets/AppDataIcon-Image.iconset/icon_16x16.png
        9402       1847 <present>  Planet/TemplateBrowser/TemplateBrowserInspectorView.swift
       19337       1803 2022-06-26 Planet/View Models/PlanetWriterViewModel.swift
        7359       1725 2023-10-13 Planet/Quick Share/PlanetQuickSharePasteView.swift
       24110       1724 <present>  Planet/LegacyCoreData/Planet.swift
        4344       1715 <present>  Planet/Helper/DirectoryMonitor.swift
       16387       1706 <present>  .github/workflows/master_deploy.yml
       10615       1704 <present>  Planet/Templates/RSS.xml
       31533       1691 <present>  Planet/Views/Articles/FollowingArticleItemView.swift
       39889       1671 2022-07-04 Planet/Entities/EditArticleDraftModel.swift
       14211       1646 <present>  Planet/Views/Following/FollowingPlanetInfoView.swift
        8397       1607 <present>  Planet/Views/Plausible/PlausiblePopover.swift
       12486       1590 <present>  Planet/Views/My/MyPlanetIPNSView.swift
        3142       1563 <present>  Planet/IPFS/Status Views/Window/IPFSStatusWindow.swift
        6850       1545 <present>  Planet/API/PlanetAPIService.swift
        4857       1542 <present>  Planet/Integrations/dWebServices.swift
       11694       1530 <present>  Planet/Labs/Published Folders/Dashboard/PFDashboardContainerViewController.swift
       12567       1529 2022-10-26 Planet/Views/My/MyPlanetPodcastCoverArtView.swift
       14180       1514 <present>  Planet/Labs/Wallet/EthereumTransaction.swift
       21692       1459 2022-06-26 Planet/Views/PlanetAvatarView.swift
       66320       1432 2022-06-26 Planet/Writer/PlanetWriterTextView.swift
        5184       1419 <present>  Technotes/ContentHashVerification.md
       10809       1408 <present>  Planet/LegacyCoreData/CoreDataPersistence.swift
       10792       1391 2022-06-26 Planet/Writer/PlanetWriterEditorTextView.swift
        6710       1353 <present>  tools/monitor-ipfs-peers/monitor.py
        4498       1338 <present>  Planet/Integrations/Pinnable.swift
        7432       1329 2022-10-26 Planet/Views/MyPlanetAvatarView.swift
        4316       1327 <present>  Planet/Entities/PublicArticleModel.swift
       13821       1295 <present>  Planet/Views/Onboarding/OnboardingView.swift
        7231       1294 <present>  Planet/Views/SimplePlanetArticleView.swift
       11941       1293 <present>  Planet/Labs/Wallet/WalletConnectV1QRCodeView.swift
        4731       1256 <present>  Planet/Entities/BackupArticleModel.swift
        8015       1245 <present>  Planet/Settings/PlanetSettingsView.swift
         910       1238 <present>  Planet/marketing_version.xcconfig
       13651       1219 2022-07-04 Planet/Entities/NewArticleDraftModel.swift
        6919       1216 <present>  Planet/PlanetUI.swift
        5684       1175 <present>  Planet/Views/AboutMyPlanetView.swift
       13260       1155 <present>  Planet/Helper/WKScriptHelper.swift
        5115       1137 <present>  Planet/IPFS/Open Views/IPFSOpenView.swift
        7449       1108 <present>  Planet/Helper/DotBitKit.swift
        5290       1100 <present>  Planet/IPFS/IPFSAPIModel.swift
       11423       1080 2022-06-08 Planet/Templates/Basic.html
        6746       1043 <present>  Planet/Views/Components/IndicatorLabelView.swift
        7212       1037 <present>  Planet/Key Manager/PlanetKeyManagerView.swift
       20138       1018 <present>  Planet/Labs/Published Folders/PlanetPublishedFolders+Extension.swift
        7358       1005 <present>  Planet/Views/My/RebuildProgressView.swift
        7987       1001 2022-05-10 Planet/Writer/PlanetWriterEditView.swift
        7727        998 <present>  Planet/Key Manager/PlanetKeyManagerViewModel.swift
        5862        974 <present>  Planet/Views/Components/CLTextFieldView.swift
       32166        971 <present>  .github/workflows/croptop.yml
       11632        966 <present>  Planet/Settings/PlanetSettingsPlanetsView.swift
        2017        951 <present>  PlanetLite/Assets.xcassets/AppIcon-Croptop.appiconset/Croptop-32.png
        7394        949 2022-06-29 Planet/Views/Sidebar/SmartFeedView.swift
        2463        946 <present>  Planet/Assets.xcassets/AppDataIcon-Fill.iconset/icon_128x128.png
        4665        941 <present>  Planet/Planet.xcconfig
        4251        928 2024-01-12 PlanetLite/AppWindow.swift
        3208        926 <present>  Planet/Helper/PodcastUtils.swift
       13860        905 <present>  Planet/TemplateBrowser/Window Controller/TB+Extension.swift
        2829        859 <present>  Planet/Settings/PlanetSettingsViewModel.swift
        2202        855 <present>  Planet/Labs/Published Folders/PlanetDirectoryMonitor.swift
        2155        848 <present>  Planet/Entities/PlanetStore+ServerInfo.swift
        3368        847 <present>  Planet/Views/Following/FollowingPlanetAvatarView.swift
       17605        842 <present>  Planet/TemplateBrowser/Window Controller/TBContainerViewController.swift
        3631        840 <present>  Planet/Writer/WriterVideoView.swift
         827        834 <present>  Planet/Assets.xcassets/AppIcon-Insider.appiconset/16.png
        5721        825 2022-05-31 Planet/Credits.rtf
         811        818 <present>  Planet/Assets.xcassets/AppIcon.appiconset/Planetable Lite 16.png
        5026        810 <present>  Planet/Views/Components/GIFIndicatorView.swift
        6910        809 2024-01-12 PlanetLite/AppContentGridCell.swift
        1859        794 2022-05-02 Planet/Assets.xcassets/AppIcon.appiconset/108_xxxlarge-16.png
        4009        788 <present>  Planet/Templates/TemplatePlaceholder.html
        5883        779 2023-05-30 Planet.xcodeproj/xcshareddata/xcschemes/Planet.xcscheme
        3444        775 <present>  Technotes/Kubo.md
        1261        769 <present>  Technotes/ENS.md
        2336        763 <present>  Planet/TemplateBrowser/TemplateMonitor.swift
       14317        759 <present>  PlanetLite/Croptop/CPNSettings.swift
        3053        751 <present>  Planet/Art/NSTG.json
        1778        725 <present>  Planet/IPFS/Status Views/Window/IPFSStatusWindowManager.swift
        3138        713 <present>  Planet/Labs/Published Folders/Dashboard/PFDashboardSidebarView.swift
        4327        711 2023-06-29 PlanetLite/AppContentDetailsView.swift
       11895        696 <present>  Planet/Views/ArticleWebViewModel.swift
        2393        693 <present>  Planet/Entities/PublicPlanetModel.swift
        3257        688 <present>  Planet/Downloads/PlanetDownloadsViewModel.swift
        3288        686 <present>  Planet/Quick Share/PlanetQuickShare+Extension.swift
        2427        686 <present>  Planet.xcodeproj/xcshareddata/xcschemes/PlanetDockPlugIn.xcscheme
         771        686 <present>  .gitignore
        1753        685 <present>  Planet/Assets.xcassets/AppIcon-Debug.appiconset/Planet Debug-16.png
        4795        661 2023-07-07 Planet/Quick Share/PlanetQuickShareViewController.swift
        4345        660 <present>  Planet/Downloads/PlanetDownloadsView.swift
        1498        654 <present>  Technotes/KeyManager.md
        9228        649 2022-06-26 Planet/Views/PlanetArticleItemView.swift
        3084        634 <present>  Technotes/PlanetInternalLinks.md
        1984        631 <present>  Planet/Views/Saver/MigrationProgressView.swift
        2430        625 <present>  Planet/Helper/Updater.swift
        2898        621 <present>  Planet/Labs/Icon Gallery/PlanetDockPlugIn.swift
        2662        614 <present>  Planet/Planet.entitlements
        4624        608 2022-12-13 Planet/TemplateBrowser/TemplateBrowserManager.swift
        3090        608 <present>  Planet/Planet.xcdatamodeld/Planet v7.xcdatamodel/contents
        2012        597 <present>  Planet/Labs/Icon Gallery/IconModel.swift
        9895        594 2024-01-12 PlanetLite/AppContainerViewController.swift
        1289        589 <present>  PlanetLite/AppSettingsView.swift
        3043        587 2022-06-26 Planet/View Models/PlanetAvatarViewModel.swift
        4623        582 2022-06-26 Planet/Views/List/PlanetArticleItemView.swift
        2283        576 <present>  Technotes/WalletConnect.md
        2417        574 <present>  Planet/TemplateBrowser/Window Controller/TBWindow.swift
        2179        573 2022-06-26 Planet/Helper/GoIPFSGateway.swift
        2539        572 <present>  Technotes/KeyboardShortcut.md
        2825        572 <present>  Planet/Views/Articles/ArticleAudioPlayer.swift
        5933        571 <present>  Planet/Views/MyPlanetInfoView.swift
        1207        564 2022-06-26 Planet/Writer/PlanetWriterPreviewView.swift
        1263        563 <present>  Planet/Views/Components/HelpLinkButton.swift
        2718        556 <present>  Planet/Views/FollowingPlanetAvatarView.swift
        3520        553 2023-06-29 PlanetLite/AppContentDetailsWindowManager.swift
        2702        548 2022-06-08 Planet/Templates/BasicPreview.html
        1230        531 <present>  Planet/Downloads/PlanetDownloadsWindow.swift
        2056        529 <present>  Planet/Views/Components/AudioPlayer.swift
        1590        521 <present>  PlanetLite/Assets.xcassets/AppIcon-Croptop.appiconset/Croptop-16.png
       12636        517 <present>  Planet/TemplateBrowser/TemplateWebView.swift
        2696        496 <present>  PlanetLite/PlanetLite.entitlements
        1007        495 2022-05-19 Planet/Templates/plain/templates/blog.html
        1409        494 <present>  Planet/IPFS/IPFSGateway.swift
        1095        491 <present>  Planet/Helper/Runner.swift
         981        483 <present>  Planet/IPFS/Open Views/Window/IPFSOpenWindow.swift
        1597        480 <present>  Planet/Templates/NoSelection.html
        1140        478 <present>  Planet/IPFS/Status Views/Window/IPFSStatusViewController.swift
        1004        476 2022-06-26 Planet/PlanetConfiguration.swift
       20619        474 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Fill.iconset/icon_512x512@2x.png
        1673        473 <present>  Planet/Assets.xcassets/AppDataIcon-Fill.iconset/icon_32x32@2x.png
        1333        465 <present>  Technotes/Releases/0.6.16.md
        7868        465 2022-10-26 Planet/Views/My/MyPlanetAvatarView.swift
        1301        464 <present>  Technotes/Xcode15.md
        1200        462 2024-01-12 PlanetLite/AppTitlebarViewController.swift
        4059        462 <present>  Planet/Assets.xcassets/AppIcon.appiconset/Contents.json
        1352        459 <present>  Technotes/Test.md
        2425        454 <present>  Planet/Writer/WriterAudioView.swift
        1881        454 2022-07-08 Planet/Entities/PlanetModel.swift
       28086        443 <present>  .github/workflows/experimental.yml
        2123        440 <present>  Technotes/Peering.md
        2654        435 2023-07-07 Planet/Quick Share/PlanetQuickShareWindow.swift
        1102        433 <present>  Planet/IPFS/Open Views/Window/IPFSOpenViewController.swift
        2735        423 <present>  Planet/Views/Components/IndicatorViews.swift
         683        420 <present>  Technotes/Slug.md
         843        418 2023-07-03 Planet/Writer/WriterPreview.swift
        1134        414 2022-05-19 Planet/Templates/plain/assets/style.css
         931        411 <present>  Planet/Labs/Wallet/WalletTransactionProgressView.swift
        2106        411 <present>  Planet/Helper/JSONUtils.swift
        1027        405 2024-01-12 PlanetLite/AppSettingsViewController.swift
         743        386 <present>  Planet/Labs/Published Folders/PlanetPublishedFolderModel.swift
        4160        385 <present>  Planet/Labs/Published Folders/Dashboard/PFDashboardWindow.swift
         871        380 2023-06-29 PlanetLite/AppContentDetailsWindow.swift
         841        375 <present>  Planet/Views/ArticleAudioPlayer.swift
        2018        373 2022-05-08 Planet/Helper/Data+sha256.swift
        5716        367 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Fill.iconset/icon_512x512.png
        5716        367 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Fill.iconset/icon_256x256@2x.png
         614        360 <present>  Technotes/Podcast.md
         727        360 <present>  Planet/Settings/PlanetSettingsModel.swift
         884        359 <present>  Planet/Views/Components/LoadingIndicatorView.swift
        5899        354 <present>  Planet.xcodeproj/xcshareddata/xcschemes/Croptop.xcscheme
        3957        353 2022-06-26 Planet/Writer/PlanetWriterHelper.swift
         810        351 <present>  Planet/Settings/PlanetSettingsPublishedFoldersView.swift
         948        350 <present>  Technotes/IPFSRepoMigrate.md
        1502        340 <present>  Planet/Assets.xcassets/AppDataIcon-Fill.iconset/icon_32x32.png
        1502        340 <present>  Planet/Assets.xcassets/AppDataIcon-Fill.iconset/icon_16x16@2x.png
        2125        337 2023-07-07 Planet/Quick Share/PlanetQuickShareWindowController.swift
         606        332 <present>  Technotes/MonoRepo.md
        4921        326 <present>  Planet/Labs/Wallet/WalletConnectV2QRCodeView.swift
         604        323 <present>  Technotes/Releases/0.7.0.md
         781        322 <present>  Technotes/PlanetAvatar.md
        7759        321 2022-06-26 Planet/Entities/PlanetArticle.swift
        3312        320 <present>  Planet/Assets.xcassets/AppIcon-Insider.appiconset/Contents.json
        2193        320 <present>  LICENSE
         752        305 <present>  Technotes/FFmpeg.md
         762        299 <present>  Technotes/API.md
         777        297 2022-02-26 Planet.xcodeproj/xcuserdata/kai.xcuserdatad/xcschemes/xcschememanagement.plist
        1441        295 <present>  Planet/Views/Components/GroupIndicatorView.swift
         860        294 <present>  Planet/IPFS/Open Views/Window/IPFSOpenWindowManager.swift
        1452        294 <present>  Planet/Assets.xcassets/AppDataIcon-Fill.iconset/icon_16x16.png
        1678        291 2022-02-24 Planet/Views/PlanetArticleDetailsView.swift
        6712        291 <present>  Planet/Labs/Published Folders/Dashboard/PFDashboardWebView.swift
        1572        290 <present>  Planet/Planet.xcdatamodeld/.xccurrentversion
         999        288 2022-06-26 Planet/PlanetStatusViewModel.swift
         586        288 2022-12-17 Planet/Labs/Published Folders/Dashboard/PFDashboardAccessoryStatusView.swift
        1763        285 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Fill.iconset/icon_256x256.png
        1763        285 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Fill.iconset/icon_128x128@2x.png
         559        282 <present>  Planet/IPFS/Status Views/Window/IPFSStatusWindowController.swift
        2935        280 2023-05-30 PlanetLite/AppExtension.swift
        2674        277 2022-07-02 Planet/Writer/DraftImageThumbnailView.swift
        3911        270 <present>  Planet/Views/Components/SharingServicePicker.swift
         561        267 <present>  Planet/IPFS/Open Views/Window/IPFSOpenWindowController.swift
         422        257 <present>  .swiftlint.yml
        2395        256 <present>  Planet/Key Manager/PlanetKeyManager+Extension.swift
         341        255 <present>  Technotes/Releases/0.6.17.md
        2436        253 2023-06-29 PlanetLite/AppContentDetailsWindowController.swift
        7736        253 <present>  Planet/Labs/Published Folders/Dashboard/PF+Extension.swift
         263        252 <present>  FUNDING.json
       14307        246 <present>  Planet/Assets.xcassets/custom.ethereum.symbolset/custom.ethereum.svg
        1094        243 2024-01-12 PlanetLite/AppSettingsWindowController.swift
        2214        233 2024-01-12 PlanetLite/AppContentViewController.swift
         419        232 <present>  Planet/Labs/dApps/DecentralizedApp.swift
         620        228 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Fill.iconset/icon_128x128.png
        7884        227 <present>  Planet/Labs/Published Folders/Dashboard/PublishedFolders+Extension.swift
         692        226 <present>  PlanetLite/Assets.xcassets/BorderColor.colorset/Contents.json
         692        226 <present>  Planet/Assets.xcassets/BorderColor.colorset/Contents.json
        1280        223 <present>  PlanetLite/Assets.xcassets/AppIcon-Croptop.appiconset/Contents.json
         372        220 <present>  Planet/Entities/SearchResult.swift
        1330        219 <present>  Planet/Assets.xcassets/AppIcon-Debug.appiconset/Contents.json
         288        217 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Fill.iconset/icon_32x32@2x.png
        3044        215 <present>  Planet/Key Manager/PlanetKeyManagerWindow.swift
         695        212 <present>  Planet/Assets.xcassets/AccountBadgeBackgroundColor.colorset/Contents.json
         615        208 <present>  tools/monitor-ipfs-peers/peers.txt
         389        207 <present>  Planet/Helper/Lifetimes.swift
        1160        206 2023-06-29 PlanetLite/AppContentDetailsViewController.swift
         309        205 2023-05-23 PlanetLite/AppViewModel.swift
       48828        203 <present>  Planet/Assets.xcassets/custom.github.symbolset/custom.github.svg
       39712        199 <present>  Planet/Assets.xcassets/custom.twitter.symbolset/custom.twitter.svg
         607        198 <present>  .editorconfig
        1135        197 2022-12-17 Planet/Labs/Published Folders/Dashboard/PFDashboardAccessoryStatusViewController.swift
         793        192 <present>  Planet/Downloads/PlanetDownloadsWindowController.swift
         596        189 <present>  git-hooks/pre-commit.sh
        1846        184 <present>  Planet/IPFS/Status Views/IPFSTrafficView.swift
        1328        180 <present>  Planet/TemplateBrowser/Window Controller/TBInspectorViewController.swift
         301        178 <present>  Planet/Key Manager/PlanetKeyManagerModel.swift
         232        173 2022-05-08 Planet/Helper/HTTPURLResponse+Extension.swift
         936        171 2022-12-13 Planet/TemplateBrowser/TemplateBrowserWindow.swift
         200        167 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Fill.iconset/icon_32x32.png
         200        167 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Fill.iconset/icon_16x16@2x.png
         244        163 <present>  PlanetLite/AppMainView.swift
        1144        163 <present>  Planet/Downloads/PlanetDownloadsViewController.swift
         194        161 <present>  Planet/zh-Hans.lproj/InfoPlist.strings
         233        159 2024-01-12 PlanetLite/main.swift
         184        156 <present>  PlanetLite/Assets.xcassets/AppDataIcon-Fill.iconset/icon_16x16.png
         248        156 <present>  .swift-format
         307        147 <present>  Planet/Avatars.xcassets/NSTG-0082.imageset/Contents.json
         307        147 <present>  Planet/Avatars.xcassets/NSTG-0053.imageset/Contents.json
         307        147 <present>  Planet/Avatars.xcassets/NSTG-0029.imageset/Contents.json
         307        147 <present>  Planet/Avatars.xcassets/NSTG-0001.imageset/Contents.json
         210        144 2022-05-08 Planet/Assets.xcassets/IPFS-GO.dataset/Contents.json
         210        144 2022-05-08 Planet/Assets.xcassets/IPFS-GO-ARM.dataset/Contents.json
         155        144 <present>  .github/FUNDING.json
         176        129 2022-05-19 Planet/Templates/plain/template.json
         150        127 <present>  Planet/Entities/MyArticleModel+Views.swift
         166        126 <present>  Planet/Assets.xcassets/custom.ethereum.symbolset/Contents.json
         155        125 <present>  tools/monitor-ipfs-peers/config.example.py
         164        123 <present>  Planet/SharedAssets.xcassets/op-logo.imageset/Contents.json
         133        121 2024-05-23 Planet/IPFS/go-ipfs-executables/ipfs-arm64-0.15.bin
         133        121 2024-05-23 Planet/IPFS/go-ipfs-executables/ipfs-amd64-0.15.bin
        1314        118 <present>  Planet/TemplateBrowser/Window Controller/TBSidebarViewController.swift
         155        116 <present>  Planet/SharedAssets.xcassets/multi.imageset/Contents.json
        1016        112 2022-05-03 Planet/Writer/PlanetWriterViewModel.swift
          94        111 <present>  Technotes/Debts.md
         513        110 <present>  Planet/Helper/StencilExtension.swift
        1283        109 <present>  Planet/TemplateBrowser/Window Controller/TBViewController.swift
         153        107 2022-05-18 Planet/Templates/TemplateTON.html
        1169        107 <present>  Planet/Key Manager/PlanetKeyManagerViewController.swift
         135        107 <present>  Planet.xcodeproj/project.xcworkspace/contents.xcworkspacedata
         385        104 <present>  Planet/Assets.xcassets/WalletAppIconMetaMask.imageset/Contents.json
         136        103 <present>  .gitattributes
         623        100 <present>  Planet/Views/Modifiers/CapsuleBar.swift
         123         98 <present>  PlanetLite/Assets.xcassets/AccentColor.colorset/Contents.json
         123         98 <present>  Planet/Assets.xcassets/AccentColor.colorset/Contents.json
         104         94 2023-08-24 Planet/Labs/Icon Gallery/PlanetDockPlugIn-Bridging-Header.h
        1844         94 <present>  Planet/Integrations/Plausible.swift
         296         92 2023-05-20 PlanetLite/AppUI.swift
        2593         90 <present>  Planet/Templates/WriterBasicPlaceholder.html
         367         88 <present>  Planet/Assets.xcassets/ENS.imageset/Contents.json
        1101         84 <present>  Planet/Labs/Published Folders/Dashboard/PFDashboardInspectorViewController.swift
        1025         78 2024-01-12 PlanetLite/AppSidebarViewController.swift
          94         76 <present>  Planet/en.lproj/InfoPlist.strings
        5212         76 <present>  Planet/Planet.xcdatamodeld/Planet v4.xcdatamodel/contents
         238         76 <present>  Planet.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
         904         75 <present>  PlanetLite/Assets.xcassets/AppIcon.appiconset/Contents.json
        1155         74 2022-06-26 Planet/PlanetWriterWindow.swift
        1095         70 <present>  Planet/Labs/Published Folders/Dashboard/PFDashboardSidebarViewController.swift
         323         68 <present>  Planet/Assets.xcassets/custom.twitter.symbolset/Contents.json
        1671         67 <present>  Planet/Planet.xcdatamodeld/Planet.xcdatamodel/contents
        3240         67 2023-01-13 Planet copy-Info.plist
        1047         63 <present>  Planet/TemplateBrowser/Window Controller/TBContentViewController.swift
         226         63 <present>  Planet.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings
         326         62 <present>  Planet/Assets.xcassets/custom.github.symbolset/Contents.json
        3013         61 <present>  Planet/Planet.xcdatamodeld/Planet v5.xcdatamodel/contents
          49         59 <present>  tools/monitor-ipfs-peers/README.md
        1074         59 <present>  Planet/Labs/Published Folders/Dashboard/PFDashboardViewController.swift
         695         53 <present>  PlanetLite/Assets.xcassets/SelectedFillColor.colorset/Contents.json
         695         53 <present>  Planet/Assets.xcassets/SelectedFillColor.colorset/Contents.json
         382         51 <present>  Planet/Assets.xcassets/WalletAppIconRainbow.imageset/Contents.json
          39         49 2024-01-30 .github/FUNDING.yml
        3011         44 <present>  Planet/Planet.xcdatamodeld/Planet v6.xcdatamodel/contents
         171         43 <present>  Planet/Assets.xcassets/custom.telegram.symbolset/Contents.json
          32         42 <present>  tools/monitor-ipfs-peers/.gitignore
        2437         42 <present>  Planet/Planet.xcdatamodeld/Planet v2.xcdatamodel/contents
        1798         40 <present>  Planet/IPFS/IPFSOpenView.swift
        2508         39 <present>  Planet/Planet.xcdatamodeld/Planet v3.xcdatamodel/contents
         164         36 <present>  Planet/Assets.xcassets/custom.mastodon.fill.symbolset/Contents.json
         695         34 <present>  Planet/Assets.xcassets/AccountBadgeBackgroundColorHover.colorset/Contents.json
         163         32 <present>  Planet/SharedAssets.xcassets/eth-logo.imageset/Contents.json
         163         31 <present>  Planet/SharedAssets.xcassets/arb-logo.imageset/Contents.json
         181         30 <present>  PlanetLite/en.lproj/Info.plist
        3343         30 <present>  Planet/Onboarding/OnboardingView.swift
         166         29 <present>  Planet/Assets.xcassets/custom.juicebox.symbolset/Contents.json
           8         26 <present>  .swift-version
         159         24 <present>  Planet/SharedAssets.xcassets/base-logo.imageset/Contents.json
         161         24 <present>  Planet/Assets.xcassets/custom.ens.symbolset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0099.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0098.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0097.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0096.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0095.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0094.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0093.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0091.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0090.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0081.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0080.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0079.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0078.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0077.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0076.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0075.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0074.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0072.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0071.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0070.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0069.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0068.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0067.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0066.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0065.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0064.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0062.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0061.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0060.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0052.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0051.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0050.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0048.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0047.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0046.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0045.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0044.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0043.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0042.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0041.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0040.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0038.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0037.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0036.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0035.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0034.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0033.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0032.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0031.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0030.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0028.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0027.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0026.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0025.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0024.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0023.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0022.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0020.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0019.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0018.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0017.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0016.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0015.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0014.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0013.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0012.imageset/Contents.json
         307         23 <present>  Planet/Avatars.xcassets/NSTG-0010.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0092.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0089.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0088.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0087.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0086.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0085.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0084.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0083.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0073.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0063.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0059.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0058.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0057.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0056.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0055.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0054.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0049.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0039.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0021.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0011.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0009.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0008.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0007.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0006.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0005.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0004.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0003.imageset/Contents.json
         307         22 <present>  Planet/Avatars.xcassets/NSTG-0002.imageset/Contents.json
          63         19 <present>  PlanetLite/Assets.xcassets/Contents.json
          63         19 <present>  Planet/SharedAssets.xcassets/Contents.json
          63         19 <present>  Planet/Preview Content/Preview Assets.xcassets/Contents.json
          63         19 <present>  Planet/Avatars.xcassets/Contents.json
          63         19 <present>  Planet/Assets.xcassets/Contents.json
```

`du -h`: size of a fresh clone:

```
8.0K	./Planet.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
 16K	./Planet.xcodeproj/project.xcworkspace/xcshareddata
 20K	./Planet.xcodeproj/project.xcworkspace
 12K	./Planet.xcodeproj/xcshareddata/xcschemes
 12K	./Planet.xcodeproj/xcshareddata
252K	./Planet.xcodeproj
 32K	./Planet/Quick Share
 72K	./Planet/Labs/Published Folders/Dashboard
112K	./Planet/Labs/Published Folders
 24K	./Planet/Labs/IPFS Status
4.0K	./Planet/Labs/dApps
4.8M	./Planet/Labs/Icon Gallery/Icons
4.8M	./Planet/Labs/Icon Gallery
4.0K	./Planet/Labs/Status Manager
8.0K	./Planet/Labs/Quick Post
 56K	./Planet/Labs/Wallet
5.0M	./Planet/Labs
 24K	./Planet/zh-Hans.lproj
 40K	./Planet/Settings
 16K	./Planet/en.lproj
 16K	./Planet/IPFS/Open Views/Window
 20K	./Planet/IPFS/Open Views
118M	./Planet/IPFS/go-ipfs-executables
118M	./Planet/IPFS
 76K	./Planet/SharedAssets.xcassets/op-logo.imageset
164K	./Planet/SharedAssets.xcassets/eth-logo.imageset
 32K	./Planet/SharedAssets.xcassets/multi.imageset
132K	./Planet/SharedAssets.xcassets/arb-logo.imageset
400K	./Planet/SharedAssets.xcassets/base-logo.imageset
808K	./Planet/SharedAssets.xcassets
4.0K	./Planet/Art
 24K	./Planet/Assets.xcassets/custom.ens.symbolset
116K	./Planet/Assets.xcassets/WalletAppIconMetaMask.imageset
 20K	./Planet/Assets.xcassets/custom.ethereum.symbolset
 32K	./Planet/Assets.xcassets/custom.telegram.symbolset
4.0K	./Planet/Assets.xcassets/BorderColor.colorset
4.0K	./Planet/Assets.xcassets/AccountBadgeBackgroundColor.colorset
132K	./Planet/Assets.xcassets/WalletAppIconRainbow.imageset
 32K	./Planet/Assets.xcassets/custom.juicebox.symbolset
 52K	./Planet/Assets.xcassets/custom.github.symbolset
4.0K	./Planet/Assets.xcassets/SelectedFillColor.colorset
668K	./Planet/Assets.xcassets/AppIcon.appiconset
4.0K	./Planet/Assets.xcassets/AccentColor.colorset
4.0K	./Planet/Assets.xcassets/AccountBadgeBackgroundColorHover.colorset
 76K	./Planet/Assets.xcassets/custom.mastodon.fill.symbolset
 20K	./Planet/Assets.xcassets/ENS.imageset
624K	./Planet/Assets.xcassets/AppIcon-Insider.appiconset
 44K	./Planet/Assets.xcassets/custom.twitter.symbolset
 68K	./Planet/Assets.xcassets/AppDataIcon-Fill.iconset
544K	./Planet/Assets.xcassets/AppDataIcon-Image.iconset
424K	./Planet/Assets.xcassets/AppIcon-Debug.appiconset
2.8M	./Planet/Assets.xcassets
 12K	./Planet/LegacyCoreData
4.0K	./Planet/Preview Content/Preview Assets.xcassets
4.0K	./Planet/Preview Content
 36K	./Planet/Key Manager
 20K	./Planet/Search
 20K	./Planet/Integrations
 76K	./Planet/Writer
 40K	./Planet/TemplateBrowser/Window Controller
104K	./Planet/TemplateBrowser
4.0K	./Planet/API
 20K	./Planet/Templates
4.0K	./Planet/Planet.xcdatamodeld/Planet v6.xcdatamodel
4.0K	./Planet/Planet.xcdatamodeld/Planet v3.xcdatamodel
4.0K	./Planet/Planet.xcdatamodeld/Planet v5.xcdatamodel
4.0K	./Planet/Planet.xcdatamodeld/Planet v2.xcdatamodel
4.0K	./Planet/Planet.xcdatamodeld/Planet v7.xcdatamodel
4.0K	./Planet/Planet.xcdatamodeld/Planet v4.xcdatamodel
4.0K	./Planet/Planet.xcdatamodeld/Planet.xcdatamodel
 32K	./Planet/Planet.xcdatamodeld
316K	./Planet/Fonts/CapsulesOTF
316K	./Planet/Fonts
 44K	./Planet/Avatars.xcassets/NSTG-0072.imageset
 56K	./Planet/Avatars.xcassets/NSTG-0073.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0005.imageset
 40K	./Planet/Avatars.xcassets/NSTG-0004.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0097.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0096.imageset
 40K	./Planet/Avatars.xcassets/NSTG-0078.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0079.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0031.imageset
 20K	./Planet/Avatars.xcassets/NSTG-0030.imageset
 60K	./Planet/Avatars.xcassets/NSTG-0046.imageset
 60K	./Planet/Avatars.xcassets/NSTG-0047.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0065.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0064.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0080.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0081.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0012.imageset
 48K	./Planet/Avatars.xcassets/NSTG-0013.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0026.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0027.imageset
 76K	./Planet/Avatars.xcassets/NSTG-0018.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0019.imageset
 64K	./Planet/Avatars.xcassets/NSTG-0051.imageset
 64K	./Planet/Avatars.xcassets/NSTG-0050.imageset
 60K	./Planet/Avatars.xcassets/NSTG-0062.imageset
 60K	./Planet/Avatars.xcassets/NSTG-0063.imageset
 48K	./Planet/Avatars.xcassets/NSTG-0015.imageset
 48K	./Planet/Avatars.xcassets/NSTG-0014.imageset
 40K	./Planet/Avatars.xcassets/NSTG-0087.imageset
 40K	./Planet/Avatars.xcassets/NSTG-0086.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0021.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0020.imageset
 20K	./Planet/Avatars.xcassets/NSTG-0068.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0069.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0056.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0057.imageset
 52K	./Planet/Avatars.xcassets/NSTG-0075.imageset
 56K	./Planet/Avatars.xcassets/NSTG-0074.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0090.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0091.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0002.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0003.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0036.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0037.imageset
 16K	./Planet/Avatars.xcassets/NSTG-0041.imageset
 16K	./Planet/Avatars.xcassets/NSTG-0040.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0008.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0009.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0025.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0024.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0089.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0088.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0052.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0053.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0066.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0067.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0058.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0059.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0083.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0082.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0011.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0010.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0032.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0033.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0045.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0044.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0038.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0039.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0071.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0070.imageset
 40K	./Planet/Avatars.xcassets/NSTG-0006.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0007.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0094.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0095.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0035.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0034.imageset
 16K	./Planet/Avatars.xcassets/NSTG-0042.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0043.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0099.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0098.imageset
 40K	./Planet/Avatars.xcassets/NSTG-0076.imageset
 40K	./Planet/Avatars.xcassets/NSTG-0077.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0093.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0092.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0001.imageset
 60K	./Planet/Avatars.xcassets/NSTG-0048.imageset
 64K	./Planet/Avatars.xcassets/NSTG-0049.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0022.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0023.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0055.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0054.imageset
 60K	./Planet/Avatars.xcassets/NSTG-0061.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0060.imageset
 20K	./Planet/Avatars.xcassets/NSTG-0028.imageset
 20K	./Planet/Avatars.xcassets/NSTG-0029.imageset
 72K	./Planet/Avatars.xcassets/NSTG-0016.imageset
 72K	./Planet/Avatars.xcassets/NSTG-0017.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0084.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0085.imageset
3.5M	./Planet/Avatars.xcassets
 44K	./Planet/Views/Sidebar
4.0K	./Planet/Views/Modifiers
 12K	./Planet/Views/Create & Follow Planet
4.0K	./Planet/Views/Plausible
 76K	./Planet/Views/Articles
4.0K	./Planet/Views/Saver
 40K	./Planet/Views/Components
132K	./Planet/Views/My
 16K	./Planet/Views/Following
4.0K	./Planet/Views/Onboarding
344K	./Planet/Views
 44K	./Planet/Downloads
132K	./Planet/Helper
384K	./Planet/Entities
132M	./Planet
 20K	./tools/monitor-ipfs-peers
 20K	./tools
4.9M	./Screenshots
4.0K	./git-hooks
4.0K	./PlanetLite/en.lproj
4.0K	./PlanetLite/Assets.xcassets/BorderColor.colorset
132K	./PlanetLite/Assets.xcassets/AppIcon-Croptop.appiconset
4.0K	./PlanetLite/Assets.xcassets/SelectedFillColor.colorset
4.0K	./PlanetLite/Assets.xcassets/AppIcon.appiconset
4.0K	./PlanetLite/Assets.xcassets/AccentColor.colorset
 68K	./PlanetLite/Assets.xcassets/AppDataIcon-Fill.iconset
172K	./PlanetLite/Assets.xcassets/AppDataIcon-Image.iconset
392K	./PlanetLite/Assets.xcassets
 16K	./PlanetLite/Croptop
492K	./PlanetLite
 12K	./Technotes/Releases
1.2M	./Technotes/Images
1.2M	./Technotes
 32K	./.github/workflows
 32K	./.github
401M	./.git/objects/pack
  0B	./.git/objects/info
401M	./.git/objects
4.0K	./.git/info
4.0K	./.git/logs/refs/heads
4.0K	./.git/logs/refs/remotes/origin
4.0K	./.git/logs/refs/remotes
8.0K	./.git/logs/refs
 12K	./.git/logs
 76K	./.git/hooks
4.0K	./.git/refs/heads
  0B	./.git/refs/tags
4.0K	./.git/refs/remotes/origin
4.0K	./.git/refs/remotes
8.0K	./.git/refs
  0B	./.git/lfs/incomplete
 59M	./.git/lfs/objects/97/11
 59M	./.git/lfs/objects/97
 58M	./.git/lfs/objects/aa/37
 58M	./.git/lfs/objects/aa
117M	./.git/lfs/objects
  0B	./.git/lfs/tmp
117M	./.git/lfs
518M	./.git
657M	.
```

Run this command to strip the largest IPFS files that are not in LFS:

```
git filter-repo \
--path Planet/IPFS/go-ipfs-executables/ipfs-amd64 \
--path Planet/IPFS/go-ipfs-executables/ipfs-arm64 \
--path Planet/Assets.xcassets/IPFS-GO.dataset/ipfs \
--path Planet/Assets.xcassets/IPFS-GO-ARM.dataset/ipfs \
--path Planet/IPFS/ipfs-executables/ipfs-amd64-0.28.bin \
--path Planet/IPFS/go-ipfs-executables/ipfs-amd64-0.28.bin \
--path Planet/IPFS/ipfs-executables/ipfs-arm64-0.28.bin \
--path Planet/IPFS/go-ipfs-executables/ipfs-arm64-0.28.bin \
--path Planet/IPFS/go-ipfs-executables/ipfs-amd64.bin \
--path Planet/IPFS/go-ipfs-executables/ipfs-arm64.bin \
--invert-paths
```

`du -h`: after running that command:

```
8.0K	./Planet.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
 16K	./Planet.xcodeproj/project.xcworkspace/xcshareddata
 20K	./Planet.xcodeproj/project.xcworkspace
 12K	./Planet.xcodeproj/xcshareddata/xcschemes
 12K	./Planet.xcodeproj/xcshareddata
252K	./Planet.xcodeproj
 32K	./Planet/Quick Share
 72K	./Planet/Labs/Published Folders/Dashboard
112K	./Planet/Labs/Published Folders
 24K	./Planet/Labs/IPFS Status
4.0K	./Planet/Labs/dApps
4.8M	./Planet/Labs/Icon Gallery/Icons
4.8M	./Planet/Labs/Icon Gallery
4.0K	./Planet/Labs/Status Manager
8.0K	./Planet/Labs/Quick Post
 56K	./Planet/Labs/Wallet
5.0M	./Planet/Labs
 24K	./Planet/zh-Hans.lproj
 40K	./Planet/Settings
 16K	./Planet/en.lproj
 16K	./Planet/IPFS/Open Views/Window
 20K	./Planet/IPFS/Open Views
118M	./Planet/IPFS/go-ipfs-executables
118M	./Planet/IPFS
 76K	./Planet/SharedAssets.xcassets/op-logo.imageset
164K	./Planet/SharedAssets.xcassets/eth-logo.imageset
 32K	./Planet/SharedAssets.xcassets/multi.imageset
132K	./Planet/SharedAssets.xcassets/arb-logo.imageset
400K	./Planet/SharedAssets.xcassets/base-logo.imageset
808K	./Planet/SharedAssets.xcassets
4.0K	./Planet/Art
 24K	./Planet/Assets.xcassets/custom.ens.symbolset
116K	./Planet/Assets.xcassets/WalletAppIconMetaMask.imageset
 20K	./Planet/Assets.xcassets/custom.ethereum.symbolset
 32K	./Planet/Assets.xcassets/custom.telegram.symbolset
4.0K	./Planet/Assets.xcassets/BorderColor.colorset
4.0K	./Planet/Assets.xcassets/AccountBadgeBackgroundColor.colorset
132K	./Planet/Assets.xcassets/WalletAppIconRainbow.imageset
 32K	./Planet/Assets.xcassets/custom.juicebox.symbolset
 52K	./Planet/Assets.xcassets/custom.github.symbolset
4.0K	./Planet/Assets.xcassets/SelectedFillColor.colorset
668K	./Planet/Assets.xcassets/AppIcon.appiconset
4.0K	./Planet/Assets.xcassets/AccentColor.colorset
4.0K	./Planet/Assets.xcassets/AccountBadgeBackgroundColorHover.colorset
 76K	./Planet/Assets.xcassets/custom.mastodon.fill.symbolset
 20K	./Planet/Assets.xcassets/ENS.imageset
624K	./Planet/Assets.xcassets/AppIcon-Insider.appiconset
 44K	./Planet/Assets.xcassets/custom.twitter.symbolset
 68K	./Planet/Assets.xcassets/AppDataIcon-Fill.iconset
544K	./Planet/Assets.xcassets/AppDataIcon-Image.iconset
424K	./Planet/Assets.xcassets/AppIcon-Debug.appiconset
2.8M	./Planet/Assets.xcassets
 12K	./Planet/LegacyCoreData
4.0K	./Planet/Preview Content/Preview Assets.xcassets
4.0K	./Planet/Preview Content
 36K	./Planet/Key Manager
 20K	./Planet/Search
 20K	./Planet/Integrations
 76K	./Planet/Writer
 40K	./Planet/TemplateBrowser/Window Controller
104K	./Planet/TemplateBrowser
4.0K	./Planet/API
 20K	./Planet/Templates
4.0K	./Planet/Planet.xcdatamodeld/Planet v6.xcdatamodel
4.0K	./Planet/Planet.xcdatamodeld/Planet v3.xcdatamodel
4.0K	./Planet/Planet.xcdatamodeld/Planet v5.xcdatamodel
4.0K	./Planet/Planet.xcdatamodeld/Planet v2.xcdatamodel
4.0K	./Planet/Planet.xcdatamodeld/Planet v7.xcdatamodel
4.0K	./Planet/Planet.xcdatamodeld/Planet v4.xcdatamodel
4.0K	./Planet/Planet.xcdatamodeld/Planet.xcdatamodel
 32K	./Planet/Planet.xcdatamodeld
316K	./Planet/Fonts/CapsulesOTF
316K	./Planet/Fonts
 44K	./Planet/Avatars.xcassets/NSTG-0072.imageset
 56K	./Planet/Avatars.xcassets/NSTG-0073.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0005.imageset
 40K	./Planet/Avatars.xcassets/NSTG-0004.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0097.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0096.imageset
 40K	./Planet/Avatars.xcassets/NSTG-0078.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0079.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0031.imageset
 20K	./Planet/Avatars.xcassets/NSTG-0030.imageset
 60K	./Planet/Avatars.xcassets/NSTG-0046.imageset
 60K	./Planet/Avatars.xcassets/NSTG-0047.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0065.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0064.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0080.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0081.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0012.imageset
 48K	./Planet/Avatars.xcassets/NSTG-0013.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0026.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0027.imageset
 76K	./Planet/Avatars.xcassets/NSTG-0018.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0019.imageset
 64K	./Planet/Avatars.xcassets/NSTG-0051.imageset
 64K	./Planet/Avatars.xcassets/NSTG-0050.imageset
 60K	./Planet/Avatars.xcassets/NSTG-0062.imageset
 60K	./Planet/Avatars.xcassets/NSTG-0063.imageset
 48K	./Planet/Avatars.xcassets/NSTG-0015.imageset
 48K	./Planet/Avatars.xcassets/NSTG-0014.imageset
 40K	./Planet/Avatars.xcassets/NSTG-0087.imageset
 40K	./Planet/Avatars.xcassets/NSTG-0086.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0021.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0020.imageset
 20K	./Planet/Avatars.xcassets/NSTG-0068.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0069.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0056.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0057.imageset
 52K	./Planet/Avatars.xcassets/NSTG-0075.imageset
 56K	./Planet/Avatars.xcassets/NSTG-0074.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0090.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0091.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0002.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0003.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0036.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0037.imageset
 16K	./Planet/Avatars.xcassets/NSTG-0041.imageset
 16K	./Planet/Avatars.xcassets/NSTG-0040.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0008.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0009.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0025.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0024.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0089.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0088.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0052.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0053.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0066.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0067.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0058.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0059.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0083.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0082.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0011.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0010.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0032.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0033.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0045.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0044.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0038.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0039.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0071.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0070.imageset
 40K	./Planet/Avatars.xcassets/NSTG-0006.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0007.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0094.imageset
 32K	./Planet/Avatars.xcassets/NSTG-0095.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0035.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0034.imageset
 16K	./Planet/Avatars.xcassets/NSTG-0042.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0043.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0099.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0098.imageset
 40K	./Planet/Avatars.xcassets/NSTG-0076.imageset
 40K	./Planet/Avatars.xcassets/NSTG-0077.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0093.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0092.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0001.imageset
 60K	./Planet/Avatars.xcassets/NSTG-0048.imageset
 64K	./Planet/Avatars.xcassets/NSTG-0049.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0022.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0023.imageset
 28K	./Planet/Avatars.xcassets/NSTG-0055.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0054.imageset
 60K	./Planet/Avatars.xcassets/NSTG-0061.imageset
 24K	./Planet/Avatars.xcassets/NSTG-0060.imageset
 20K	./Planet/Avatars.xcassets/NSTG-0028.imageset
 20K	./Planet/Avatars.xcassets/NSTG-0029.imageset
 72K	./Planet/Avatars.xcassets/NSTG-0016.imageset
 72K	./Planet/Avatars.xcassets/NSTG-0017.imageset
 36K	./Planet/Avatars.xcassets/NSTG-0084.imageset
 44K	./Planet/Avatars.xcassets/NSTG-0085.imageset
3.5M	./Planet/Avatars.xcassets
 44K	./Planet/Views/Sidebar
4.0K	./Planet/Views/Modifiers
 12K	./Planet/Views/Create & Follow Planet
4.0K	./Planet/Views/Plausible
 76K	./Planet/Views/Articles
4.0K	./Planet/Views/Saver
 40K	./Planet/Views/Components
132K	./Planet/Views/My
 16K	./Planet/Views/Following
4.0K	./Planet/Views/Onboarding
344K	./Planet/Views
 44K	./Planet/Downloads
132K	./Planet/Helper
384K	./Planet/Entities
132M	./Planet
 20K	./tools/monitor-ipfs-peers
 20K	./tools
4.9M	./Screenshots
4.0K	./git-hooks
4.0K	./PlanetLite/en.lproj
4.0K	./PlanetLite/Assets.xcassets/BorderColor.colorset
132K	./PlanetLite/Assets.xcassets/AppIcon-Croptop.appiconset
4.0K	./PlanetLite/Assets.xcassets/SelectedFillColor.colorset
4.0K	./PlanetLite/Assets.xcassets/AppIcon.appiconset
4.0K	./PlanetLite/Assets.xcassets/AccentColor.colorset
 68K	./PlanetLite/Assets.xcassets/AppDataIcon-Fill.iconset
172K	./PlanetLite/Assets.xcassets/AppDataIcon-Image.iconset
392K	./PlanetLite/Assets.xcassets
 16K	./PlanetLite/Croptop
492K	./PlanetLite
 12K	./Technotes/Releases
1.2M	./Technotes/Images
1.2M	./Technotes
 32K	./.github/workflows
 32K	./.github
232K	./.git/filter-repo
 64M	./.git/objects/pack
4.0K	./.git/objects/info
 64M	./.git/objects
252K	./.git/info
  0B	./.git/logs/refs/heads
  0B	./.git/logs/refs/remotes
  0B	./.git/logs/refs
  0B	./.git/logs
 76K	./.git/hooks
  0B	./.git/refs/heads
  0B	./.git/refs/tags
  0B	./.git/refs/remotes
  0B	./.git/refs/replace
  0B	./.git/refs
  0B	./.git/lfs/incomplete
 59M	./.git/lfs/objects/97/11
 59M	./.git/lfs/objects/97
 58M	./.git/lfs/objects/aa/37
 58M	./.git/lfs/objects/aa
117M	./.git/lfs/objects
  0B	./.git/lfs/tmp
117M	./.git/lfs
182M	./.git
321M	.
```