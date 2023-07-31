# frozen_string_literal: true

require 'rbnacl'
require 'base64'
require 'octokit'
require 'optparse'

require_relative 'lib/org_secrets'
require_relative 'lib/generate_dump'

puts <<-HEADER 

_____/\\\\\\\\\\\\\\\\\\\\\\\\_______/\\\\\\\\\\__________/\\\\\\\\\\\\\\\\\\\\\\____/\\\\\\\\____________/\\\\\\\\_        
 ___/\\\\\\//////////______/\\\\\\///\\\\\\______/\\\\\\/////////\\\\\\_\\/\\\\\\\\\\\\________/\\\\\\\\\\\\_       
  __/\\\\\\_______________/\\\\\\/__\\///\\\\\\___\\//\\\\\\______\\///__\\/\\\\\\//\\\\\\____/\\\\\\//\\\\\\_      
   _\\/\\\\\\____/\\\\\\\\\\\\\\__/\\\\\\______\\//\\\\\\___\\////\\\\\\_________\\/\\\\\\\\///\\\\\\/\\\\\\/_\\/\\\\\\_     
    _\\/\\\\\\___\\/////\\\\\\_\\/\\\\\\_______\\/\\\\\\______\\////\\\\\\______\\/\\\\\\__\\///\\\\\\/___\\/\\\\\\_    
     _\\/\\\\\\_______\\/\\\\\\_\\//\\\\\\______/\\\\\\__________\\////\\\\\\___\\/\\\\\\____\\///_____\\/\\\\\\_   
      _\\/\\\\\\_______\\/\\\\\\__\\///\\\\\\__/\\\\\\_____/\\\\\\______\\//\\\\\\__\\/\\\\\\_____________\\/\\\\\\_  
       _\\//\\\\\\\\\\\\\\\\\\\\\\\\/_____\\///\\\\\\\\\\/_____\\///\\\\\\\\\\\\\\\\\\\\\\/___\\/\\\\\\_____________\\/\\\\\\_ 
        __\\////////////_________\\/////_________\\///////////_____\\///______________\\///__

                            GitHub Organization Secrets Migrator (GOSM)
                                      With ❤️ from Xpirit.com

HEADER

subcommands = { import: nil, dump: nil }

subcommand = ARGV.shift
if subcommand.nil? || !subcommands.key?(subcommand.to_sym)
  puts 'Please provide a valid subcommand (import or dump).'
  exit 1
end

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: gosm #{subcommand} [opts]"

  opts.on('-oORG', '--org ORG', 'Source GitHub organization name') do |org|
    options[:org] = org
  end

  opts.on('-pPATH', '--dump-path PATH', 'Path to directory of dumped secrets for import') do |path|
    options[:path] = path
  end

  opts.on('-yPATH', '--workflow-file PATH', 'Output path for the dump GitHub Actions workflow') do |workflow_file|
    options[:workflow_file] = workflow_file
  end

  opts.on('-vVIS', '--imported-secret-visibility VIS', 'Visibility of imported secrets (default private)') do |v|
    options[:visibility] = v
  end

  opts.on('-h', '--help', 'Display help') do
    puts opts
    exit
  end
end.order!

case subcommand
when 'import'
  puts "Importing secrets to organization '#{options[:org]}' from dump '#{options[:path]}'"
when 'dump'
  puts "Generating an Actions workflow to dump secrets for '#{options[:org]}': '#{options[:workflow_file]}'"
end

unless ENV.key?('GH_PAT')
  puts 'Please provide a valid GitHub Personal Access Token in the GH_PAT environment variable.'
  exit 1
end

client = Octokit::Client.new(access_token: ENV['GH_PAT'])

if subcommand == 'import'
  unless options[:org] && options[:path]
    puts 'Please provide both the destination GitHub organization name and path to the directory of dumped secrets.'
    exit 1
  end

  options[:visibility] = 'private' unless options[:visibility]

  org_key_data = client.get_org_public_key(options[:org])
  org_public_key = RbNaCl::PublicKey.new(Base64.decode64(org_key_data.key))

  plaintext_secrets = Dir.glob(File.join(options[:path], '*.txt'))

  plaintext_secrets.each do |file_path|
    secret_name = File.basename(file_path, '.txt')

    File.open(file_path, 'r') do |file|
      puts "Importing #{secret_name} to #{options[:org]}"

      secret_content = file.read
      box = RbNaCl::Boxes::Sealed.from_public_key(org_public_key)
      encrypted_secret = box.encrypt(secret_content)

      puts "[Warning] #{secret_name} is empty." if secret_content.empty?

      client.create_or_update_org_secret(options[:org], secret_name,
                                         { encrypted_value: Base64.strict_encode64(encrypted_secret),
                                           key_id: org_key_data.key_id,
                                           visibility: options[:visibility] })
    end
  end

  puts 'Import complete ❤️'
end

if subcommand == 'dump'
  unless options[:org] && options[:workflow_file]
    puts 'ERROR: Please provide both the source organization name and path to output the workflow file.'
    exit 1
  end

  client.get_org_public_key(options[:org])
  list = client.list_org_secrets(options[:org])

  dump = DumpWorkflowGenerator.new
  yaml_content = dump.generate_dump_for(list.secrets.map(&:name).flatten)

  File.open(options[:workflow_file], 'w') do |file|
    file.write(yaml_content)
  end

  puts "Workflow for dumping '#{options[:org]}' secrets written to '#{options[:workflow_file]}'."
end

puts ""