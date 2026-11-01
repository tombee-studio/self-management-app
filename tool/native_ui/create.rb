require 'xcodeproj'
path='/private/tmp/iris-native-ui/NativeUI.xcodeproj'
project=Xcodeproj::Project.new(path)
target=project.new_target(:ui_test_bundle,'NativeUI',:ios,'16.0')
file=project.main_group.new_file('/private/tmp/iris-native-ui/NativeUI.swift')
target.source_build_phase.add_file_reference(file)
target.build_configurations.each do |config|
 config.build_settings['GENERATE_INFOPLIST_FILE']='YES'
 config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']='studio.tombee.iris.stgNativeUI'
 config.build_settings['SWIFT_VERSION']='5.0'
 config.build_settings['CODE_SIGNING_ALLOWED']='NO'
 config.build_settings['TARGETED_DEVICE_FAMILY']='1,2'
end
project.save
scheme=Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.add_test_target(target)
scheme.save_as(project.path,'NativeUI',true)
