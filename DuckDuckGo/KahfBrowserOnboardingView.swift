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
    public let tutorialSettings: TutorialSettings
    @State var stage = 1
    @State var selectedApps: [BestApps] = []
    
    var addFavorite: ((String, URL) -> Void)?
    
    var body: some View {
        switch stage {
        case 1: stage1View
        case 2: stage2View
        case 3: stage3View
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
                
                VStack {
                    Text("Fast, Safe, Decent")
                        .font(FontHelper.poppins(size: 27, weight: .bold))
                        .foregroundColor(Color.white)
                        .multilineTextAlignment(.center)
                    
                    Text("AI powered")
                        .font(FontHelper.poppins(size: 27, weight: .bold))
                        .foregroundColor(Color.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Browser")
                        .font(FontHelper.poppins(size: 27, weight: .bold))
                        .foregroundColor(Color.white)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 160)
                .padding(.horizontal, 24)
                
                Button(action: {
                    stage += 1
                }, label: {
                    Text("Let's Go").foregroundColor(Color.white)
                })
                .frame(maxWidth: .infinity)
                .frame(height: 45)
                .background(Color.black.opacity(0.5).cornerRadius(10))
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
                
                VStack {
                    Text("Fast, Safe, Decent")
                        .font(FontHelper.poppins(size: 27, weight: .bold))
                        .foregroundColor(Color(red: 187 / 255, green: 92 / 255, blue: 241 / 255))
                        .multilineTextAlignment(.center)
                    
                    Text("AI powered")
                        .font(FontHelper.poppins(size: 27, weight: .bold))
                        .foregroundColor(Color(red: 187 / 255, green: 92 / 255, blue: 241 / 255))
                        .multilineTextAlignment(.center)
                    
                    Text("Browser")
                        .font(FontHelper.poppins(size: 27, weight: .bold))
                        .foregroundColor(Color(red: 187 / 255, green: 92 / 255, blue: 241 / 255))
                        .multilineTextAlignment(.center)
                }
                .frame(height: 160)
                .padding(.horizontal, 24)
                .padding(.top, 40)

                Text("Browse the internet while keeping to your moral values as the Kahf Browser's AI hides indecent images and harmful content as you browse, making it the safest browser in the world.")
                    .foregroundColor(Color.black)
                    .font(FontHelper.inter(size: 15, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(height: 106)
                    .padding(.horizontal, 24)
                
                Button(action: {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }, label: {
                    Text("Set as Default Browser").foregroundColor(Color.white)
                        .font(FontHelper.poppins(size: 14, weight: .semibold))
                })
                .frame(maxWidth: .infinity)
                .frame(height: 45)
                .background(Color(red: 69 / 255, green: 84 / 255, blue: 245 / 255).cornerRadius(10))
                .padding(.horizontal, 16)
                .padding(.top, 20 )
                
                Button(action: {
                    stage += 1
                }, label: {
                    Text("Skip").foregroundColor(Color.black)
                        .font(FontHelper.poppins(size: 14, weight: .semibold))
                })
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 50)
    
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    var stage3View: some View {
        ZStack {
            Image(.bgImg3).resizable().edgesIgnoringSafeArea(.all)
            VStack(spacing: 30) {
                
                Image(.onboardingPhone)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .background(Color.clear)
                    .padding(.top, 60)
            
                
                Text("Hide Indecent Images")
                    .font(FontHelper.poppins(size: 30, weight: .bold))
                    .foregroundColor(Color(red: 187 / 255, green: 92 / 255, blue: 241 / 255))
                    .multilineTextAlignment(.center)
                
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
                        tutorialSettings.hasSeenOnboarding = true
                        selectedApps.forEach { app in
                            addFavorite?(app.title, URL(string: app.url)!)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    }, label: {
                        Text("Next").foregroundColor(Color.white)
                            .font(FontHelper.poppins(size: 14, weight: .semibold))
                    })
                    .frame(maxWidth: .infinity)
                    .frame(height: 45)
                    .background(Color(red: 69 / 255, green: 84 / 255, blue: 245 / 255).cornerRadius(10))
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    
                    Button(action: {
                        tutorialSettings.hasSeenOnboarding = true
                        self.presentationMode.wrappedValue.dismiss()
                    }, label: {
                        Text("Skip").foregroundColor(Color.black)
                            .font(FontHelper.poppins(size: 14, weight: .semibold))
                    })
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 50)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
    
    func setDefaultBrowser() {
        
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
                    .frame(width: 60, height: 60)
            }
            .frame(width: 100, height: 100)
            .background(selectedApps.contains(app) ? Color.blue.opacity(0.2) : Color.white)
            .cornerRadius(10)
            .overlay(gradientOverlay(selected: selectedApps.contains(app)))
        }
    }

}
