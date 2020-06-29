platform :ios, '9.0'

def required_pods
  pod 'DTMHeatmap'
  pod 'Charts', '~> 3.4.0'
  pod 'AppAuth', '~> 1.3.0'
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
