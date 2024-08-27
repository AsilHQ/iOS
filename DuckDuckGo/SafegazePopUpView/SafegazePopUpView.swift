//
//  AutocompleteView.swift
//  Kahf Browser
//
//  Copyright © 2024 Kahf Browser. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import SwiftUI
import WebKit

struct SafegazePopUpView: View {
    @State var isOpened: Bool
    @State var value: Float = 0.1
    @State var url: URL?
    @State var lifetimeAvoidedContentCount: Int = 2
    var updateView: (() -> Void)?
    var updateBlurIntensity: (() -> Void)?
    var shieldsSettingsChanged: (() -> Void)?
    var tab: Tab 
    
    var body: some View {
        VStack {
            SafegazeView(value: $value, isOn: $isOpened, url: url, domainAvoidedContentCount: 100, lifetimeAvoidedContentCount: lifetimeAvoidedContentCount)
        }
        .cornerRadius(20)
        .shadow(color: Color(red: 0.09, green: 0.12, blue: 0.27).opacity(0.08), radius: 20, x: 0, y: 8)
        .onChange(of: isOpened) { newValue in
            updateSafegaze(isOpened: newValue)
            shieldsSettingsChanged?()
            updateView?()
        }
        .onChange(of: value) { newValue in
            value = newValue
        }
        .onDisappear() {
//            Preferences.Safegaze.blurIntensity.value = value
            if isOpened {
                updateBlurIntensity?()
            }
        }
    }
    
    func updateSafegaze(isOpened: Bool) {
        guard let url = url else { return }
//        Domain.setSafegaze(
//            forUrl: url,
//            isOn: isOpened,
//            isPrivateBrowsing: PrivateBrowsingManager.shared.isPrivateBrowsing
//        )
    }
    
    @MainActor static func redirect(url: URL?, updateView: (() -> Void)?, updateBlurIntensity: (() -> Void)?, shieldsSettingsChanged: (() -> Void)?, tab: Tab) -> UIView {
        let popupView = SafegazePopUpView(isOpened: true, url: url, updateView: updateView, updateBlurIntensity: updateBlurIntensity, shieldsSettingsChanged: shieldsSettingsChanged, tab: tab)
        return UIHostingController(rootView: popupView).view
        
    }
}

//#if DEBUG
//struct SafegazePopUpView_Previews: PreviewProvider {
//    static var previews: some View {
//        SafegazePopUpView(isOpened: true, tab: Tab(configuration: WKWebViewConfiguration()))
//    }
//}
//#endif
