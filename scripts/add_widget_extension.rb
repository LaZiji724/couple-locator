#!/usr/bin/env ruby
# 给 ios/Runner.xcodeproj 增加「小组件 + 锁屏实时活动」Widget Extension（含 App Group 权限）。
# 默认工程不含扩展 → 侧载最稳；需要小组件时在 CI/本机运行本脚本再打包（见 docs/IOS_SIDELOAD.md）。
# 用法：ruby scripts/add_widget_extension.rb
require 'xcodeproj'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
IOS = File.join(ROOT, 'ios')
proj_path = File.join(IOS, 'Runner.xcodeproj')
proj = Xcodeproj::Project.open(proj_path)

if proj.targets.any? { |t| t.name == 'CoupleWidgets' }
  puts 'CoupleWidgets 已存在，跳过'
  exit 0
end

runner = proj.targets.find { |t| t.name == 'Runner' } or abort('找不到 Runner target')
bundle_id = runner.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER']
bundle_id = 'com.couple.coupleLocator' if bundle_id.nil? || bundle_id.include?('$')

ext = proj.new_target(:app_extension, 'CoupleWidgets', :ios, '14.0')
ext.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{bundle_id}.CoupleWidgets"
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = 'CoupleWidgets/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS'] = 'CoupleWidgets/CoupleWidgets.entitlements'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['SKIP_INSTALL'] = 'YES'
  s['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  s['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  s['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
end

group = proj.main_group.new_group('CoupleWidgets', 'CoupleWidgets')
swift = group.new_file('CoupleWidgetBundle.swift')
group.new_file('Info.plist')
group.new_file('CoupleWidgets.entitlements')
ext.add_file_references([swift])

# 主 App 的 App Group 权限
FileUtils.cp(File.join(IOS, 'Runner', 'Runner.entitlements.widgets'), File.join(IOS, 'Runner', 'Runner.entitlements'))
runner_group = proj.main_group['Runner']
runner_group.new_file('Runner.entitlements')
runner.build_configurations.each { |c| c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements' }

# 嵌入扩展到主 App（PlugIns）
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(ext.product_reference, true)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
runner.add_dependency(ext)

# 避免与 Flutter 的 "Thin Binary" 脚本形成构建环：把 Embed 阶段挪到脚本阶段之前
phases = runner.build_phases
phases.delete(embed)
thin_idx = phases.index { |p| p.respond_to?(:name) && p.name.to_s.include?('Thin Binary') } || phases.length
phases.insert(thin_idx, embed)

proj.save
puts "已添加 CoupleWidgets（#{bundle_id}.CoupleWidgets）并启用 App Group"
