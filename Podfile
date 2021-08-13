platform :ios, '9.0'

def required_pods
  pod 'DTMHeatmap'
  pod 'Charts', '~> 3.6.0'
  pod 'AppAuth', '~> 1.4.0'
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
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '9.0'
    end
  end
end
