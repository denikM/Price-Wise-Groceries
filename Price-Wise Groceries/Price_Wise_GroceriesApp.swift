//
//  Price_Wise_GroceriesApp.swift
//  Price-Wise Groceries
//
//  Created by Denis Matiichine on 2024-11-15.
//

import SwiftUI
import SwiftData

@main
struct Price_Wise_GroceriesApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
