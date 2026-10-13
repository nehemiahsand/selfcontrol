# Keep the pinned legacy dependencies buildable with modern Apple SDK headers.
# Changes are confined to generated Pods and reapplied by pod install.
patches = {
  'Pods/TransformerKit/Sources/NSValueTransformerName.h' => {
    '@import Darwin.Availability;' => '#include <Availability.h>'
  },
  'Pods/TransformerKit/Sources/NSValueTransformer+TransformerKit.m' => {
    '@import Darwin.Availability;' => '#include <Availability.h>'
  },
  'Pods/TransformerKit/Sources/TTTDateTransformers.m' => {
    '@import Darwin.C.xlocale;' => '#include <xlocale.h>'
  },
  'Pods/Sentry/Sources/SentryCrash/Recording/Tools/SentryCrashMachineContext.c' => {
    '#include "SentryCrashMachineContext.h"' => "#include <sys/_types/_ucontext64.h>\n#include \"SentryCrashMachineContext.h\""
  },
  'Pods/Sentry/Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_CPPException.cpp' => {
    '#include <typeinfo>' => "#include <typeinfo>\n#include <exception>"
  }
}
patches.each do |path, replacements|
  next unless File.file?(path)
  text = File.read(path)
  replacements.each do |before, after|
    next if text.include?(after)
    raise "Unsupported dependency source: #{path}" unless text.include?(before)
    text = text.sub(before, after)
  end
  File.chmod(0644, path)
  File.write(path, text)
end
# CocoaPods' legacy static-framework resource path omits Resources on macOS.
Dir.glob('Pods/Target Support Files/Pods-*/*resources*').each do |path|
  next unless File.file?(path)
  text = File.read(path)
  changed = text.gsub('MASPreferences.framework/en.lproj/', 'MASPreferences.framework/Resources/en.lproj/')
  File.write(path, changed) if changed != text
end
