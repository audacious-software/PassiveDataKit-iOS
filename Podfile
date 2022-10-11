platform :ios, '12.0'

def required_pods
  pod 'DTMHeatmap'
  pod 'Charts', '~> 4.1.0'
  pod 'AppAuth', '~> 1.6.0'
  pod 'AFNetworking', '~> 4.0'
end

target 'PassiveDataKit' do
  use_frameworks!

  required_pods
  
  target 'PassiveDataKitTests' do
    inherit! :search_paths
    use_frameworks!
    required_pods
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
