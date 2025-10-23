#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'ios/Pods/Pods.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  if target.name == 'BoringSSL-GRPC'
    puts "Fixing #{target.name}..."
    target.build_configurations.each do |config|
      # OTHER_CFLAGSから-Gを削除
      other_cflags = config.build_settings['OTHER_CFLAGS'] || []
      if other_cflags.is_a?(String)
        other_cflags = other_cflags.split(' ')
      end
      other_cflags = other_cflags.reject { |flag| flag == '-G' }
      config.build_settings['OTHER_CFLAGS'] = other_cflags.join(' ')

      # OPENSSL_NO_ASMを追加
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
      unless config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'].include?('OPENSSL_NO_ASM=1')
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'OPENSSL_NO_ASM=1'
      end

      puts "  #{config.name}: #{config.build_settings['OTHER_CFLAGS']}"
    end
  end
end

project.save
puts "Done!"
