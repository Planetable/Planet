import Foundation


enum PlanetError: Error {
    case PersistenceError
    case NetworkError
    case IPFSError
    case EthereumError
    case PlanetFeedError
    case PlanetExistsError
    case PlanetNotExistsError
    case MissingTemplateError
    case MissingPlanetKeyError
    case AvatarError
    case PodcastCoverArtError
    case ImportPlanetError
    case ExportPlanetError
    case FileExistsError
    case FollowLocalPlanetError
    case FollowPlanetVerifyError
    case InvalidPlanetURLError
    case ENSNoContentHashError
    case DotBitNoDWebRecordError
    case DotBitIPNSResolveError
    case RenderMarkdownError
    case PublishedServiceFolderUnchangedError
    case PublishedServiceFolderPermissionError
    case MovePublishingPlanetArticleError
    case WalletConnectV2ProjectIDMissingError
    case PublicAPIError
    case KeyManagerSavingKeyError
    case KeyManagerLoadingKeyError
    case KeyManagerDeletingKeyError
    case KeyManagerGeneratingKeyError
    case KeyManagerImportingKeyError
    case KeyManagerImportingKeyExistsError
    case KeyManagerExportingKeyExistsError
    case InternalError
    case UnknownError(Error)
}


extension PlanetError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .PersistenceError:
            return NSLocalizedString("Persistence Error", comment: "")
        case .NetworkError:
            return NSLocalizedString("Network Error", comment: "")
        case .IPFSError:
            return NSLocalizedString("IPFS Error", comment: "")
        case .EthereumError:
            return NSLocalizedString("Ethereum Error", comment: "")
        case .PlanetFeedError:
            return NSLocalizedString("Planet Feed Error", comment: "")
        case .PlanetExistsError:
            return NSLocalizedString("Planet Exists Error", comment: "")
        case .PlanetNotExistsError:
            return NSLocalizedString("Planet Not Exists Error", comment: "")
        case .MissingTemplateError:
            return NSLocalizedString("Missing Template Error", comment: "")
        case .MissingPlanetKeyError:
            return NSLocalizedString("Missing Planet Key Error", comment: "")
        case .AvatarError:
            return NSLocalizedString("Avatar Error", comment: "")
        case .PodcastCoverArtError:
            return NSLocalizedString("Podcast Cover Art Error", comment: "")
        case .ImportPlanetError:
            return NSLocalizedString("Import Planet Error", comment: "")
        case .ExportPlanetError:
            return NSLocalizedString("Export Planet Error", comment: "")
        case .FileExistsError:
            return NSLocalizedString("File Exists Error", comment: "")
        case .FollowLocalPlanetError:
            return NSLocalizedString("Follow Local Planet Error", comment: "")
        case .FollowPlanetVerifyError:
            return NSLocalizedString("Follow Planet Verify Error", comment: "")
        case .InvalidPlanetURLError:
            return NSLocalizedString("Invalid Planet URL Error", comment: "")
        case .ENSNoContentHashError:
            return NSLocalizedString("ENS No Content Hash Error", comment: "")
        case .DotBitNoDWebRecordError:
            return NSLocalizedString("DotBit No DWeb Record Error", comment: "")
        case .DotBitIPNSResolveError:
            return NSLocalizedString("DotBit IPNS Resolve Error", comment: "")
        case .RenderMarkdownError:
            return NSLocalizedString("Render Markdown Error", comment: "")
        case .PublishedServiceFolderUnchangedError:
            return NSLocalizedString("Published Service Folder Unchanged Error", comment: "")
        case .PublishedServiceFolderPermissionError:
            return NSLocalizedString("Published Service Folder Permission Error", comment: "")
        case .MovePublishingPlanetArticleError:
            return NSLocalizedString("Move Publishing Planet Article Error", comment: "")
        case .WalletConnectV2ProjectIDMissingError:
            return NSLocalizedString("Wallet Connect V2 Project ID Missing Error", comment: "")
        case .PublicAPIError:
            return NSLocalizedString("Public API Error", comment: "")
        case .KeyManagerSavingKeyError:
            return NSLocalizedString("Key Manager Saving Key Error", comment: "")
        case .KeyManagerLoadingKeyError:
            return NSLocalizedString("Key Manager Loading Key Error", comment: "")
        case .KeyManagerDeletingKeyError:
            return NSLocalizedString("Key Manager Deleting Key Error", comment: "")
        case .KeyManagerGeneratingKeyError:
            return NSLocalizedString("Key Manager Generating Key Error", comment: "")
        case .KeyManagerImportingKeyError:
            return NSLocalizedString("Key Manager Importing Key Error", comment: "")
        case .KeyManagerImportingKeyExistsError:
            return NSLocalizedString("Key Manager Importing Key Exists Error", comment: "")
        case .KeyManagerExportingKeyExistsError:
            return NSLocalizedString("Key Manager Exporting Key Exists Error", comment: "")
        case .InternalError:
            return NSLocalizedString("Internal Error", comment: "")
        case .UnknownError(let error):
            return error.localizedDescription
        }
    }
}
