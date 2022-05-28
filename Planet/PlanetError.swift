//
// PlanetError.swift
//
//
// Created by Shu Lyu on 2022-04-07.
//

enum PlanetError: Error {
    case NetworkError
    case IPFSError
    case EthereumError
    case PlanetFeedError
    case FollowLocalPlanetError
    case FollowExistingPlanetError
    case FollowPlanetVerifyError
    case InvalidPlanetURLError
    case InternalError
    case UnknownError(Error)
}
