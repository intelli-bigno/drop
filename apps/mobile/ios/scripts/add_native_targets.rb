# 네이티브 셸 타깃 배선 (BRU-160) — DropShare(공유 확장)·DropWidget(홈 위젯)을
# Runner.xcodeproj에 추가한다. 재실행해도 안전하다(있으면 갱신만).
#
# 실행:  cd apps/mobile/ios && ruby scripts/add_native_targets.rb
#
# 프로젝트 파일을 손으로 고치지 않는 이유: pbxproj 편집은 diff가 사람 눈에
# 검증 불가능하다. 이 스크립트가 무엇을 어떻게 추가하는지의 정본이다.
# 스펙 원본은 apps/ios/project.yml(XcodeGen)의 DropShare·DropWidget 타깃.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../Runner.xcodeproj', __dir__)
APP_BUNDLE_ID = 'com.intellieffect.drop.mobile'

# 확장은 SwiftUI containerBackground(iOS 17)를 쓴다. Runner(13.0)보다 높아도
# 된다 — 옛 OS에서는 확장만 설치되지 않는다.
EXTENSION_DEPLOYMENT_TARGET = '17.0'

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner 타깃이 없습니다' unless runner

development_team = runner.build_configurations
  .map { |c| c.build_settings['DEVELOPMENT_TEAM'] }.compact.first

# ── 파일 참조 도우미 ─────────────────────────────────────────────

def group_for(project, dir_name)
  group = project.main_group[dir_name] ||
          project.main_group.new_group(dir_name, dir_name)
  group.set_source_tree('SOURCE_ROOT')
  group.set_path(dir_name)
  group
end

def file_ref(group, file_name)
  group.files.find { |f| f.path == file_name } || group.new_file(file_name)
end

# Generated.xcconfig — FLUTTER_BUILD_NAME/NUMBER가 여기서 온다. 확장의
# 버전·빌드 번호는 앱과 같아야 App Store가 받는다.
generated_xcconfig = project.files.find { |f| f.real_path.to_s.end_with?('Flutter/Generated.xcconfig') }
raise 'Flutter/Generated.xcconfig 참조가 없습니다' unless generated_xcconfig

# ── Runner: 채널 소스 + App Group 엔타이틀먼트 ──────────────────

runner_group = project.main_group['Runner']
channel_ref = file_ref(runner_group, 'NativeShellChannel.swift')
unless runner.source_build_phase.files_references.include?(channel_ref)
  runner.add_file_references([channel_ref])
end
file_ref(runner_group, 'Runner.entitlements')
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# ── 확장 타깃 ────────────────────────────────────────────────────

# 두 확장이 공유하는 이식 조각 (SharedInbox·WidgetSnapshot·토큰).
shell_group = group_for(project, 'DropShell')
shell_refs = ['DropShellCore.swift', 'DropShellTokens.swift']
  .map { |name| file_ref(shell_group, name) }

def add_extension(project, runner, generated_xcconfig, development_team,
                  name:, source_refs:, info_plist:, entitlements:, bundle_suffix:)
  target = project.targets.find { |t| t.name == name }
  if target.nil?
    target = project.new_target(:app_extension, name, :ios,
                                EXTENSION_DEPLOYMENT_TARGET, nil, :swift)
  end

  missing = source_refs.reject { |ref| target.source_build_phase.files_references.include?(ref) }
  target.add_file_references(missing)

  target.build_configurations.each do |config|
    config.base_configuration_reference = generated_xcconfig
    settings = config.build_settings
    settings['PRODUCT_NAME'] = name
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{APP_BUNDLE_ID}.#{bundle_suffix}"
    settings['INFOPLIST_FILE'] = info_plist
    settings['CODE_SIGN_ENTITLEMENTS'] = entitlements
    settings['SWIFT_VERSION'] = '5.0'
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = EXTENSION_DEPLOYMENT_TARGET
    settings['TARGETED_DEVICE_FAMILY'] = '1'
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['DEVELOPMENT_TEAM'] = development_team if development_team
    # 앱과 같은 버전·빌드 번호 (Generated.xcconfig의 FLUTTER_BUILD_*).
    settings['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
    settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
    settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
    settings['SKIP_INSTALL'] = 'YES'
    settings['LD_RUNPATH_SEARCH_PATHS'] =
      '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  end

  # Runner에 임베드 — 없으면 빌드는 되지만 앱에 확장이 실리지 않는다.
  embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
  if embed.nil?
    embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
    embed.dst_subfolder_spec = Xcodeproj::Constants::COPY_FILES_BUILD_PHASE_DESTINATIONS[:plug_ins]
    embed.dst_path = ''
  end
  unless embed.files_references.include?(target.product_reference)
    build_file = embed.add_file_reference(target.product_reference)
    build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  end

  # Flutter의 "Thin Binary" 스크립트가 앱 번들 전체를 읽는다 — 임베드가 그 뒤에
  # 서면 빌드 사이클("Cycle inside Runner")이 난다. 반드시 그 앞으로 옮긴다.
  thin = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
  if thin
    phases = runner.build_phases
    while phases.index(embed) > phases.index(thin)
      phases.move(embed, phases.index(embed) - 1)
    end
  end
  runner.add_dependency(target)

  target
end

share_group = group_for(project, 'DropShare')
add_extension(
  project, runner, generated_xcconfig, development_team,
  name: 'DropShare',
  source_refs: [file_ref(share_group, 'ShareViewController.swift')] + shell_refs,
  info_plist: 'DropShare/Info.plist',
  entitlements: 'DropShare/DropShare.entitlements',
  bundle_suffix: 'share'
)
file_ref(share_group, 'Info.plist')
file_ref(share_group, 'DropShare.entitlements')

widget_group = group_for(project, 'DropWidget')
add_extension(
  project, runner, generated_xcconfig, development_team,
  name: 'DropWidget',
  source_refs: [
    file_ref(widget_group, 'DropWidgetBundle.swift'),
    file_ref(widget_group, 'DropWidget.swift'),
  ] + shell_refs,
  info_plist: 'DropWidget/Info.plist',
  entitlements: 'DropWidget/DropWidget.entitlements',
  bundle_suffix: 'widget'
)
file_ref(widget_group, 'Info.plist')
file_ref(widget_group, 'DropWidget.entitlements')

project.save
puts "완료: #{project.targets.map(&:name).join(', ')}"
