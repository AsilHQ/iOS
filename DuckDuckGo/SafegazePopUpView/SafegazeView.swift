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

enum SafeInternet: String {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
    
    var color: Color {
        switch self {
        case .high:
            return Color(red: 57 / 255, green: 182 / 255, blue: 53 / 255, opacity: 1)
        case .medium:
            return Color(red: 255 / 255, green: 170 / 255, blue: 70 / 255, opacity: 1)
        case .low:
            return Color(red: 254 / 255, green: 16 / 255, blue: 42 / 255, opacity: 1)
        }
    }
    
    var title: String {
        switch self {
        case .high:
            return "HIGH"
        case .medium:
            return "MEDIUM"
        case .low:
            return "LOW"
        }
    }
    
    var text: String {
        switch self {
        case .high:
            return "Safe search + kids friendly youtube. Block ads + trackers + harmful websites + adult contents"
        case .medium:
            return "Harmful Website + Block Ads + Safe Search"
        case .low:
            return "Harmful Websites + Block Ads only"
        }
    }
}

enum DecentInternet {
    case fullImage
    case humanOnly
}

struct SafegazeView: View {
    @State var safeInternet: SafeInternet = (SafeInternet(rawValue: AppUserDefaults().safegazeModeValue) ?? .high)
    @State var decentInternet: DecentInternet = .fullImage
    @AppStorage("com.duckduckgo.ios.safegazeOn") private var safegazeOn: Bool = AppUserDefaults().safegazeOn
    @AppStorage("com.duckduckgo.ios.decentInternetOn") private var isDecentInternetOn: Bool = AppUserDefaults().decentInternetOn
    @AppStorage("com.duckduckgo.ios.blockedTrackersCount") private var blockedTrackersCount: Int = AppUserDefaults().blockedTrackersCount
    @AppStorage("com.duckduckgo.ios.safegazeBlurredImageCount") private var safegazeBlurredImageCount: Int = AppUserDefaults().safegazeBlurredImageCount
    @AppStorage("com.duckduckgo.ios.safegazeModeValue") private var safegazeModeValue: String = AppUserDefaults().safegazeModeValue
    
    @State private var selection: Int = 0
    @State private var isShareSheetPresented: Bool = false
    var tab: Tab
    
    let gray130 = Color(red: 130 / 255, green: 130 / 255, blue: 130 / 255, opacity: 1)
    let green = Color(red: 57 / 255, green: 182 / 255, blue: 53 / 255, opacity: 1)
    let black = Color(red: 34 / 255, green: 34 / 255, blue: 34 / 255, opacity: 1)
    let red = Color(red: 254 / 255, green: 16 / 255, blue: 42 / 255, opacity: 1)
    
    var safegazeSettingsChanged: (() -> Void)?
    var openShareSheet: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 10) {
            headerSection
            if safegazeOn {
                horizontalDivider
                saferInternetSection
            }
            horizontalDivider
            decentInternetSection
            horizontalDivider
            harmAvoidedSection
            horizontalDivider
            footerSection
        }
        .padding(.top)
        .padding(.horizontal, 20)
        .onChange(of: safegazeOn, perform: { _ in
            safegazeSettingsChanged?()
            NotificationCenter.default.post(name: AppUserDefaults.Notifications.textSizeChange, object: self)
        })
        .onChange(of: isDecentInternetOn, perform: { _ in
            safegazeSettingsChanged?()
            NotificationCenter.default.post(name: AppUserDefaults.Notifications.textSizeChange, object: self)
        })
        .onChange(of: safeInternet, perform: { value in
            safegazeModeValue = value.rawValue
            safegazeSettingsChanged?()
            NotificationCenter.default.post(name: AppUserDefaults.Notifications.textSizeChange, object: self)
        })
    }

    var horizontalDivider: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(Color.black)
            .opacity(0.1)
    }
    
    var verticalDivider: some View {
        Rectangle()
            .frame(width: 1, height: 41)
            .foregroundColor(Color.black)
            .opacity(0.1)
    }
    
    var headerSection: some View {
        HStack {
            Image(.kahfGuard)
                .resizable()
                .frame(width: 137, height: 31)
                .foregroundColor(Color(designSystemColor: .textPrimary))

            Spacer()
            HStack(spacing: 5) {
                Text("On/Off")
                    .foregroundColor(gray130)
                    .font(FontHelper.lato(size: 14))
                
                Toggle(isOn: $safegazeOn) {}
                    .controlSize(.mini)
                    .scaleEffect(0.7)
                    .labelsHidden()
                    .foregroundColor(Color(red: 57 / 255, green: 182 / 255, blue: 53 / 255, opacity: 1))
            }
        }.frame(maxWidth: .infinity)
    }
    
    var saferInternetSection: some View {
        sectionView(title: "Safer Internet") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    saferInternetButton(mode: .high)
                    saferInternetButton(mode: .medium)
                    saferInternetButton(mode: .low)
                }.padding(.top, 10)
                
                infoTextBox(text: safeInternet.text, backgroundColor: safeInternet.color.opacity(0.1))
            }
        }
    }
    
    var decentInternetSection: some View {
            VStack(spacing: 0) {
                HStack {
                    VStack(spacing: 10) {
                        HStack {
                            sectionTitle("Decent Internet")
                            Spacer()
                            HStack(spacing: 5) {
                                Text("On/Off")
                                    .foregroundColor(gray130)
                                    .font(FontHelper.lato(size: 10))
                                
                                
                                Toggle(isOn: $isDecentInternetOn) {}
                                    .controlSize(.mini)
                                    .scaleEffect(0.5)
                                    .labelsHidden()
                                    .foregroundColor(Color(red: 57 / 255, green: 182 / 255, blue: 53 / 255, opacity: 1))
                            }
                        }.frame(height: 20)
                        
                        HStack {
                            VStack {
                                sectionSubtitle("Blur indecent photos. Avoid major sins.").frame(width: 150)
                                Spacer()
                            }
                            Spacer()
                            imageViewColumn(image: "KahfFullImage")
                        }.frame(height: 80)
                    }
                }
            }.frame(height: 100)
    }
    
    
    var harmAvoidedSection: some View {
        sectionView(title: "Harm Avoided") {
            HStack {
                harmAvoidedColumn(number: "\(AppUserDefaults().safegazeHarmfulSites)", label: "Harmful Sites")
                Spacer()
                verticalDivider
                Spacer()
                harmAvoidedColumn(number: "\(AppUserDefaults().safegazeBlurredImageCount)", label: "Indecent Pictures")
                Spacer()
                verticalDivider
                Spacer()
                harmAvoidedColumn(number: "\(AppUserDefaults().blockedTrackersCount)", label: "Ads + Trackers")
            }.frame(maxWidth: .infinity)
        }
    }
    
    var footerSection: some View {
        HStack {
            footerButton(icon: "KahfShare", title: "Share") {
                openShareSheet?()
            }
            Spacer()
            footerButton(icon: "KahfSupport", title: "Support") {
                guard let url = URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSeaW7PjI-K3yqZZ4gpuXbbx5qOFxAwILLy5uy7PTerXfdzFqw/viewform") else { return }
                UIApplication.shared.open(url)
            }
        }
        .padding(.horizontal, 70)
        .padding(.top, 5)
        .padding(.bottom, 10)
    }

    // MARK: - Reusable Components
    
    func sectionView<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            sectionTitle(title)
            content()
        }
    }
    
    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(FontHelper.poppins(size: 18, weight: .bold))
            .foregroundColor(Color(designSystemColor: .textPrimary))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    func sectionSubtitle(_ subtitle: String) -> some View {
        Text(subtitle)
            .font(FontHelper.lato(size: 13, weight: .regular))
            .foregroundColor(Color(designSystemColor: .textPrimary))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func imageViewColumn(image: String) -> some View {
        Image(image)
            .resizable()
            .frame(width: 80, height: 80)
            .cornerRadius(6)
            .foregroundColor(.black)
    }
    
    func harmAvoidedColumn(number: String, label: String) -> some View {
        VStack(alignment: .leading) {
            Text(number)
                .font(FontHelper.poppins(size: 24, weight: .bold))
                .foregroundColor(Color(designSystemColor: .textPrimary))
            Text(label)
                .font(FontHelper.lato(size: 13))
                .foregroundColor(gray130)
        }
    }

    func footerButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
        }, label: {
            VStack(spacing: 5) {
                Image(icon)
                    .frame(width: 20, height: 20)
                    .tint(Color(designSystemColor: .textPrimary))
                Text(title)
                    .font(FontHelper.lato(size: 12))
                    .foregroundColor(Color(designSystemColor: .textPrimary))
            }
        })
        .frame(width: 50)
    }

    func infoTextBox(text: String, backgroundColor: Color) -> some View {
        Text(text)
            .multilineTextAlignment(.leading)
            .font(FontHelper.lato(size: 14))
            .foregroundColor(Color(designSystemColor: .textPrimary))
            .padding(.horizontal, 14.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 60)
            .background(backgroundColor)
            .cornerRadius(10)
    }
    
    func saferInternetButton(mode: SafeInternet) -> some View {
        Button(action: {
            safeInternet = mode
            AppUserDefaults().safegazeModeValue = mode.rawValue
        }, label: {
            ZStack {
                Text(mode.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .frame(height: 42)
                    .frame(minWidth: 80, maxWidth: 100)
                    .background(safeInternet == mode ? mode.color : Color.white)
                    .foregroundColor(safeInternet == mode ? .white : mode.color)
                    .cornerRadius(27)
                    .overlay(
                        RoundedRectangle(cornerRadius: 27)
                            .stroke(mode.color, lineWidth: safeInternet == mode ? 0 : 1)
                    )
                if safeInternet == mode {
                    checkmarkCircle(color: safeInternet.color)
                }
            }
        })
    }

    func checkmarkCircle(color: Color) -> some View {
        Image(systemName: "checkmark.circle")
            .resizable()
            .frame(width: 20, height: 20)
            .foregroundColor(color)
            .background(Color.white)
            .cornerRadius(10)
            .offset(y: -21)
    }
    
    @MainActor static func redirect(updateView: (() -> Void)?, updateBlurIntensity: (() -> Void)?, safegazeSettingsChanged: (() -> Void)?, openShareSheet: (() -> Void)?, tab: Tab) -> UIView {
        let popupView = SafegazeView(tab: tab, safegazeSettingsChanged: safegazeSettingsChanged, openShareSheet: openShareSheet)
        return UIHostingController(rootView: popupView).view
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#if DEBUG
#Preview {
    SafegazeView(tab: Tab())
}
#endif
