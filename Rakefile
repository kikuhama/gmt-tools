desc 'Run server'
task :run, [:port] do |task, args|
  port = args.port.to_i
  if port == 0
    port = "4567"
  end
  cmd = "bundle exec rackup -p #{port} -s puma -o 0.0.0.0"
  `#{cmd}`
end
