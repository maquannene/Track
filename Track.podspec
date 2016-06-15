Pod::Spec.new do |s|
s.name         = 'Track'
s.summary      = 'Track is a thread safe cache write by Swift. Composed of DiskCache and MemoryCache which support LRU.'
s.version      = '1.2.2'
s.license      = { :type => 'MIT', :file => 'LICENSE' }
s.authors      = { 'maquannene' => 'maquan@wps.cn' }
s.homepage     = 'https://github.com/maquannene/Track'
s.platform     = :ios, '8.0'
s.ios.deployment_target = '8.0'
s.source       = { :git => 'https://github.com/maquannene/Track.git', :tag => s.version.to_s }
s.source_files = 'Track/*.{swift}'
s.frameworks = 'UIKit', 'QuartzCore'
end
