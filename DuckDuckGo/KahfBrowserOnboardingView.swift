//
//  KahfBrowserOnboardingView.swift
//  DuckDuckGo
//
//  Copyright © 2024 KahfBrowser. All rights reserved.
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

import SwiftUI

enum BestApps {
    case x
    case gmail
    case facebook
    case youtube
    case instagram
    case spotify
    
    var title: String {
        switch self {
        case .x: return "X"
        case .gmail: return "Gmail"
        case .facebook: return "Facebook"
        case .youtube: return "Youtube"
        case .instagram: return "Instagram"
        case .spotify: return "Spotify"
        }
    }
    
    var url: String {
        switch self {
        case .x: return "https://x.com/"
        case .gmail: return "https://mail.google.com/"
        case .facebook: return "https://m.facebook.com/"
        case .youtube: return "https://m.youtube.com/"
        case .instagram: return "https://www.instagram.com/"
        case .spotify: return "https://open.spotify.com/"
        }
    }
    
    var icon: Image {
        switch self {
        case .x: Image(.x)
        case .gmail: Image(.gmail)
        case .facebook: Image(.facebook)
        case .youtube: Image(.youtube)
        case .instagram: Image(.instagram)
        case .spotify: Image(.spotify)
        }
    }
}

struct KahfBrowserOnboardingView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var isDecentInternetOn: Bool = AppUserDefaults().decentInternetOn
    
    public let tutorialSettings: TutorialSettings
    @State var stage = 1
    @State var selectedApps: [BestApps] = []
    
    var addFavorite: ((String, URL) -> Void)?
    
    var body: some View {
        switch stage {
        case 1: stage1View
        case 2: stage2View
        case 3: stage3View
        case 4: stage4View
        default: Text("")
        }
    }
    
    var stage1View: some View {
        ZStack {
            Image(.bgImg1).resizable().edgesIgnoringSafeArea(.all)
            VStack {
                Image(.onboardingLogo)
                    .padding(.bottom, 20)
                
                Image(.onboardingName)
                
                Spacer()
                
                title(textColor: .white)
                
                Button(action: {
                    stage += 1
                }, label: {
                    Text("Let's Go").foregroundColor(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 45)
                    .background(Color.black.opacity(0.5).cornerRadius(10))
                })
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                Spacer()
                
            }.frame(maxWidth: .infinity).padding(.top, 50)
        }
    }
    
    var stage2View: some View {
        ZStack {
            Image(.bgImg2).resizable().edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                
                title(textColor: Color(red: 187 / 255, green: 92 / 255, blue: 241 / 255))

                GeometryReader { geometry in
                    let maxFontSize: CGFloat = 15
                    let availableWidth = geometry.size.width * 0.9 // Adjust for padding
                    let calculatedFontSize = min(maxFontSize, availableWidth / 22) // Adjust factor for better fitting

                    Text("Experience a safer internet with Kahf Browser. Powered by advanced AI, it filters out indecent images and harmful content in real time, allowing you to browse while staying true to your moral values.")
                        .foregroundColor(Color.black)
                        .font(FontHelper.inter(size: calculatedFontSize, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7) // Allows the text to scale down if needed
                        .lineLimit(nil) // Allow multiple lines
                        .frame(height: 106)
                        .padding(.horizontal, 24)
                }
                .frame(height: 120)
                
                Button(action: {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }, label: {
                    Text("Set as Default Browser").foregroundColor(Color.white)
                        .font(FontHelper.poppins(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 45)
                        .background(Color(red: 69 / 255, green: 84 / 255, blue: 245 / 255).cornerRadius(10))
                })
                .padding(.horizontal, 16)
                .padding(.top, 20 )
                
                Button(action: {
                    stage += 1
                }, label: {
                    Text("Skip").foregroundColor(Color.black)
                        .font(FontHelper.poppins(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                })
                .padding(.top, 20)
                .padding(.bottom, 50)
    
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    var stage3View: some View {
        ZStack {
            Image(.bgImg3).resizable().edgesIgnoringSafeArea(.all)
            
            VStack {
                GeometryReader { geometry in
                    let availableWidth = geometry.size.width * 0.8 // Adjust for padding

                    let maxTitleFontSize: CGFloat = 35
                    let calculatedTitleFontSize = min(maxTitleFontSize, availableWidth / 6.5)

                    let maxSubtitleFontSize: CGFloat = 14
                    let calculatedSubtitleFontSize = min(maxSubtitleFontSize, availableWidth / 20)

                    VStack(spacing: 20) {
                        VStack {
                            Text("Choose")
                                .font(FontHelper.poppins(size: calculatedTitleFontSize, weight: .bold))
                                .foregroundColor(Color.black)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .frame(maxWidth: availableWidth)
                            
                            Text("the app you")
                                .font(FontHelper.poppins(size: calculatedTitleFontSize, weight: .bold))
                                .foregroundColor(Color.black)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .frame(maxWidth: availableWidth)
                            
                            Text("use most")
                                .font(FontHelper.poppins(size: calculatedTitleFontSize, weight: .bold))
                                .foregroundColor(Color.black)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .frame(maxWidth: availableWidth)
                        }

                        Text("Select your favorite apps to keep them handy in your home screen")
                            .font(FontHelper.poppins(size: calculatedSubtitleFontSize, weight: .semibold))
                            .foregroundColor(Color.black)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                            .lineLimit(3)
                            .frame(maxWidth: availableWidth)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 15) {
                        appButton(for: .youtube)
                        appButton(for: .facebook)
                        appButton(for: .x)
                    }
                    
                    HStack {
                        appButton(for: .gmail)
                    }
                }.frame(maxWidth: .infinity)
                
                Button(action: {
                    selectedApps.forEach { app in
                        addFavorite?(app.title, URL(string: app.url)!)
                    }
                    stage += 1
                }, label: {
                    Text("Next").foregroundColor(Color.white)
                        .font(FontHelper.poppins(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 45)
                        .background(Color(red: 69 / 255, green: 84 / 255, blue: 245 / 255).cornerRadius(10))
                })
                .padding(.horizontal, 16)
                .padding(.top, 45)
                
                Button(action: {
                    stage += 1
                }, label: {
                    Text("Skip for now").foregroundColor(Color.black)
                        .font(FontHelper.poppins(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                })
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 50)
                
                Spacer()
    
            }.padding(.top, 20).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    var stage4View: some View {
        ZStack {
            Image(.bgImg3).resizable().edgesIgnoringSafeArea(.all)
            VStack(spacing: 30) {
                
                Image(.onboardingPhone)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .background(Color.clear)
                    .padding(.top, 60)
            
                GeometryReader { geometry in
                    let availableWidth = geometry.size.width * 0.8 // Use 80% of the screen width

                    let maxTitleFontSize: CGFloat = 30
                    let calculatedTitleFontSize = min(maxTitleFontSize, availableWidth / 6.5) // Adjust based on width

                    VStack {
                        Text("Hide Indecent Images")
                            .font(FontHelper.poppins(size: calculatedTitleFontSize, weight: .bold))
                            .foregroundColor(Color(red: 187 / 255, green: 92 / 255, blue: 241 / 255))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7) // Allows scaling down if needed
                            .lineLimit(1) // Ensures it's always one line
                            .frame(maxWidth: availableWidth) // Limits the width dynamically
                            .fixedSize(horizontal: false, vertical: true) // Prevents vertical compression
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center) // Ensures VStack is centered
                }
                .frame(height: 50) // Adjust height to make sure it's properly centered
                
                
                VStack(spacing: 0) {
                    Text("Hiding inappropriate images.")
                        .foregroundColor(Color.black)
                        .font(FontHelper.inter(size: 15, weight: .semibold))
                        .multilineTextAlignment(.center)
                        
                    
                    Text("Avoid major sins")
                        .foregroundColor(Color.black)
                        .font(FontHelper.inter(size: 15, weight: .semibold))
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                Text("Device is compatible to hide indecent images")
                    .foregroundColor(Color.green)
                    .font(FontHelper.poppins(size: 12, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                VStack(spacing: 0) {
                    Button(action: {
                        withAnimation {
                            isDecentInternetOn = true
                            completeOnboarding()
                        }
                    }, label: {
                        Text("Enable Image Blurring").foregroundColor(Color.white)
                            .font(FontHelper.poppins(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 45)
                            .background(Color(red: 69 / 255, green: 84 / 255, blue: 245 / 255).cornerRadius(10))
                    })
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    
                    Button(action: {
                        completeOnboarding()
                    }, label: {
                        Text("Skip").foregroundColor(Color.black)
                            .font(FontHelper.poppins(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    })
                    .padding(.top, 20)
                    .padding(.bottom, 50)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.onChange(of: isDecentInternetOn, perform: { _ in
            AppUserDefaults().decentInternetOn = isDecentInternetOn
        })
    }
    
    func title(textColor: Color) -> some View {
        GeometryReader { geometry in
            let maxFontSize: CGFloat = 27
            let availableWidth = geometry.size.width * 0.9 // Adjust for padding
            let calculatedFontSize = min(maxFontSize, availableWidth / 10) // Adjust factor as needed

            VStack {
                Text("Clean, Safe and Decent")
                    .font(FontHelper.poppins(size: calculatedFontSize, weight: .bold))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5) // Allows scaling down if needed
                    .lineLimit(1)

                Text("browsing-powered by")
                    .font(FontHelper.poppins(size: calculatedFontSize, weight: .bold))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("AI")
                    .font(FontHelper.poppins(size: calculatedFontSize, weight: .bold))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .frame(width: availableWidth) // Ensures text doesn't overflow
            .padding(.horizontal, 16) // Add some padding for better spacing
        }
        .frame(height: 120)
    }
    
    func gradientOverlay(selected: Bool) -> some View {
        Group {
            if selected {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 62/255, green: 141/255, blue: 255/255, opacity: 0.5),
                                Color(red: 171/255, green: 106/255, blue: 255/255, opacity: 0.5)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            } else {
                EmptyView()
            }
        }
    }
    
    func appButton(for app: BestApps) -> some View {
        Button {
            if let index = selectedApps.firstIndex(of: app) {
                selectedApps.remove(at: index)
            } else {
                selectedApps.append(app)
            }
        } label: {
            ZStack {
                app.icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
            }
            .frame(width: 100, height: 100)
            .background(selectedApps.contains(app) ? Color.blue.opacity(0.2) : Color.white)
            .cornerRadius(10)
            .overlay(gradientOverlay(selected: selectedApps.contains(app)))
        }
    }
    
    func completeOnboarding() {
        tutorialSettings.hasSeenOnboarding = true
        self.presentationMode.wrappedValue.dismiss()
    }

}
