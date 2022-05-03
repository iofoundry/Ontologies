require 'git'
require 'fileutils'
require 'redcarpet'

def log(text)
  puts "#{Time.now.utc}: #{text}"
end
  

log "started update"

$root = File.join('..', 'www')
Dir.mkdir($root) unless File.exists?($root)

def convert_readme
  out = File.join($root, 'index.html')
  inp = 'README.md'
  return if File.exists?(out) and File.stat(inp).mtime < File.stat(out).mtime

  log "Rendering #{inp} to #{out}"
  renderer = Redcarpet::Render::HTML.new(prettify: true)
  markdown = Redcarpet::Markdown.new(renderer, fenced_code_blocks: true)
  html = markdown.render(File.read(inp))
  
  File.open(out, 'w') do |f|
    f.write <<EOT
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Industrial Ontologies Foundary</title>
  <style type="text/css">
   body {
    font-family: "Open Sans", sans-serif;
   } 

   h1 {
     border-bottom: 1px solid #c9d1d9;
     margin-bottom: 14px;
     padding-bottom: 0.3em;
     margin-top: 24px;
     line-height: 1.25;
   }
  </style>
</head>
<body>
EOT
    f.write(html)
    f.write <<EOT
</body>
</html>
EOT
  end
end

log "Updating Repos"

system('git', 'pull')
system('git', 'submodule', 'update')

log "Updating ontologies"

dirs = nil
File.open('.gitmodules') do |f|
  dirs = f.read.split("\n").select { |l| l =~ /path/ }.map { |l| l.split.last }
end

def extract(git, mod, version, prefix)
  file = git.archive(version, nil, { format: 'tar', prefix: "#{prefix}#{mod}/" })
  list = `tar tf #{file}`.split("\n").select { |f| f =~ /\.rdf$/ }
  Dir.chdir($root) do
    log "Extracting #{version} to #{prefix}#{mod}/"
    system('tar', 'xvf', file, *list)
  end
end

dirs.each do |mod|
  git = Git.open(mod)
  tags = git.tags.map(&:name)
  unless tags.empty?
    tags.each do |tag|
      prefix = "#{tag.delete('-')}/"
      extract(git, mod, tag, prefix)
    end
    
    prefix = tags.sort.last.delete('-')

    Dir.chdir($root) do
      Dir["#{prefix}/*"].select { |d| File.directory?(d) }.each do |d|
        target = "./#{File.basename(d)}"

        log "Removing #{target}"
        FileUtils.rm_rf(target)
        
        log "linking #{d} to #{target}"
        FileUtils.ln_sf(d, target)
      end
    end
  else
    extract(git, mod, 'HEAD', '')
  end
end

convert_readme

puts "#{Time.now.utc}: completed update"


