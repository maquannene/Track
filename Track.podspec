Pod::Spec.new do |s|
s.name         = 'Track'
s.summary      = 'rack is write by Swift and thread safe cache. It is composed of DiskCache and MemoryCache which support LRU.'
s.version      = '1.0.0'
s.license      = { :type => 'MIT', :file => 'LICENSE' }
s.authors      = { 'maquannene' => 'maquan@wps.cn' }
s.homepage     = 'https://github.com/maquannene/Track'
s.platform     = :ios, '8.0'
s.ios.deployment_target = '8.0'
s.source       = { :git => 'https://github.com/maquannene/Track.git', :tag => '1.0.0' }
s.source_files = 'Track/*.{swift}'
s.frameworks = 'UIKit', 'QuartzCore'
end
