//
//  Neurise_Project_appApp.swift
//  Neurise_Project_app
//
//  Created by 황기성 on 5/14/26.
//

import SwiftUI

@main
struct Neurise_Project_appApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
        }
    }
}
