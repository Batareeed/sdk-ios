//
//  Repository.swift
//  Example
//
//  Created by Ryan Davis on 4/8/20.
//  Copyright © 2020 Afterpay. All rights reserved.
//

import Afterpay
import Foundation
import os.log

final class Repository {
  private let apiClient: APIClient
  private let userDefaults: UserDefaults
  private let now: () -> Date

  static let shared = Repository(apiClient: .live, userDefaults: .standard, now: Date.init)

  init(apiClient: APIClient, userDefaults: UserDefaults, now: @escaping () -> Date) {
    self.apiClient = apiClient
    self.userDefaults = userDefaults
    self.now = now
  }

  func checkout(
    email: String,
    amount: String,
    completion: @escaping (Result<URL, Error>) -> Void
  ) {
    apiClient.checkout(email, amount) { result in
      completion(result.flatMap { data in
        do {
          let response = try JSONDecoder().decode(CheckoutsResponse.self, from: data)
          return .success(response.url)
        } catch {
          return .failure(error)
        }
      })
    }
  }

  func fetchConfiguration(completion: @escaping (Result<Configuration, Error>) -> Void) {
    getCachedOrRemoteConfiguration { result in
      completion(result.flatMap { data in
        do {
          let response = try JSONDecoder().decode(ConfigurationResponse.self, from: data)
          let configuration = try Configuration(
            minimumAmount: response.minimumAmount?.amount,
            maximumAmount: response.maximumAmount.amount,
            currencyCode: response.maximumAmount.currency
          )
          return .success(configuration)
        } catch {
          return .failure(error)
        }
      })
    }
  }

  private func getCachedOrRemoteConfiguration(completion: @escaping APIClient.Completion) {
    if let configuration = userDefaults.configuration, shouldUseCachedConfiguration {
      return completion(.success(configuration))
    }

    apiClient.configuration { result in
      if case .success(let response) = result {
        self.userDefaults.configuration = response
        self.userDefaults.lastFetchDate = self.now()
      }
      completion(result)
    }
  }

  private var shouldUseCachedConfiguration: Bool {
    guard let fetchDate = userDefaults.lastFetchDate else {
      return false
    }
    return now().timeIntervalSince(fetchDate) < .oneDay
  }
}

private extension UserDefaults {
  var configuration: Data? {
    get { data(forKey: #function) }
    set { set(newValue, forKey: #function) }
  }

  var lastFetchDate: Date? {
    get { object(forKey: #function) as? Date }
    set { set(newValue, forKey: #function) }
  }
}

private extension TimeInterval {
  static var oneDay: Self { 60 * 60 * 24 }
}
