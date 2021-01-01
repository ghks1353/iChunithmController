//
//  AppDelegate.swift
//  iChunithmController
//
//  Created by Seru on 2021/01/01.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		return true
	}

	// MARK: UISceneSession Lifecycle

	func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
		
		let conf = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
		conf.delegateClass = SceneDelegate.self
		
		return conf
	}

}

