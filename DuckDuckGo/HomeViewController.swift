//
//  HomeViewController.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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

import UIKit
import Core
import Bookmarks
import Combine
import Common
import DDGSync
import Persistence
import RemoteMessaging
import SwiftUI
import BrowserServicesKit
import os.log
import SnapKit

class CreditButton: UIButton {
    var url: URL?
}

class HomeViewController: UIViewController, NewTabPage {

    @IBOutlet weak var ctaContainerBottom: NSLayoutConstraint!
    @IBOutlet weak var ctaContainer: UIView!

    @IBOutlet weak var collectionView: HomeCollectionView!
    
    @IBOutlet weak var daxDialogContainer: UIView!
    @IBOutlet weak var daxDialogContainerHeight: NSLayoutConstraint!
    weak var daxDialogViewController: DaxDialogViewController?
    var hostingController: UIHostingController<AnyView>?

    var logoContainer: UIView! {
        return delegate?.homeDidRequestLogoContainer(self)
    }
 
    var searchHeaderTransition: CGFloat = 0.0 {
        didSet {
            let percent = searchHeaderTransition > 0.99 ? searchHeaderTransition : 0.0

            // hide the keyboard if transitioning away
            if oldValue == 1.0 && searchHeaderTransition != 1.0 {
                chromeDelegate?.omniBar.resignFirstResponder()
            }
            
            delegate?.home(self, searchTransitionUpdated: percent)
            chromeDelegate?.omniBar.alpha = percent
            chromeDelegate?.tabBarContainer.alpha = percent
        }
    }

    var isDragging: Bool {
        collectionView.isDragging
    }

    weak var delegate: HomeControllerDelegate?
    weak var chromeDelegate: BrowserChromeDelegate?

    private var viewHasAppeared = false
    private var defaultVerticalAlignConstant: CGFloat = 0
    
    private let homePageConfiguration: HomePageConfiguration
    private let tabModel: Tab
    private let favoritesViewModel: FavoritesListInteracting
    private let appSettings: AppSettings
    private let syncService: DDGSyncing
    private let syncDataProviders: SyncDataProviders
    private let variantManager: VariantManager
    private let newTabDialogFactory: any NewTabDaxDialogProvider
    private let newTabDialogTypeProvider: NewTabDialogSpecProvider
    private var viewModelCancellable: AnyCancellable?
    private var favoritesDisplayModeCancellable: AnyCancellable?

    let privacyProDataReporter: PrivacyProDataReporting

    var hasFavoritesToShow: Bool {
        !favoritesViewModel.favorites.isEmpty
    }

    static func loadFromStoryboard(
        homePageDependecies: HomePageDependencies
    ) -> HomeViewController {
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        let controller = storyboard.instantiateViewController(identifier: "HomeViewController", creator: { coder in
            HomeViewController(
                coder: coder,
                homePageConfiguration: homePageDependecies.homePageConfiguration,
                tabModel: homePageDependecies.model,
                favoritesViewModel: homePageDependecies.favoritesViewModel,
                appSettings: homePageDependecies.appSettings,
                syncService: homePageDependecies.syncService,
                syncDataProviders: homePageDependecies.syncDataProviders,
                privacyProDataReporter: homePageDependecies.privacyProDataReporter,
                variantManager: homePageDependecies.variantManager,
                newTabDialogFactory: homePageDependecies.newTabDialogFactory,
                newTabDialogTypeProvider: homePageDependecies.newTabDialogTypeProvider
            )
        })
        return controller
    }

    required init?(
        coder: NSCoder,
        homePageConfiguration: HomePageConfiguration,
        tabModel: Tab,
        favoritesViewModel: FavoritesListInteracting,
        appSettings: AppSettings,
        syncService: DDGSyncing,
        syncDataProviders: SyncDataProviders,
        privacyProDataReporter: PrivacyProDataReporting,
        variantManager: VariantManager,
        newTabDialogFactory: any NewTabDaxDialogProvider,
        newTabDialogTypeProvider: NewTabDialogSpecProvider
    ) {
        self.homePageConfiguration = homePageConfiguration
        self.tabModel = tabModel
        self.favoritesViewModel = favoritesViewModel
        self.appSettings = appSettings
        self.syncService = syncService
        self.syncDataProviders = syncDataProviders
        self.privacyProDataReporter = privacyProDataReporter
        self.variantManager = variantManager
        self.newTabDialogFactory = newTabDialogFactory
        self.newTabDialogTypeProvider = newTabDialogTypeProvider

        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(HomeViewController.onKeyboardChangeFrame),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)

        collectionView.homePageConfiguration = homePageConfiguration
        configureCollectionView()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(remoteMessagesDidChange),
                                               name: RemoteMessagingStore.Notifications.remoteMessagesDidChange,
                                               object: nil)

        registerForBookmarksChanges()
        
        addWallpaper()
    }
    
    private func addWallpaper() {
        
        let wallpaperImageView = UIImageView()
        wallpaperImageView.contentMode = .scaleAspectFill
        self.view.addSubview(wallpaperImageView)
        self.view.sendSubviewToBack(wallpaperImageView)
        
        // Create container view
        let containerView = UIView()
        self.view.addSubview(containerView)
        
        // Create labels
        let titleLabel = UILabel()
        titleLabel.textColor = .white
        titleLabel.font = UIFont(name: "Lato-Regular", size: 13)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        containerView.addSubview(titleLabel)
        
        let subtitleLabel = UILabel()
        subtitleLabel.textColor = .white
        subtitleLabel.font = UIFont(name: "Lato-Regular", size: 11)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        containerView.addSubview(subtitleLabel)
        
        // Create credit button
        let creditButton = CreditButton()
        creditButton.titleLabel?.font = UIFont(name: "Lato-Regular", size: 7)
        creditButton.titleLabel?.textAlignment = .center
        creditButton.setTitleColor(.white, for: .normal)
        containerView.addSubview(creditButton)
        
        // Set up SnapKit constraints
        wallpaperImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualToSuperview().offset(-16)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualToSuperview().offset(-16)
        }
        
        creditButton.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualToSuperview().offset(-16)
            make.height.equalTo(10)
            make.bottom.equalToSuperview().offset(-6)
        }
        
        // Load and display wallpaper with metadata
        let (image, metadata, url) = WallpaperManager.getRandomWallpaper(selectedUrl: tabModel.selectedWallpaper)
        wallpaperImageView.image = image
        tabModel.selectedWallpaper = url
        if let metadata = metadata {
            titleLabel.text = metadata.title.isEmpty ? nil : metadata.title
            subtitleLabel.text = metadata.subtitle
            
            // Handle HTML in credit text
            if !metadata.credit.isEmpty {
                if let attributedString = WallpaperManager.createAttributedString(from: metadata.credit) {
                    let mutableAttrString = NSMutableAttributedString(attributedString: attributedString)
                    
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont(name: "Lato-Regular", size: 11)!,
                        .foregroundColor: UIColor.white
                    ]
                    
                    mutableAttrString.addAttributes(
                        attributes,
                        range: NSRange(location: 0, length: mutableAttrString.length)
                    )
                    
                    creditButton.setAttributedTitle(mutableAttrString, for: .normal)
                } else {
                    creditButton.setTitle(metadata.credit, for: .normal)
                }                
                // Add button action if URL exists
                if !metadata.url.isEmpty {
                    creditButton.addTarget(self, action: #selector(creditButtonTapped), for: .touchUpInside)
                    if let url = URL(string: metadata.url) {
                        creditButton.url = url
                    }
                }
            }
            
            // Hide empty elements
            titleLabel.isHidden = metadata.title.isEmpty
            subtitleLabel.isHidden = metadata.subtitle.isEmpty
            creditButton.isHidden = metadata.credit.isEmpty
            
            // Hide container if all elements are empty
            containerView.isHidden = metadata.title.isEmpty && metadata.subtitle.isEmpty && metadata.credit.isEmpty
        }
    }
    
    @objc private func creditButtonTapped(_ sender: UIButton) {
        guard let creditButton = sender as? CreditButton, let url = creditButton.url else { return }
        load(url: url)
    }

    private func registerForBookmarksChanges() {
        viewModelCancellable = favoritesViewModel.externalUpdates.sink { [weak self] _ in
            guard let self = self else { return }
            self.bookmarksDidChange()
            if self.favoritesViewModel.favorites.isEmpty {
                self.delegate?.home(self, didRequestHideLogo: false)
            }
        }

        favoritesDisplayModeCancellable = NotificationCenter.default.publisher(for: AppUserDefaults.Notifications.favoritesDisplayModeChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                self.favoritesViewModel.favoritesDisplayMode = self.appSettings.favoritesDisplayMode
                self.collectionView.reloadData()
            }
    }
    
    @objc func bookmarksDidChange() {
        configureCollectionView()
    }
    
    @objc func remoteMessagesDidChange() {
        DispatchQueue.main.async {
            Logger.remoteMessaging.info("Remote messages did change")
            self.collectionView.refreshHomeConfiguration()
            self.refresh()
        }
    }

    func configureCollectionView() {
        collectionView.configure(withController: self, favoritesViewModel: favoritesViewModel)
    }
    
    func enableContentUnderflow() -> CGFloat {
        return delegate?.home(self, didRequestContentOverflow: true) ?? 0
    }
    
    @discardableResult
    func disableContentUnderflow() -> CGFloat {
        return delegate?.home(self, didRequestContentOverflow: false) ?? 0
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.viewDidTransition(to: size)
        })
        self.collectionView.collectionViewLayout.invalidateLayout()
    }

    func refresh() {
        collectionView.reloadData()
    }
    
    func openedAsNewTab(allowingKeyboard: Bool) {
        collectionView.openedAsNewTab(allowingKeyboard: allowingKeyboard)
    }
    
    @IBAction func launchSettings() {
        delegate?.showSettings(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // If there's no tab switcher then this will be true, if there is a tabswitcher then only allow the
        //  stuff below to happen if it's being dismissed
        guard presentedViewController?.isBeingDismissed ?? true else { return }

        Pixel.fire(pixel: .homeScreenShown)
        sendDailyDisplayPixel()

        collectionView.didAppear()

        viewHasAppeared = true
        tabModel.viewed = true
    }
    
    var isShowingDax: Bool {
        return !daxDialogContainer.isHidden
    }

    func hideLogo() {
        delegate?.home(self, didRequestHideLogo: true)
    }
    
    func onboardingCompleted() {
//        presentNextDaxDialog()
    }

    func presentNextDaxDialog() {
        if variantManager.isContextualDaxDialogsEnabled {
            showNextDaxDialogNew(dialogProvider: newTabDialogTypeProvider, factory: newTabDialogFactory)
        } else {
            showNextDaxDialog(dialogProvider: newTabDialogTypeProvider)
        }
    }

    func showNextDaxDialog() {
        presentNextDaxDialog()
    }

    func reloadFavorites() {
        collectionView.reloadData()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
    }

    @IBAction func hideKeyboard() {
        // without this the keyboard hides instantly and abruptly
        UIView.animate(withDuration: 0.5) {
            self.chromeDelegate?.omniBar.resignFirstResponder()
        }
    }

    @objc func onKeyboardChangeFrame(notification: NSNotification) {
        guard let beginFrame = notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect else { return }
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        let diff = beginFrame.origin.y - endFrame.origin.y

        if diff > 0 {
            ctaContainerBottom.constant = endFrame.size.height - (chromeDelegate?.toolbarHeight ?? 0)
        } else {
            ctaContainerBottom.constant = 0
        }

        view.setNeedsUpdateConstraints()

        if viewHasAppeared {
            UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
        }
    }

    func load(url: URL) {
        delegate?.home(self, didRequestUrl: url)
    }

    func dismiss() {
        delegate = nil
        chromeDelegate = nil
        removeFromParent()
        view.removeFromSuperview()
    }
    
    func launchNewSearch() {
        collectionView.launchNewSearch()
    }

    private(set) lazy var faviconsFetcherOnboarding: FaviconsFetcherOnboarding =
        .init(syncService: syncService, syncBookmarksAdapter: syncDataProviders.bookmarksAdapter)
}

private extension HomeViewController {
    func sendDailyDisplayPixel() {

        let favoritesCount = favoritesViewModel.favorites.count
        let bucket = HomePageDisplayDailyPixelBucket(favoritesCount: favoritesCount)

        DailyPixel.fire(pixel: .newTabPageDisplayedDaily, withAdditionalParameters: ["FavoriteCount": bucket.value])
    }
}

extension HomeViewController: FavoritesHomeViewSectionRendererDelegate {
    
    func favoritesRenderer(_ renderer: FavoritesHomeViewSectionRenderer, didSelect favorite: BookmarkEntity) {
        guard let url = favorite.urlObject else { return }
        Pixel.fire(pixel: .favoriteLaunchedNTP)
        DailyPixel.fire(pixel: .favoriteLaunchedNTPDaily)
        Favicons.shared.loadFavicon(forDomain: url.host, intoCache: .fireproof, fromCache: .tabs)
        delegate?.home(self, didRequestUrl: url)
    }
    
    func favoritesRenderer(_ renderer: FavoritesHomeViewSectionRenderer, didRequestEdit favorite: BookmarkEntity) {
        delegate?.home(self, didRequestEdit: favorite)
    }

    func favoritesRenderer(_ renderer: FavoritesHomeViewSectionRenderer, favoriteDeleted favorite: BookmarkEntity) {
        delegate?.home(self, didRequestHideLogo: renderer.viewModel.favorites.count > 0)
    }

}

extension HomeViewController: HomeMessageViewSectionRendererDelegate {
    
    func homeMessageRenderer(_ renderer: HomeMessageViewSectionRenderer, didDismissHomeMessage homeMessage: HomeMessage) {
        refresh()
    }
}

extension HomeViewController: HomeScreenTransitionSource {
    var snapshotView: UIView {
        if let logoContainer = logoContainer, !logoContainer.isHidden {
            return logoContainer
        } else {
            return collectionView
        }
    }

    var rootContainerView: UIView {
        collectionView
    }
}
