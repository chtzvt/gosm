# frozen_string_literal: true

require_relative 'yaml_parser_monkeypatch'

# DumpWorkflowGenerator produces a GitHub Actions workflow configured to dump the
# specified organization secrets.

# The class contains a static base template, which is parsed, modified with the provided
# secret names, and re-serialized.

class DumpWorkflowGenerator
  @@template = <<-TEMPLATE
        name: "Dump Secrets"

        on:
          workflow_dispatch:

        jobs:
            run:
              name: "Dump Secrets"
              runs-on: ubuntu-latest

              steps:
                  - name: "Check out repository"
                    uses: actions/checkout@v3

                  - uses: ruby/setup-ruby@v1
                    with:
                      ruby-version: 3.2.0
                      bundler-cache: true

                  - name: "Generate Dump"
                    shell: ruby {0}
                    env:
                      PLACEHOLDER: ""
                    run: |
                          Dir.mkdir('secrets_dump')

                          ENV.each do |k,v|
                              next unless k.start_with?('scdmp_')
                              secret_value = ENV[k]
                              secret_name = k.sub("scdmp_", "")

                              File.open("secrets_dump/\#{secret_name}.txt", "w") do |f|
                                  f.write secret_value
                                  f.close
                              end
                          end
                  - uses: actions/upload-artifact@v3
                    with:
                      name: secrets-dump
                      path: secrets_dump/
                      retention-days: 1
  TEMPLATE

  def generate_dump_for(secrets)
    template_yml = YAML.safe_load(@@template)

    template_yml['jobs']['run']['steps'].each do |step|
      next unless step['name'] == 'Generate Dump'

      secrets.each do |secret|
        step['env']["scdmp_#{secret}"] = "${{secrets.#{secret.strip}}}"
      end

      step['env'].delete('PLACEHOLDER')
    end

    YAML.dump_stream(template_yml).gsub(/^ +([A-Z_]+):/, '\1:')
  end
end
