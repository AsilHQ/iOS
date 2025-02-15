//
//  SafegazeViewController.swift
//  DuckDuckGo
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import SnapKit
import WebKit
import UIKit
import Core

/// Displays shield settings and shield stats for a given URL
class SafegazeViewController: UIViewController, PopoverContentComponent {

  let associatedTab: Tab
  let webView: WKWebView
    
  var safegazeSettingsChanged: ((SafegazeViewController) -> Void)?

  private var statsUpdateObservable: AnyObject?

  init(associatedTab: Tab, webView: WKWebView) {
    self.associatedTab = associatedTab
    self.webView = webView

    super.init(nibName: nil, bundle: nil)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: animated)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.setNavigationBarHidden(false, animated: animated)
  }
    
  // MARK: - State

  private func updateShieldBlockStats() {
//     shieldsView.simpleShieldView.blockCountView.countLabel.attributedText = {
//          let string = NSMutableAttributedString(
//            string: String(tab.contentBlocker.stats.safegazeCount.noneFormattedString ?? "")
//          )
//          return string
//    }()
//    shieldsView.simpleShieldView.totalCountView.descriptionLabel.attributedText = {
//        let string = NSMutableAttributedString(
//            string: String(format: Strings.Shields.safegazeTotalCountLabel, BraveGlobalShieldStats.shared.safegazeCount.noneFormattedString ?? ""),
//            attributes: [.font: UIFont.systemFont(ofSize: 13.0), .foregroundColor: UIColor.braveLabel ]
//        )
//        return string
//    }()
  }

  private func updateContentView(to view: UIView, animated: Bool) {
    if animated {
      UIView.animate(
        withDuration: shieldsView.contentView == nil ? 0 : 0.1,
        animations: {
          self.shieldsView.contentView?.alpha = 0.0
        },
        completion: { _ in
          self.shieldsView.contentView = view
          view.alpha = 0
          self.updatePreferredContentSize()
          UIView.animate(withDuration: 0.1) {
            view.alpha = 1.0
          }
        })
    } else {
      shieldsView.contentView = view
    }
  }

  private func updatePreferredContentSize() {
    guard let visibleView = shieldsView.contentView else { return }
    let width = min(360, UIScreen.main.bounds.width - 20)
    // Ensure the a static width is given to the main view so we can calculate the height
    // correctly when we force a layout
    let height = visibleView.systemLayoutSizeFitting(
        CGSize(width: width, height: 0),
        withHorizontalFittingPriority: .required,
        verticalFittingPriority: .fittingSizeLevel
    ).height
    
    preferredContentSize = CGSize(
        width: width,
        height: height
    )
  }

  // MARK: -
  var shieldsView: View {
    return view as! View  // swiftlint:disable:this force_cast
  }

  override func loadView() {
      let newView = View(frame: .zero, associatedTab: associatedTab)
      newView.safegazeSettingsChanged = {
          self.dismiss(animated: true)
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
              self.webView.reload()
          }
      }
      newView.openShareSheet = {
          guard let url = URL(string: "https://apps.apple.com/tr/app/kahf-halal-browser/id6478084743") else { return }
          let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
          self.present(activityViewController, animated: true)
      }
      view = newView
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    updateShieldBlockStats()

    navigationController?.setNavigationBarHidden(true, animated: false)

    updatePreferredContentSize()
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }
}

extension SafegazeViewController {
  class View: UIView {

    private let scrollView = UIScrollView().then {
      $0.delaysContentTouches = false
    }

    var contentView: UIView? {
      didSet {
        oldValue?.removeFromSuperview()
        if let view = contentView {
          scrollView.addSubview(view)
          view.snp.makeConstraints {
            $0.edges.equalToSuperview()
          }
        }
      }
    }

    let stackView = UIStackView().then {
      $0.axis = .vertical
      $0.isLayoutMarginsRelativeArrangement = true
      $0.translatesAutoresizingMaskIntoConstraints = false
    }

    public var updateBgView: ((UIView, Bool) -> Void)?
    public var updateBlurIntensity: (() -> Void)?
    public var safegazeSettingsChanged: (() -> Void)?
    public var openShareSheet: (() -> Void)?
    var associatedTab: Tab
    
      
    init(frame: CGRect, associatedTab: Tab) {
      self.associatedTab = associatedTab
      super.init(frame: frame)

      backgroundColor = .systemBackground

      let popupView = SafegazeView.redirect(updateView: { [self] in
          setNeedsUpdateConstraints()
          layoutIfNeeded()
          updateBgView?(stackView, true)
      }, updateBlurIntensity: {
          self.updateBlurIntensity?()
      }, safegazeSettingsChanged: {
          self.safegazeSettingsChanged?()
      }, openShareSheet: {
          self.openShareSheet?()
      }, tab: associatedTab)
      stackView.addArrangedSubview(popupView)

      addSubview(scrollView)
      scrollView.addSubview(stackView)

      scrollView.snp.makeConstraints {
        $0.edges.equalToSuperview()
      }

      scrollView.contentLayoutGuide.snp.makeConstraints {
        $0.left.right.equalTo(self)
      }

      stackView.snp.makeConstraints {
        $0.edges.equalToSuperview()
      }

      contentView = stackView
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
      fatalError()
    }
  }
}
