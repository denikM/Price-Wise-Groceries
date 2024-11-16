//
//  DataModels.swift
//  Price-Wise Groceries
//
//  Created by Denis Matiichine on 2024-11-16.
//

import Foundation

struct APIResponse: Decodable {
    let status: String
    let object: APIObject?
}

struct APIObject: Decodable {
    let responseStatusCode: Int
    let productId: Int
    let coordinate: String
    let vectorId: Int
    let vectorDataPoint: [VectorDataPoint]
}

struct VectorDataPoint: Decodable {
    let refPer: String
    let refPer2: String?
    let refPerRaw: String
    let refPerRaw2: String?
    let value: Double
    let decimals: Int
    let scalarFactorCode: Int
    let symbolCode: Int
    let statusCode: Int
    let securityLevelCode: Int
    let releaseTime: String
    let frequencyCode: Int
}

struct SeriesInfoResponse: Decodable {
    let status: String
    let object: SeriesInfoObject?
}

struct SeriesInfoObject: Decodable {
    let responseStatusCode: Int
    let productId: Int
    let coordinate: String
    let vectorId: Int
    let frequencyCode: Int
    let scalarFactorCode: Int
    let decimals: Int
    let terminated: Int
    let SeriesTitleEn: String
    let SeriesTitleFr: String
    let memberUomCode: Int?
}
