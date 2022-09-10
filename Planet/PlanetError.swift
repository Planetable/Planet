enum PlanetError: Error {
    case PersistenceError
    case NetworkError
    case IPFSError
    case EthereumError
    case PlanetFeedError
    case PlanetExistsError
    case MissingTemplateError
    case AvatarError
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
    case InternalError
    case UnknownError(Error)
}
