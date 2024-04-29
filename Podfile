# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

source 'https://cdn.cocoapods.org/'
source 'https://github.com/TheraForge/OTFCocoapodSpecs'

target 'OTFCloudClientAPI' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  pod 'KeychainAccess'
  pod 'OTFCDTDatastore', '2.1.1-beta.4'
  pod 'OTFUtilities', '1.0.1-beta'
  # Pods for OTFCloudClientAPI

  target 'OTFCloudClientAPIWatchOS' do
    # Pods for testing
    use_frameworks!
    platform :watchos, '8.0'
    pod 'KeychainAccess'
    pod 'OTFCDTDatastore', '2.1.1-beta.4'
    pod 'OTFUtilities', '1.0.1-beta'
  end
  
  target 'OTFCloudClientAPITests' do
    # Pods for testing
  end

  post_install do |installer|
    installer.generated_projects.each do |project|
      project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
          config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '8.0'
        end
      end
    end
  end
end
