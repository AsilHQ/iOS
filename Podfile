platform :ios, '15.5'

# ignore all warnings from all pods
inhibit_all_warnings!

target 'Core' do
  use_frameworks!
  pod 'LiteRTSwift', '~> 0.0.1-nightly', :subspecs => ['CoreML', 'Metal']
  pod 'MediaPipeTasksVision'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = '$(inherited)'
    end
  end
end

