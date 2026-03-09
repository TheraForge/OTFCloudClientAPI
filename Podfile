# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

source 'https://cdn.cocoapods.org/'
source 'https://github.com/TheraForge/OTFCocoapodSpecs'

target 'OTFCloudClientAPI' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  platform :ios, '16.0'
  pod 'KeychainAccess'
  pod 'OTFCDTDatastore', '2.1.1-tf.2'
  pod 'OTFUtilities', '2.0.0'
  # Pods for OTFCloudClientAPI

  target 'OTFCloudClientAPIWatchOS' do
    # Pods for testing
    use_frameworks!
    platform :watchos, '9.0'
    pod 'KeychainAccess'
    pod 'OTFCDTDatastore', '2.1.1-tf.2'
    pod 'OTFUtilities', '2.0.0'
  end
  
  target 'OTFCloudClientAPITests' do
    # Pods for testing
  end

  post_install do |installer|
    installer.generated_projects.each do |project|
      project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
          config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '9.0'
        end
      end
    end
  end
end
